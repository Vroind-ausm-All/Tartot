extends RefCounted
class_name CombatSystem
## Der Kampf - getreuer Port von Combat/CombatSystem.cs und Combat/BossRules.cs.
##
## Reihenfolge eines Zuges (ResolveTurn): Pakt klaeren, werten, Haltung,
## Fate-Treffer, Brennen, Vergangenheit + Gegenwart, Brand, Tod/Siegel,
## Segen, Gegnerzug, Supernova, ZUKUNFT, Tod/Siegel, Zeichen pruefen,
## Glas, ablegen, Todeszeichen ticken, naechster Zug.
##
## Alle float-Rechnungen laufen ueber Num (float32 + Banker's Rounding),
## damit derselbe Seed hier und in C# denselben Kampf ergibt.

## Karten auf der Hand zu Beginn jedes Zuges.
const HAND_SIZE := 5
## Wirkung der Deck-Resonanz auf den Multiplikator, je Stufe ueber 1.
const DECK_RESONANCE_PER_STEP := 0.06
## Anteil der Kartenwirkung, den eine umgekehrte Karte als Selbstschaden kostet.
const REVERSED_COST_FRACTION := 0.08
## Wirkungszuwachs eines Grossen Arkanums je freigeschalteter Lesart.
const INTERPRETATION_POWER_PER_READING := 0.10
## Musterkette: Multiplikator je Glied, hoechstens 5 Glieder.
const CHAIN_BONUS_PER_LINK := 0.10
const MAX_CHAIN_LINKS := 5
## Der Buchhalter behaelt so viel Schild zwischen den Runden.
const BOOKKEEPER_SHIELD_KEPT := 0.15

# --- Bossregeln (BossRules.cs) ---------------------------------
## Reihenfolge, in der der Turm Positionen einstuerzen laesst.
const TOWER_CYCLE := [Enums.SlotPosition.FUTURE, Enums.SlotPosition.PRESENT, Enums.SlotPosition.PAST]
const PACT_FATE_BONUS := 0.5
const WEAK_PACT_FATE_BONUS := 0.3
const PACT_MAX_HP_COST := 6
const SECOND_PACT_MAX_HP_COST := 10
const WEAK_PACT_MAX_HP_COST := 4
const PACT_DECLINE_PENALTY := 0.20
const PACT_DARKNESS := 6
const TEMPERANCE_HALF := 0.65
const TEMPERANCE_BALANCE_MULT := 0.5
const TEMPERANCE_REFLECT := 0.15
const ACOLYTE_BLESSING := 4
const ACOLYTE_STRIKE := 2
const SUPERNOVA_AT := 4
const SUPERNOVA_PER_SUN := 3

const E := Enums.CharmEffectType
const S := Enums.SlotPosition
const R := Enums.BossRule

var _rng: DeterministicRandom

## Der Strom wird hereingegeben: nur so bleiben Kampf, Belohnung und
## Laden auf getrennten Stroemen.
func _init(rng: DeterministicRandom) -> void:
	_rng = rng

func random_snapshot() -> Dictionary:
	return _rng.snapshot()

func start_combat(run: RunState, enemy_definition: EnemyDefinition) -> CombatState:
	var combat := CombatState.new()
	combat.enemy = EnemyState.new(enemy_definition)
	combat.player_shield = run.start_shield_buff + charm_stacks(run, E.START_SHIELD) * 3
	combat.temporary_luck = run.luck + charm_stacks(run, E.START_LUCK)
	combat.draw_pile.append_array(run.deck)
	_shuffle(combat.draw_pile)
	combat.temporary_draw_bonus = mini(2, charm_stacks(run, E.OPENING_DRAW))
	draw_to_hand(run, combat, hand_size_for(combat) + combat.temporary_draw_bonus)
	combat.temporary_draw_bonus = 0
	_roll_intent(combat)
	if has_rule(combat, R.DEVIL):
		_offer_pact(combat)
	_prepare_rules(run, combat, null)
	return combat

func place_card(combat: CombatState, instance_id: String, slot: int) -> bool:
	var card := combat.find_in_hand(instance_id)
	if card == null:
		return false
	# Der Turm: ein eingestuerzter Platz nimmt keine Karte.
	if combat.blocked_slot == slot:
		return false
	if combat.slots.has(slot):
		combat.hand.append(combat.slots[slot])
	for occupied in combat.slots.keys():
		if (combat.slots[occupied] as CardInstance).instance_id == instance_id:
			combat.slots.erase(occupied)
	combat.hand.erase(card)
	combat.slots[slot] = card
	return true

func return_slot_to_hand(combat: CombatState, slot: int) -> bool:
	if not combat.slots.has(slot):
		return false
	combat.hand.append(combat.slots[slot])
	combat.slots.erase(slot)
	return true

func luck_reroll(run: RunState, combat: CombatState, instance_id: String) -> bool:
	if combat.temporary_luck <= 0:
		return false
	var card := combat.find_in_hand(instance_id)
	if card == null:
		return false
	combat.temporary_luck -= 1
	combat.hand.erase(card)
	combat.veiled_cards.erase(card.instance_id)
	combat.discard_pile.append(card)
	draw_to_hand(run, combat, 1)
	return true

## Vorschau ohne jede Nebenwirkung.
func preview_score(run: RunState, combat: CombatState) -> ScoreBreakdown:
	var score := _calculate_score(run, combat, false)
	if combat.slots.is_empty():
		return score
	var entries := resolved_entries(combat)
	var pre_stance := combat.enemy.stance
	var stance_damage := _stance_damage(score, entries)
	var just_broke := pre_stance > 0 and pre_stance - stance_damage <= 0
	score.breaks_stance = just_broke
	score.expected_hit = _fate_after_stance(combat, score.fate_damage, just_broke, pre_stance)
	score.lethal = combat.enemy.sigils == 0 and score.expected_hit >= combat.enemy.hp + combat.enemy.shield
	_add_hints(combat, entries, score)
	return score

## DIE kanonische Position: wohin eine Karte auf diesem Platz tatsaechlich
## wirkt (Das Rad, Der Gehaengte). Vorschau und Aufloesung nutzen nur sie.
func effective_slot(combat: CombatState, placed: int) -> int:
	if combat == null or combat.enemy == null:
		return placed
	var enemy := combat.enemy
	var weak := enemy.definition.rules_weakened
	var slot := placed
	if has_rule(combat, R.WHEEL) and (not weak or combat.turn % 2 == 0):
		slot = (slot + (2 if enemy.phase >= 1 and not weak else 1)) % 3
	if has_rule(combat, R.HANGED_MAN) and (not weak or combat.turn % 2 == 1):
		if slot == S.PAST:
			slot = S.FUTURE
		elif slot == S.FUTURE:
			slot = S.PAST
		else:
			slot = S.PRESENT
	return slot

