extends RefCounted
class_name GameController
## Der Ablauf eines Runs: Kampf, Beute, Wege, Haendler, Ritual, Orakel,
## Ereignis, Rast, Finale, Spirale (GameController.cs).
##
## Kennt keine Oberflaeche. Die UI ruft Methoden auf und liest Zustand;
## alles Spielrelevante passiert hier und in den Systemen dahinter.

const P := Enums.GamePhase
const PT := Enums.PathType

## Gold fuer den direkten Weg ohne Umweg.
const DIRECT_PATH_GOLD := 12
## Anteil der Max-HP, den eine Rast heilt.
const REST_HEAL_FRACTION := 0.30
## Anteil der Max-HP, der zwischen zwei Akten zurueckkommt.
const ACT_TRANSITION_HEAL := 0.25
## Schleier 4: so viel Max-HP weniger.
const VEIL_HP_COST := 4
## Je so viel Ueberschuss gibt es ein Gold.
const OVERKILL_PER_GOLD := 8
const SOAK_DARKNESS := 6
const BIND_DARKNESS := 10
const BANISH_GOLD := 70
const BANISH_LIGHT := 8
const SPIRAL_ENTRY_HEAL := 0.40
## Grundpreis fuers Vergessen beim Haendler, vor Rabatten.
const REMOVAL_BASE_PRICE := 45
const REMOVAL_PRICE_STEP := 25
const REFINE_BASE_PRICE := 70
const REFINE_PRICE_STEP := 30
## Wachstum der Spirale je Tiefe (double, wie in C#).
const SPIRAL_HP_GROWTH := 1.08
const SPIRAL_HP_CURVE := 0.008
const SPIRAL_RULES := [Enums.BossRule.TOWER, Enums.BossRule.MOON, Enums.BossRule.DEATH,
	Enums.BossRule.WHEEL, Enums.BossRule.DEVIL, Enums.BossRule.HANGED_MAN]

var _rng: DeterministicRandom
var combat_system: CombatSystem
var progression: ProgressionSystem
## Der Seed dieses Runs. Teilbar, reproduzierbar.
var seed: int = 1337
var _meta: MetaProgress
var _setup: RunSetup

var run: RunState
var combat: CombatState
var phase: int = P.COMBAT
var rewards: Array[RewardOption] = []
var paths: Array[int] = []
var shop_offers: Array[ShopOffer] = []
var last_victory: VictorySummary
var last_turn: TurnResult
var message: String = ""

## Das laufende Ereignis (Phase EVENT).
var current_event: EventDefinition
var event_resolved: bool = false
var event_epilogue: String = ""

## meta: optional. Lesarten, Story-Flags, Charm-Pool und das Grab werden beim
## Start in den Run kopiert - danach ist der Run in sich geschlossen.
## setup: Figur, Schleier, Tageskarte. null = Wahrsagerin ohne Schleier.
## _restoring: nur fuer restore() - baut nichts auf.
func _init(p_seed := 1337, meta: MetaProgress = null, setup: RunSetup = null, _restoring := false) -> void:
	seed = p_seed
	_meta = meta
	_setup = setup if setup != null else RunSetup.new()
	if _restoring:
		return
	# Getrennte Stroeme: ein Reroll im Laden darf die Kartenzuege im
	# naechsten Kampf nicht verschieben, sonst ist der Seed wertlos.
	var root := DeterministicRandom.new(seed)
	_rng = root.stream("world")
	combat_system = CombatSystem.new(root.stream("combat"))
	progression = ProgressionSystem.new(root.stream("progression"))
	new_run()

func world_random_snapshot() -> Dictionary:
	return _rng.snapshot()

func combat_random_snapshot() -> Dictionary:
	return combat_system.random_snapshot()

func progression_random_snapshot() -> Dictionary:
	return progression.random_snapshot()

