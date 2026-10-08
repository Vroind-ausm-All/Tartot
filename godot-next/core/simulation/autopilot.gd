extends RefCounted
class_name Autopilot
## Spielt das Spiel ohne Spieler (Simulation/Autopilot.cs).
##
## Nicht optimal, sondern *vernuenftig* - etwa auf dem Niveau eines
## aufmerksamen Spielers im dritten Run. Liegt im Kern, weil Tests,
## Balancing-Messung und der Paritaetsbeweis gegen C# ihn brauchen.
## Jede Entscheidung und jede Reihenfolge (auch die der Hand beim
## Durchprobieren) ist bewusst wie in C#, sonst laufen die Spuren auseinander.

const ALL_SLOTS := [Enums.SlotPosition.PAST, Enums.SlotPosition.PRESENT, Enums.SlotPosition.FUTURE]
const P := Enums.GamePhase
const PT := Enums.PathType
const FLOAT_MIN := -3.4028234663852886e38
## Ab so viel Gold lohnt der Weg zum Haendler ueberhaupt.
const WORTH_SHOPPING_GOLD := 60
## Unter diese Groesse duennt der Autopilot nicht weiter aus.
const MINIMUM_DECK := 8

## Obergrenze fuer die Deckgroesse, ab der nur noch gedünnt wird.
var deck_target: int = 14
var max_turns_per_fight: int = 120
## Dreht das Startdeck komplett auf die umgekehrte Seite (nur fuer Messreihen).
var reverse_starting_deck: bool = false
## Meta-Fortschritt, aus dem die Lesarten uebernommen werden.
var meta: MetaProgress = null
## Figur und Schleier. null = Wahrsagerin ohne Schleier.
var setup: RunSetup = null
## Nach dem Finale in die Spirale weitergehen.
var continue_into_spiral: bool = false
## Das Spiel des letzten Runs.
var last_game: GameController = null

func play_run(seed: int, max_fights := 30) -> RunOutcome:
	var game := GameController.new(seed, meta, setup)
	last_game = game
	if reverse_starting_deck:
		for card in game.run.deck:
			card.orientation = Enums.Orientation.REVERSED
	var outcome := RunOutcome.new()
	var guard := 0
	while game.phase != P.GAME_OVER and game.run.fight_index < max_fights and guard < 5000:
		guard += 1
		step(game, outcome)

	var run := game.run
	outcome.fights_cleared = run.fight_index
	outcome.deck_size = run.deck.size()
	outcome.gold = run.gold
	outcome.fate = run.fate_score_total
	outcome.hp = run.hp
	outcome.charm_stacks = run.charm_total()
	outcome.deck_resonance = run.deck_resonance
	outcome.shop_removals = run.shop_removals
	outcome.reached_limit = run.fight_index >= max_fights
	outcome.won = run.won
	outcome.act_reached = run.act()
	outcome.spiral_depth = ActCatalog.spiral_depth(run.fight_index)
	outcome.darkness = run.darkness
	var stats := run.stats
	outcome.stats = stats.to_dictionary()
	outcome.world_spreads = stats.world_spreads
	outcome.longest_chain = stats.longest_chain
	outcome.best_hit = stats.best_hit
	outcome.events_seen = stats.events_seen
	outcome.pacts_accepted = stats.pacts_accepted
	outcome.cards_lost_to_death = stats.cards_lost_to_death
	outcome.bosses_defeated = stats.bosses_defeated
	outcome.darkest_shimmer = stats.darkest_shimmer
	return outcome

## Ein einzelner Schritt: das, was die aktuelle Phase verlangt.
func step(game: GameController, outcome: RunOutcome = null) -> void:
	if outcome == null:
		outcome = RunOutcome.new()
	match game.phase:
		P.COMBAT:
			var record := FightRecord.new()
			record.index = game.run.fight_index
			record.enemy_id = game.combat.enemy.definition.id
			record.tier = game.combat.enemy.definition.tier
			record.hp_before = Num.dv(game.run.hp, maxi(1, game.run.max_hp))
			record.turns = play_combat(game)
			outcome.turns_played += record.turns
			record.hp_after = Num.dv(game.run.hp, maxi(1, game.run.max_hp))
			record.died = game.phase == P.GAME_OVER
			record.gold_after = game.run.gold
			outcome.fights.append(record)
			if record.died:
				outcome.died_against = game.combat.enemy.definition.name if game.combat != null else "-"
		P.REWARD:
			_take_reward(game)
		P.PATH_CHOICE:
			var path := _choose_path(game)
			if path == PT.ELITE:
				outcome.elites_fought += 1
			if path == PT.SHOP:
				outcome.shop_visits += 1
			if game.paths.has(PT.SHOP):
				outcome.paths_with_shop += 1
			game.choose_path(path)
		P.SHOP:
			_shop(game)
		P.RITUAL:
			_ritual(game)
		P.ORACLE:
			game.choose_oracle("XXI")
			game.continue_from_offgame()
		P.EVENT:
			_play_event(game)
		P.REST:
			outcome.rests_taken += 1
			_rest(game)
		P.BOSS_LOOT:
			game.choose_boss_loot(_choose_boss_loot(game))
		P.VICTORY:
			if continue_into_spiral:
				game.continue_into_spiral()
			else:
				game.end_run()

