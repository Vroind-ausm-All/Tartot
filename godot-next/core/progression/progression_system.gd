extends RefCounted
class_name ProgressionSystem
## Sieg, Belohnungen, Ritual, Orakel, Items, Resonanz
## (Progression/ProgressionSystem.cs). Zieht nur aus dem Fortschrittsstrom.

## Ab dieser Deckgroesse gibt es keine Groessenpunkte mehr.
const DECK_SIZE_CEILING := 16
## Anteil legendaerer Karten unter den gezogenen Arkana.
const LEGENDARY_SHARE := 0.05

const E := Enums.CharmEffectType
const IT := Enums.ItemEffectType

var _rng: DeterministicRandom

func _init(rng: DeterministicRandom) -> void:
	assert(rng != null)
	_rng = rng

func random_snapshot() -> Dictionary:
	return _rng.snapshot()

func resolve_victory(run: RunState, combat: CombatState) -> VictorySummary:
	var summary := VictorySummary.new()
	var contributions: Array = Num.sortiert(combat.contributions.values(),
		func(c: PlayedCardContribution) -> float: return c.score(), true)
	var scores: Array = []
	for c: PlayedCardContribution in contributions:
		scores.append(c.score())
	var total := maxf(1.0, Num.summe_f(scores))
	var last := combat.last_score
	var fate_base := last.fate_damage if last != null else 10
	var quality_bonus := maxi(0, last.chips if last != null else 0) \
		+ Num.rnd(Num.mul(last.multiplier if last != null else 1.0, 20.0))
	var deck_bonus := 1.20 if run.deck.size() <= 10 else 1.0
	if run.prophecy == "XXI" and run.deck.size() <= 10:
		deck_bonus = Num.add(deck_bonus, 0.15)
	summary.fate_earned = maxi(15, Num.rnd(Num.mul(fate_base + quality_bonus, deck_bonus)))

	var greed := charm_stacks(run, E.GREED)
	var enemy := combat.enemy.definition
	var tier_gold := 1.5 if enemy.is_boss() else (1.3 if enemy.tier == Enums.EnemyTier.ELITE else 1.0)
	var veil_gold := 0.75 if run.veil >= 1 else 1.0
	var g := Num.mul(12 + run.fight_index * 3, Num.add(1.0, Num.mul(greed, 0.10)))
	g = Num.mul(g, tier_gold)
	g = Num.mul(g, enemy.gold_factor)
	g = Num.mul(g, veil_gold)
	summary.gold_earned = Num.rnd(g)
	run.fate += summary.fate_earned
	run.fate_score_total += summary.fate_earned
	run.gold += summary.gold_earned
	summary.best_combo = last.combo_name if last != null else "Offene Legung"

	for contribution: PlayedCardContribution in contributions:
		var share := Num.dv(contribution.score(), total)
		var xp := maxi(4, Num.rnd(Num.add(8.0, Num.mul(share, 28.0))))
		contribution.card.add_experience(xp)
		summary.card_xp.append([contribution.card, xp])

	if not contributions.is_empty():
		var top_three: Array = contributions.slice(0, 3)
		var weights: Array = []
		for x: PlayedCardContribution in top_three:
			weights.append(maxf(1.0, x.score()))
		var weighted_total := Num.summe_f(weights)
		var roll := Num.mul(_rng.next_float(), weighted_total)
		var accumulator := 0.0
		var chosen: PlayedCardContribution = top_three[0]
		for candidate: PlayedCardContribution in top_three:
			accumulator = Num.add(accumulator, maxf(1.0, candidate.score()))
			if roll <= accumulator:
				chosen = candidate
				break

		var card := chosen.card
		summary.champion = card
		card.add_experience(card.xp_to_next_level())
		card.add_victory_mark()

		# Gold bleibt der stabile Pfad. Blut ist eine riskante Sieger-Evolution.
		if card.shimmer == Enums.Shimmer.GOLD and card.level >= 8 and card.victory_marks >= 2:
			card.shimmer = Enums.Shimmer.BLOOD
		elif card.shimmer == Enums.Shimmer.BLOOD and card.level >= 12 and card.victory_marks >= 2:
			card.shimmer = Enums.Shimmer.BLACK

	var pentacle_gold := charm_stacks(run, E.PENTACLE_GOLD)
	if pentacle_gold > 0 and combat.player_shield >= 10:
		run.gold += pentacle_gold * 2

	update_deck_resonance(run)
	return summary

