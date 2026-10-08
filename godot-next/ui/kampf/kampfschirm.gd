extends Control
class_name Kampfschirm
## Der Kampftisch: Bühne mit Bossfigur oben, Regelkarte an der Tischkante,
## drei Schicksalsplätze, Vorschau, Hand, Ausführen in Daumennähe.
##
## Liest und verändert nur über den GameController. Nach "Schicksal
## ausführen" ist der Kern schon fertig; der CueBuilder macht aus dem
## Ergebnis eine Folge, die hier abgespielt wird. Die Animation ist nie die
## Wahrheit: wird sie unterbrochen, zeigt _refresh() den Kernzustand.

signal finished
## Jeder abgespielte Cue (fuer Tests und spaeter Haptik).
signal cue_gespielt(cue: Dictionary)

const SLOT_HINTS := ["90 % — Vorbereitung", "100 % — sicher", "150 % — nach dem Gegner"]
const SLOTS := [Enums.SlotPosition.PAST, Enums.SlotPosition.PRESENT, Enums.SlotPosition.FUTURE]

var game: GameController
## Animationstempo (Tests drehen hoch).
var tempo := 1.0
var selected: CardInstance = null
var toast_text := ""
var gesperrt := false

var buehne: Buehne
var boss: BossDarstellung
var regelkarte: Regelkarte
var where_label: Label
var enemy_name: Label
var enemy_hp: Label
var hp_balken: Balken
var haltung_balken: Balken
var enemy_stance: Label
var enemy_intent: Label
var player_line: Label
var preview: Label
var hint: Label
var kaskade: Label
var treffer: Label
var log_label: Label
var toast: Label
var hand_box: HBoxContainer
var item_box: HBoxContainer
var plaetze: Array[Schicksalsplatz] = []
var act_button: Button
var pact_box: VBoxContainer
var sfx: AudioStreamPlayer