## Stellt einen gespeicherten Run wieder her - einschliesslich eines
## laufenden Kampfes, denn auf dem Handy wird die App jederzeit weggeraeumt.
static func restore(save: SaveData) -> GameController:
	assert(save != null and save.run != null, "Speicherstand ohne Run.")
	var game := GameController.new(save.seed, null, null, true)
	game._rng = DeterministicRandom.restore(save.world_random)
	game.combat_system = CombatSystem.new(DeterministicRandom.restore(save.combat_random))
	game.progression = ProgressionSystem.new(DeterministicRandom.restore(save.progression_random))
	game.run = save.run
	game.combat = save.combat
	game.phase = save.phase

	# Phasen, deren Angebot nicht mitgespeichert wird, werden neu aufgebaut.
	match game.phase:
		P.REWARD:
			game.rewards = game.progression.generate_rewards(game.run)
		P.PATH_CHOICE:
			game._generate_paths()
		P.SHOP:
			game.open_shop()
		P.EVENT:
			# Das Ereignis selbst wird gespeichert: ein neu gezogenes waere
			# ein Reroll durch App-Neustart.
			game.current_event = EventCatalog.find(save.event_id)
			game.event_resolved = save.event_resolved
			game.event_epilogue = save.event_epilogue
			if game.current_event == null:
				game.start_fight(true)
		P.BOSS_LOOT:
			if game.combat == null:
				game._generate_paths()
				game.phase = P.PATH_CHOICE
		P.COMBAT:
			if game.combat == null:
				# Kampfphase ohne Kampfzustand: neuen Kampf beginnen.
				game.start_fight(false)

	game.message = "Fortgesetzt."
	return game

## Speichert den aktuellen Stand als JSON.
func save(indented := false) -> String:
	return SaveSystem.serialize(self, indented)

# ------------------------------------------------------------ Run
func new_run() -> void:
	var deuter := DeuterCatalog.find(_setup.deuter_id)
	run = GameCatalog.create_run(deuter)
	run.veil = maxi(0, mini(DeuterCatalog.MAX_VEIL, _setup.veil))
	run.is_daily = _setup.is_daily
	if run.veil >= 4:
		run.max_hp -= VEIL_HP_COST
		run.hp = run.max_hp

	# Die Tageskarte ist fuer alle gleich - kein Meta-Fortschritt darin.
	if not run.is_daily:
		_apply_meta(run, _meta)

	# Die Bosse stehen von Anfang an fest und sind angekuendigt.
	run.act_bosses.clear()
	for a in range(1, ActCatalog.ACT_COUNT + 1):
		run.act_bosses.append((_rng.pick(ActCatalog.bosses_of(a)) as EnemyDefinition).id)
	# Akt IV: Die Welt oder die rote Sonne - ebenfalls von Anfang an bekannt.
	run.act_bosses.append((_rng.pick(ActCatalog.finales()) as EnemyDefinition).id)

	combat = null
	last_victory = null
	last_turn = null
	current_event = null
	rewards.clear()
	paths.clear()
	shop_offers.clear()
	run.fight_index = 0
	phase = P.COMBAT
	start_fight(false)
	var boss := upcoming_boss()
	message = "Akt I: %s. Am Ende wartet %s." % [ActCatalog.ACT_NAMES[1], boss.name if boss != null else ""]

## Der angekuendigte Boss des aktuellen Akts.
func upcoming_boss() -> EnemyDefinition:
	var a := run.act()
	if a == 4:
		return finale_of_run()
	if a < 1 or a > run.act_bosses.size():
		return null
	return ActCatalog.find(run.act_bosses[a - 1])

func start_fight(advance: bool) -> void:
	if advance:
		run.fight_index += 1
	# Die Resonanz vor dem Kampf auffrischen.
	progression.update_deck_resonance(run)
	var enemy := _build_enemy()
	combat = combat_system.start_combat(run, enemy)
	phase = P.COMBAT

	if enemy.is_boss():
		var texts: Array[String] = []
		for r in enemy.rules:
			texts.append(ActCatalog.rule_text(r, 0, enemy.rules_weakened))
		message = ("%s erscheint. %s" % [enemy.name, " ".join(texts)]).strip_edges()
	elif enemy.tier == Enums.EnemyTier.ELITE:
		message = "Elite: %s versperrt den Weg." % enemy.name
	else:
		message = "%s tritt aus dem Schatten." % enemy.name

func resolve_turn() -> TurnResult:
	if phase != P.COMBAT:
		return null
	last_turn = combat_system.resolve_turn(run, combat)
	var log := last_turn.log
	message = "\n".join(log.slice(maxi(0, log.size() - 4)))

	if last_turn.victory:
		_on_victory()
	elif last_turn.defeat:
		phase = P.GAME_OVER
		message = "Der Run endet in Akt %s, Kampf %d. Gesamt-Fate: %d." % [
			Num.roman(mini(4, run.act())), run.fight_index + 1, run.fate_score_total]
	return last_turn