# ------------------------------------------------------------ Kampf
func play_combat(game: GameController) -> int:
	var turns := 0
	while game.phase == P.COMBAT and turns < max_turns_per_fight:
		turns += 1
		if not play_turn(game):
			break
	return turns

## Ein einzelner Zug: Pakt beantworten, legen, ausfuehren.
func play_turn(game: GameController) -> bool:
	if not arrange(game):
		return false
	game.resolve_turn()
	return true

## Legt die beste Legung auf den Tisch, ohne sie auszufuehren.
func arrange(game: GameController) -> bool:
	if game.combat.pact_pending:
		game.answer_pact(_accept_pact(game))
	_use_healing_if_low(game)
	var layout := _best_layout(game)
	_clear_slots(game)
	for entry in layout:
		game.combat_system.place_card(game.combat, entry[0], entry[1])

	if game.combat.slots.is_empty():
		if game.combat.hand.is_empty():
			return false
		for slot in ALL_SLOTS:
			if game.combat_system.place_card(game.combat, game.combat.hand[0].instance_id, slot):
				break
		if game.combat.slots.is_empty():
			return false
	return true

## Die beste Legung als Vorschlag, ohne den Tisch zu veraendern: was vorher
## lag, liegt danach wieder da. Fuer Hinweise und Vorfuehrungen.
## Ergebnis: [[instance_id, slot], ...]
func suggest_layout(game: GameController) -> Array:
	var before: Array = []
	for slot in game.combat.slots:
		before.append([game.combat.slots[slot].instance_id, slot])
	var best := _best_layout(game)
	for entry in before:
		game.combat_system.place_card(game.combat, entry[0], entry[1])
	return best

## Probiert alle Karten-/Positions-Kombinationen durch und nimmt die mit
## der besten Vorschau.
func _best_layout(game: GameController) -> Array:
	var hand: Array = game.combat.hand.duplicate()
	var best: Array = []
	var best_value := FLOAT_MIN
	var incoming := _expected_incoming_damage(game)
	# Der Turm: ein eingestuerzter Platz kommt gar nicht erst in Frage.
	var open: Array = []
	for s in ALL_SLOTS:
		if game.combat.blocked_slot != s:
			open.append(s)

	for combo: Array in _combinations(hand, mini(open.size(), hand.size())):
		for slots: Array in _permutations(open, combo.size()):
			_clear_slots(game)
			for i in combo.size():
				game.combat_system.place_card(game.combat, combo[i].instance_id, slots[i])
			var value := _evaluate(game, combo, slots, incoming)
			if value > best_value:
				best_value = value
				best = []
				for i in combo.size():
					best.append([combo[i].instance_id, slots[i]])
	_clear_slots(game)
	return best

