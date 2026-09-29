class_name WertungsKaskade
extends Control
## Die Zaehl-Kaskade wie bei Balatro: jede Karte zaehlt einzeln, springt kurz
## an und wirft ihre Chips (blau) und ihren Mult (rot) in die Waagschale.
## Danach kommen Muster und Editionen, zuletzt Chips × Mult - und wenn der
## Treffer toedlich ist, brennt die Zahl.

signal treffer(schicksal: int)
signal wackeln(staerke: float)

const SCHRIFT := "res://addons/tartot_karten/schrift/"
const BLAU := Color("3B4A8C")
const ROT := Color("B3262B")
const GOLD := Color("E3A83B")
const PAPIER := Color("EFE3C8")
const TINTE := Color("1A1412")

var chips := 0
var mult := 1.0

var _chips_label: Label
var _mult_label: Label
var _muster: Label
var _summe: Label
var _funken: CPUParticles2D
var _schwebe_ebene: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muster = _label("Jersey10.ttf", 44, GOLD)
	_muster.position = Vector2(0, -8)
	_muster.size = Vector2(620, 48)
	add_child(_muster)
	var chips_box := _kasten(BLAU, Vector2(0, 44))
	_chips_label = _label("AlfaSlabOne.ttf", 52, PAPIER)
	_chips_label.size = chips_box.size
	chips_box.add_child(_chips_label)
	var mal := _label("AlfaSlabOne.ttf", 52, PAPIER)
	mal.text = "×"
	mal.position = Vector2(270, 44)
	mal.size = Vector2(80, 92)
	add_child(mal)
	var mult_box := _kasten(ROT, Vector2(350, 44))
	_mult_label = _label("AlfaSlabOne.ttf", 52, PAPIER)
	_mult_label.size = mult_box.size
	mult_box.add_child(_mult_label)
	_summe = _label("AbrilFatface.ttf", 64, PAPIER)
	_summe.position = Vector2(0, 142)
	_summe.size = Vector2(620, 80)
	_summe.pivot_offset = _summe.size * 0.5
	add_child(_summe)

	_funken = CPUParticles2D.new()
	_funken.position = Vector2(310, 182)
	_funken.emitting = false
	_funken.one_shot = true
	_funken.amount = 90
	_funken.lifetime = 1.1
	_funken.explosiveness = 0.85
	_funken.spread = 180.0
	_funken.initial_velocity_min = 180.0
	_funken.initial_velocity_max = 520.0
	_funken.gravity = Vector2(0, -260)
	_funken.scale_amount_min = 4.0
	_funken.scale_amount_max = 9.0
	var farben := Gradient.new()
	farben.set_color(0, Color("F4D27A"))
	farben.set_color(1, Color(0.7, 0.1, 0.08, 0.0))
	_funken.color_ramp = farben
	add_child(_funken)
	zuruecksetzen()


func _kasten(farbe: Color, pos: Vector2) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = farbe
	s.border_color = TINTE
	s.set_border_width_all(4)
	s.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", s)
	p.position = pos
	p.size = Vector2(270, 92)
	p.pivot_offset = p.size * 0.5
	add_child(p)
	return p


func _label(schrift: String, groesse: int, farbe: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(SCHRIFT + schrift))
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.add_theme_color_override("font_outline_color", TINTE)
	l.add_theme_constant_override("outline_size", 8)
	return l


## Ebene fuer die fliegenden Zahlen (sollte ueber den Karten liegen).
func schwebe_ebene_setzen(ebene: Node) -> void:
	_schwebe_ebene = ebene


func zuruecksetzen() -> void:
	chips = 0
	mult = 1.0
	_anzeigen()
	_muster.text = ""
	_summe.text = ""
	_summe.add_theme_color_override("font_color", PAPIER)


## Vorschau, ohne Kaskade: was diese Legung ergeben wuerde.
func vorschau(ergebnis: Dictionary) -> void:
	chips = ergebnis.get("chips", 0)
	mult = ergebnis.get("mult", 1.0)
	_muster.text = ergebnis.get("muster", "") if chips > 0 else ""
	_summe.text = ""
	_anzeigen()


func _anzeigen() -> void:
	_chips_label.text = str(chips)
	_mult_label.text = ("%.2f" % mult).replace(".", ",").trim_suffix("0").trim_suffix(",0")


