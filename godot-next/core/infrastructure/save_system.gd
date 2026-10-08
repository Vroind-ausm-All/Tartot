extends RefCounted
class_name SaveSystem
## Speichern und Laden (Infrastructure/SaveGame.cs) - dasselbe JSON-Format
## wie der C#-Kern.
##
## Karten werden einmal als Pool abgelegt und ueberall sonst nur ueber ihre
## Instanz-Id referenziert. Sonst wuerde eine Karte, die zugleich im Deck und
## im Ablagestapel liegt, beim Laden zu zwei verschiedenen Objekten.
## Zufallszustaende stehen als Dezimaltext darin, weil ulong nicht
## verlustfrei in double passt.

static func serialize(game: GameController, indented := false) -> String:
	assert(game != null)
	var root := {
		"version": SaveData.CURRENT_VERSION,
		"seed": game.seed,
		"phase": Enums.NAMES_PHASE[game.phase],
		"rng": {
			"world": _write_random(game.world_random_snapshot()),
			"combat": _write_random(game.combat_random_snapshot()),
			"progression": _write_random(game.progression_random_snapshot()),
		},
	}
	# Alle Karteninstanzen, die irgendwo vorkommen, genau einmal.
	var cards: Array = []
	for card: CardInstance in _collect_cards(game).values():
		cards.append(_write_card(card))
	root["cards"] = cards
	root["run"] = _write_run(game.run)
	if game.combat != null:
		root["combat"] = _write_combat(game.combat)
		root["enemyId"] = game.combat.enemy.definition.id if game.combat.enemy != null and game.combat.enemy.definition != null else ""
	if game.current_event != null:
		root["event"] = {"id": game.current_event.id, "resolved": game.event_resolved, "epilogue": game.event_epilogue}
	return JSON.stringify(root, "  " if indented else "", false, true)

static func deserialize(text: String) -> SaveData:
	var parsed: Variant = JSON.parse_string(text)
	var root: Dictionary = parsed if parsed is Dictionary else {}
	var save := SaveData.new()
	save.version = _int(root, "version", 1)
	save.seed = _int(root, "seed")
	save.phase = _enum(root, "phase", Enums.NAMES_PHASE, Enums.GamePhase.COMBAT)
	save.enemy_id = _str(root, "enemyId")

	var rng: Dictionary = root.get("rng", {}) if root.get("rng") is Dictionary else {}
	save.world_random = _read_random(rng.get("world"))
	save.combat_random = _read_random(rng.get("combat"))
	save.progression_random = _read_random(rng.get("progression"))

	var pool := {}
	for entry in _arr(root, "cards"):
		if entry is Dictionary:
			var card := _read_card(entry)
			if card != null:
				pool[card.instance_id] = card

	save.run = _read_run(root.get("run"), pool)
	var combat_node: Variant = root.get("combat")
	if combat_node is Dictionary:
		save.combat = _read_combat(combat_node, pool, save.enemy_id)
	var event_node: Variant = root.get("event")
	if event_node is Dictionary:
		save.event_id = _str(event_node, "id")
		save.event_resolved = _bool(event_node, "resolved")
		save.event_epilogue = _str(event_node, "epilogue")
	return save

## Liefert null, wenn der Text kein brauchbarer Speicherstand ist.
static func try_deserialize(text: String) -> SaveData:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return null
	var save := deserialize(text)
	return save if save.run != null else null

# ------------------------------------------------------------ JSON-Helfer
static func _int(node: Dictionary, key: String, fallback := 0) -> int:
	var v: Variant = node.get(key)
	return Num.rnd(float(v)) if (v is float or v is int) else fallback

static func _float(node: Dictionary, key: String, fallback := 0.0) -> float:
	var v: Variant = node.get(key)
	return Num.f(float(v)) if (v is float or v is int) else fallback

static func _bool(node: Dictionary, key: String, fallback := false) -> bool:
	var v: Variant = node.get(key)
	return v if v is bool else fallback

static func _str(node: Dictionary, key: String, fallback := "") -> String:
	var v: Variant = node.get(key)
	return v if v is String else fallback

static func _arr(node: Dictionary, key: String) -> Array:
	var v: Variant = node.get(key)
	return v if v is Array else []

static func _enum(node: Dictionary, key: String, names: Array, fallback: int) -> int:
	var v: Variant = node.get(key)
	return Enums.parse(names, v, fallback) if v is String else fallback

static func _strings(node: Dictionary, key: String) -> Array[String]:
	var out: Array[String] = []
	for v in _arr(node, key):
		if v is String:
			out.append(v)
	return out