func resolve_turn(run: RunState, combat: CombatState) -> TurnResult:
	var result := TurnResult.new()
	if combat.slots.is_empty() or combat.player_won or combat.player_lost:
		result.log.append("Lege mindestens eine Karte.")
		return result

	# Ein unbeantworteter Pakt gilt als abgelehnt.
	if combat.pact_pending:
		answer_pact(run, combat, false)

	var entries := resolved_entries(combat)
	var score := _calculate_score(run, combat, true)
	combat.last_score = score
	var played: Array[CardInstance] = []
	for e in entries:
		played.append(e["card"])
	combat.last_played_cards = played
	result.score = score

	run.stats.turns_played += 1
	for e in entries:
		if (e["card"] as CardInstance).is_reversed():
			run.stats.reversed_played += 1
	if score.is_world:
		run.stats.world_spreads += 1
		combat.worlds_this_fight += 1
		run.stats.most_worlds_in_fight = maxi(run.stats.most_worlds_in_fight, combat.worlds_this_fight)
	for e in entries:
		if e["placed"] != e["effective"]:
			result.log.append("%s wirkt als %s." % [(e["card"] as CardInstance).definition.name, slot_name(e["effective"])])

	var pre_stance := combat.enemy.stance
	var stance_damage := _stance_damage(score, entries)
	combat.enemy.stance = maxi(0, combat.enemy.stance - stance_damage)
	var just_broke := pre_stance > 0 and combat.enemy.stance == 0
	result.stance_broken = just_broke
	if just_broke:
		result.log.append("HALTUNG GEBROCHEN – Schadensfenster geöffnet.")
		_on_stance_broken(combat, result)

	var fate_damage := _fate_after_stance(combat, score.fate_damage, just_broke, pre_stance)
	fate_damage = _deal_enemy_damage(run, combat, fate_damage, true)
	result.fate_damage = fate_damage
	# Rekord ist der Wert der Legung, nicht der gedeckelte Schaden.
	if score.fate_damage > run.stats.best_hit:
		result.new_best_hit = run.stats.best_hit > 0
		run.stats.best_hit = score.fate_damage
		run.stats.best_hit_combo = score.combo_name
	result.log.append("%s: %d Chips × %s × Wiederholung %s = %d Fate-Schaden." % [
		score.combo_name, score.chips, Num.de(score.multiplier), Num.de(score.repeat_penalty), fate_damage])

	_distribute_fate_contribution(combat, entries, fate_damage, stance_damage, score.multiplier)

	# Die Maessigkeit in der zweiten Phase: wer nicht beide Elemente legt,
	# bekommt einen Teil des eigenen Treffers zurueck.
	if temperance_mixing(combat) and fate_damage > 0 and not is_balanced(played):
		result.reflected = Num.rnd(Num.mul(fate_damage, TEMPERANCE_REFLECT))
		result.log.append("Die Mäßigkeit spiegelt %d zurück." % result.reflected)
		_take_player_damage(run, combat, result.reflected, result)

	# Brennende Karten: der Gegner faengt Feuer, du verbrennst dir die Finger.
	for e in entries:
		var c: CardInstance = e["card"]
		if c.edition == Enums.CardEdition.BURNING:
			combat.enemy.burn += CardEditions.BURN_BRAND
			run.hp = maxi(1, run.hp - CardEditions.BURN_SELF_DAMAGE)
			result.log.append("%s brennt: +%d Brand, −%d LP." % [c.definition.name, CardEditions.BURN_BRAND, CardEditions.BURN_SELF_DAMAGE])

	var immediate: Array = []
	var future: Array = []
	for e in entries:
		if e["effective"] != S.FUTURE:
			immediate.append(e)
		else:
			future.append(e)

	for e in immediate:
		_apply_card(run, combat, e["card"], e["effective"], result)

	_tick_enemy_burn(run, combat, result)
	_check_enemy_death_or_sigil(run, combat, result)

	if not combat.player_won and not combat.player_lost:
		_apply_blessings(combat, result)
		_resolve_enemy_intent(run, combat, result)
		_check_supernova(run, combat, result)

	if not combat.player_lost:
		for e in future:
			_apply_card(run, combat, e["card"], e["effective"], result)
		_check_enemy_death_or_sigil(run, combat, result)
		_lift_mark_if_faced(combat, future, result)

	for e in entries:
		var c: CardInstance = e["card"]
		# Glas zerspringt nach dem Zug - dann ist die Karte fuer den Run verloren.
		if c.edition == Enums.CardEdition.GLASS and not c.is_copy \
				and run.deck.size() > GameCatalog.MINIMUM_DECK_SIZE \
				and _rng.chance(Num.f(CardEditions.GLASS_SHATTER_CHANCE)):
			run.deck.erase(c)
			result.shattered.append(c.definition.name)
			result.log.append("%s zerspringt." % c.definition.name)
			continue
		combat.discard_pile.append(c)
	combat.slots.clear()

	if combat.player_won:
		_award_rage_on_victory(combat)
		combat.marked_card_id = ""
		result.overkill = combat.last_overkill
		if result.overkill > 0:
			result.log.append("ÜBERSCHUSS: %d über das Leben hinaus." % result.overkill)
		result.victory = true
		return result

	if combat.player_lost:
		result.defeat = true
		return result

	_tick_death_mark(run, combat, result)

	combat.turn += 1
	if combat.enemy.stance == 0:
		if combat.enemy.broken_this_round:
			combat.enemy.stance = maxi(1, Num.rnd(Num.mul(combat.enemy.definition.max_stance, 0.60)))
			combat.enemy.broken_this_round = false
			result.log.append("Der Gegner fängt sich und gewinnt Haltung zurück.")
		else:
			combat.enemy.broken_this_round = true

	var retained := Num.mul(charm_stacks(run, E.SHIELD_RETENTION), 0.10)
	retained = Num.add(retained, BOOKKEEPER_SHIELD_KEPT if run.deuter_rule == Enums.DeuterRule.BOOKKEEPER else 0.0)
	combat.player_shield = int(floor(Num.mul(combat.player_shield, minf(Num.f(0.5), retained))))
	# Der Zieh-Bonus (Der Gehaengte, Leere Karte) gilt auch im naechsten Zug.
	draw_to_hand(run, combat, hand_size_for(combat) + combat.temporary_draw_bonus)
	combat.temporary_draw_bonus = 0
	_roll_intent(combat)
	_prepare_rules(run, combat, result)
	return result

## Haltungsschaden einer Legung: Chips/9 plus 2 je Schwert.
static func _stance_damage(score: ScoreBreakdown, entries: Array) -> int:
	var swords := 0
	for e in entries:
		if (e["card"] as CardInstance).definition.suit == Enums.Suit.SWORDS:
			swords += 1
	@warning_ignore("integer_division")
	return maxi(1, score.chips / 9 + swords * 2)

## Was vom Fate-Treffer ankommt: steht die Haltung, ist er auf 35 % der
## Max-HP gedeckelt; bricht sie gerade oder ist sie gebrochen, wirkt er x1,5.
static func _fate_after_stance(combat: CombatState, fate: int, just_broke: bool, pre_stance: int) -> int:
	if just_broke or combat.enemy.broken_this_round:
		fate = Num.rnd(Num.mul(fate, 1.5))
	if pre_stance > 0 and not just_broke:
		var cap := maxi(1, Num.rnd(Num.mul(combat.enemy.definition.max_hp, 0.35)))
		fate = mini(fate, cap)
	return fate

static func slot_name(slot: int) -> String:
	match slot:
		S.PAST: return "VERGANGENHEIT"
		S.FUTURE: return "ZUKUNFT"
	return "GEGENWART"

func draw_to_hand(run: RunState, combat: CombatState, target_count: int) -> void:
	target_count = maxi(0, target_count)
	while combat.hand.size() < target_count:
		if combat.draw_pile.is_empty():
			if combat.discard_pile.is_empty():
				break
			combat.draw_pile.append_array(combat.discard_pile)
			combat.discard_pile.clear()
			_shuffle(combat.draw_pile)
			combat.reshuffles += 1
			target_count += mini(2, charm_stacks(run, E.RESHUFFLE_DRAW))
		var top: CardInstance = combat.draw_pile[0]
		combat.draw_pile.remove_at(0)
		combat.hand.append(top)

