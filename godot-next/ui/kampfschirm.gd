extends Control
class_name Kampfschirm
## Der Kampf: Gegner oben, drei Plaetze in der Mitte, Hand unten.
## Liest und veraendert nur ueber den GameController - keine eigene Regel.

signal finished

const SLOT_HINTS := {
	Enums.SlotPosition.PAST: "90 % — Vorbereitung",
	Enums.SlotPosition.PRESENT: "100 % — sicher",
	Enums.SlotPosition.FUTURE: "150 % — nach dem Gegner",
}
const SLOT_TITLES := {
	Enums.SlotPosition.PAST: "VERGANGENHEIT",
	Enums.SlotPosition.PRESENT: "GEGENWART",
	Enums.SlotPosition.FUTURE: "ZUKUNFT",
}

var game: GameController
var selected: CardInstance = null
var toast_text := ""

var enemy_art: PixelArt
var where_label: Label
var enemy_name: Label
var enemy_rule: Label
var enemy_hp: Label
var enemy_stance: Label
var enemy_intent: Label
var player_line: Label
var preview: Label
var hint: Label
var log_label: Label
var toast: Label
var hand_box: HBoxContainer
var item_box: HBoxContainer
var slots: Dictionary = {}
var slot_boxes: Dictionary = {}
var slot_hints: Dictionary = {}
var act_button: Button
var pact_box: VBoxContainer
var sfx: AudioStreamPlayer