static func _sorted(keys: Array) -> Array:
	var k := keys.duplicate()
	k.sort()
	return k

# ------------------------------------------------------------ Karten
static func _collect_cards(game: GameController) -> Dictionary:
	var pool := {}
	var lists: Array = [game.run.deck, game.run.removed_cards]
	if game.combat != null:
		lists.append_array([game.combat.draw_pile, game.combat.discard_pile, game.combat.hand,
			game.combat.slots.values(), game.combat.last_played_cards])
	for list in lists:
		for card in list:
			if card != null:
				pool[card.instance_id] = card
	return pool

static func _write_card(card: CardInstance) -> Dictionary:
	return {
		"id": card.instance_id,
		"def": card.definition.id,
		"level": card.level,
		"shimmer": Enums.NAMES_SHIMMER[card.shimmer],
		"orientation": Enums.NAMES_ORIENTATION[card.orientation],
		"copy": card.is_copy,
		"xp": card.experience,
		"marks": card.victory_marks,
		"rage": card.rage,
		"edition": Enums.NAMES_EDITION[card.edition],
	}

static func _read_card(node: Dictionary) -> CardInstance:
	var definition := GameCatalog.card(_str(node, "def"))
	if definition == null:
		return null   # Karte aus einer alten Version
	var card := CardInstance.new(definition, _bool(node, "copy"))
	card.instance_id = _str(node, "id")
	card.level = maxi(1, _int(node, "level", 1))
	card.shimmer = _enum(node, "shimmer", Enums.NAMES_SHIMMER, Enums.Shimmer.MATTE)
	card.orientation = _enum(node, "orientation", Enums.NAMES_ORIENTATION, Enums.Orientation.UPRIGHT)
	card.experience = _int(node, "xp")
	card.victory_marks = _int(node, "marks")
	card.rage = _int(node, "rage")
	card.edition = _enum(node, "edition", Enums.NAMES_EDITION, Enums.CardEdition.NONE)
	return card

static func _card_refs(cards: Array) -> Array:
	var out: Array = []
	for card in cards:
		out.append(card.instance_id)
	return out

static func _read_card_refs(node: Dictionary, key: String, pool: Dictionary) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for v in _arr(node, key):
		if v is String and pool.has(v):
			out.append(pool[v])
	return out

static func _counts(d: Dictionary) -> Dictionary:
	var node := {}
	for k in d:
		node[k] = int(d[k])
	return node

# --------------------------------------------------------------- Run
static func _write_run(run: RunState) -> Dictionary:
	return {
		"deck": _card_refs(run.deck),
		"removed": _card_refs(run.removed_cards),
		"charms": _counts(run.charms),
		"items": _counts(run.items),
		"maxHp": run.max_hp,
		"hp": run.hp,
		"gold": run.gold,
		"fate": run.fate,
		"luck": run.luck,
		"fightIndex": run.fight_index,
		"endlessTier": run.endless_tier,
		"deckResonance": run.deck_resonance,
		"rewardRerolls": run.reward_rerolls,
		"shopRerolls": run.shop_rerolls,
		"reviveCharges": run.revive_charges,
		"startShieldBuff": run.start_shield_buff,
		"freeShop": run.free_next_shop_purchase,
		"fateTotal": run.fate_score_total,
		"prophecy": run.prophecy,
		"shopRemovals": run.shop_removals,
		"shopRefines": run.shop_refines,
		"interpretations": _counts(run.interpretations),
		"deuter": run.deuter_id if run.deuter_id != "" else DeuterCatalog.DEFAULT_ID,
		"deuterRule": Enums.NAMES_DEUTER_RULE[run.deuter_rule],
		"veil": run.veil,
		"daily": run.is_daily,
		"actBosses": run.act_bosses.duplicate(),
		"defeatedBosses": run.defeated_bosses.duplicate(),
		"seenEnemies": run.seen_enemies.duplicate(),
		"seenEvents": run.seen_events.duplicate(),
		"won": run.won,
		"pendingEnemy": run.pending_enemy_id,
		"nextElite": run.next_fight_elite,
		"lastPath": Enums.NAMES_PATH[run.last_path],
		"sinceShop": run.steps_since_shop,
		"sinceRest": run.steps_since_rest,
		"bonusRewards": run.bonus_reward_choices,
		"darkness": run.darkness,
		"storyFlags": _sorted(run.story_flags.keys()),
		"newStoryFlags": run.new_story_flags.duplicate(),
		"graveCard": run.grave_card_id,
		"graveFight": run.grave_fight,
		"charmPool": null if run.charm_pool == null else _sorted((run.charm_pool as Dictionary).keys()),
		"stats": run.stats.to_dictionary(),
		"bestHitCombo": run.stats.best_hit_combo,
	}