func _calculate_score(run: RunState, combat: CombatState, commit: bool) -> ScoreBreakdown:
	var entries := resolved_entries(combat)
	var cards: Array[CardInstance] = []
	for e in entries:
		cards.append(e["card"])
	var score := ScoreBreakdown.new()
	score.chips = 0
	score.multiplier = 1.0
	score.combo_name = "Offene Legung"
	if cards.is_empty():
		return score

	var reversed_mult := 0.15 if run.deuter_rule == Enums.DeuterRule.BLOOD_READER else 0.10
	@warning_ignore("integer_division")
	var dark_chips := run.darkness / 20
	var edition_x := 1.0
	for card in cards:
		var mult_before := score.multiplier
		var chips := card.effective_rank()
		if card.definition.suit == Enums.Suit.SWORDS:
			chips += charm_stacks(run, E.SWORDS_CHIPS) * 2
		if card.is_copy:
			chips += charm_stacks(run, E.COPY_BASE)
		if card.is_upgraded():
			score.multiplier = Num.add(score.multiplier, Num.mul(charm_stacks(run, E.UPGRADED_POWER), 0.08))
		if card.is_copy:
			score.multiplier = Num.add(score.multiplier, Num.mul(charm_stacks(run, E.COPY_POWER), 0.10))
		if card.is_reversed():
			score.multiplier = Num.add(score.multiplier, reversed_mult)
			score.multiplier = Num.add(score.multiplier, Num.mul(charm_stacks(run, E.SELF_DAMAGE_POWER), 0.12))
			# Verdunkelung naehrt die verkehrte Seite.
			chips += dark_chips
		if card.rage >= 3:
			chips = Num.rnd(Num.mul(chips, 1.5))
			score.notes.append("%s ist in Raserei (+50%% Chips). " % card.definition.name)
		# Editionen: flach auf Chips und Mult, der Faktor kommt ganz am Ende.
		chips += CardEditions.chips(card.edition)
		score.multiplier = Num.add(score.multiplier, CardEditions.mult_add(card.edition))
		edition_x = Num.mul(edition_x, CardEditions.mult_x(card.edition))
		score.chips += chips
		var step := ScoreStep.new()
		step.instance_id = card.instance_id
		step.label = card.definition.name
		step.chips = chips
		step.mult_add = Num.sub(score.multiplier, mult_before)
		step.mult_x = CardEditions.mult_x(card.edition)
		step.edition = card.edition
		score.steps.append(step)

	var any_present := false
	var any_future := false
	for e in entries:
		any_present = any_present or e["effective"] == S.PRESENT
		any_future = any_future or e["effective"] == S.FUTURE
	if any_present:
		score.multiplier = Num.add(score.multiplier, 0.15)
	if any_future:
		score.multiplier = Num.add(score.multiplier, Num.add(0.10, Num.mul(charm_stacks(run, E.FUTURE_POWER), 0.10)))

	var values: Array[int] = []
	var suit_set := {}
	var major_count := 0
	for c in cards:
		values.append(c.definition.rank)
		suit_set[c.definition.suit] = true
		if c.definition.is_major():
			major_count += 1
	values.sort()
	var sum := 0
	for v in values:
		sum += v
	var same_suit := cards.size() == 3 and suit_set.size() == 1
	var unique_suits := suit_set.size()
	var straight := values.size() == 3 and values[1] == values[0] + 1 and values[2] == values[1] + 1
	var top_group := 0
	for v in values:
		top_group = maxi(top_group, values.count(v))

	var combo_parts: Array[String] = []
	var chainable := false
	if sum == 21:
		score.multiplier = Num.add(score.multiplier, 2.10)
		score.chips += 21
		score.is_world = true
		combo_parts.append("DIE WELT 21")
		chainable = true
		# Nur beim echten Zug, nicht in der Vorschau: sonst baute blosses
		# Hin- und Herschieben unbegrenzt Rage auf.
		if commit:
			for c in cards:
				c.rage = mini(3, c.rage + 1)
	if straight:
		score.multiplier = Num.add(score.multiplier, 0.75)
		score.chips += 8
		combo_parts.append("Folge")
		chainable = true
	if same_suit:
		score.multiplier = Num.add(score.multiplier, 0.65)
		score.chips += 10
		combo_parts.append("Resonanz")
		chainable = true
	if top_group == 3:
		score.multiplier = Num.add(score.multiplier, 1.0)
		score.chips += 12
		combo_parts.append("Dreiklang")
		chainable = true
	elif top_group == 2:
		score.multiplier = Num.add(score.multiplier, 0.50)
		score.chips += 5
		combo_parts.append("Paar")
		chainable = true
	if cards.size() == 3 and unique_suits == 3:
		score.multiplier = Num.add(score.multiplier, 0.35)
		combo_parts.append("Drei Pfade")
	if temperance_mixing(combat) and is_balanced(cards):
		score.multiplier = Num.add(score.multiplier, TEMPERANCE_BALANCE_MULT)
		combo_parts.append("Gleichgewicht")
		chainable = true
	if major_count >= 2:
		score.multiplier = Num.add(score.multiplier, Num.add(0.60, Num.mul(major_count - 2, 0.25)))
		combo_parts.append("Großes Omen")
		chainable = true

	var wands := 0
	for c in cards:
		if c.definition.suit == Enums.Suit.WANDS:
			wands += 1
	if wands >= 2:
		score.multiplier = Num.add(score.multiplier, Num.mul(wands * charm_stacks(run, E.WAND_COMBO), 0.08))
	@warning_ignore("integer_division")
	if run.hp <= run.max_hp / 2:
		score.multiplier = Num.add(score.multiplier, Num.mul(charm_stacks(run, E.SELF_DAMAGE_POWER), 0.04))
	@warning_ignore("integer_division")
	var thread_steps := maxi(0, run.charms.size() - 1) / 5 * charm_stacks(run, E.WORLD_THREAD)
	score.multiplier = Num.add(score.multiplier, Num.mul(thread_steps, 0.02))

	# Deck-Resonanz: ein kleines, entwickeltes, stimmiges Deck schlaegt haerter.
	# Der Eremit liest sie doppelt.
	var resonance_step := Num.mul(DECK_RESONANCE_PER_STEP, 2) if run.deuter_rule == Enums.DeuterRule.HERMIT else Num.f(DECK_RESONANCE_PER_STEP)
	score.multiplier = Num.add(score.multiplier, Num.mul(maxi(0, run.deck_resonance - 1), resonance_step))

	if run.prophecy == "XXI" and run.deck.size() <= 10:
		score.multiplier = Num.add(score.multiplier, 0.30)

	# Musterkette: wer Zug um Zug ein Muster legt, baut sich auf.
	score.has_pattern = chainable
	score.chain = combat.pattern_chain + 1 if chainable else 0
	if chainable and combat.pattern_chain > 0:
		var links := mini(MAX_CHAIN_LINKS, combat.pattern_chain)
		var bonus := Num.mul(links, CHAIN_BONUS_PER_LINK)
		score.multiplier = Num.add(score.multiplier, bonus)
		score.notes.append("Kette ×%d (+%s)." % [score.chain, Num.de(bonus)])
	if commit:
		combat.pattern_chain = combat.pattern_chain + 1 if chainable else 0
		run.stats.longest_chain = maxi(run.stats.longest_chain, combat.pattern_chain)

	if combo_parts.is_empty():
		score.combo_name = "Dreier-Legung" if cards.size() == 3 else "Offene Legung"
	else:
		score.combo_name = " + ".join(combo_parts)
	var ids: Array[String] = []
	for c in cards:
		ids.append(c.definition.id)
	ids.sort()
	var signature := "-".join(ids) + "|" + score.combo_name
	var repeats := combat.same_combo_repeats + 1 if signature == combat.last_combo_signature else 0
	match repeats:
		0: score.repeat_penalty = 1.0
		1: score.repeat_penalty = Num.f(0.90)
		2: score.repeat_penalty = Num.f(0.75)
		_: score.repeat_penalty = Num.f(0.50)

	if commit:
		if signature == combat.last_combo_signature:
			combat.same_combo_repeats += 1
		else:
			combat.last_combo_signature = signature
			combat.same_combo_repeats = 0

	# Muster, Positionen, Kette, Charms: alles, was nach den Karten auf den Mult kam.
	var mult_adds: Array = []
	var card_chips := 0
	for st in score.steps:
		mult_adds.append(st.mult_add)
		card_chips += st.chips
	var card_mult := Num.add(1.0, Num.summe_f(mult_adds))
	if Num.sub(score.multiplier, card_mult) > Num.f(0.001) or score.chips > card_chips:
		var tail := ScoreStep.new()
		tail.label = score.combo_name
		tail.chips = score.chips - card_chips
		tail.mult_add = Num.sub(score.multiplier, card_mult)
		score.steps.append(tail)
	if absf(Num.sub(edition_x, 1.0)) > Num.f(0.001):
		score.multiplier = Num.mul(score.multiplier, edition_x)
		score.notes.append("Editionen ×%s." % Num.de(edition_x))

	var pact := Num.add(1.0, combat.fate_bonus)
	if combat.fate_bonus > 0.0:
		score.notes.append("Pakt +%d %%." % Num.rnd(combat.fate_bonus * 100.0))
	for c in cards:
		if combat.is_veiled(c):
			score.veiled = true
	var raw := Num.mul(Num.mul(Num.mul(score.chips, score.multiplier), score.repeat_penalty), pact)
	score.fate_damage = maxi(1, Num.rnd(raw))
	return score