func _init(p_game: GameController) -> void:
	game = p_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Thema.DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	margin.add_child(root)

	where_label = Thema.label("", 5, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(where_label)

	enemy_art = PixelArt.new(_art_key())
	enemy_art.custom_minimum_size = Vector2(96, 96)
	var center := CenterContainer.new()
	center.add_child(enemy_art)
	root.add_child(center)

	enemy_name = Thema.label("", 9, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_rule = Thema.label("", 5, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER, true)
	enemy_hp = Thema.label("", 7, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_stance = Thema.label("", 5, Thema.INDIGO_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_intent = Thema.label("", 6, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	for l in [enemy_name, enemy_rule, enemy_hp, enemy_stance, enemy_intent]:
		root.add_child(l)

	player_line = Thema.label("", 5, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(player_line)

	var spread := HBoxContainer.new()
	spread.alignment = BoxContainer.ALIGNMENT_CENTER
	spread.add_theme_constant_override("separation", 2)
	root.add_child(spread)
	for pos in [Enums.SlotPosition.PAST, Enums.SlotPosition.PRESENT, Enums.SlotPosition.FUTURE]:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(83, 84)
		panel.add_theme_stylebox_override("panel", Thema.panel(Thema.DEEP, Thema.SEPIA3, 1))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		box.add_child(Thema.label(SLOT_TITLES[pos], 4, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var content := CenterContainer.new()
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(content)
		var slot_hint := Thema.label("", 3, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER, true)
		box.add_child(slot_hint)
		panel.gui_input.connect(_slot_input.bind(pos))
		spread.add_child(panel)
		slots[pos] = panel
		slot_boxes[pos] = content
		slot_hints[pos] = slot_hint

	preview = Thema.label("", 5, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	hint = Thema.label("", 4, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(preview)
	root.add_child(hint)

	pact_box = VBoxContainer.new()
	root.add_child(pact_box)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 2)
	root.add_child(hand_box)

	item_box = HBoxContainer.new()
	item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(item_box)

	act_button = Thema.button("SCHICKSAL AUSFÜHREN", true)
	act_button.pressed.connect(_resolve)
	root.add_child(act_button)

	log_label = Thema.label("", 4, Thema.SEPIA1, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(log_label)

	toast = Thema.label("", 7, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.visible = false
	add_child(toast)

	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	_refresh()
	_boss_intro()

func _art_key() -> String:
	var d := game.combat.enemy.definition
	return d.art if d.art != "" else d.name

## "Akt II · Kampf 3/5", "FINALE" oder "Spirale 4".
static func where(run: RunState) -> String:
	if ActCatalog.is_finale(run.fight_index):
		return "FINALE"
	if ActCatalog.is_spiral(run.fight_index):
		return "Spirale %d" % ActCatalog.spiral_depth(run.fight_index)
	return "Akt %s · Kampf %d/%d" % [Num.roman(run.act()), run.fight_index % ActCatalog.FIGHTS_PER_ACT + 1, ActCatalog.FIGHTS_PER_ACT]

static func intent_text(enemy: EnemyState) -> String:
	match enemy.intent:
		Enums.IntentType.GUARD: return "%d Schild" % enemy.intent_value
		Enums.IntentType.HEX: return "Fluch (%d Schaden, −1 Luck)" % (enemy.intent_value / 2)
		Enums.IntentType.DRAIN: return "%d Schaden, heilt sich" % enemy.intent_value
		Enums.IntentType.FRENZY: return "2 × %d Schaden" % enemy.intent_value
	return "%d Schaden" % enemy.intent_value

func _slot_input(event: InputEvent, pos: int) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed or game.phase != Enums.GamePhase.COMBAT:
		return
	var combat := game.combat
	if selected != null:
		if game.combat_system.place_card(combat, selected.instance_id, pos):
			_play(AudioBank.click())
		selected = null
	elif combat.slots.has(pos):
		game.combat_system.return_slot_to_hand(combat, pos)
	_refresh()

func _card_selected(card: CardInstance) -> void:
	toast_text = ""
	selected = null if selected == card else card
	_refresh()

func _resolve() -> void:
	if game.phase != Enums.GamePhase.COMBAT:
		return
	if game.combat.slots.is_empty():
		log_label.text = "Lege mindestens eine Karte."
		return
	var stance_before := game.combat.enemy.stance
	var turn := game.resolve_turn()
	selected = null
	_play(AudioBank.break_stance() if turn != null and turn.stance_broken and stance_before > 0 else AudioBank.hit())
	toast_text = Spiel.after_turn(turn)
	if game.phase != Enums.GamePhase.COMBAT:
		_refresh()
		await get_tree().create_timer(0.6 if toast_text == "" else 1.8).timeout
		finished.emit()
		return
	_refresh()

func _refresh() -> void:
	var run := game.run
	var combat := game.combat
	var enemy := combat.enemy
	var d := enemy.definition
	where_label.text = "%s · RUNDE %d" % [where(run).to_upper(), combat.turn]
	enemy_name.text = d.name.to_upper()
	enemy_rule.text = "  ·  ".join(CombatSystem.active_rule_texts(combat))
	# Der Mond zeigt sein Leben nur ungefaehr.
	var hp := maxi(0, enemy.hp)
	var moon := CombatSystem.has_rule(combat, Enums.BossRule.MOON)
	@warning_ignore("integer_division")
	var hp_text := "≈ %d" % ((hp + 9) / 10 * 10) if moon else str(hp)
	enemy_hp.text = "%s / %d HP%s" % [hp_text, d.max_hp, "   ✦ %d Siegel" % enemy.sigils if enemy.sigils > 0 else ""]
	enemy_stance.text = "HALTUNG GEBROCHEN — Schadensfenster offen" if enemy.stance <= 0 \
		else "Haltung %d / %d" % [enemy.stance, d.max_stance]
	enemy_intent.text = "Nächster Zug: " + ("??? — der Mond verbirgt es" if enemy.intent_hidden else intent_text(enemy))
	player_line.text = "%d/%d HP · %d Schild · %d Fate · %d Gold · Luck %d%s" % [run.hp, run.max_hp,
		combat.player_shield, run.fate, run.gold, combat.temporary_luck,
		" · Dunkel %d" % run.darkness if run.darkness > 0 else ""]

	for pos in slots:
		var panel: PanelContainer = slots[pos]
		var content: CenterContainer = slot_boxes[pos]
		for child in content.get_children():
			child.queue_free()
		var blocked: bool = combat.blocked_slot == pos
		var occupied: bool = combat.slots.has(pos)
		var effective: int = game.combat_system.effective_slot(combat, pos)
		var border := Thema.RED if blocked else (Thema.GOLD if occupied else (Thema.PAPER if selected != null else Thema.SEPIA3))
		panel.add_theme_stylebox_override("panel", Thema.panel(Thema.DEEP, border, 1))
		(slot_hints[pos] as Label).text = "EINGESTÜRZT — der Turm" if blocked \
			else ("wirkt als %s" % CombatSystem.slot_name(effective) if effective != pos else SLOT_HINTS[pos])
		if occupied:
			content.add_child(_card_view(combat.slots[pos]))

	for child in hand_box.get_children():
		child.queue_free()
	for c in combat.hand:
		var view := _card_view(c)
		view.selected = selected == c
		view.chosen.connect(_card_selected)
		hand_box.add_child(view)

	preview.text = ""
	hint.text = ""
	var score := game.preview_score()
	if score != null and not combat.slots.is_empty():
		preview.text = "%s · %d × %s = %d" % [score.combo_name, score.chips, Num.de(score.multiplier), score.fate_damage]
		if score.breaks_stance:
			preview.text += " · HALTUNG BRICHT"
		if score.lethal:
			preview.text += " · TÖDLICH"
		hint.text = " · ".join(score.hints)

	_refresh_pact()
	_refresh_items()
	log_label.text = game.message
	act_button.disabled = game.phase != Enums.GamePhase.COMBAT
	toast.text = toast_text
	toast.visible = toast_text != ""

func _card_view(c: CardInstance) -> Kartenblatt:
	var combat := game.combat
	var mark := combat.mark_turns_left if combat.marked_card_id == c.instance_id else 0
	return Kartenblatt.new(c, combat.is_veiled(c), mark)

func _refresh_pact() -> void:
	for child in pact_box.get_children():
		child.queue_free()
	var combat := game.combat
	pact_box.visible = game.phase == Enums.GamePhase.COMBAT and combat.pact_pending
	if not pact_box.visible:
		return
	var bonus := CombatSystem.pact_bonus(combat)
	var cost := CombatSystem.pact_cost(combat)
	pact_box.add_child(Thema.label("Der Teufel bietet einen Pakt: +%d %% Fate-Schaden für diesen Kampf.\nPreis: %d Max-HP für immer und +%d Verdunkelung.\nLehnst du ab, schlägt er %d %% härter zu." % [
		roundi(bonus * 100.0), cost, CombatSystem.PACT_DARKNESS, roundi(CombatSystem.PACT_DECLINE_PENALTY * 100.0)],
		5, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pact_box.add_child(row)
	var yes := Thema.button("UNTERSCHREIBEN", true)
	var no := Thema.button("ABLEHNEN")
	yes.pressed.connect(func(): game.answer_pact(true); Spiel.save_run(); _refresh())
	no.pressed.connect(func(): game.answer_pact(false); Spiel.save_run(); _refresh())
	row.add_child(yes)
	row.add_child(no)

## Items, die man im Kampf benutzen kann. Zielkarten-Items wirken auf die
## gewaehlte Handkarte.
func _refresh_items() -> void:
	for child in item_box.get_children():
		child.queue_free()
	for item in GameCatalog.items():
		var count := int(game.run.items.get(item.id, 0))
		if count <= 0:
			continue
		var b := Thema.button("%s ×%d" % [item.name, count])
		b.custom_minimum_size = Vector2(0, 24)
		b.add_theme_font_size_override("font_size", 6)
		b.tooltip_text = item.description
		var id := item.id
		b.pressed.connect(func():
			game.use_item(id, selected)
			selected = null
			Spiel.save_run()
			_refresh())
		item_box.add_child(b)

func _boss_intro() -> void:
	var d := game.combat.enemy.definition
	if not d.is_boss():
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
	box.add_child(Thema.label(d.name, 14, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(Thema.label(" ".join(CombatSystem.active_rule_texts(game.combat)), 6, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER, true))
	add_child(overlay)
	_play(AudioBank.boss())
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()

func _play(stream: AudioStream) -> void:
	sfx.stream = stream
	sfx.play()