static func _read_run(node: Variant, pool: Dictionary) -> RunState:
	if not node is Dictionary:
		return null
	var run := RunState.new()
	run.max_hp = _int(node, "maxHp", 72)
	run.hp = _int(node, "hp", 72)
	run.gold = _int(node, "gold")
	run.fate = _int(node, "fate")
	run.luck = _int(node, "luck")
	run.fight_index = _int(node, "fightIndex")
	run.endless_tier = _int(node, "endlessTier")
	run.deck_resonance = _int(node, "deckResonance", 1)
	run.reward_rerolls = _int(node, "rewardRerolls")
	run.shop_rerolls = _int(node, "shopRerolls")
	run.revive_charges = _int(node, "reviveCharges")
	run.start_shield_buff = _int(node, "startShieldBuff")
	run.free_next_shop_purchase = _bool(node, "freeShop")
	run.fate_score_total = _int(node, "fateTotal")
	run.prophecy = _str(node, "prophecy")
	run.shop_removals = _int(node, "shopRemovals")
	run.shop_refines = _int(node, "shopRefines")
	run.deuter_id = _str(node, "deuter", DeuterCatalog.DEFAULT_ID)
	run.deuter_rule = _enum(node, "deuterRule", Enums.NAMES_DEUTER_RULE, Enums.DeuterRule.NONE)
	run.veil = _int(node, "veil")
	run.is_daily = _bool(node, "daily")
	run.won = _bool(node, "won")
	run.pending_enemy_id = _str(node, "pendingEnemy")
	run.next_fight_elite = _bool(node, "nextElite")
	run.last_path = _enum(node, "lastPath", Enums.NAMES_PATH, Enums.PathType.FIGHT)
	run.steps_since_shop = _int(node, "sinceShop")
	run.steps_since_rest = _int(node, "sinceRest")
	run.bonus_reward_choices = _int(node, "bonusRewards")
	run.darkness = _int(node, "darkness")
	run.grave_card_id = _str(node, "graveCard")
	run.grave_fight = _int(node, "graveFight")

	run.act_bosses.append_array(_strings(node, "actBosses"))
	run.defeated_bosses.append_array(_strings(node, "defeatedBosses"))
	run.seen_enemies.append_array(_strings(node, "seenEnemies"))
	run.seen_events.append_array(_strings(node, "seenEvents"))
	for flag in _strings(node, "storyFlags"):
		run.story_flags[flag] = true
	run.new_story_flags.append_array(_strings(node, "newStoryFlags"))
	if node.get("charmPool") is Array:
		var cp := {}
		for id in _strings(node, "charmPool"):
			cp[id] = true
		run.charm_pool = cp

	# Staende aus Version 1 kennen keine geplanten Bosse: nachholen.
	if run.act_bosses.is_empty():
		for a in range(1, ActCatalog.ACT_COUNT + 1):
			run.act_bosses.append(ActCatalog.bosses_of(a)[0].id)

	var stats := {}
	if node.get("stats") is Dictionary:
		for k in node["stats"]:
			stats[String(k)] = Num.rnd(float(node["stats"][k]))
	run.stats.load(stats)
	run.stats.best_hit_combo = _str(node, "bestHitCombo")

	if node.get("interpretations") is Dictionary:
		for k in node["interpretations"]:
			run.interpretations[String(k)] = Num.rnd(float(node["interpretations"][k]))

	run.deck.append_array(_read_card_refs(node, "deck", pool))
	run.removed_cards.append_array(_read_card_refs(node, "removed", pool))

	if node.get("charms") is Dictionary:
		for k in node["charms"]:
			if GameCatalog.charm(String(k)) != null:
				run.charms[String(k)] = Num.rnd(float(node["charms"][k]))
	if node.get("items") is Dictionary:
		for k in node["items"]:
			if GameCatalog.item(String(k)) != null:
				run.items[String(k)] = Num.rnd(float(node["items"][k]))
	return run

