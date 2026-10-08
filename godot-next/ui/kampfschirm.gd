extends Control
class_name Kampfschirm

signal finished

var run: Run
var combat: Kampf
var selected: Karte = null

var enemy_art: PixelArt
var enemy_name: Label
var enemy_rule: Label
var enemy_hp: Label
var enemy_stance: Label
var enemy_intent: Label
var player_line: Label
var preview: Label
var hint: Label
var hand_box: HBoxContainer
var slots: Dictionary = {}
var slot_boxes: Dictionary = {}
var act_button: Button
var pact_box: HBoxContainer
var sfx: AudioStreamPlayer

func _init(p_run: Run) -> void:
	run = p_run
	combat = run.combat
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Thema.DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	margin.add_child(root)

	var where := Thema.label(_where(), 5, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(where)

	enemy_art = PixelArt.new(String(combat.enemy_def.get("name", "")))
	enemy_art.custom_minimum_size = Vector2(96, 104)
	var center := CenterContainer.new()
	center.add_child(enemy_art)
	root.add_child(center)

	enemy_name = Thema.label("", 9, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_rule = Thema.label("", 5, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER, true)
	enemy_rule.custom_minimum_size.y = 14
	enemy_hp = Thema.label("", 7, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_stance = Thema.label("", 5, Thema.INDIGO_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_intent = Thema.label("", 6, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(enemy_name)
	root.add_child(enemy_rule)
	root.add_child(enemy_hp)
	root.add_child(enemy_stance)
	root.add_child(enemy_intent)

	player_line = Thema.label("", 5, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(player_line)

	var spread := HBoxContainer.new()
	spread.alignment = BoxContainer.ALIGNMENT_CENTER
	spread.add_theme_constant_override("separation", 2)
	root.add_child(spread)
	for pos in [Konst.Slot.PAST, Konst.Slot.PRESENT, Konst.Slot.FUTURE]:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(83, 82)
		panel.add_theme_stylebox_override("panel", Thema.panel(Thema.DEEP, Thema.SEPIA3, 1))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(box)
		var title := Thema.label(Konst.POS_NAME[pos].to_upper(), 4, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		box.add_child(title)
		var content := CenterContainer.new()
		content.name = "Content"
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(content)
		var slot_hint := Thema.label(_slot_hint(pos), 3, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER, true)
		slot_hint.name = "Hint"
		box.add_child(slot_hint)
		panel.gui_input.connect(_slot_input.bind(pos))
		spread.add_child(panel)
		slots[pos] = panel
		slot_boxes[pos] = content

	preview = Thema.label("", 5, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	preview.custom_minimum_size.y = 12
	hint = Thema.label("", 4, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	hint.custom_minimum_size.y = 10
	root.add_child(preview)
	root.add_child(hint)

	pact_box = HBoxContainer.new()
	pact_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(pact_box)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 2)
	root.add_child(hand_box)

	act_button = Thema.button("SCHICKSAL AUSFÜHREN", true)
	act_button.pressed.connect(_resolve)
	root.add_child(act_button)

	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	_refresh()
	_boss_intro()

func _where() -> String:
	if run.is_finale():
		return "FINALE · RUNDE %d" % combat.turn
	if run.is_spiral():
		return "SPIRALE %d · RUNDE %d" % [Konst.spiral_depth(run.fight_index), combat.turn]
	return "AKT %s · KAMPF %d/5 · RUNDE %d" % [Konst.roman(run.current_act()), run.fight_index % 5 + 1, combat.turn]

func _slot_hint(pos: int) -> String:
	match pos:
		Konst.Slot.PAST: return "90 % · sofort"
		Konst.Slot.PRESENT: return "100 % · sicher"
		_: return "150 % · nach Gegner"

func _slot_input(event: InputEvent, pos: int) -> void:
	var pressed := (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	if combat.slots.has(pos):
		combat.return_slot(pos)
		selected = null
	elif selected != null:
		if combat.place(selected, pos):
			_play(AudioBank.click())
		selected = null
	_refresh()

func _card_selected(card: Karte) -> void:
	selected = null if selected == card else card
	_refresh()

func _resolve() -> void:
	if not combat.can_resolve():
		hint.text = "Lege mindestens eine Karte."
		return
	var was_stance := combat.enemy_stance
	combat.resolve()
	_play(AudioBank.break_stance() if was_stance > 0 and combat.enemy_stance <= 0 else AudioBank.hit())
	selected = null
	if combat.player_won or combat.player_lost:
		run.finish_combat()
		Spiel.save_run()
		await get_tree().create_timer(0.35).timeout
		finished.emit()
		return
	Spiel.save_run()
	_refresh()

func _refresh() -> void:
	enemy_name.text = String(combat.enemy_def.get("name", "")).to_upper()
	enemy_rule.text = combat.rule_text()
	enemy_hp.text = "%d / %d HP%s" % [combat.enemy_hp, int(combat.enemy_def["hp"]), " · %d SIEGEL" % combat.enemy_sigils if combat.enemy_sigils > 0 else ""]
	enemy_stance.text = "HALTUNG GEBROCHEN" if combat.enemy_stance <= 0 else "Haltung %d / %d" % [combat.enemy_stance, int(combat.enemy_def["stance"])]
	enemy_intent.text = "Nächster Zug: %s" % combat.intent_text()
	player_line.text = "%d/%d HP · %d Schild · %d Fate · %d Gold · Dunkel %d" % [run.hp, run.max_hp, combat.player_shield, run.fate, run.gold, run.darkness]

	for pos in slots:
		var panel: PanelContainer = slots[pos]
		var content: CenterContainer = slot_boxes[pos]
		for child in content.get_children():
			child.queue_free()
		var border := Thema.RED if combat.blocked_slot != null and int(combat.blocked_slot) == pos else (Thema.GOLD if combat.slots.has(pos) else Thema.SEPIA3)
		panel.add_theme_stylebox_override("panel", Thema.panel(Thema.DEEP, border, 1))
		var h: Label = panel.get_node("VBoxContainer/Hint")
		var eff := combat.effective_slot(pos)
		h.text = "EINGESTÜRZT" if combat.blocked_slot != null and int(combat.blocked_slot) == pos else ("wirkt als %s" % Konst.POS_NAME[eff] if eff != pos else _slot_hint(pos))
		if combat.slots.has(pos):
			var c: Karte = combat.slots[pos]
			var view := Kartenblatt.new(c, combat.veiled_ids.has(c.instance_id), combat.mark_turns if combat.marked_id == c.instance_id else 0)
			content.add_child(view)

	for child in hand_box.get_children():
		child.queue_free()
	for c in combat.hand:
		var view := Kartenblatt.new(c, combat.veiled_ids.has(c.instance_id), combat.mark_turns if combat.marked_id == c.instance_id else 0)
		view.selected = selected == c
		view.chosen.connect(_card_selected)
		hand_box.add_child(view)

	var score := combat.preview()
	preview.text = ""
	hint.text = ""
	if not score.is_empty():
		preview.text = "%s · %d × %.2f = %d → %d" % [score["combo"], score["chips"], score["multiplier"], score["fate_damage"], score["expected_hit"]]
		if bool(score["breaks_stance"]):
			preview.text += " · HALTUNG BRICHT"
		hint.text = " · ".join(score["hints"])

	for child in pact_box.get_children():
		child.queue_free()
	pact_box.visible = combat.pact_pending
	if combat.pact_pending:
		var yes := Thema.button("PAKT +50 %", true)
		var no := Thema.button("ABLEHNEN")
		yes.pressed.connect(func(): combat.answer_pact(true); _refresh(); Spiel.save_run())
		no.pressed.connect(func(): combat.answer_pact(false); _refresh(); Spiel.save_run())
		pact_box.add_child(yes)
		pact_box.add_child(no)

func _boss_intro() -> void:
	if int(combat.enemy_def.get("tier", 0)) < Konst.Tier.BOSS:
		return
	var overlay := ColorRect.new()
	overlay.color = Thema.DEEP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(box)
	box.add_child(Thema.label("HEUTE IM LICHTSPIELHAUS", 6, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Thema.label(String(combat.enemy_def["name"]), 14, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(Thema.label(combat.rule_text(), 6, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER, true))
	add_child(overlay)
	_play(AudioBank.boss())
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()

func _play(stream: AudioStream) -> void:
	sfx.stream = stream
	sfx.play()