## Beantwortet das Angebot des Teufels.
func answer_pact(accept: bool) -> bool:
	if phase != P.COMBAT or combat == null:
		return false
	var ok := combat_system.answer_pact(run, combat, accept)
	if ok:
		message = "Du unterschreibst. Deine Legungen treffen härter – dein Leben ist kürzer." if accept \
			else "Du lehnst ab. Der Teufel lächelt und schlägt härter zu."
	return ok

func _on_victory() -> void:
	var enemy := combat.enemy.definition
	last_victory = progression.resolve_victory(run, combat)
	var stats := run.stats
	stats.fights_won += 1
	stats.most_shield_at_victory = maxi(stats.most_shield_at_victory, combat.player_shield)
	if combat.turn == 1:
		stats.one_turn_kills += 1
	for card in run.deck:
		EventCatalog.note_shimmer(run, card)

	# Ueberschuss: der Treffer, der mehr nimmt, als da war, zahlt aus.
	var overkill := combat.last_overkill
	if overkill > 0:
		@warning_ignore("integer_division")
		var gold := mini(overkill_gold_cap(run.act()), overkill / OVERKILL_PER_GOLD)
		run.gold += gold
		last_victory.overkill_gold = gold
		stats.best_overkill = maxi(stats.best_overkill, overkill)

	if enemy.tier == Enums.EnemyTier.ELITE:
		stats.elites_defeated += 1

	if enemy.is_boss():
		stats.bosses_defeated += 1
		if run.deck.size() <= 8:
			stats.thin_boss_kills += 1
		# Jedes gefallene Omen hinterlaesst Tinte.
		run.add_darkness(6)

		if enemy.tier == Enums.EnemyTier.FINALE:
			run.won = true
			phase = P.VICTORY
			message = "DIE WELT IST NICHT DAS ENDE."
			return

		if enemy.act <= ActCatalog.ACT_COUNT and not run.defeated_bosses.has(enemy.id):
			run.defeated_bosses.append(enemy.id)
		phase = P.BOSS_LOOT
		message = "%s fällt. Das Omen liegt vor dir. " % enemy.name + \
			("Überschuss: +%d Gold." % last_victory.overkill_gold if last_victory.overkill_gold > 0 else "")
		return

	rewards = progression.generate_rewards(run, 3, enemy.tier == Enums.EnemyTier.ELITE)
	phase = P.REWARD
	message = "Sieg. +%d Fate, +%d Gold. " % [last_victory.fate_earned, last_victory.gold_earned] + \
		("Überschuss: +%d Gold. " % last_victory.overkill_gold if last_victory.overkill_gold > 0 else "") + \
		("%s wurde vom Schicksal berührt." % last_victory.champion.definition.name if last_victory.champion != null else "")

static func overkill_gold_cap(a: int) -> int:
	return 4 + 4 * mini(4, maxi(1, a))

# ---------------------------------------------------- Omen-Beute
## Die Karten, die beim TRAENKEN dunkler werden: die drei, die im
## Bosskampf am meisten geleistet haben.
func soak_targets() -> Array[CardInstance]:
	var from_fight: Array[CardInstance] = []
	if combat != null:
		var sorted := Num.sortiert(combat.contributions.values(),
			func(c: PlayedCardContribution) -> float: return c.score(), true)
		for c: PlayedCardContribution in sorted:
			if from_fight.size() >= 3:
				break
			if run.deck.has(c.card):
				from_fight.append(c.card)
	var by_strength := Num.sortiert(run.deck,
		func(c: CardInstance) -> int: return c.level * 3 + c.shimmer * 6 + c.definition.rank, true)
	for card: CardInstance in by_strength:
		if from_fight.size() >= 3:
			break
		if not from_fight.has(card):
			from_fight.append(card)
	return from_fight

## Das Grosse Arkanum, das BINDEN ins Deck holt.
func omen_card() -> CardDefinition:
	if combat == null or combat.enemy == null or combat.enemy.definition == null:
		return null
	var id := combat.enemy.definition.omen_card_id
	return null if id == "" else GameCatalog.card(id)