# ------------------------------------------------------------- Kampf
static func _write_combat(combat: CombatState) -> Dictionary:
	var slots := {}
	for slot in combat.slots:
		slots[Enums.NAMES_SLOT[slot]] = combat.slots[slot].instance_id

	var enemy := combat.enemy
	var enemy_node := {
		"hp": enemy.hp,
		"stance": enemy.stance,
		"sigils": enemy.sigils,
		"shield": enemy.shield,
		"burn": enemy.burn,
		"ramp": enemy.attack_ramp,
		"broken": enemy.broken_this_round,
		"intent": Enums.NAMES_INTENT[enemy.intent],
		"intentValue": enemy.intent_value,
		"phase": enemy.phase,
		"intentHidden": enemy.intent_hidden,
		"definition": _write_enemy_definition(enemy.definition),
	}

	var contributions: Array = []
	for c: PlayedCardContribution in combat.contributions.values():
		contributions.append({"card": c.card.instance_id, "damage": c.damage, "shield": c.shield,
			"healing": c.healing, "stance": c.stance_damage, "mult": c.mult_contribution})

	return {
		"draw": _card_refs(combat.draw_pile),
		"discard": _card_refs(combat.discard_pile),
		"hand": _card_refs(combat.hand),
		"slots": slots,
		"enemy": enemy_node,
		"turn": combat.turn,
		"playerShield": combat.player_shield,
		"luck": combat.temporary_luck,
		"cardsPlayed": combat.cards_played_this_combat,
		"reshuffles": combat.reshuffles,
		"lastCombo": combat.last_combo_signature,
		"comboRepeats": combat.same_combo_repeats,
		"skipIntent": combat.skip_enemy_intent,
		"drawBonus": combat.temporary_draw_bonus,
		"lastPlayed": _card_refs(combat.last_played_cards),
		"chain": combat.pattern_chain,
		"overkill": combat.last_overkill,
		"blocked": Enums.NAMES_SLOT[combat.blocked_slot] if combat.blocked_slot >= 0 else "",
		"towerCollapses": combat.tower_collapses,
		"acolytes": combat.acolytes,
		"suns": combat.suns,
		"veiled": _sorted(combat.veiled_cards.keys()),
		"marked": combat.marked_card_id,
		"markTurns": combat.mark_turns_left,
		"nextMark": combat.next_mark_turn,
		"pactPending": combat.pact_pending,
		"pactsOffered": combat.pacts_offered,
		"fateBonus": combat.fate_bonus,
		"attackBonus": combat.enemy_attack_bonus,
		"worlds": combat.worlds_this_fight,
		"contributions": contributions,
	}

static func _write_enemy_definition(d: EnemyDefinition) -> Dictionary:
	var pattern: Array = []
	for intent in d.pattern:
		pattern.append(Enums.NAMES_INTENT[intent])
	var rules: Array = []
	for rule in d.rules:
		rules.append(Enums.NAMES_RULE[rule])
	return {
		"id": d.id, "name": d.name, "maxHp": d.max_hp, "maxStance": d.max_stance,
		"attack": d.base_attack, "sigils": d.sigils, "flavor": d.flavor,
		"tier": Enums.NAMES_TIER[d.tier], "act": d.act, "pattern": pattern, "rules": rules,
		"weakened": d.rules_weakened, "omen": d.omen_card_id, "art": d.art,
		"goldFactor": d.gold_factor, "phaseHp": d.phase_hp, "stage": d.stage,
	}

## Der Gegner wird vollstaendig gespeichert, nicht nur seine Id: Schleier,
## Verdunkelung, Spirale und Finale veraendern ihn gegenueber dem Katalog.
static func _read_enemy_definition(node: Variant) -> EnemyDefinition:
	if not node is Dictionary:
		return null
	var d := EnemyDefinition.new()
	d.id = _str(node, "id")
	d.name = _str(node, "name")
	d.max_hp = maxi(1, _int(node, "maxHp", 1))
	d.max_stance = _int(node, "maxStance")
	d.base_attack = _int(node, "attack")
	d.sigils = _int(node, "sigils")
	d.flavor = _str(node, "flavor")
	d.tier = _enum(node, "tier", Enums.NAMES_TIER, Enums.EnemyTier.NORMAL)
	d.act = _int(node, "act", 1)
	d.rules_weakened = _bool(node, "weakened")
	d.omen_card_id = _str(node, "omen")
	d.art = _str(node, "art")
	d.gold_factor = _float(node, "goldFactor", 1.0)
	d.phase_hp = _int(node, "phaseHp")
	d.stage = _str(node, "stage")
	for v in _arr(node, "pattern"):
		if v is String and Enums.NAMES_INTENT.has(v):
			d.pattern.append(Enums.NAMES_INTENT.find(v))
	for v in _arr(node, "rules"):
		if v is String and Enums.NAMES_RULE.has(v):
			d.rules.append(Enums.NAMES_RULE.find(v))
	return d

