extends SceneTree
## Spur eines Autopilot-Runs fuer den Paritaetsbeweis gegen den C#-Kern.
##
##   godot --headless --path godot-next --script res://tools/trace.gd -- --trace=7 --deuter=eremit --veil=3 --spiral=1
##
## Format wie src/Tartot.Sim/Trace.cs - tools/paritaet.sh vergleicht beide
## Zeile fuer Zeile.

func _init() -> void:
	var args := _args()
	var seed := int(args.get("trace", "1"))
	var max_fights := int(args.get("fights", "30"))
	var setup := RunSetup.new(String(args.get("deuter", DeuterCatalog.DEFAULT_ID)), int(args.get("veil", "0")),
		int(args.get("daily", "0")) != 0)
	var spiral := int(args.get("spiral", "0")) != 0
	print(write_trace(seed, max_fights, setup, spiral, int(args.get("laufbahn", "0")), int(args.get("roundtrip", "0")) != 0))
	quit()

static func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out

## career > 0: so viele Runs hintereinander mit einem gemeinsamen Meta-Fortschritt.
## roundtrip: nach jeder Zeile speichern und neu laden.
static func write_trace(seed: int, max_fights: int, setup: RunSetup, spiral: bool, career := 0, roundtrip := false) -> String:
	var out := PackedStringArray()
	if career <= 0:
		_play_traced(seed, max_fights, setup, spiral, null, roundtrip, out)
	else:
		var meta := MetaProgress.new()
		for i in career:
			var game := _play_traced(seed + i, max_fights, setup, spiral, meta, roundtrip, out)
			var won := game.run.won
			var killed_by := "-"
			if not won and game.phase == Enums.GamePhase.GAME_OVER and game.combat != null:
				killed_by = game.combat.enemy.definition.name
			var report := meta.complete_run(game, won, killed_by)
			out.append(_report_line(report))
			out.append("M " + meta.serialize())
	return "\n".join(out)

static func _play_traced(seed: int, max_fights: int, setup: RunSetup, spiral: bool, meta: MetaProgress,
		roundtrip: bool, out: PackedStringArray) -> GameController:
	var pilot := Autopilot.new()
	pilot.setup = setup
	pilot.continue_into_spiral = spiral
	pilot.meta = meta
	var game := GameController.new(seed, meta, setup)
	out.append(_step_line(game, "start"))

	var guard := 0
	while game.phase != Enums.GamePhase.GAME_OVER and game.run.fight_index < max_fights and guard < 5000:
		guard += 1
		if game.phase == Enums.GamePhase.COMBAT:
			var turns := 0
			while game.phase == Enums.GamePhase.COMBAT and turns < pilot.max_turns_per_fight:
				turns += 1
				if not pilot.arrange(game):
					break
				var layout := _layout(game)
				var enemy_before := game.combat.enemy
				var intent_before := enemy_before.intent
				var round_before := game.combat.turn
				var result := game.resolve_turn()
				var cues := "+".join(AnimationCues.for_turn(result, enemy_before, intent_before, round_before))
				out.append(_turn_line(game, result, layout) + " cues=" + cues)
				if roundtrip:
					game = _round_trip(game)
			out.append(_step_line(game, "combat"))
			continue
		var before := game.phase
		pilot.step(game)
		out.append(_step_line(game, Enums.NAMES_PHASE[before]))
		if roundtrip:
			game = _round_trip(game)

	out.append("E won=%s fi=%d fate=%d stats=%s combo=%s" % [_b(game.run.won), game.run.fight_index,
		game.run.fate_score_total, _counts(game.run.stats.to_dictionary()), game.run.stats.best_hit_combo])
	out.append("J " + game.save())
	return game

static func _round_trip(game: GameController) -> GameController:
	return GameController.restore(SaveSystem.deserialize(game.save()))

static func _report_line(r: RunReport) -> String:
	var near := PackedStringArray()
	for n in r.near_misses:
		near.append("%s|%s|%s|%s" % [n.title, n.detail, n.reward, _bits(n.progress)])
	return "R won=%s head=%s fights=%d act=%d spiral=%d fate=%d best=%d combo=%s by=%s dark=%d records=%s unlocked=%s near=%s" % [
		_b(r.won), r.headline, r.fights_cleared, r.act, r.spiral_depth, r.fate_total, r.best_hit, r.best_hit_combo,
		r.killed_by, r.darkness, " ; ".join(r.records), " ; ".join(r.unlocked), " ; ".join(near)]

static func _b(x: bool) -> String:
	return "1" if x else "0"

static func _bits(f: float) -> String:
	return str(PackedFloat32Array([f]).to_byte_array().decode_s32(0))

static func _card(c: CardInstance) -> String:
	return "%s:%d:%d:%d:%d:%d:%d:%d%s" % [c.definition.id, c.level, c.shimmer, c.orientation, c.edition,
		c.experience, c.victory_marks, c.rage, ":c" if c.is_copy else ""]

static func _cards(cards: Array) -> String:
	var parts := PackedStringArray()
	for c in cards:
		parts.append(_card(c))
	return ",".join(parts)

static func _join(xs: Array, sep := ",") -> String:
	var parts := PackedStringArray()
	for x in xs:
		parts.append(str(x))
	return sep.join(parts)