func choose_boss_loot(choice: int) -> bool:
	if phase != P.BOSS_LOOT:
		return false
	match choice:
		Enums.BossLootChoice.SOAK:
			var cards := soak_targets()
			var names: Array[String] = []
			for card in cards:
				card.level += 1
				EventCatalog.darken(run, card)
				names.append("%s (%s)" % [card.definition.name, shimmer_name(card.shimmer)])
			run.add_darkness(SOAK_DARKNESS)
			message = "TRÄNKEN: " + ", ".join(names) + " trinken die Tinte des Omens."
		Enums.BossLootChoice.BIND:
			var omen := omen_card()
			if omen == null:
				return false
			var card := CardInstance.new(omen)
			card.level = 2
			card.shimmer = Enums.Shimmer.BLOOD
			card.orientation = Enums.Orientation.REVERSED
			run.deck.append(card)
			EventCatalog.note_shimmer(run, card)
			run.add_darkness(BIND_DARKNESS)
			message = "BINDEN: %s gehört jetzt dir – verkehrt herum und blutig." % omen.name
		_:
			run.gold += BANISH_GOLD
			var healed := _heal(Num.rnd(Num.mul(run.max_hp, 0.20)))
			run.add_darkness(-BANISH_LIGHT)
			message = "BANNEN: +%d Gold, +%d HP. Das Licht kehrt ein wenig zurück." % [BANISH_GOLD, healed]

	progression.update_deck_resonance(run)

	# Zwischen den Akten atmet man durch - nicht in der Spirale.
	if not ActCatalog.is_spiral(run.fight_index):
		var fraction := Num.sub(ACT_TRANSITION_HEAL, 0.10) if run.veil >= 7 else Num.f(ACT_TRANSITION_HEAL)
		var healed := _heal(Num.rnd(Num.mul(run.max_hp, fraction)))
		var next_act := ActCatalog.act_of(run.fight_index + 1)
		if next_act <= ActCatalog.ACT_COUNT:
			message += "\nAkt %s: %s. Du atmest durch (+%d HP)." % [Num.roman(next_act), ActCatalog.ACT_NAMES[next_act], healed]
		else:
			message += "\nNur noch die Welt steht vor dir. Du atmest durch (+%d HP)." % healed

	_generate_paths()
	phase = P.PATH_CHOICE
	return true

func _heal(amount: int) -> int:
	var before := run.hp
	run.hp = mini(run.max_hp, run.hp + maxi(0, amount))
	return run.hp - before

static func shimmer_name(shimmer: int) -> String:
	match shimmer:
		Enums.Shimmer.WHITE: return "Weiß"
		Enums.Shimmer.INDIGO: return "Indigo"
		Enums.Shimmer.GOLD: return "Gold"
		Enums.Shimmer.BLOOD: return "Blut"
		Enums.Shimmer.BLACK: return "Schwarz"
	return "Matt"

# ------------------------------------------------------- Sieg
## Nach dem Finale: weiter in die Schwarze Spirale.
func continue_into_spiral() -> void:
	if phase != P.VICTORY:
		return
	var healed := _heal(Num.rnd(Num.mul(run.max_hp, SPIRAL_ENTRY_HEAL)))
	_generate_paths()
	phase = P.PATH_CHOICE
	message = "Die Schwarze Spirale öffnet sich. Sie hat kein Ende – nur eine Tiefe. (+%d HP)" % healed

## Beendet einen gewonnenen Run (oder bricht einen ab).
func end_run() -> void:
	phase = P.GAME_OVER

# ---------------------------------------------------- Belohnung
func choose_reward(index: int) -> void:
	if phase != P.REWARD or index < 0 or index >= rewards.size():
		return
	var reward := rewards[index]
	progression.take_reward(run, reward)
	message = "Belohnung erhalten: %s." % reward.title
	_generate_paths()
	phase = P.PATH_CHOICE

func skip_reward_for_fate() -> void:
	if phase != P.REWARD:
		return
	var fate := 40 + run.fight_index * 8
	run.fate += fate
	message = "Belohnung übersprungen: +%d Fate. Dein Deck bleibt dünn." % fate
	_generate_paths()
	phase = P.PATH_CHOICE