## Ein schlichter Balken (HP, Haltung).
class Balken extends Control:
	var anteil := 1.0
	var farbe := Thema.RED
	func _init(p_farbe: Color) -> void:
		farbe = p_farbe
		custom_minimum_size = Vector2(0, 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func setze(wert: int, maximum: int) -> void:
		anteil = clampf(float(wert) / float(maxi(1, maximum)), 0.0, 1.0)
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Thema.INK)
		draw_rect(Rect2(0, 0, size.x * anteil, size.y), farbe)

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
		margin.add_theme_constant_override("margin_" + side, 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	margin.add_child(root)

	where_label = Thema.label("", 6, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(where_label)

	# --- Bühne mit Bossfigur, Name und Balken
	var def := game.combat.enemy.definition
	buehne = Buehne.new()
	buehne.stil = def.stage
	buehne.custom_minimum_size = Vector2(0, 132)
	root.add_child(buehne)
	boss = BossRegistry.erzeuge(def)
	boss.tempo = tempo
	boss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss.offset_top = 10
	boss.offset_bottom = -6
	buehne.add_child(boss)
	enemy_name = Thema.label("", 8, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	buehne.add_child(enemy_name)

	var balken_box := VBoxContainer.new()
	balken_box.add_theme_constant_override("separation", 1)
	root.add_child(balken_box)
	enemy_hp = Thema.label("", 7, Thema.RED, HORIZONTAL_ALIGNMENT_CENTER)
	hp_balken = Balken.new(Thema.RED)
	haltung_balken = Balken.new(Thema.INDIGO_LIGHT)
	enemy_stance = Thema.label("", 6, Thema.INDIGO_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	enemy_intent = Thema.label("", 6, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	for n in [enemy_hp, hp_balken, haltung_balken, enemy_stance, enemy_intent]:
		balken_box.add_child(n)

	# --- Regelkarte an der Tischkante (nur, wenn der Gegner Regeln bricht)
	regelkarte = Regelkarte.new()
	regelkarte.visible = not def.rules.is_empty()
	root.add_child(regelkarte)

	player_line = Thema.label("", 6, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(player_line)

	# --- Drei Plätze
	var spread := HBoxContainer.new()
	spread.alignment = BoxContainer.ALIGNMENT_CENTER
	spread.add_theme_constant_override("separation", 3)
	root.add_child(spread)
	for pos in SLOTS:
		var platz := Schicksalsplatz.new(pos)
		platz.angetippt.connect(_slot_angetippt)
		platz.abgelegt.connect(_slot_abgelegt)
		spread.add_child(platz)
		plaetze.append(platz)

	kaskade = Thema.label("", 6, Thema.SEPIA1, HORIZONTAL_ALIGNMENT_CENTER, true)
	preview = Thema.label("", 7, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	hint = Thema.label("", 6, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(preview)
	root.add_child(hint)

	pact_box = VBoxContainer.new()
	root.add_child(pact_box)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", 2)
	hand_box.custom_minimum_size = Vector2(0, 68)
	root.add_child(hand_box)

	item_box = HBoxContainer.new()
	item_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(item_box)

	act_button = Thema.button("SCHICKSAL AUSFÜHREN", true)
	act_button.pressed.connect(_resolve)
	root.add_child(act_button)

	log_label = Thema.label("", 6, Thema.SEPIA1, HORIZONTAL_ALIGNMENT_CENTER, true)
	root.add_child(log_label)

	# Einblendungen über allem
	kaskade.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	kaskade.position = Vector2(10, 150)
	kaskade.size = Vector2(250, 60)
	kaskade.visible = false
	add_child(kaskade)
	treffer = Thema.label("", 22, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	treffer.position = Vector2(0, 70)
	treffer.size = Vector2(270, 30)
	treffer.visible = false
	add_child(treffer)
	toast = Thema.label("", 8, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast.position = Vector2(15, 200)
	toast.size = Vector2(240, 80)
	toast.visible = false
	add_child(toast)

	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	boss.set_phase_two(game.combat.enemy.phase >= 1)
	buehne.phase_two = game.combat.enemy.phase >= 1
	_refresh()
	_intro()

# ------------------------------------------------------------ Texte
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

# ------------------------------------------------------------ Eingaben
func _slot_angetippt(pos: int) -> void:
	if gesperrt or game.phase != Enums.GamePhase.COMBAT:
		return
	var combat := game.combat
	if selected != null:
		if combat.blocked_slot == pos:
			plaetze[pos].abweisen(tempo)
			log_label.text = "Dieser Platz ist eingestürzt."
			return
		_lege(selected, pos)
	elif combat.slots.has(pos):
		game.combat_system.return_slot_to_hand(combat, pos)
		_refresh()

func _slot_abgelegt(pos: int, card: CardInstance) -> void:
	if gesperrt or game.phase != Enums.GamePhase.COMBAT:
		return
	_lege(card, pos)

func _lege(card: CardInstance, pos: int) -> void:
	if game.combat_system.place_card(game.combat, card.instance_id, pos):
		_play(AudioBank.click())
		selected = null
		_refresh()
		plaetze[pos].karte_einrasten(tempo)
	else:
		plaetze[pos].abweisen(tempo)

func _card_selected(card: CardInstance) -> void:
	if gesperrt:
		return
	toast_text = ""
	selected = null if selected == card else card
	_refresh()

func _resolve() -> void:
	if gesperrt or game.phase != Enums.GamePhase.COMBAT:
		return
	if game.combat.slots.is_empty():
		log_label.text = "Lege mindestens eine Karte."
		return
	gesperrt = true
	act_button.disabled = true
	var vorher := CueBuilder.vorher(game)
	var turn := game.resolve_turn()
	selected = null
	var cues := CueBuilder.baue(vorher, turn, game)
	toast_text = Spiel.after_turn(turn)
	await _spiele(cues)
	if game.phase != Enums.GamePhase.COMBAT:
		_refresh()
		await _warte(0.5 if toast_text == "" else 1.6)
		finished.emit()
		return
	gesperrt = false
	_refresh()

# ------------------------------------------------------------ Folge
func _warte(sekunden: float) -> void:
	await get_tree().create_timer(sekunden / tempo).timeout

func _ton(name: String) -> void:
	if name == "":
		return
	var stream := BossRegistry.ton(game.combat.enemy.definition, name)
	if stream == null:
		match name:
			"break": stream = AudioBank.break_stance()
			"intro", "phase2", "death": stream = AudioBank.boss()
			_: stream = AudioBank.hit()
	_play(stream)

func _spiele(cues: Array[Dictionary]) -> void:
	var zeilen: Array[String] = []
	kaskade.visible = true
	for c in cues:
		cue_gespielt.emit(c)
		match String(c["typ"]):
			"wertung":
				zeilen.append(String(c["text"]))
				kaskade.text = "\n".join(zeilen.slice(maxi(0, zeilen.size() - 4)))
				_play(AudioBank.click())
				await _warte(0.14)
			"fate":
				preview.text = String(c["text"])
				treffer.text = "−%d" % int(c["wert"])
				treffer.visible = true
				treffer.pivot_offset = treffer.size * 0.5
				treffer.scale = Vector2(1.6, 1.6)
				var t := create_tween()
				t.set_speed_scale(tempo)
				t.tween_property(treffer, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
				_aktualisiere_gegner()
				await _warte(0.22)
			"boss":
				_ton(String(c.get("ton", "")))
				await boss.spiele(String(c["cue"]))
			"siegel":
				buehne.phase_two = true
				buehne.blitzen()
				await regelkarte.siegel_bricht(String(c["text"]), tempo)
			"einsturz":
				buehne.blitzen()
				_ton("break")
				await plaetze[int(c["slot"])].stuerzt_ein(tempo)
			"aufrichten":
				plaetze[int(c["slot"])].richtet_sich_auf()
			"spieler":
				_aktualisiere_spieler()
				if int(c["schaden"]) > 0:
					player_line.modulate = Thema.RED
					var t2 := create_tween()
					t2.set_speed_scale(tempo)
					t2.tween_property(player_line, "modulate", Color.WHITE, 0.3)
				await _warte(0.12)
			"verhuellen":
				await buehne.nebel(tempo)
			"verlust":
				toast.text = String(c["text"])
				toast.visible = true
				await _warte(0.6)
	treffer.visible = false
	kaskade.visible = false

# ------------------------------------------------------------ Darstellung
func _aktualisiere_gegner() -> void:
	var combat := game.combat
	var enemy := combat.enemy
	var d := enemy.definition
	enemy_name.text = d.name.to_upper()
	# Der Mond zeigt sein Leben nur ungefähr.
	var hp := maxi(0, enemy.hp)
	var moon := CombatSystem.has_rule(combat, Enums.BossRule.MOON)
	@warning_ignore("integer_division")
	var hp_text := "≈ %d" % ((hp + 9) / 10 * 10) if moon else str(hp)
	enemy_hp.text = "%s / %d HP%s" % [hp_text, d.max_hp, "   ✦ %d Siegel" % enemy.sigils if enemy.sigils > 0 else ""]
	hp_balken.setze(hp, d.max_hp)
	haltung_balken.setze(maxi(0, enemy.stance), d.max_stance)
	enemy_stance.text = "HALTUNG GEBROCHEN — Schadensfenster offen" if enemy.stance <= 0 \
		else "Haltung %d / %d" % [enemy.stance, d.max_stance]
	enemy_intent.text = "Nächster Zug: " + ("??? — der Mond verbirgt es" if enemy.intent_hidden else intent_text(enemy))

func _aktualisiere_spieler() -> void:
	var run := game.run
	var combat := game.combat
	player_line.text = "%d/%d HP · %d Schild · %d Fate · %d Gold · Luck %d%s" % [run.hp, run.max_hp,
		combat.player_shield, run.fate, run.gold, combat.temporary_luck,
		" · Dunkel %d" % run.darkness if run.darkness > 0 else ""]

func _refresh() -> void:
	var run := game.run
	var combat := game.combat
	where_label.text = "%s · RUNDE %d" % [where(run).to_upper(), combat.turn]
	_aktualisiere_gegner()
	_aktualisiere_spieler()
	if regelkarte.visible:
		regelkarte.setze(" ".join(CombatSystem.active_rule_texts(combat)), combat.enemy.phase >= 1)

	for pos in SLOTS:
		var platz := plaetze[pos]
		var blocked: bool = combat.blocked_slot == pos
		if blocked and not platz.eingestuerzt:
			platz.eingestuerzt = true
			platz._absacken = 1.0
		elif not blocked and platz.eingestuerzt:
			platz.richtet_sich_auf()
		platz.hervorgehoben = selected != null and not blocked
		platz.annehmen = not gesperrt
		var effective: int = game.combat_system.effective_slot(combat, pos)
		var hinweis: String = "" if blocked else ("wirkt als %s" % CombatSystem.slot_name(effective) if effective != pos else SLOT_HINTS[pos])
		platz.zeige(_card_view(combat.slots[pos]) if combat.slots.has(pos) else null, hinweis)

	for child in hand_box.get_children():
		child.queue_free()
	for c in combat.hand:
		var view := _card_view(c)
		view.selected = selected == c
		view.ziehbar = not gesperrt
		view.chosen.connect(_card_selected)
		hand_box.add_child(view)

	preview.text = ""
	hint.text = ""
	var score := game.preview_score()
	if score != null and not combat.slots.is_empty():
		preview.text = "%s · %d × %s = %d" % [score.combo_name, score.chips, Num.de(score.multiplier), score.fate_damage]
		if score.expected_hit != score.fate_damage and score.expected_hit > 0:
			preview.text += " → %d" % score.expected_hit
		if score.breaks_stance:
			preview.text += " · HALTUNG BRICHT"
		if score.lethal:
			preview.text += " · TÖDLICH"
		hint.text = " · ".join(score.hints)

	_refresh_pact()
	_refresh_items()
	log_label.text = game.message
	act_button.disabled = gesperrt or game.phase != Enums.GamePhase.COMBAT
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
		6, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
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
## gewählte Handkarte.
func _refresh_items() -> void:
	for child in item_box.get_children():
		child.queue_free()
	for item in GameCatalog.items():
		var count := int(game.run.items.get(item.id, 0))
		if count <= 0:
			continue
		var b := Thema.button("%s ×%d" % [item.name, count])
		b.custom_minimum_size = Vector2(0, 22)
		b.add_theme_font_size_override("font_size", 6)
		b.tooltip_text = item.description
		var id := item.id
		b.pressed.connect(func():
			if gesperrt:
				return
			game.use_item(id, selected)
			selected = null
			Spiel.save_run()
			_refresh())
		item_box.add_child(b)

func _intro() -> void:
	var d := game.combat.enemy.definition
	gesperrt = true
	_refresh()
	if d.is_boss():
		var overlay := ColorRect.new()
		overlay.color = Color(Thema.DEEP, 0.92)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		overlay.add_child(box)
		box.add_child(Thema.label("HEUTE IM LICHTSPIELHAUS", 7, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(Thema.label(d.name, 14, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
		box.add_child(Thema.label(d.flavor, 7, Thema.SEPIA1, HORIZONTAL_ALIGNMENT_CENTER, true))
		add_child(overlay)
		_ton("intro")
		await _warte(1.1)
		if is_instance_valid(overlay):
			overlay.queue_free()
	await boss.spiele("intro")
	if regelkarte.visible:
		await regelkarte.auftritt(tempo)
		_play(AudioBank.click())
	gesperrt = false
	_refresh()

func _play(stream: AudioStream) -> void:
	sfx.stream = stream
	sfx.play()