func _evaluate(game: GameController, combo: Array, slots: Array, incoming: int) -> float:
	var score := game.combat_system.preview_score(game.run, game.combat)
	if score == null:
		return FLOAT_MIN

	var value := Num.f(score.fate_damage)

	# Ueberschuessiger Schaden zaehlt wenig - toeten reicht.
	var enemy_pool := game.combat.enemy.hp + game.combat.enemy.shield
	if value > enemy_pool:
		value = Num.add(enemy_pool, Num.mul(Num.sub(value, enemy_pool), 0.15))

	# In Lebensgefahr zaehlt Verteidigung mehr als Schaden.
	var survivable := game.run.hp + game.combat.player_shield - incoming
	if survivable <= 0:
		var defensive := 0
		for c: CardInstance in combo:
			if c.definition.suit == Enums.Suit.PENTACLES or c.definition.suit == Enums.Suit.CUPS:
				defensive += 1
		value = Num.add(value, Num.mul(defensive, 40.0))

	# Die Zukunft ist wertlos, wenn man den Zug nicht ueberlebt - gemeint ist
	# die Position, an der die Karte wirkt, nicht wo sie liegt.
	var effective: Array = []
	for s in slots:
		effective.append(game.combat_system.effective_slot(game.combat, s))
	if survivable <= 0 and effective.has(Enums.SlotPosition.FUTURE):
		value = Num.sub(value, 25.0)

	# Der Mond: verdeckte Karten sind ein Wagnis, die Vorschau luegt ein wenig.
	for c: CardInstance in combo:
		if game.combat.veiled_cards.has(c.instance_id):
			value = Num.mul(value, 0.7)
			break

	# Der Tod: die gezeichnete Karte in die Zukunft legen rettet sie.
	var marked := game.combat.marked_card_id
	if marked != "" and survivable > 0:
		for i in combo.size():
			if combo[i].instance_id == marked and effective[i] == Enums.SlotPosition.FUTURE:
				value = Num.add(value, 30.0)

	# Musterkette halten ist etwas wert, auch wenn der Treffer gleich waere.
	if score.has_pattern and game.combat.pattern_chain > 0:
		value = Num.add(value, Num.mul(4.0, mini(5, game.combat.pattern_chain)))
	return value

static func _clear_slots(game: GameController) -> void:
	for slot in ALL_SLOTS:
		game.combat_system.return_slot_to_hand(game.combat, slot)

static func _expected_incoming_damage(game: GameController) -> int:
	var enemy := game.combat.enemy
	# Der Mond verbirgt die Absicht: dann mit einem normalen Angriff rechnen.
	if enemy.intent_hidden:
		return enemy.definition.base_attack + enemy.attack_ramp
	match enemy.intent:
		Enums.IntentType.GUARD:
			return 0
		Enums.IntentType.FRENZY:
			return enemy.intent_value * 2
		Enums.IntentType.HEX:
			@warning_ignore("integer_division")
			return maxi(1, enemy.intent_value / 2)
	return enemy.intent_value

# ------------------------------------------------------- Off-Game
func _take_reward(game: GameController) -> void:
	if game.run.deck.size() >= deck_target or game.rewards.is_empty():
		game.skip_reward_for_fate()
		return
	var best_index := 0
	var best_value := FLOAT_MIN
	for i in game.rewards.size():
		var value := _reward_value(game.rewards[i])
		if value > best_value:
			best_value = value
			best_index = i
	game.choose_reward(best_index)

static func _reward_value(reward: RewardOption) -> float:
	match reward.type:
		Enums.RewardType.CHARM:
			return 30.0
		Enums.RewardType.ITEM:
			return 12.0
		Enums.RewardType.FATE:
			return Num.mul(reward.fate, 0.2)
		Enums.RewardType.CARD:
			if reward.card == null:
				return 0.0
			var value := Num.add(reward.card.rank, 10.0 if reward.card.is_major() else 0.0)
			value = Num.add(value, Num.mul(reward.card_level - 1, 4.0))
			value = Num.add(value, Num.mul(reward.card_shimmer, 2.0))
			return Num.add(value, 6.0 if reward.card_edition != Enums.CardEdition.NONE else 0.0)
	return 0.0

static func _hp_share(run: RunState) -> float:
	return Num.dv(run.hp, maxi(1, run.max_hp))

func _choose_path(game: GameController) -> int:
	var run := game.run
	var hp := _hp_share(run)
	var paths := game.paths
	if paths.has(PT.REST) and hp < Num.f(0.55):
		return PT.REST
	# Ausduennen hat Vorrang, solange das Deck ueber dem Ziel liegt.
	if paths.has(PT.RITUAL) and run.deck.size() > deck_target:
		return PT.RITUAL
	if paths.has(PT.SHOP) and run.gold >= WORTH_SHOPPING_GOLD:
		return PT.SHOP
	if paths.has(PT.ELITE) and hp > Num.f(0.70):
		return PT.ELITE
	if paths.has(PT.EVENT):
		return PT.EVENT
	if paths.has(PT.REST) and hp < Num.f(0.80):
		return PT.REST
	if paths.has(PT.RITUAL):
		return PT.RITUAL
	return PT.FIGHT