# ------------------------------------------------------- Wegwahl
func choose_path(path: int) -> void:
	if phase != P.PATH_CHOICE:
		return
	run.steps_since_shop = 0 if path == PT.SHOP else run.steps_since_shop + 1
	run.steps_since_rest = 0 if path == PT.REST else run.steps_since_rest + 1
	run.last_path = path

	match path:
		PT.FIGHT:
			run.gold += DIRECT_PATH_GOLD
			start_fight(true)
			message = "Kein Umweg (+%d Gold). " % DIRECT_PATH_GOLD + message
		PT.ELITE:
			run.next_fight_elite = true
			start_fight(true)
		PT.SHOP:
			open_shop()
		PT.RITUAL:
			phase = P.RITUAL
			message = "Ritual: Wähle eine Karte aus deinem Deck und verändere ihr Schicksal."
		PT.ORACLE:
			phase = P.ORACLE
			message = "Das Orakel bietet drei Prophezeiungen."
		PT.EVENT:
			_start_event()
		PT.REST:
			phase = P.REST
			message = "RAST: Ruhe dich aus oder lies eine Karte neu."

func continue_from_offgame() -> void:
	if phase != P.SHOP and phase != P.RITUAL and phase != P.ORACLE and phase != P.EVENT and phase != P.REST:
		return
	current_event = null
	start_fight(true)

## Drei Wege nach jedem Kampf. Der direkte Kampf ist immer dabei, die
## anderen beiden zieht das Schicksal - mit Garantien.
func _generate_paths() -> void:
	var next := run.fight_index + 1
	var boss_next := ActCatalog.is_boss_fight(next) or ActCatalog.is_finale(next) or ActCatalog.is_spiral_boss(next)

	var forced: Array[int] = []
	# Vor dem Omen: immer eine Rast anbieten.
	if boss_next or run.steps_since_rest >= 5:
		forced.append(PT.REST)
	# Ohne Haendler kann niemand ein Deck bauen.
	if run.steps_since_shop >= 4:
		forced.append(PT.SHOP)

	var candidates: Array = [PT.SHOP, PT.RITUAL, PT.ORACLE, PT.EVENT, PT.REST]
	# Elite nie zweimal in Folge, nie direkt vor einem Boss und nicht in der Spirale.
	if not boss_next and not ActCatalog.is_spiral(next) and run.last_path != PT.ELITE \
			and next % ActCatalog.FIGHTS_PER_ACT != 0:
		candidates.append(PT.ELITE)
	# Ereignisse sind der haeufigste Umweg - sie tragen die Geschichten.
	candidates.append(PT.EVENT)

	paths = [PT.FIGHT]
	for path in forced:
		if paths.size() < 3 and not paths.has(path):
			paths.append(path)
	var guard := 0
	while paths.size() < 3:
		guard += 1
		if guard > 50:
			break
		var pick: int = _rng.pick(candidates)
		if not paths.has(pick):
			paths.append(pick)
	_rng.shuffle(paths)

# ----------------------------------------------------- Ereignis
func _start_event() -> void:
	var eligible: Array = []
	var weights: Array = []
	for e in EventCatalog.all():
		if e.is_eligible(run):
			eligible.append(e)
			weights.append(e.weight)
	if eligible.is_empty():
		# Alle Szenen gesehen: dann wenigstens eine Rast.
		phase = P.REST
		message = "Der Weg ist still. Du rastest."
		return

	# Geschichten ueber Runs haben Vorrang, damit sie weitergehen.
	current_event = _rng.pick_weighted(eligible, weights)
	event_resolved = false
	event_epilogue = ""
	run.seen_events.append(current_event.id)
	run.stats.events_seen += 1
	phase = P.EVENT
	message = current_event.title

func can_choose_event_option(index: int) -> bool:
	return phase == P.EVENT and current_event != null and not event_resolved \
		and index >= 0 and index < current_event.choices.size() \
		and current_event.choices[index].is_available(run)

func choose_event_option(index: int) -> bool:
	if not can_choose_event_option(index):
		return false
	var choice := current_event.choices[index]
	event_epilogue = choice.run(EventContext.new(run, _rng))
	event_resolved = true
	progression.update_deck_resonance(run)
	message = event_epilogue
	return true

# ---------------------------------------------------------- Rast
func rest_heal_amount() -> int:
	var fraction := Num.sub(REST_HEAL_FRACTION, 0.10) if run.veil >= 7 else Num.f(REST_HEAL_FRACTION)
	return Num.rnd(Num.mul(run.max_hp, fraction))