## Beinahe-Treffer fuer die Vorschau: "die 7 der Kelche vollendet DIE WELT".
static func _add_hints(combat: CombatState, entries: Array, score: ScoreBreakdown) -> void:
	if score.veiled:
		return
	var ranks: Array[int] = []
	for e in entries:
		ranks.append((e["card"] as CardInstance).definition.rank)
	ranks.sort()
	var hand: Array[CardInstance] = []
	for c in combat.hand:
		if not combat.is_veiled(c):
			hand.append(c)
	# Ein eingestuerzter Platz (Der Turm) ist kein freier Platz.
	var open_slots := 3 - combat.slots.size() - (1 if combat.has_blocked_slot() else 0)
	var free_slot := entries.size() < 3 and open_slots > 0

	if entries.size() == 2 and free_slot:
		var need := 21 - (ranks[0] + ranks[1])
		var completer: CardInstance = null
		for c in hand:
			if c.definition.rank == need:
				completer = c
				break
		if completer != null:
			score.hints.append("%s vollendet DIE WELT (21)." % completer.definition.name)
		elif need >= 1 and need <= 14:
			score.hints.append("Noch %d bis DIE WELT." % need)
		if ranks[0] == ranks[1]:
			for c in hand:
				if c.definition.rank == ranks[0]:
					score.hints.append("%s macht den Dreiklang." % c.definition.name)
					break
		elif ranks[1] - ranks[0] == 1:
			for c in hand:
				if c.definition.rank == ranks[0] - 1 or c.definition.rank == ranks[1] + 1:
					score.hints.append("%s vollendet die Folge." % c.definition.name)
					break
	elif entries.size() == 3 and not score.is_world:
		var total := ranks[0] + ranks[1] + ranks[2]
		var gap := absi(21 - total)
		if gap > 0 and gap <= 3:
			score.hints.append("Summe %d: nur %d neben DIE WELT." % [total, gap])

	if score.lethal:
		score.hints.insert(0, "TÖDLICH – dieser Treffer beendet den Kampf.")
	while score.hints.size() > 2:
		score.hints.remove_at(score.hints.size() - 1)

func _apply_card(run: RunState, combat: CombatState, card: CardInstance, slot: int, result: TurnResult) -> void:
	var slot_factor := 1.0
	if slot == S.PAST:
		slot_factor = Num.f(0.90)
	elif slot == S.FUTURE:
		slot_factor = Num.f(1.50)
	var charm_factor := 1.0
	if card.is_copy:
		charm_factor = Num.add(charm_factor, Num.mul(charm_stacks(run, E.COPY_POWER), 0.10))
	if card.is_upgraded():
		charm_factor = Num.add(charm_factor, Num.mul(charm_stacks(run, E.UPGRADED_POWER), 0.08))
	if card.is_reversed():
		charm_factor = Num.add(charm_factor, Num.mul(charm_stacks(run, E.SELF_DAMAGE_POWER), 0.12))
		# +6 % je 20 Verdunkelung: je dunkler der Run, desto lohnender die verkehrte Seite.
		@warning_ignore("integer_division")
		charm_factor = Num.add(charm_factor, Num.mul(run.darkness / 20, 0.06))
	var rage_factor := 1.5 if card.rage >= 3 else 1.0
	if card.rage >= 3:
		card.rage = 0
	var factor := Num.mul(Num.mul(Num.mul(Num.mul(slot_factor, card.power_multiplier()), charm_factor), rage_factor), temperance_factor(combat, card))
	var power := maxi(1, Num.rnd(Num.mul(card.definition.base_power, factor)))

	if card.definition.is_major():
		_apply_major(run, combat, card, slot, factor, result)
		_pay_reversed_cost(run, card, power, result)
		return

	match card.definition.suit:
		Enums.Suit.SWORDS:
			var bonus := charm_stacks(run, E.FIRST_ATTACK_BONUS) * 4
			var damage := _deal_enemy_damage(run, combat, power + bonus, false)
			_add_contribution(combat, card, damage)
			result.log.append("%s: %d Klingenschaden." % [card.definition.name, damage])
		Enums.Suit.WANDS:
			@warning_ignore("integer_division")
			var burn := maxi(1, power / 3 + charm_stacks(run, E.WANDS_BURN))
			combat.enemy.burn += burn
			@warning_ignore("integer_division")
			var damage := _deal_enemy_damage(run, combat, maxi(1, power / 2), false)
			_add_contribution(combat, card, damage)
			result.log.append("%s: %d Schaden und +%d Brand." % [card.definition.name, damage, burn])
		Enums.Suit.CUPS:
			var heal := power + charm_stacks(run, E.CUP_AFTER_ATTACK) * 2
			heal = _apply_heal(run, combat, card, heal, result)
			_add_contribution(combat, card, 0, 0, heal)
		Enums.Suit.PENTACLES:
			var shield := power + charm_stacks(run, E.PENTACLE_SHIELD) * 2
			@warning_ignore("integer_division")
			if run.hp <= run.max_hp / 2:
				shield += charm_stacks(run, E.LOW_HP_SHIELD) * 2
			combat.player_shield += shield
			_add_contribution(combat, card, 0, shield)
			result.shield_gained += shield
			result.log.append("%s: +%d Schild." % [card.definition.name, shield])

	_pay_reversed_cost(run, card, power, result)
	_apply_generic_charm_triggers(run, combat, card, result)