static func _read_combat(node: Dictionary, pool: Dictionary, enemy_id: String) -> CombatState:
	var enemy_node: Variant = node.get("enemy")
	var definition := _read_enemy_definition(enemy_node.get("definition") if enemy_node is Dictionary else null)
	if definition == null:
		var found := ActCatalog.find(enemy_id)
		definition = found.clone() if found != null else ActCatalog.all()[0].clone()
	var combat := CombatState.new()
	combat.enemy = EnemyState.new(definition)

	if enemy_node is Dictionary:
		var e := combat.enemy
		e.hp = _int(enemy_node, "hp", definition.max_hp)
		e.stance = _int(enemy_node, "stance", definition.max_stance)
		e.sigils = _int(enemy_node, "sigils", definition.sigils)
		e.shield = _int(enemy_node, "shield")
		e.burn = _int(enemy_node, "burn")
		e.attack_ramp = _int(enemy_node, "ramp")
		e.broken_this_round = _bool(enemy_node, "broken")
		e.intent = _enum(enemy_node, "intent", Enums.NAMES_INTENT, Enums.IntentType.ATTACK)
		e.intent_value = _int(enemy_node, "intentValue")
		e.phase = _int(enemy_node, "phase")
		e.intent_hidden = _bool(enemy_node, "intentHidden")

	combat.draw_pile.append_array(_read_card_refs(node, "draw", pool))
	combat.discard_pile.append_array(_read_card_refs(node, "discard", pool))
	combat.hand.append_array(_read_card_refs(node, "hand", pool))
	combat.last_played_cards.append_array(_read_card_refs(node, "lastPlayed", pool))

	var slots: Variant = node.get("slots")
	if slots is Dictionary:
		for k in slots:
			var slot := Enums.NAMES_SLOT.find(String(k))
			var ref: Variant = slots[k]
			if slot >= 0 and ref is String and pool.has(ref):
				combat.slots[slot] = pool[ref]

	combat.turn = _int(node, "turn", 1)
	combat.player_shield = _int(node, "playerShield")
	combat.temporary_luck = _int(node, "luck")
	combat.cards_played_this_combat = _int(node, "cardsPlayed")
	combat.reshuffles = _int(node, "reshuffles")
	combat.last_combo_signature = _str(node, "lastCombo")
	combat.same_combo_repeats = _int(node, "comboRepeats")
	combat.skip_enemy_intent = _bool(node, "skipIntent")
	combat.temporary_draw_bonus = _int(node, "drawBonus")
	combat.pattern_chain = _int(node, "chain")
	combat.last_overkill = _int(node, "overkill")
	combat.blocked_slot = Enums.NAMES_SLOT.find(_str(node, "blocked"))
	combat.tower_collapses = _int(node, "towerCollapses")
	combat.acolytes = _int(node, "acolytes")
	combat.suns = _int(node, "suns")
	for id in _strings(node, "veiled"):
		combat.veiled_cards[id] = true
	combat.marked_card_id = _str(node, "marked")
	combat.mark_turns_left = _int(node, "markTurns")
	combat.next_mark_turn = _int(node, "nextMark", 2)
	combat.pact_pending = _bool(node, "pactPending")
	combat.pacts_offered = _int(node, "pactsOffered")
	combat.fate_bonus = _float(node, "fateBonus")
	combat.enemy_attack_bonus = _float(node, "attackBonus")
	combat.worlds_this_fight = _int(node, "worlds")

	for entry in _arr(node, "contributions"):
		if not entry is Dictionary:
			continue
		var card_id := _str(entry, "card")
		if not pool.has(card_id):
			continue
		var c := PlayedCardContribution.new()
		c.card = pool[card_id]
		c.damage = _int(entry, "damage")
		c.shield = _int(entry, "shield")
		c.healing = _int(entry, "healing")
		c.stance_damage = _int(entry, "stance")
		c.mult_contribution = _float(entry, "mult")
		combat.contributions[card_id] = c
	return combat

# --------------------------------------------------------------- RNG
static func _write_random(s: Dictionary) -> Dictionary:
	# Als Zeichenkette, weil ulong nicht verlustfrei in double passt.
	return {
		"state": DeterministicRandom.ulong_to_string(int(s["state"])),
		"inc": DeterministicRandom.ulong_to_string(int(s["inc"])),
		"draws": int(s["draws"]),
	}

static func _read_random(node: Variant) -> Dictionary:
	if not node is Dictionary:
		return {"state": 0, "inc": 0, "draws": 0}
	return {
		"state": DeterministicRandom.ulong_from_string(_str(node, "state", "0")),
		"inc": DeterministicRandom.ulong_from_string(_str(node, "inc", "0")),
		"draws": _int(node, "draws"),
	}
