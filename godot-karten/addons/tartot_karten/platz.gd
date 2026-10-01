class_name KartenPlatz
extends Node2D
## Eine Position der Legung: Vergangenheit, Gegenwart oder Zukunft.
##
## Wie auf den Boss-Blaettern: ein Reiter mit dem Namen, darunter eine
## Filmstreifen-Karte mit einem Bild aus der Welt des Bosses und der
## Wirkung des Platzes. Leuchtet golden, wenn eine gezogene Karte darueber
## schwebt; eingestuerzt (der Turm) bekommt er einen Riss und einen Stempel.

const GROESSE := Vector2(224, 292)
const FENSTER := Rect2(26, 14, 172, 192)

@export var titel := "GEGENWART"
@export var wirkung := "Mult +0,15"

var groesse := GROESSE
var karte: TarotKarte = null
var markiert := false:
	set(v):
		if v != markiert:
			markiert = v
			_glanz_ziel = 1.0 if v else 0.0
var gesperrt := false:
	set(v):
		gesperrt = v
		if _stempel:
			_stempel.visible = v
			_bild.modulate = Color(0.45, 0.4, 0.38) if v else Color.WHITE

var _wurzel: Control
var _bild: TextureRect
var _text: Label
var _stempel: Control
var _glanz := 0.0
var _glanz_ziel := 0.0


func _ready() -> void:
	_wurzel = Control.new()
	_wurzel.position = -GROESSE * 0.5
	_wurzel.size = GROESSE
	_wurzel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wurzel)

	var reiter := NinePatchRect.new()
	reiter.texture = load(TarotStil.KUNST + "ui/reiter.png")
	reiter.patch_margin_left = 26
	reiter.patch_margin_right = 26
	reiter.patch_margin_top = 18
	reiter.patch_margin_bottom = 18
	reiter.position = Vector2(-8, -62)
	reiter.size = Vector2(GROESSE.x + 16, 50)
	_wurzel.add_child(reiter)
	var name_l := TarotStil.label(titel, 30, TarotStil.PAPIER, false, 4)
	name_l.position = reiter.position + Vector2(0, 2)
	name_l.size = reiter.size
	_wurzel.add_child(name_l)

	var karte_bild := TextureRect.new()
	karte_bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	karte_bild.texture = load(TarotStil.KUNST + "ui/platz.png")
	karte_bild.size = GROESSE
	_wurzel.add_child(karte_bild)

	_bild = TextureRect.new()
	_bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bild.position = FENSTER.position
	_bild.size = FENSTER.size
	_bild.clip_contents = true
	_wurzel.add_child(_bild)
	var linie := ReferenceRect.new()
	linie.position = FENSTER.position - Vector2(1, 1)
	linie.size = FENSTER.size + Vector2(2, 2)
	linie.border_color = TarotStil.TINTE
	linie.border_width = 3.0
	linie.editor_only = false
	_wurzel.add_child(linie)

	_text = TarotStil.label(wirkung.to_upper(), 23, TarotStil.TINTE, false, 0)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_text.position = Vector2(14, 214)
	_text.size = Vector2(196, 70)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_constant_override("line_spacing", -6)
	_wurzel.add_child(_text)

	_stempel = Control.new()
	_stempel.size = GROESSE
	_stempel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stempel.draw.connect(_stempel_zeichnen)
	_stempel.visible = false
	_wurzel.add_child(_stempel)


## Bild aus der Welt des Bosses (buehnen/<boss>/platz_<n>.png).
func bild_setzen(textur: Texture2D) -> void:
	if _bild:
		_bild.texture = textur


func wirkung_setzen(text: String) -> void:
	wirkung = text
	if _text:
		_text.text = text.to_upper()


func _process(delta: float) -> void:
	_glanz = lerpf(_glanz, _glanz_ziel, 1.0 - exp(-12.0 * delta))
	var s := 1.0 + 0.05 * _glanz
	_wurzel.scale = Vector2(s, s)
	_wurzel.pivot_offset = GROESSE * 0.5
	queue_redraw()


func _draw() -> void:
	if _glanz > 0.01:
		var r := Rect2(-GROESSE * 0.5 * 1.05, GROESSE * 1.05).grow(6)
		for i in 4:
			draw_rect(r.grow(i * 5), Color(0.96, 0.82, 0.48, 0.22 * _glanz / (i + 1)), false, 6.0)
		draw_rect(r, Color(0.96, 0.82, 0.48, 0.9 * _glanz), false, 4.0)


func _stempel_zeichnen() -> void:
	var c := GROESSE * 0.5
	# Riss quer durchs Bild
	var riss := PackedVector2Array([Vector2(30, 20), Vector2(80, 70), Vector2(66, 100), Vector2(120, 140), Vector2(104, 170), Vector2(170, 210)])
	_stempel.draw_polyline(riss, TarotStil.TINTE, 7.0)
	_stempel.draw_polyline(riss, Color(0.9, 0.35, 0.2), 2.5)
	_stempel.draw_set_transform(c, -0.32, Vector2.ONE)
	var schrift := TarotStil.titel()
	_stempel.draw_rect(Rect2(-100, -30, 200, 60), Color(0.70, 0.15, 0.17, 0.85), false, 6.0)
	_stempel.draw_string(schrift, Vector2(-100, 12), "EINGESTÜRZT", HORIZONTAL_ALIGNMENT_CENTER, 200, 30, Color(0.70, 0.15, 0.17, 0.95))
	_stempel.draw_set_transform(Vector2.ZERO)


func enthaelt(punkt: Vector2) -> bool:
	return Rect2(global_position - GROESSE * 0.6, GROESSE * 1.2).has_point(punkt)