## Ein Charm, der noch Platz hat und nicht schon im selben Angebot liegt.
func _pick_offerable_charm(run: RunState, already_offered: Array) -> CharmDefinition:
	var candidates: Array = []
	for charm in GameCatalog.charms():
		if run.charm_stacks(charm.id) >= charm.max_stacks:
			continue
		if not run.charm_allowed(charm.id):
			continue
		var duplicate := false
		for offered: RewardOption in already_offered:
			if offered.charm != null and offered.charm.id == charm.id:
				duplicate = true
				break
		if not duplicate:
			candidates.append(charm)
	return null if candidates.is_empty() else _rng.pick(candidates)

static func _charm_reward(charm: CharmDefinition) -> RewardOption:
	var r := RewardOption.new()
	r.type = Enums.RewardType.CHARM
	r.title = charm.name
	r.description = charm.description
	r.charm = charm
	return r

## elite: Elites geben verlaesslich Charms - die ersten zwei Wahlen sind welche.
func generate_rewards(run: RunState, count := 3, elite := false) -> Array[RewardOption]:
	@warning_ignore("integer_division")
	count += charm_stacks(run, E.EXTRA_REWARD_CHOICE) / 2
	if run.bonus_reward_choices > 0:
		run.bonus_reward_choices -= 1
		count += 1
	if run.veil >= 3:
		count -= 1
	count = maxi(1, mini(5, count))
	var rewards: Array[RewardOption] = []
	var rare_chance := Num.add(Num.add(0.08, Num.mul(charm_stacks(run, E.RARE_CHANCE), 0.04)), Num.mul(run.luck, 0.01))
	var upgraded_chance := Num.add(0.05, Num.mul(charm_stacks(run, E.UPGRADED_REWARD_CHANCE), 0.08))
	# Der Eremit findet seltener Karten - er soll duenn bleiben wollen.
	var card_share := 25 if run.deuter_rule == Enums.DeuterRule.HERMIT else 45
	var reversed_chance := Num.mul(run.darkness, 0.005)

	if elite:
		var i := 0
		while i < 2 and rewards.size() < count:
			var charm := _pick_offerable_charm(run, rewards)
			if charm == null:
				break
			rewards.append(_charm_reward(charm))
			i += 1

	var guard := 0
	while rewards.size() < count:
		guard += 1
		if guard > 200:
			break
		var roll := _rng.next_int(100)
		if roll < card_share:
			var card := _random_card_reward(run, rare_chance)
			var shimmer := Enums.Shimmer.INDIGO if _rng.chance(rare_chance) else Enums.Shimmer.MATTE
			var upgraded := _rng.chance(upgraded_chance)
			var reversed := _rng.chance(reversed_chance)
			var edition := _roll_edition(run)
			var edition_title := "" if edition == Enums.CardEdition.NONE else CardEditions.name_of(edition) + ": "
			var edition_text := "" if edition == Enums.CardEdition.NONE else " %s: %s." % [CardEditions.name_of(edition), CardEditions.text_of(edition)]
			var r := RewardOption.new()
			r.type = Enums.RewardType.CARD
			r.title = edition_title + ("↕ " if reversed else "") + (card.name + "+" if upgraded else card.name)
			r.description = "%s · %s%s.%s %s" % [
				CardEditions.rarity_name(card.rarity()),
				"Indigo-Schimmer" if shimmer == Enums.Shimmer.INDIGO else "Matt",
				", umgekehrt" if reversed else "",
				edition_text, card.description]
			r.card_edition = edition
			r.card = card
			r.card_level = 2 if upgraded else 1
			r.card_shimmer = shimmer
			r.card_orientation = Enums.Orientation.REVERSED if reversed else Enums.Orientation.UPRIGHT
			rewards.append(r)
		elif roll < 75:
			var charm := _pick_offerable_charm(run, rewards)
			if charm == null:
				continue
			rewards.append(_charm_reward(charm))
		elif roll < 92:
			var item: ItemDefinition = _rng.pick(GameCatalog.items())
			var r := RewardOption.new()
			r.type = Enums.RewardType.ITEM
			r.title = item.name
			r.description = item.description
			r.item = item
			rewards.append(r)
		else:
			var fate := 45 + run.fight_index * 10
			var r := RewardOption.new()
			r.type = Enums.RewardType.FATE
			r.title = "%d Fate" % fate
			r.description = "Überspringe neue Teile und verdichte deinen bestehenden Build."
			r.fate = fate
			rewards.append(r)
	return rewards

