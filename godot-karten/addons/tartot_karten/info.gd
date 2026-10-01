class_name KartenInfo
extends PanelContainer
## Das Infofeld ueber einer Karte, wie bei Balatro: Name, Wirkung, und darunter
## farbige Plaketten fuer Seltenheit und Edition.

const EDITION_FARBEN := {
	"Shimmering": Color("F4D27A"), "Glowing": Color("7F8FD0"),
	"Burning": Color("E0543A"), "Glass": Color("C9D6E3"),
}

var _name: Label
var _text: Label
var _edition_text: Label
var _plaketten: HBoxContainer
var _karte: TarotKarte


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := TarotStil.platte("tafel.png", Vector4(30, 30, 30, 30), Vector4(28, 22, 28, 24))
	add_theme_stylebox_override("panel", stil)

	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 6)
	add_child(spalte)
	_name = _label(true, 36, Color("F0CD80"))
	spalte.add_child(_name)
	_text = _label(false, 30, Color("EFE3C8"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 0)
	spalte.add_child(_text)
	_edition_text = _label(false, 30, Color("F4D27A"))
	_edition_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edition_text.custom_minimum_size = Vector2(440, 0)
	spalte.add_child(_edition_text)
	_plaketten = HBoxContainer.new()
	_plaketten.alignment = BoxContainer.ALIGNMENT_CENTER
	_plaketten.add_theme_constant_override("separation", 10)
	spalte.add_child(_plaketten)
	visible = false


func _label(titel: bool, groesse: int, farbe: Color) -> Label:
	return TarotStil.label("", groesse, farbe, not titel, 4 if titel else 0)


func _plakette(text: String, grund: Color, schrift_farbe: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = grund
	s.set_corner_radius_all(16)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	var l := _label(true, 24, schrift_farbe)
	l.add_theme_constant_override("outline_size", 0)
	l.text = text
	p.add_child(l)
	return p


func zeigen(karte: TarotKarte) -> void:
	if karte == null:
		verbergen()
		return
	if karte == _karte and visible:
		return
	_karte = karte
	var d := karte.daten
	_name.text = str(d.get("name", karte.id))
	_text.text = str(d.get("text", ""))
	for kind in _plaketten.get_children():
		kind.queue_free()
	var selten := KartenDaten.seltenheit(d.get("rarity", "Common"))
	var grund := Color(selten["color"])
	var schrift := Color("1A1412") if d.get("rarity", "") == "Legendary" else Color("EFE3C8")
	_plaketten.add_child(_plakette(selten["name"], grund, schrift))
	if karte.edition != "":
		var ed := KartenDaten.edition(karte.edition)
		var farbe: Color = EDITION_FARBEN.get(karte.edition, Color.WHITE)
		_plaketten.add_child(_plakette(ed.get("name", karte.edition), farbe, Color("1A1412")))
		_edition_text.text = ed.get("text", "")
		_edition_text.add_theme_color_override("font_color", farbe)
		_edition_text.visible = true
	else:
		_edition_text.visible = false
	visible = true
	reset_size()
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.92, 0.92)
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func verbergen() -> void:
	_karte = null
	visible = false


func _process(_delta: float) -> void:
	if not visible or _karte == null or not is_instance_valid(_karte):
		return
	# ueber der Karte, auf dem Bildschirm gehalten
	var breite := size.x
	var hoehe := size.y
	var oben := _karte.global_position.y - TarotKarte.GROESSE.y * 0.5 * _karte.scale.y - hoehe - 18.0
	if oben < 20.0:
		oben = _karte.global_position.y + TarotKarte.GROESSE.y * 0.5 * _karte.scale.y + 18.0
	var links := clampf(_karte.global_position.x - breite * 0.5, 16.0, 1080.0 - breite - 16.0)
	position = Vector2(links, oben)
	pivot_offset = size * 0.5