## Rasten: heilen, dann weiter.
func rest_heal() -> bool:
	if phase != P.REST:
		return false
	var healed := _heal(rest_heal_amount())
	start_fight(true)
	message = "Du rastest: +%d HP. " % healed + message
	return true

## Rasten: eine Karte neu lesen (+1 Stufe), dann weiter.
func rest_study(card: CardInstance) -> bool:
	if phase != P.REST or card == null or not run.deck.has(card):
		return false
	card.level += 1
	progression.update_deck_resonance(run)
	start_fight(true)
	message = "Du liest %s neu: Stufe %d. " % [card.definition.name, card.level] + message
	return true

# -------------------------------------------------------- Haendler
func open_shop() -> void:
	phase = P.SHOP
	shop_offers.clear()
	var card := _random_card()
	var reversed := _rng.chance(Num.mul(run.darkness, 0.005))
	var card_offer := RewardOption.new()
	card_offer.type = Enums.RewardType.CARD
	card_offer.card = card
	card_offer.title = card.name
	card_offer.description = card.description
	card_offer.card_orientation = Enums.Orientation.REVERSED if reversed else Enums.Orientation.UPRIGHT
	shop_offers.append(_make_shop_offer(card_offer, 38))

	var charms: Array = []
	for c in GameCatalog.charms():
		if run.charm_allowed(c.id):
			charms.append(c)
	var i := 0
	while i < 2 and not charms.is_empty():
		var charm: CharmDefinition = _rng.pick(charms)
		var r := RewardOption.new()
		r.type = Enums.RewardType.CHARM
		r.charm = charm
		r.title = charm.name
		r.description = charm.description
		shop_offers.append(_make_shop_offer(r, 58 + i * 7))
		i += 1
	var item: ItemDefinition = _rng.pick(GameCatalog.items())
	var item_offer := RewardOption.new()
	item_offer.type = Enums.RewardType.ITEM
	item_offer.item = item
	item_offer.title = item.name
	item_offer.description = item.description
	shop_offers.append(_make_shop_offer(item_offer, 46))
	message = "Der Händler öffnet seinen Mantel."

## Was das naechste Vergessen beim Haendler kostet. Der Buchhalter zahlt doppelt.
func removal_price() -> int:
	return progression.shop_price(run, REMOVAL_BASE_PRICE + run.shop_removals * REMOVAL_PRICE_STEP) \
		* (2 if run.deuter_rule == Enums.DeuterRule.BOOKKEEPER else 1)

func can_remove_at_shop(card: CardInstance) -> bool:
	return phase == P.SHOP and card != null and run.deck.has(card) \
		and run.deck.size() > GameCatalog.MINIMUM_DECK_SIZE and run.gold >= removal_price()

## Loescht eine Karte beim Haendler gegen Gold.
func remove_card_at_shop(card: CardInstance) -> bool:
	if not can_remove_at_shop(card):
		message = "Dünner geht es nicht." if run.deck.size() <= GameCatalog.MINIMUM_DECK_SIZE else "Nicht genug Gold."
		return false
	run.gold -= removal_price()
	run.shop_removals += 1
	run.deck.erase(card)
	run.removed_cards.append(card)
	progression.update_deck_resonance(run)
	message = "%s wurde vergessen." % card.definition.name
	return true

## Veredeln beim Haendler: eine Karte steigt eine Stufe und dunkelt nach.
func refine_price() -> int:
	return progression.shop_price(run, REFINE_BASE_PRICE + run.shop_refines * REFINE_PRICE_STEP)

func can_refine_at_shop(card: CardInstance) -> bool:
	return phase == P.SHOP and card != null and run.deck.has(card) and run.gold >= refine_price()

func refine_at_shop(card: CardInstance) -> bool:
	if not can_refine_at_shop(card):
		message = "Nicht genug Gold."
		return false
	run.gold -= refine_price()
	run.shop_refines += 1
	card.level += 1
	EventCatalog.darken(run, card)
	run.add_darkness(2)
	progression.update_deck_resonance(run)
	message = "%s wurde veredelt: Stufe %d, %s." % [card.definition.name, card.level, shimmer_name(card.shimmer)]
	return true