func take_reward(run: RunState, reward: RewardOption) -> void:
	match reward.type:
		Enums.RewardType.CARD:
			var instance := CardInstance.new(reward.card)
			instance.level = maxi(1, reward.card_level)
			instance.shimmer = reward.card_shimmer
			instance.edition = reward.card_edition
			instance.orientation = reward.card_orientation
			run.deck.append(instance)
		Enums.RewardType.CHARM:
			run.add_charm(reward.charm)
		Enums.RewardType.ITEM:
			run.add_item(reward.item)
		Enums.RewardType.FATE:
			run.fate += reward.fate
	update_deck_resonance(run)

func remove_card(run: RunState, card: CardInstance, fate_cost := 120) -> bool:
	var discount := Num.mul(charm_stacks(run, E.REMOVE_DISCOUNT), 0.15)
	fate_cost = maxi(20, Num.rnd(Num.mul(fate_cost, maxf(Num.f(0.35), Num.sub(1.0, discount)))))
	if run.deuter_rule == Enums.DeuterRule.BOOKKEEPER:
		fate_cost *= 2
	if run.fate < fate_cost or run.deck.size() <= GameCatalog.MINIMUM_DECK_SIZE or not run.deck.has(card):
		return false
	run.fate -= fate_cost
	run.deck.erase(card)
	run.removed_cards.append(card)
	run.max_hp += charm_stacks(run, E.REMOVE_MAX_HP)
	run.hp = mini(run.hp, run.max_hp)
	update_deck_resonance(run)
	return true

static func _count_def(run: RunState, def_id: String) -> int:
	var n := 0
	for c in run.deck:
		if c.definition.id == def_id:
			n += 1
	return n

func mirror_card(run: RunState, card: CardInstance, fate_cost := 160) -> bool:
	if run.fate < fate_cost or not run.deck.has(card):
		return false
	if card.definition.is_major() and _count_def(run, card.definition.id) >= 2:
		return false
	run.fate -= fate_cost
	run.deck.append(_copy_of(card))
	update_deck_resonance(run)
	return true

static func _copy_of(card: CardInstance) -> CardInstance:
	var copy := CardInstance.new(card.definition, true)
	copy.level = card.level
	copy.shimmer = card.shimmer
	copy.orientation = card.orientation
	return copy

func flip_card(run: RunState, card: CardInstance, fate_cost := 90) -> bool:
	if run.fate < fate_cost or not run.deck.has(card):
		return false
	run.fate -= fate_cost
	card.orientation = Enums.Orientation.REVERSED if card.orientation == Enums.Orientation.UPRIGHT else Enums.Orientation.UPRIGHT
	return true

func evolve_card(run: RunState, card: CardInstance, fate_cost := 220) -> bool:
	if run.fate < fate_cost or not run.deck.has(card):
		return false
	run.fate -= fate_cost
	card.level += 1
	if card.shimmer < Enums.Shimmer.GOLD:
		card.shimmer += 1
	elif card.shimmer == Enums.Shimmer.GOLD:
		card.shimmer = Enums.Shimmer.BLOOD
	# Aufwerten hat immer auch einen dunklen Preis.
	run.add_darkness(2)
	EventCatalog.note_shimmer(run, card)
	return true

func shop_price(run: RunState, base_price: int) -> int:
	var discount := Num.mul(charm_stacks(run, E.SHOP_DISCOUNT), 0.05)
	return maxi(1, Num.rnd(Num.mul(base_price, maxf(Num.f(0.50), Num.sub(1.0, discount)))))

## Wie stimmig der Build ist - geht als Multiplikator in jede Legung ein.
func update_deck_resonance(run: RunState) -> void:
	var score := 1
	@warning_ignore("integer_division")
	score += maxi(0, DECK_SIZE_CEILING - run.deck.size()) / 2
	var indigo := false
	var gold := 0
	for c in run.deck:
		if c.shimmer >= Enums.Shimmer.INDIGO:
			indigo = true
		if c.shimmer >= Enums.Shimmer.GOLD:
			gold += 1
	if indigo:
		score += 1
	if gold >= 2:
		score += 1
	var charms := run.charm_total()
	if charms >= 6:
		score += 1
	if charms >= 12:
		score += 1
	if run.fight_index >= 4:
		score += 1
	if run.fight_index >= 7:
		score += 1
	run.deck_resonance = mini(10, score)