static func _counts(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s=%d" % [k, int(d[k])])
	return ",".join(parts)

static func _clean(s: String) -> String:
	return s.replace("\n", " | ")

static func _rng(game: GameController) -> String:
	return "%d/%d/%d" % [game.world_random_snapshot()["draws"], game.combat_random_snapshot()["draws"],
		game.progression_random_snapshot()["draws"]]

static func _layout(game: GameController) -> String:
	var parts := PackedStringArray()
	for s in Autopilot.ALL_SLOTS:
		if game.combat.slots.has(s):
			parts.append("%d=%s" % [s, game.combat.slots[s].definition.id])
	return ",".join(parts)

static func _turn_line(game: GameController, r: TurnResult, layout: String) -> String:
	var c := game.combat
	var e := c.enemy
	var s: ScoreBreakdown = r.score if r != null else null
	var sb := "T"
	sb += " fi=%d turn=%d lay=%s" % [game.run.fight_index, c.turn, layout]
	if s != null:
		sb += " chips=%d mult=%s fd=%d exp=%d combo=%s rep=%s chain=%d" % [s.chips, _bits(s.multiplier), s.fate_damage,
			s.expected_hit, s.combo_name, _bits(s.repeat_penalty), s.chain]
	if r != null:
		sb += " dmg=%d edmg=%d heal=%d sg=%d br=%s v=%s d=%s ok=%d lost=%s nova=%s refl=%d shat=%s" % [r.fate_damage,
			r.enemy_damage, r.healing, r.shield_gained, _b(r.stance_broken), _b(r.victory), _b(r.defeat), r.overkill,
			r.card_lost, _b(r.supernova), r.reflected, _join(r.shattered)]
	sb += " e=%s ehp=%d est=%d sig=%d esh=%d burn=%d ramp=%d int=%d:%d:%s eph=%d" % [e.definition.id, e.hp, e.stance,
		e.sigils, e.shield, e.burn, e.attack_ramp, e.intent, e.intent_value, _b(e.intent_hidden), e.phase]
	sb += " hp=%d/%d sh=%d luck=%d chainc=%d sig=%s reps=%d" % [game.run.hp, game.run.max_hp, c.player_shield,
		c.temporary_luck, c.pattern_chain, c.last_combo_signature, c.same_combo_repeats]
	sb += " blk=%s acol=%d suns=%d mark=%s:%d pact=%s:%d:%s:%s" % ["-" if c.blocked_slot < 0 else str(c.blocked_slot),
		c.acolytes, c.suns, _b(c.marked_card_id != ""), c.mark_turns_left, _b(c.pact_pending), c.pacts_offered,
		_bits(c.fate_bonus), _bits(c.enemy_attack_bonus)]
	var hand := PackedStringArray()
	var veiled := 0
	for x in c.hand:
		hand.append(x.definition.id)
		if c.veiled_cards.has(x.instance_id):
			veiled += 1
	sb += " hand=%s veil=%d" % [",".join(hand), veiled]
	sb += " draw=%d disc=%d rng=%s" % [c.draw_pile.size(), c.discard_pile.size(), _rng(game)]
	if r != null:
		sb += " log=" + _clean(" / ".join(r.log))
	return sb

static func _step_line(game: GameController, what: String) -> String:
	var run := game.run
	var sb := "S " + what
	sb += " phase=%d fi=%d act=%d hp=%d/%d gold=%d fate=%d total=%d" % [game.phase, run.fight_index, run.act(), run.hp,
		run.max_hp, run.gold, run.fate, run.fate_score_total]
	sb += " luck=%d dark=%d res=%d veil=%d bonus=%d free=%s rev=%d ssb=%d" % [run.luck, run.darkness, run.deck_resonance,
		run.veil, run.bonus_reward_choices, _b(run.free_next_shop_purchase), run.revive_charges, run.start_shield_buff]
	sb += " proph=%s rem=%d ref=%d pend=%s elite=%s last=%d ss=%d sr=%d" % [run.prophecy, run.shop_removals,
		run.shop_refines, run.pending_enemy_id, _b(run.next_fight_elite), run.last_path, run.steps_since_shop,
		run.steps_since_rest]
	sb += " bosses=%s def=%s seen=%s ev=%s" % [_join(run.act_bosses), _join(run.defeated_bosses), _join(run.seen_enemies),
		_join(run.seen_events)]
	var flags := run.story_flags.keys()
	flags.sort()
	sb += " flags=%s new=%s" % [_join(flags), _join(run.new_story_flags)]
	sb += " charms=%s items=%s" % [_counts(run.charms), _counts(run.items)]
	sb += " deck=%s removed=%s" % [_cards(run.deck), _cards(run.removed_cards)]
	sb += " paths=%s" % _join(game.paths)
	var rewards := PackedStringArray()
	for x in game.rewards:
		rewards.append("%d:%s:%d:%d:%d:%d" % [x.type, x.title, x.card_level, x.card_shimmer, x.card_orientation, x.card_edition])
	sb += " rewards=" + " ; ".join(rewards)
	var shop := PackedStringArray()
	for o in game.shop_offers:
		shop.append("%s:%d:%s" % [o.reward.title, o.price, _b(o.sold)])
	sb += " shop=" + " ; ".join(shop)
	sb += " event=%s:%s" % [game.current_event.id if game.current_event != null else "-", _b(game.event_resolved)]
	if game.last_victory != null:
		var v := game.last_victory
		var xps := []
		for pair in v.card_xp:
			xps.append(pair[1])
		sb += " vic=%d:%d:%d:%s:%s" % [v.fate_earned, v.gold_earned, v.overkill_gold,
			v.champion.definition.id if v.champion != null else "-", _join(xps)]
	if game.combat != null:
		var d := game.combat.enemy.definition
		sb += " enemy=%s:%d:%d:%d:%d:%s" % [d.id, d.max_hp, d.max_stance, d.base_attack, d.sigils, _join(d.rules, "+")]
	sb += " rng=" + _rng(game)
	sb += " msg=" + _clean(game.message)
	return sb