## Der Umkehrpreis: Selbstschaden, der Schild ignoriert und nicht toeten kann.
## Wer alle drei Lesarten eines Grossen Arkanums kennt, legt es ohne Preis umgekehrt.
func _pay_reversed_cost(run: RunState, card: CardInstance, power: int, result: TurnResult) -> void:
	if not card.is_reversed():
		return
	if card.definition.is_major() and run.interpretation_count(card.definition.id) >= 3:
		result.log.append("%s: die verkehrte Lesart kostet dich nichts mehr." % card.definition.name)
		return
	var fraction := Num.f(REVERSED_COST_FRACTION)
	if run.deuter_rule == Enums.DeuterRule.BLOOD_READER:
		fraction = Num.mul(fraction, 1.25)
	if run.veil >= 7:
		fraction = Num.mul(fraction, 1.5)
	var self_damage := maxi(1, Num.rnd(Num.mul(power, fraction)))
	run.hp = maxi(1, run.hp - self_damage)
	result.log.append("Umkehrpreis: -%d HP." % self_damage)

func _apply_major(run: RunState, combat: CombatState, card: CardInstance, slot: int, factor: float, result: TurnResult) -> void:
	var readings := run.interpretation_count(card.definition.id)
	if readings > 0:
		factor = Num.mul(factor, Num.add(1.0, Num.mul(readings, INTERPRETATION_POWER_PER_READING)))
		result.log.append("%s: %d Lesart(en) vertieft die Deutung." % [card.definition.name, readings])

	var p := maxi(1, Num.rnd(Num.mul(card.definition.base_power + card.level, factor)))
	var M := Enums.MajorArcana
	match card.definition.major:
		M.FOOL:
			draw_to_hand(run, combat, mini(8, combat.hand.size() + (3 if card.is_reversed() else 2)))
			if card.is_reversed():
				combat.temporary_luck += 1
			result.log.append("Der Narr verwirft Gewissheit: zusätzliche Karten gezogen.")
		M.MAGICIAN:
			var echo: CardInstance = combat.last_played_cards.back() if not combat.last_played_cards.is_empty() else null
			if echo != null:
				var dmg := _deal_enemy_damage(run, combat, maxi(2, echo.effective_rank() + p), false)
				_add_contribution(combat, card, dmg, 0, 0, 0, 0.15)
				result.log.append("Der Magier spiegelt %s: %d Echo-Schaden." % [echo.definition.name, dmg])
			else:
				combat.temporary_luck += 1
				result.log.append("Der Magier findet noch kein Echo und erzeugt stattdessen 1 Luck.")
		M.HIGH_PRIESTESS:
			combat.temporary_luck += 1
			draw_to_hand(run, combat, mini(7, combat.hand.size() + 1))
			result.log.append("Die Hohepriesterin enthüllt Möglichkeiten: +1 Luck, +1 Karte.")
		M.EMPRESS:
			_apply_heal(run, combat, card, 6 + p, result)
		M.EMPEROR:
			combat.player_shield += 10 + p
			_add_contribution(combat, card, 0, 10 + p)
			result.log.append("Der Herrscher errichtet %d Schild." % (10 + p))
		M.HIEROPHANT:
			card.add_experience(10 + p)
			result.log.append("Der Hierophant lehrt die Karte: zusätzliche Erfahrung.")
		M.LOVERS:
			var lovers := _deal_enemy_damage(run, combat, p * 2, false)
			_add_contribution(combat, card, lovers, 0, 0, 0, 0.25)
			result.log.append("Die Liebenden verbinden zwei Schicksale und verdoppeln ihren Impuls.")
		M.CHARIOT:
			var chariot := _deal_enemy_damage(run, combat, p + (p if slot == S.FUTURE else 0), false)
			_add_contribution(combat, card, chariot)
			result.log.append("Der Wagen rast voran: %d Schaden." % chariot)
		M.STRENGTH:
			var strength := _deal_enemy_damage(run, combat, p * 2, false)
			combat.player_shield += 4
			_add_contribution(combat, card, strength, 4)
			result.log.append("Kraft: %d Schaden und 4 Schild." % strength)
		M.HERMIT:
			if not combat.hand.is_empty():
				var weakest: CardInstance = Num.kleinstes(combat.hand, func(c): return c.effective_rank())
				combat.hand.erase(weakest)
				combat.discard_pile.append(weakest)
				draw_to_hand(run, combat, combat.hand.size() + 2)
			result.log.append("Der Eremit dünnt die aktuelle Hand aus und zieht tiefer.")
		M.WHEEL:
			for h in combat.hand.duplicate():
				combat.discard_pile.append(h)
			combat.hand.clear()
			draw_to_hand(run, combat, 5)
			result.log.append("Das Rad ersetzt die gesamte Hand.")
		M.JUSTICE:
			var justice := _deal_enemy_damage(run, combat, 6 + p, false)
			_add_contribution(combat, card, justice)
			result.log.append("Gerechtigkeit richtet: %d Schaden." % justice)
		M.HANGED_MAN:
			combat.player_shield += p
			combat.temporary_draw_bonus += 2
			result.log.append("Der Gehängte opfert Tempo: Schild jetzt, zusätzliche Karten im nächsten Zug.")
		M.DEATH:
			var death := _deal_enemy_damage(run, combat, p * 2, false)
			if not combat.discard_pile.is_empty():
				combat.discard_pile.remove_at(_rng.next_int(combat.discard_pile.size()))
			_add_contribution(combat, card, death)
			result.log.append("Der Tod vernichtet: %d Schaden und eine Karte verlässt diesen Kampf." % death)
		M.TEMPERANCE:
			var temp := _deal_enemy_damage(run, combat, p, false)
			combat.player_shield += p
			@warning_ignore("integer_division")
			_apply_heal(run, combat, card, p / 2, result)
			_add_contribution(combat, card, temp, p, 0, 0, 0.15)
			result.log.append("Mäßigkeit mischt Schaden, Schild und Heilung.")
		M.DEVIL:
			var devil := _deal_enemy_damage(run, combat, p * 3, false)
			run.hp = maxi(1, run.hp - 4)
			_add_contribution(combat, card, devil, 0, 0, 0, 0.25)
			result.log.append("Der Teufel gewährt %d Schaden gegen 4 HP." % devil)
		M.TOWER:
			combat.player_shield = 0
			combat.enemy.shield = 0
			var tower := _deal_enemy_damage(run, combat, 18 + p, false)
			_add_contribution(combat, card, tower)
			result.log.append("Der Turm zerbricht Schutz: %d Schaden." % tower)
		M.STAR:
			@warning_ignore("integer_division")
			_apply_heal(run, combat, card, 8 + p / 2, result)
			combat.temporary_luck += 1
			draw_to_hand(run, combat, mini(7, combat.hand.size() + 1))
			result.log.append("Der Stern schenkt Heilung, Luck und eine Karte.")
		M.MOON:
			combat.temporary_luck += 2 if card.is_reversed() else 1
			var moon := _deal_enemy_damage(run, combat, p, false)
			_add_contribution(combat, card, moon, 0, 0, 0, 0.20)
			result.log.append("Der Mond verstärkt Unsicherheit und umgekehrte Wege.")
		M.SUN:
			var sun := _deal_enemy_damage(run, combat, 10 + p, false)
			@warning_ignore("integer_division")
			_apply_heal(run, combat, card, 6 + p / 2, result)
			draw_to_hand(run, combat, mini(7, combat.hand.size() + 1))
			_add_contribution(combat, card, sun)
			result.log.append("Die Sonne vereint Schaden, Heilung und Ziehen.")
		M.JUDGEMENT:
			if not combat.discard_pile.is_empty():
				var returned: CardInstance = Num.groesstes(combat.discard_pile, func(c): return c.effective_rank())
				combat.discard_pile.erase(returned)
				combat.hand.append(returned)
				result.log.append("Das Gericht ruft %s zurück." % returned.definition.name)
		M.WORLD:
			var world_bonus := 30 if combat.last_score != null and combat.last_score.combo_name.contains("DIE WELT") else 16
			var world := _deal_enemy_damage(run, combat, world_bonus + p, false)
			combat.player_shield += 10
			draw_to_hand(run, combat, mini(7, combat.hand.size() + 2))
			_add_contribution(combat, card, world, 10, 0, 0, 0.35)
			result.log.append("Die Welt schließt den Kreis: %d Schaden, 10 Schild, Karten gezogen." % world)