func apply_oracle(run: RunState, prophecy: String) -> void:
	run.prophecy = prophecy
	if prophecy == "BLUT":
		var n := 0
		for card in run.deck:
			if n >= 2:
				break
			if card.orientation == Enums.Orientation.REVERSED:
				card.add_experience(15)
				n += 1
	elif prophecy == "EINHEIT":
		run.fate += 60
	elif prophecy == "XXI":
		run.luck += 1

func use_item(run: RunState, combat: CombatState, item_id: String, target: CardInstance = null) -> bool:
	var item := GameCatalog.item(item_id)
	if item == null or not run.consume_item(item_id):
		return false
	match item.effect:
		IT.MIRROR_CARD:
			if target == null or not _mirror_card_free(run, target):
				run.add_item(item)
				return false
		IT.REMOVE_CARD:
			if target == null or not _remove_card_free(run, target):
				run.add_item(item)
				return false
		IT.FLIP_CARD:
			if target == null:
				run.add_item(item)
				return false
			target.orientation = Enums.Orientation.REVERSED if target.orientation == Enums.Orientation.UPRIGHT else Enums.Orientation.UPRIGHT
		IT.UPGRADE_CARD:
			if target == null:
				run.add_item(item)
				return false
			target.level += 1
		IT.HEAL:
			run.hp = mini(run.max_hp, run.hp + item.magnitude)
		IT.GAIN_GOLD:
			run.gold += item.magnitude
		IT.GAIN_LUCK:
			run.luck += item.magnitude
			if combat != null:
				combat.temporary_luck += item.magnitude
		IT.REVIVE:
			run.revive_charges += 1
		IT.START_SHIELD_BUFF:
			run.start_shield_buff += item.magnitude
		IT.SKIP_ENEMY_INTENT:
			if combat == null:
				run.add_item(item)
				return false
			combat.skip_enemy_intent = true
		IT.TOWER_BLAST:
			if combat == null:
				run.add_item(item)
				return false
			combat.player_shield = 0
			combat.enemy.hp -= item.magnitude
		IT.DEVILS_BARGAIN:
			run.free_next_shop_purchase = true
		IT.RESTORE_REMOVED_CARD:
			if not run.removed_cards.is_empty():
				var restored: CardInstance = run.removed_cards.pop_back()
				restored.level += 1
				run.deck.append(restored)
		_:
			# Einige Utility-Items sind fuer spaetere UI-Interaktionen reserviert.
			run.fate += 15
	update_deck_resonance(run)
	return true

func _mirror_card_free(run: RunState, card: CardInstance) -> bool:
	if not run.deck.has(card):
		return false
	if card.definition.is_major() and _count_def(run, card.definition.id) >= 2:
		return false
	run.deck.append(_copy_of(card))
	return true

func _remove_card_free(run: RunState, card: CardInstance) -> bool:
	if not run.deck.has(card) or run.deck.size() <= 5:
		return false
	run.deck.erase(card)
	run.removed_cards.append(card)
	return true

func _random_card_reward(_run: RunState, rare_chance: float) -> CardDefinition:
	var majors: Array = []
	var minors: Array = []
	for c in GameCatalog.cards():
		if c.is_major():
			majors.append(c)
		else:
			minors.append(c)
	if _rng.chance(minf(Num.f(0.30), rare_chance)):
		# Legendaere Arkana kommen seltener als die uebrigen.
		var legendary: Array = []
		var others: Array = []
		for c: CardDefinition in majors:
			if c.rarity() == Enums.Rarity.LEGENDARY:
				legendary.append(c)
			else:
				others.append(c)
		return _rng.pick(legendary) if _rng.chance(LEGENDARY_SHARE) else _rng.pick(others)
	return _rng.pick(minors)

## Wuerfelt die Edition einer Belohnungskarte. Der Katzenzahn macht sie wahrscheinlicher.
func _roll_edition(run: RunState) -> int:
	var roll := _rng.next_int(1000) - charm_stacks(run, E.RARE_CHANCE) * 10
	for edition in CardEditions.ALL:
		roll -= int(CardEditions.REWARD_PERMILLE[edition])
		if roll < 0:
			return edition
	return Enums.CardEdition.NONE

func charm_stacks(run: RunState, effect: int) -> int:
	var charm := GameCatalog.charm_for_effect(effect)
	return 0 if charm == null else run.charm_stacks(charm.id)