## Spielt die Schritte ab. karten: instance_id -> TarotKarte. Gibt den Treffer zurueck.
func abspielen(schritte: Array, karten: Dictionary, gegner_lp: int) -> int:
	chips = 0
	mult = 1.0
	_summe.text = ""
	_anzeigen()
	var takt := 0.42
	for i in schritte.size():
		var s: Dictionary = schritte[i]
		var karte: TarotKarte = karten.get(s["id"], null)
		var ort := Vector2(540, 900)
		if karte != null and is_instance_valid(karte):
			karte.stossen(0.24)
			ort = karte.global_position + Vector2(0, -TarotKarte.GROESSE.y * 0.5)
		else:
			_muster.text = str(s["label"])
			_muster.pivot_offset = _muster.size * 0.5
			_hupfen(_muster, 1.25)
		if int(s["chips"]) > 0:
			chips += int(s["chips"])
			_fliegen("+%d" % int(s["chips"]), BLAU, ort + Vector2(-50, 0))
			_hupfen(_chips_label.get_parent(), 1.12)
		if float(s["mult"]) > 0.0:
			mult += float(s["mult"])
			_fliegen("+%s Mult" % _komma(float(s["mult"])), ROT, ort + Vector2(60, -40))
			_hupfen(_mult_label.get_parent(), 1.12)
		_anzeigen()
		await get_tree().create_timer(takt).timeout
		takt = maxf(0.2, takt * 0.86)   # die Kaskade wird schneller, wie ein Spielautomat

	# Faktoren zuletzt - wie im Kern (CalculateScore multipliziert nach allen
	# Summanden). Jede Karte mit Faktor springt noch einmal an: der Hoehepunkt.
	for s in schritte:
		if float(s["xmult"]) == 1.0:
			continue
		var karte: TarotKarte = karten.get(s["id"], null)
		var ort := Vector2(540, 900)
		if karte != null and is_instance_valid(karte):
			karte.stossen(0.32)
			ort = karte.global_position + Vector2(0, -TarotKarte.GROESSE.y * 0.5)
		mult *= float(s["xmult"])
		_fliegen("×%s Mult" % _komma(float(s["xmult"])), ROT, ort + Vector2(0, -60), 1.4)
		_hupfen(_mult_label.get_parent(), 1.35)
		wackeln.emit(8.0)
		_anzeigen()
		await get_tree().create_timer(0.55).timeout

	# Chips × Mult: die Zahl zaehlt hoch und wird dabei groesser.
	var ziel := maxi(1, roundi(chips * mult))
	var t := create_tween()
	t.tween_method(func(w): _summe.text = str(roundi(w)), 0.0, float(ziel), 0.7).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_summe, "scale", Vector2(1.35, 1.35), 0.7)
	await t.finished
	var toedlich := ziel >= gegner_lp
	wackeln.emit(clampf(log(float(ziel)) * 3.0, 4.0, 22.0) * (1.6 if toedlich else 1.0))
	if toedlich:
		_summe.add_theme_color_override("font_color", Color("F4D27A"))
		_funken.restart()
		_funken.emitting = true
	var z := create_tween()
	z.tween_property(_summe, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	treffer.emit(ziel)
	return ziel


func _komma(x: float) -> String:
	return ("%.2f" % x).replace(".", ",").trim_suffix("0").trim_suffix(",0")


func _hupfen(knoten: Control, staerke: float) -> void:
	knoten.pivot_offset = knoten.size * 0.5
	var t := create_tween()
	t.tween_property(knoten, "scale", Vector2(staerke, staerke), 0.06)
	t.tween_property(knoten, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _fliegen(text: String, farbe: Color, ort: Vector2, groesse := 1.0) -> void:
	var l := _label("AlfaSlabOne.ttf", int(46 * groesse), PAPIER)
	l.text = text
	var grund := StyleBoxFlat.new()
	grund.bg_color = farbe
	grund.set_corner_radius_all(10)
	grund.set_content_margin_all(8)
	grund.border_color = TINTE
	grund.set_border_width_all(3)
	l.add_theme_stylebox_override("normal", grund)
	var ebene := _schwebe_ebene if _schwebe_ebene != null else self
	ebene.add_child(l)
	l.reset_size()
	l.position = ort - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)