func buy_shop_offer(index: int) -> bool:
	if phase != P.SHOP or index < 0 or index >= shop_offers.size():
		return false
	var offer := shop_offers[index]
	if offer.sold:
		return false
	if not run.free_next_shop_purchase and run.gold < offer.price:
		message = "Nicht genug Gold."
		return false
	if run.free_next_shop_purchase:
		run.free_next_shop_purchase = false
	else:
		run.gold -= offer.price
	progression.take_reward(run, offer.reward)
	offer.sold = true
	message = "Gekauft: %s." % offer.reward.title
	return true

# ---------------------------------------------------------- Ritual
func ritual_remove(card: CardInstance) -> bool:
	var ok := progression.remove_card(run, card)
	message = "%s wurde vergessen." % card.definition.name if ok else "Das Ritual kann diese Karte nicht löschen."
	return ok

func ritual_mirror(card: CardInstance) -> bool:
	var ok := progression.mirror_card(run, card)
	message = "%s wurde gespiegelt." % card.definition.name if ok else "Spiegelung nicht möglich."
	return ok

func ritual_flip(card: CardInstance) -> bool:
	var ok := progression.flip_card(run, card)
	message = "%s wurde umgekehrt." % card.definition.name if ok else "Umkehrung nicht möglich."
	return ok

func ritual_evolve(card: CardInstance) -> bool:
	var ok := progression.evolve_card(run, card)
	message = "%s entwickelt sich zu %s, Stufe %d." % [card.definition.name, shimmer_name(card.shimmer), card.level] if ok \
		else "Nicht genug Fate für die Entwicklung."
	return ok

func choose_oracle(prophecy: String) -> void:
	if phase != P.ORACLE:
		return
	progression.apply_oracle(run, prophecy)
	match prophecy:
		"XXI": message = "Prophezeiung XXI: Kleine Decks und 21er-Legungen werden belohnt."
		"BLUT": message = "Prophezeiung BLUT: Umgekehrte Karten wachsen schneller."
		_: message = "Prophezeiung EINHEIT: Ein fokussiertes Deck wird belohnt."

func use_item(item_id: String, target: CardInstance = null) -> bool:
	var ok := progression.use_item(run, combat if phase == P.COMBAT else null, item_id, target)
	message = "Item verwendet: %s." % GameCatalog.item(item_id).name if ok \
		else "Dieses Item braucht ein gültiges Ziel oder einen anderen Zeitpunkt."
	return ok

func preview_score() -> ScoreBreakdown:
	return combat_system.preview_score(run, combat) if phase == P.COMBAT else null

# --------------------------------------------------------- Intern
## Kopiert Lesarten, Story-Flags, Charm-Pool und das Grab in den Run.
static func _apply_meta(r: RunState, meta: MetaProgress) -> void:
	if meta == null:
		return
	for key in meta.interpretations:
		var list: Array = meta.interpretations[key]
		if list != null and list.size() > 0:
			r.interpretations[key] = list.size()
	for flag in meta.story_flags:
		r.story_flags[flag] = true
	r.charm_pool = meta.charm_pool()

	if not meta.death_cards.is_empty():
		var grave: DeathCard = meta.death_cards[meta.death_cards.size() - 1]
		if grave.card_id != "":
			r.grave_card_id = grave.card_id
			r.grave_fight = grave.fight

func _make_shop_offer(reward: RewardOption, base_price: int) -> ShopOffer:
	var offer := ShopOffer.new()
	offer.reward = reward
	offer.price = progression.shop_price(run, base_price)
	return offer

func _random_card() -> CardDefinition:
	return _rng.pick(GameCatalog.cards())

func _pick_unseen(pool: Array[EnemyDefinition]) -> EnemyDefinition:
	var fresh: Array = []
	for e in pool:
		if not run.seen_enemies.has(e.id):
			fresh.append(e)
	if fresh.is_empty():
		fresh.assign(pool)
	return _rng.pick(fresh)

## Der Endgegner dieses Runs. Alte Spielstaende kennen nur Die Welt.
func finale_of_run() -> EnemyDefinition:
	var id := run.act_bosses[ActCatalog.ACT_COUNT] if run.act_bosses.size() > ActCatalog.ACT_COUNT else ""
	var finale := ActCatalog.find(id)
	return finale if finale != null and finale.tier == Enums.EnemyTier.FINALE else ActCatalog.finale()