## Ereignisse: das Erste, was nicht Weitergehen heisst - ausser bei wenig
## Leben. Der Autopilot liest den Hinweistext wie ein Mensch.
static func _play_event(game: GameController) -> void:
	var run := game.run
	var choices: Array = game.current_event.choices if game.current_event != null else []
	var hp := _hp_share(run)
	var best_index := -1
	var best_value := FLOAT_MIN
	for i in choices.size():
		if not game.can_choose_event_option(i):
			continue
		var hint: String = choices[i].hint
		var value := 0.0 if choices[i].label == "Weitergehen" else 1.0
		if hint.contains("Heile"):
			value = Num.add(value, Num.mul(Num.sub(1.0, hp), 3.0))
		if hint.contains("HP") and hint.contains("−") and hp < Num.f(0.5):
			value = Num.sub(value, 2.0)
		if hint.contains("Max-HP") and hint.contains("Tausche") and run.max_hp < 60:
			value = Num.sub(value, 2.0)
		if value > best_value:
			best_value = value
			best_index = i
	if best_index >= 0:
		game.choose_event_option(best_index)
	game.continue_from_offgame()

static func _rest(game: GameController) -> void:
	var run := game.run
	if run.hp < Num.mul(run.max_hp, 0.65) or run.deck.is_empty():
		game.rest_heal()
	else:
		game.rest_study(_strongest(run))

func _choose_boss_loot(game: GameController) -> int:
	var run := game.run
	if run.hp < Num.mul(run.max_hp, 0.40):
		return Enums.BossLootChoice.BANISH
	if run.deck.size() < deck_target - 2 and game.omen_card() != null:
		return Enums.BossLootChoice.BIND
	return Enums.BossLootChoice.SOAK

## Heiltraenke nicht horten: unter einem Drittel HP trinken.
static func _use_healing_if_low(game: GameController) -> void:
	var run := game.run
	@warning_ignore("integer_division")
	if run.hp >= run.max_hp / 3:
		return
	for item in GameCatalog.items():
		if item.effect != Enums.ItemEffectType.HEAL:
			continue
		if int(run.items.get(item.id, 0)) > 0:
			game.use_item(item.id)
			return

## Den Pakt nur mit Polster annehmen.
static func _accept_pact(game: GameController) -> bool:
	var run := game.run
	return run.hp > Num.mul(run.max_hp, 0.60) and run.max_hp - CombatSystem.pact_cost(game.combat) >= 50

func _shop(game: GameController) -> void:
	# Erst aufraeumen, dann kaufen.
	while game.run.deck.size() > deck_target:
		var worst := _weakest(game.run)
		if worst == null or not game.can_remove_at_shop(worst):
			break
		if not game.remove_card_at_shop(worst):
			break

	for i in game.shop_offers.size():
		# Karten nur kaufen, solange Platz im Deck ist.
		var offer := game.shop_offers[i]
		if offer.reward.type == Enums.RewardType.CARD and game.run.deck.size() >= deck_target:
			continue
		game.buy_shop_offer(i)

	# Was uebrig bleibt, wird Kraft: die staerkste Karte veredeln.
	var guard := 0
	while guard < 3 and not game.run.deck.is_empty():
		if not game.refine_at_shop(_strongest(game.run)):
			break
		guard += 1

	game.continue_from_offgame()

func _ritual(game: GameController) -> void:
	if game.run.deck.size() > MINIMUM_DECK:
		game.ritual_remove(_weakest(game.run))
	else:
		game.ritual_evolve(_strongest(game.run))
	game.continue_from_offgame()

static func _strength(card: CardInstance) -> int:
	return card.effective_rank() + card.level * 2 + (8 if card.definition.is_major() else 0)

static func _strongest(run: RunState) -> CardInstance:
	return Num.groesstes(run.deck, func(c: CardInstance) -> int: return _strength(c))

static func _weakest(run: RunState) -> CardInstance:
	return Num.kleinstes(run.deck, func(c: CardInstance) -> int: return _strength(c))

# --------------------------------------------------- Kombinatorik
## Alle Teilmengen der Groesse size, size-1, ... 1 - in derselben
## Reihenfolge wie die C#-Generatoren.
static func _combinations(source: Array, size: int) -> Array:
	var out: Array = []
	for n in range(size, 0, -1):
		_choose(source, n, 0, [], out)
	return out

static func _choose(source: Array, n: int, start: int, current: Array, out: Array) -> void:
	if current.size() == n:
		out.append(current.duplicate())
		return
	for i in range(start, source.size()):
		current.append(source[i])
		_choose(source, n, i + 1, current, out)
		current.pop_back()

static func _permutations(remaining: Array, n: int) -> Array:
	if n == 0:
		return [[]]
	var out: Array = []
	for i in remaining.size():
		var rest := remaining.duplicate()
		rest.remove_at(i)
		for tail: Array in _permutations(rest, n - 1):
			var list: Array = [remaining[i]]
			list.append_array(tail)
			out.append(list)
	return out