func _apply_heal(run: RunState, combat: CombatState, card: CardInstance, amount: int, result: TurnResult) -> int:
	var glass_stacks := charm_stacks(run, E.GLASS_HEART)
	if glass_stacks > 0:
		amount = Num.rnd(Num.mul(amount, Num.add(1.0, Num.mul(glass_stacks, 0.25))))
	var before := run.hp
	run.hp = mini(run.max_hp, run.hp + amount)
	var actual := run.hp - before
	var overheal := maxi(0, amount - actual)
	var convert := Num.mul(charm_stacks(run, E.OVERHEAL_TO_SHIELD), 0.20)
	if overheal > 0 and convert > 0.0:
		combat.player_shield += Num.rnd(Num.mul(overheal, minf(1.0, convert)))
	var damage_percent := Num.mul(charm_stacks(run, E.HEAL_DAMAGE), 0.20)
	if damage_percent > 0.0:
		var damage := _deal_enemy_damage(run, combat, maxi(1, Num.rnd(Num.mul(amount, minf(1.0, damage_percent)))), false)
		_add_contribution(combat, card, damage)
	result.healing += actual
	result.log.append("%s: +%d HP." % [card.definition.name, actual])
	return actual

func _apply_generic_charm_triggers(run: RunState, combat: CombatState, card: CardInstance, result: TurnResult) -> void:
	# Der Zaehler steigt, waehrend die Karte wirkt.
	combat.cards_played_this_combat += 1
	if card.is_reversed():
		var shield := charm_stacks(run, E.REVERSED_SHIELD)
		if shield > 0:
			combat.player_shield += shield
			result.shield_gained += shield
	var every_third := charm_stacks(run, E.EVERY_THIRD_CARD_DAMAGE)
	if every_third > 0 and combat.cards_played_this_combat % 3 == 0:
		var dmg := _deal_enemy_damage(run, combat, every_third * 3, false)
		result.log.append("Schwarzer Nagel: +%d Schaden." % dmg)
	var every_fifth := charm_stacks(run, E.EVERY_FIFTH_HEAL)
	if every_fifth > 0 and combat.cards_played_this_combat % 5 == 0:
		var before := run.hp
		run.hp = mini(run.max_hp, run.hp + every_fifth)
		result.healing += run.hp - before

func _tick_enemy_burn(run: RunState, combat: CombatState, result: TurnResult) -> void:
	if combat.enemy.burn <= 0 or combat.enemy.is_dead():
		return
	var damage := combat.enemy.burn + charm_stacks(run, E.BURN_POWER)
	damage = _deal_enemy_damage(run, combat, damage, false)
	combat.enemy.burn = maxi(0, combat.enemy.burn - 1)
	result.log.append("Brand tickt für %d." % damage)

func _resolve_enemy_intent(run: RunState, combat: CombatState, result: TurnResult) -> void:
	if combat.skip_enemy_intent:
		combat.skip_enemy_intent = false
		result.log.append("Die gegnerische Aktion wird übersprungen.")
		return
	var enemy := combat.enemy
	match enemy.intent:
		Enums.IntentType.GUARD:
			enemy.shield += enemy.intent_value
			result.log.append("%s erhält %d Schild." % [enemy.definition.name, enemy.intent_value])
		Enums.IntentType.HEX:
			combat.temporary_luck = maxi(0, combat.temporary_luck - 1)
			@warning_ignore("integer_division")
			_take_player_damage(run, combat, maxi(1, enemy.intent_value / 2), result)
			result.log.append("Ein Fluch frisst 1 Luck.")
		Enums.IntentType.DRAIN:
			var dealt := _take_player_damage(run, combat, enemy.intent_value, result)
			@warning_ignore("integer_division")
			enemy.hp = mini(enemy.definition.max_hp, enemy.hp + dealt / 2)
			@warning_ignore("integer_division")
			result.log.append("Der Gegner heilt %d HP durch Drain." % (dealt / 2))
		Enums.IntentType.FRENZY:
			_take_player_damage(run, combat, enemy.intent_value, result)
			if not combat.player_lost:
				_take_player_damage(run, combat, enemy.intent_value, result)
		_:
			_take_player_damage(run, combat, enemy.intent_value, result)

func _take_player_damage(run: RunState, combat: CombatState, incoming: int, result: TurnResult) -> int:
	var blocked := mini(combat.player_shield, incoming)
	combat.player_shield -= blocked
	var damage := incoming - blocked
	if blocked > 0:
		var thorns := charm_stacks(run, E.THORNS) * 2
		if thorns > 0:
			_deal_enemy_damage(run, combat, mini(blocked, thorns), false)
	run.hp -= damage
	result.enemy_damage += damage
	result.log.append("Gegner trifft für %d (%d geblockt)." % [damage, blocked])
	if run.hp <= 0:
		if run.revive_charges > 0:
			run.revive_charges -= 1
			@warning_ignore("integer_division")
			run.hp = maxi(1, run.max_hp / 4)
			result.log.append("Aschephiole: Wiederbelebung.")
		elif charm_stacks(run, E.PHOENIX) > 0:
			run.hp = 1 + charm_stacks(run, E.PHOENIX) * 5
			run.charms[GameCatalog.charm_for_effect(E.PHOENIX).id] = 0
			result.log.append("Phönixfeder verhindert den Tod.")
		else:
			run.hp = 0
			combat.player_lost = true
	return damage

func _deal_enemy_damage(run: RunState, combat: CombatState, amount: int, fate_damage: bool) -> int:
	amount = maxi(0, amount)
	if combat.enemy.shield > 0:
		# Durchdringung senkt das wirksame Schild einmal.
		var pierce := 0 if fate_damage else charm_stacks(run, E.ARMOR_PIERCE)
		var effective_shield := maxi(0, combat.enemy.shield - pierce)
		var blocked := mini(effective_shield, amount)
		combat.enemy.shield = maxi(0, combat.enemy.shield - blocked)
		amount -= blocked
	combat.enemy.hp -= amount
	return amount

func _check_enemy_death_or_sigil(run: RunState, combat: CombatState, result: TurnResult) -> void:
	# Schon besiegt: was die Zukunftskarten danach noch treffen, ist weiterer Ueberschuss.
	if combat.player_won:
		combat.last_overkill += maxi(0, -combat.enemy.hp)
		combat.enemy.hp = 0
		return
	if combat.enemy.hp > 0:
		return
	if combat.enemy.sigils > 0:
		combat.enemy.sigils -= 1
		var definition := combat.enemy.definition
		if definition.phase_hp > 0:
			# Bosse mit Blatt kommen staerker zurueck, als sie gingen.
			definition.max_hp = definition.phase_hp
			combat.enemy.hp = definition.phase_hp
		else:
			combat.enemy.hp = maxi(1, Num.rnd(Num.mul(definition.max_hp, 0.45)))
		combat.enemy.stance = combat.enemy.definition.max_stance
		combat.enemy.attack_ramp += 3
		result.log.append("SCHICKSALSSIEGEL BRICHT – der Gegner kehrt verändert zurück.")
		_on_phase_change(run, combat, result)
		return
	combat.last_overkill = maxi(0, -combat.enemy.hp)
	combat.enemy.hp = 0
	combat.player_won = true
	result.log.append("Gegner besiegt.")