func _build_enemy() -> EnemyDefinition:
	var index := run.fight_index
	var a := mini(ActCatalog.ACT_COUNT, maxi(1, run.act()))
	var template: EnemyDefinition

	# Ein Ereignis darf einen normalen Kampf ersetzen, nie einen Boss.
	var boss_slot := ActCatalog.is_boss_fight(index) or ActCatalog.is_finale(index) or ActCatalog.is_spiral(index)
	var pending: EnemyDefinition = null if boss_slot else ActCatalog.find(run.pending_enemy_id)
	if pending != null:
		run.pending_enemy_id = ""
	var elite := run.next_fight_elite and not boss_slot
	if not boss_slot:
		run.next_fight_elite = false

	if pending != null:
		template = pending.clone()
	elif ActCatalog.is_finale(index) and finale_of_run() != ActCatalog.finale():
		template = finale_of_run().clone()
	elif ActCatalog.is_finale(index):
		template = ActCatalog.finale().clone()
		# Das Finale traegt die Regeln der Bosse, die du geschlagen hast.
		for id in run.defeated_bosses:
			var boss := ActCatalog.find(id)
			if boss == null:
				continue
			for rule in boss.rules:
				if not template.rules.has(rule):
					template.rules.append(rule)
	elif ActCatalog.is_spiral(index):
		template = _build_spiral_enemy(ActCatalog.spiral_depth(index))
	elif ActCatalog.is_boss_fight(index):
		var planned: EnemyDefinition = ActCatalog.find(run.act_bosses[a - 1]) if a - 1 < run.act_bosses.size() else null
		template = (planned if planned != null else _rng.pick(ActCatalog.bosses_of(a)) as EnemyDefinition).clone()
	elif elite:
		template = _pick_unseen(ActCatalog.elites_of(a)).clone()
	else:
		template = _pick_unseen(ActCatalog.normals_of(a)).clone()

	if not run.seen_enemies.has(template.id):
		run.seen_enemies.append(template.id)
	return _scale(template)

## Die Schwarze Spirale: Gegner aus allen Akten, superexponentiell wachsend.
## Jeder vierte ist der Weltenwurm mit Regeln, die sich stapeln.
func _build_spiral_enemy(depth: int) -> EnemyDefinition:
	var template: EnemyDefinition
	if ActCatalog.is_spiral_boss(run.fight_index):
		template = ActCatalog.spiral_boss().clone()
		@warning_ignore("integer_division")
		var rule_count := mini(SPIRAL_RULES.size(), 2 + depth / (ActCatalog.SPIRAL_BOSS_INTERVAL * 2))
		for rule in _rng.pick_distinct(SPIRAL_RULES, rule_count):
			template.rules.append(rule)
	else:
		var pool: Array = []
		pool.append_array(ActCatalog.normals_of(3))
		pool.append_array(ActCatalog.elites_of(3))
		template = (_rng.pick(pool) as EnemyDefinition).clone()

	var growth := pow(SPIRAL_HP_GROWTH, depth) * (1.0 + SPIRAL_HP_CURVE * depth * depth)
	template.id = "%s_spirale_%d" % [template.id, depth]
	template.name = "%s · Spirale %d" % [template.name, depth]
	template.act = 5
	template.max_hp = Num.rnd(template.max_hp * growth)
	template.max_stance = Num.rnd(template.max_stance * (1.0 + depth * 0.06))
	template.base_attack += depth
	@warning_ignore("integer_division")
	template.sigils = mini(4, template.sigils + depth / 8)
	return template

## Schleier und Verdunkelung auf einen Gegner anwenden.
func _scale(enemy: EnemyDefinition) -> EnemyDefinition:
	var strong := enemy.is_boss() or enemy.tier == Enums.EnemyTier.ELITE
	if run.veil >= 2 and strong:
		enemy.max_hp = Num.rnd(Num.mul(enemy.max_hp, 1.2))
		enemy.phase_hp = Num.rnd(Num.mul(enemy.phase_hp, 1.2))
		enemy.max_stance = Num.rnd(Num.mul(enemy.max_stance, 1.2))
	# Die harten Stufen greifen erst ab Akt II.
	var late_act := maxi(0, mini(3, run.act() - 1))
	if run.veil >= 5 and strong:
		enemy.base_attack += late_act
	if run.veil >= 6 and late_act > 0:
		enemy.base_attack += 1
	@warning_ignore("integer_division")
	enemy.base_attack += run.darkness / 25
	if enemy.tier == Enums.EnemyTier.FINALE and run.veil >= 8:
		enemy.sigils += 1
	return enemy
