# Eine Karte auf dem Bildschirm.
#
# Leitsatz aus der Artdirection: Man erkennt die Karte an ihrer Silhouette,
# der Text ist sekundaer. Deshalb dominiert das Symbol, die Zahl steht oben,
# der Effekttext klein darunter. Umgekehrte Karten bekommen einen dunklen
# Kopf, damit man die Orientierung in unter einer Sekunde sieht.
extends PanelContainer
class_name Kartenblatt

const Konst := preload("res://core/konst.gd")

signal angetippt(blatt: Kartenblatt)

var karte: Karte
var katalog: Katalog
var gewaehlt: bool = false:
	set(wert):
		gewaehlt = wert
		_rahmen_auffrischen()

var _kopf: Label
var _symbol: Label
var _text: Label
var _tinte_strich: ColorRect

func _init(p_karte: Karte, p_katalog: Katalog, breite: float = 190.0) -> void:
	karte = p_karte
	katalog = p_katalog
	custom_minimum_size = Vector2(breite, breite * 1.42)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	_kopf = Thema.label(_kopftext(), int(breite * 0.15), Color.WHITE)
	box.add_child(_kopf)

	_symbol = Thema.label(Konst.FARBE_ZEICHEN[karte.farbe], int(breite * 0.38), Color.WHITE)
	_symbol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_symbol)

	_text = Thema.label(katalog.text(karte), int(breite * 0.085), Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER, true)
	_text.custom_minimum_size.y = breite * 0.34
	box.add_child(_text)

	# Ein schmaler Streifen unten zeigt die Verderbnis der Karte.
	_tinte_strich = ColorRect.new()
	_tinte_strich.custom_minimum_size.y = 5
	box.add_child(_tinte_strich)

	auffrischen()

func _kopftext() -> String:
	var t: String = karte.rangname()
	if karte.stufe > 0:
		t += Konst.STUFE_NAME[karte.stufe]
	return t

func auffrischen() -> void:
	var flaeche: Color = Thema.kartenflaeche(karte.tinte, karte.ist_umgekehrt())
	var schrift: Color = Thema.kartenschrift(karte.tinte)
	var akzent: Color = Thema.akzent(karte.farbe)
	_kopf.text = _kopftext()
	_kopf.add_theme_color_override("font_color", akzent if karte.tinte <= 2 else Thema.OCKER_HELL)
	_symbol.add_theme_color_override("font_color", akzent)
	_symbol.text = Konst.FARBE_ZEICHEN[karte.farbe]
	if karte.ist_umgekehrt():
		# Umgekehrt heisst nicht schlechter, sondern anders - also gespiegelt
		# statt durchgestrichen.
		_symbol.rotation = PI
	_text.text = katalog.text(karte)
	_text.add_theme_color_override("font_color", schrift)
	_tinte_strich.color = Thema.SCHWARZ.lerp(Thema.BLUT, float(karte.tinte) / 5.0)
	add_theme_stylebox_override("panel", Thema.rahmen(akzent, 2, flaeche, 8))
	_rahmen_auffrischen()

func _rahmen_auffrischen() -> void:
	if not is_inside_tree():
		return
	var akzent: Color = Thema.akzent(karte.farbe)
	var flaeche: Color = Thema.kartenflaeche(karte.tinte, karte.ist_umgekehrt())
	var stil: StyleBoxFlat = Thema.rahmen(
		Thema.ELFENBEIN if gewaehlt else akzent,
		4 if gewaehlt else 2, flaeche, 8)
	add_theme_stylebox_override("panel", stil)

func _gui_input(ereignis: InputEvent) -> void:
	if ereignis is InputEventMouseButton and ereignis.pressed:
		angetippt.emit(self)
		accept_event()
	elif ereignis is InputEventScreenTouch and ereignis.pressed:
		angetippt.emit(self)
		accept_event()