func _roll_intent(combat: CombatState) -> void:
	var enemy := combat.enemy
	var definition := enemy.definition
	@warning_ignore("integer_division")
	var low_hp := enemy.hp <= definition.max_hp / 2
	var attack := definition.base_attack + enemy.attack_ramp
	var bonus := Num.add(1.0, combat.enemy_attack_bonus)
	var scaled := func(value: int) -> int:
		return 0 if value <= 0 else maxi(1, Num.rnd(Num.mul(value, bonus)))

	if low_hp and combat.turn % 4 == 0:
		enemy.intent = Enums.IntentType.FRENZY
		@warning_ignore("integer_division")
		enemy.intent_value = scaled.call(maxi(1, attack / 2))
		return

	var intent: int
	if not definition.pattern.is_empty():
		intent = definition.pattern[(combat.turn - 1) % definition.pattern.size()]
	# Der seltenere Zug wird zuerst geprueft.
	elif combat.turn % 5 == 0:
		intent = Enums.IntentType.HEX
	elif combat.turn % 3 == 0:
		intent = Enums.IntentType.GUARD
	else:
		intent = Enums.IntentType.ATTACK

	enemy.intent = intent
	match intent:
		Enums.IntentType.GUARD:
			@warning_ignore("integer_division")
			enemy.intent_value = maxi(4, definition.max_stance / 2)
		Enums.IntentType.HEX, Enums.IntentType.DRAIN:
			enemy.intent_value = scaled.call(attack)
		Enums.IntentType.FRENZY:
			enemy.intent_value = scaled.call(maxi(1, Num.rnd(Num.mul(attack, 0.6))))
		_:
			enemy.intent_value = scaled.call(attack + (2 if low_hp else 0))

func _distribute_fate_contribution(combat: CombatState, entries: Array, damage: int, stance_damage: int, mult: float) -> void:
	var total := 0
	for e in entries:
		total += (e["card"] as CardInstance).effective_rank()
	var total_ranks := maxi(1, total)
	for e in entries:
		var c: CardInstance = e["card"]
		var share := Num.dv(c.effective_rank(), total_ranks)
		_add_contribution(combat, c,
			Num.rnd(Num.mul(damage, share)), 0, 0,
			Num.rnd(Num.mul(stance_damage, share)),
			Num.mul(mult, share))

func _add_contribution(combat: CombatState, card: CardInstance, damage := 0, shield := 0, healing := 0, stance := 0, mult := 0.0) -> void:
	var contribution: PlayedCardContribution = combat.contributions.get(card.instance_id, null)
	if contribution == null:
		contribution = PlayedCardContribution.new()
		contribution.card = card
		combat.contributions[card.instance_id] = contribution
	contribution.damage += damage
	contribution.shield += shield
	contribution.healing += healing
	contribution.stance_damage += stance
	contribution.mult_contribution = Num.add(contribution.mult_contribution, mult)

func _award_rage_on_victory(combat: CombatState) -> void:
	for c in combat.last_played_cards:
		c.rage = mini(3, c.rage + 1)

func charm_stacks(run: RunState, effect: int) -> int:
	var charm := GameCatalog.charm_for_effect(effect)
	return 0 if charm == null else run.charm_stacks(charm.id)

## Die Legung in Wirkungsreihenfolge: [{placed, effective, card}], sortiert
## nach Wirkungsort, dann nach Lageort.
func resolved_entries(combat: CombatState) -> Array:
	var list: Array = []
	for slot in [S.PAST, S.PRESENT, S.FUTURE]:
		if combat.slots.has(slot):
			list.append({"placed": slot, "effective": effective_slot(combat, slot), "card": combat.slots[slot]})
	return Num.sortiert(list, func(e): return e["effective"] * 3 + e["placed"])

func _shuffle(list: Array) -> void:
	_rng.shuffle(list)

# ================================================== Bossregeln (BossRules.cs)
static func has_rule(combat: CombatState, rule: int) -> bool:
	return combat != null and combat.enemy != null and combat.enemy.definition != null and combat.enemy.definition.rules.has(rule)

## Der Gehaengte nimmt in der zweiten Phase eine Handkarte.
func hand_size_for(combat: CombatState) -> int:
	var enemy := combat.enemy if combat != null else null
	if enemy != null and has_rule(combat, R.HANGED_MAN) and enemy.phase >= 1 and not enemy.definition.rules_weakened:
		return HAND_SIZE - 1
	return HAND_SIZE

## Aktuelle Regeltexte des Gegners, fuer das Banner unter seinem Namen.
static func active_rule_texts(combat: CombatState) -> Array[String]:
	var out: Array[String] = []
	if combat == null or combat.enemy == null:
		return out
	for rule in combat.enemy.definition.rules:
		out.append(ActCatalog.rule_text(rule, combat.enemy.phase, combat.enemy.definition.rules_weakened))
	return out

static func _offer_pact(combat: CombatState) -> void:
	var weak := combat.enemy.definition.rules_weakened
	if weak and combat.pacts_offered > 0:
		return
	combat.pact_pending = true
	combat.pacts_offered += 1

## Was ein Pakt jetzt kosten wuerde (Max-HP).
static func pact_cost(combat: CombatState) -> int:
	if combat.enemy.definition.rules_weakened:
		return WEAK_PACT_MAX_HP_COST
	return SECOND_PACT_MAX_HP_COST if combat.pacts_offered >= 2 else PACT_MAX_HP_COST

static func pact_bonus(combat: CombatState) -> float:
	return Num.f(WEAK_PACT_FATE_BONUS) if combat.enemy.definition.rules_weakened else Num.f(PACT_FATE_BONUS)

## Der Teufel verhandelt: mehr Fate-Schaden fuer den Rest des Kampfes gegen
## dauerhafte Max-HP und Verdunkelung. Wer ablehnt, spuert seinen Zorn.
func answer_pact(run: RunState, combat: CombatState, accept: bool) -> bool:
	if not combat.pact_pending:
		return false
	combat.pact_pending = false
	var weak := combat.enemy.definition.rules_weakened
	if accept:
		combat.fate_bonus = Num.add(combat.fate_bonus, pact_bonus(combat))
		run.max_hp = maxi(10, run.max_hp - pact_cost(combat))
		run.hp = mini(run.hp, run.max_hp)
		run.add_darkness(PACT_DARKNESS)
		run.stats.pacts_accepted += 1
	elif not weak:
		combat.enemy_attack_bonus = Num.add(combat.enemy_attack_bonus, PACT_DECLINE_PENALTY)
	# Die angezeigte Absicht muss den neuen Zorn schon zeigen.
	_roll_intent(combat)
	return true

## Setzt die Regeln fuer den kommenden Zug: eingestuerzte Position,
## verborgene Absicht, verdeckte Karten, gezeichnete Karte.
func _prepare_rules(run: RunState, combat: CombatState, result: TurnResult) -> void:
	var enemy := combat.enemy
	var weak := enemy.definition.rules_weakened
	var phase := enemy.phase
	combat.blocked_slot = -1
	combat.veiled_cards.clear()
	enemy.intent_hidden = false

	if has_rule(combat, R.TOWER):
		var interval := 4 if weak else (2 if phase >= 1 else 3)
		if combat.turn >= interval and combat.turn % interval == 0:
			var slot: int = TOWER_CYCLE[combat.tower_collapses % TOWER_CYCLE.size()]
			combat.tower_collapses += 1
			combat.blocked_slot = slot
			if result != null:
				result.tower_collapsed = slot
				result.log.append("Der Turm wirft seinen Schatten: die %s stürzt ein." % slot_name(slot))

	if has_rule(combat, R.MOON):
		var hidden := (combat.turn % 3 == 0) if weak else (phase >= 1 or combat.turn % 2 == 0)
		if hidden:
			enemy.intent_hidden = true
			var count := 2 if phase >= 1 and not weak else 1
			for c in _rng.pick_distinct(combat.hand, mini(count, combat.hand.size())):
				combat.veiled_cards[(c as CardInstance).instance_id] = true
			if result != null:
				result.log.append("Der Mond verhüllt, was kommt.")

	if has_rule(combat, R.DEATH) and combat.marked_card_id == "" \
			and combat.turn >= combat.next_mark_turn and run.deck.size() > GameCatalog.MINIMUM_DECK_SIZE:
		# Der Tod liebt, was du liebst: er zeichnet deine staerkste Karte.
		var target: CardInstance = Num.groesstes(run.deck, func(c): return c.shimmer * 6 + c.level * 3 + c.definition.rank)
		combat.marked_card_id = target.instance_id
		combat.mark_turns_left = 4 if weak else (2 if phase >= 1 else 3)
		if result != null:
			result.log.append("Der Tod zeichnet %s. Noch %d Runden." % [target.definition.name, combat.mark_turns_left])

	if has_rule(combat, R.HIEROPHANT):
		var interval := 3 if weak else (1 if phase >= 1 else 2)
		var max_acolytes := 2 if weak else (5 if phase >= 1 else 3)
		if combat.turn % interval == 0 and combat.acolytes < max_acolytes:
			combat.acolytes += 1
			if result != null:
				result.log.append("Der Hierophant ruft einen Akolythen. Es sind %d." % combat.acolytes)
		# In der zweiten Phase schlagen die Akolythen mit.
		if phase >= 1 and not weak and enemy.intent != Enums.IntentType.GUARD:
			enemy.intent_value += ACOLYTE_STRIKE * combat.acolytes

	if has_rule(combat, R.SUN):
		combat.suns += 2 if phase >= 1 else 1
		if result != null:
			result.log.append("Eine neue Sonne geht auf. Es sind %d." % combat.suns)

# ------------------------------------------------------ Maessigkeit
## Wasserrunden (ungerade) und Feuerrunden (gerade).
static func is_fire_round(combat: CombatState) -> bool:
	return combat.turn % 2 == 0

## Stab ist Feuer, Kelch ist Wasser: das Element der Runde halbiert sein Gegenteil.
static func temperance_factor(combat: CombatState, card: CardInstance) -> float:
	if not has_rule(combat, R.TEMPERANCE):
		return 1.0
	var suit := card.definition.suit
	if suit == Enums.Suit.WANDS and not is_fire_round(combat):
		return Num.f(TEMPERANCE_HALF)
	if suit == Enums.Suit.CUPS and is_fire_round(combat):
		return Num.f(TEMPERANCE_HALF)
	return 1.0

## Zweite Phase: wer beide Elemente legt, haelt das Gleichgewicht.
static func temperance_mixing(combat: CombatState) -> bool:
	return has_rule(combat, R.TEMPERANCE) and combat.enemy.phase >= 1 and not combat.enemy.definition.rules_weakened

static func is_balanced(cards: Array) -> bool:
	var wands := false
	var cups := false
	for c in cards:
		var suit: int = (c as CardInstance).definition.suit
		wands = wands or suit == Enums.Suit.WANDS
		cups = cups or suit == Enums.Suit.CUPS
	return wands and cups

## Vor dem Gegnerzug: die Akolythen segnen ihn mit Schild.
func _apply_blessings(combat: CombatState, result: TurnResult) -> void:
	if not has_rule(combat, R.HIEROPHANT) or combat.acolytes <= 0:
		return
	var shield := ACOLYTE_BLESSING * combat.acolytes
	combat.enemy.shield += shield
	result.log.append("%d Akolythen segnen den Hierophanten: +%d Schild." % [combat.acolytes, shield])

## Nach dem Gegnerzug: vier Sonnen am Himmel werden zur Supernova.
func _check_supernova(run: RunState, combat: CombatState, result: TurnResult) -> void:
	if not has_rule(combat, R.SUN) or combat.suns < SUPERNOVA_AT or combat.player_lost:
		return
	var damage := SUPERNOVA_PER_SUN * combat.suns
	result.log.append("SUPERNOVA – %d Sonnen verglühen." % combat.suns)
	result.supernova = true
	combat.suns = 0
	_take_player_damage(run, combat, damage, result)

## Gebrochene Haltung vertreibt Akolythen und loescht Sonnen.
static func _on_stance_broken(combat: CombatState, result: TurnResult) -> void:
	if combat.acolytes > 0:
		result.log.append("Die Haltung bricht – %d Akolythen fliehen." % combat.acolytes)
		combat.acolytes = 0
	if combat.suns > 0:
		result.log.append("Die Haltung bricht – %d Sonnen erlöschen." % combat.suns)
		combat.suns = 0

## Die gezeichnete Karte, falls es eine gibt.
static func marked_card(run: RunState, combat: CombatState) -> CardInstance:
	if combat == null or combat.marked_card_id == "":
		return null
	for c in run.deck:
		if c.instance_id == combat.marked_card_id:
			return c
	return null

## Wer die gezeichnete Karte in die Zukunft legt und den Zug ueberlebt,
## rettet sie - die Zukunft gehoert nicht dem Tod.
static func _lift_mark_if_faced(combat: CombatState, future: Array, result: TurnResult) -> void:
	if combat.marked_card_id == "":
		return
	for e in future:
		var c: CardInstance = e["card"]
		if c.instance_id == combat.marked_card_id:
			combat.marked_card_id = ""
			combat.next_mark_turn = combat.turn + 3
			result.log.append("%s hat dem Tod in die Augen gesehen. Das Zeichen verblasst." % c.definition.name)
			return

static func _tick_death_mark(run: RunState, combat: CombatState, result: TurnResult) -> void:
	if combat.marked_card_id == "":
		return
	combat.mark_turns_left -= 1
	if combat.mark_turns_left > 0:
		return
	var card := marked_card(run, combat)
	combat.marked_card_id = ""
	combat.next_mark_turn = combat.turn + 2
	if card == null or run.deck.size() <= GameCatalog.MINIMUM_DECK_SIZE:
		return
	run.deck.erase(card)
	run.removed_cards.append(card)
	combat.hand.erase(card)
	combat.draw_pile.erase(card)
	combat.discard_pile.erase(card)
	run.stats.cards_lost_to_death += 1
	result.card_lost = card.definition.name
	result.log.append("DER TOD NIMMT %s." % card.definition.name.to_upper())

static func _on_phase_change(run: RunState, combat: CombatState, result: TurnResult) -> void:
	var enemy := combat.enemy
	enemy.phase += 1
	result.phase_changed = true
	for text in active_rule_texts(combat):
		if text != "":
			result.log.append("Neue Phase – " + text)
	if has_rule(combat, R.DEVIL):
		_offer_pact(combat)
