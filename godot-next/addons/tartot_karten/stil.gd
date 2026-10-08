class_name TarotStil
extends RefCounted
## Der Stil der Boss-Blaetter an einer Stelle: Farben, Schrift, Zierplatten,
## Knoepfe. Alles, was am Tisch Rahmen oder Schrift hat, holt sich das hier -
## so bleibt der Tisch aus einem Guss.
##
## Schrift: IM Fell DW Pica (Igino Marini, OFL) - Bleisatz des 17. Jahrhunderts,
## schmal und etwas kraeftiger gesetzt, wie die Titel auf den Blaettern.

const TINTE := Color("1A1412")
const NACHT := Color("140F0C")
const PAPIER := Color("EFE3C8")
const PAPIER_DUNKEL := Color("C9B48E")
const SEPIA := Color("8F7A5A")
const GOLD := Color("C9A258")
const GOLD_HELL := Color("F0CD80")
const BLUT := Color("B3262B")
const GLUT := Color("E0543A")
const INDIGO := Color("3B4A8C")

const KUNST := "res://addons/tartot_karten/kunst/"
const SCHRIFT := "res://addons/tartot_karten/schrift/"

static var _titel: FontVariation
static var _text: FontVariation
static var _zahlen: FontVariation


## Titelschrift: Kapitaelchen, schmal, kraeftig.
static func titel() -> Font:
	if _titel == null:
		_titel = FontVariation.new()
		_titel.base_font = load(SCHRIFT + "IMFePIsc28P.ttf")
		_titel.variation_embolden = 0.55
		_titel.variation_transform = Transform2D(Vector2(0.86, 0), Vector2(0, 1), Vector2.ZERO)
		_titel.spacing_glyph = 1
	return _titel


## Lesetext: dieselbe Familie mit Kleinbuchstaben.
static func text() -> Font:
	if _text == null:
		_text = FontVariation.new()
		_text.base_font = load(SCHRIFT + "IMFePIrm28P.ttf")
		_text.variation_embolden = 0.25
	return _text


## Zahlen: Oranienbaum (Oleg Pospelov, OFL), schmale Versalziffern wie auf
## den Blaettern - IM Fell hat Mediaevalziffern, die tanzen in "32/50".
static func zahlen() -> Font:
	if _zahlen == null:
		_zahlen = FontVariation.new()
		_zahlen.base_font = load(SCHRIFT + "Oranienbaum-Regular.ttf")
		_zahlen.variation_embolden = 0.85
	return _zahlen


static func zahl(inhalt: String, groesse: int, farbe := PAPIER, kontur := 6) -> Label:
	var l := label(inhalt, groesse, farbe, false, kontur)
	l.add_theme_font_override("font", zahlen())
	return l


static func label(inhalt: String, groesse: int, farbe := PAPIER, lese := false, kontur := 6) -> Label:
	var l := Label.new()
	l.text = inhalt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", text() if lese else titel())
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	if kontur > 0:
		l.add_theme_color_override("font_outline_color", TINTE)
		l.add_theme_constant_override("outline_size", kontur)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l


## 9-Slice aus kunst/ui.
static func platte(datei: String, rand: Vector4, innen := Vector4(-1, -1, -1, -1)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(KUNST + "ui/" + datei)
	s.texture_margin_left = rand.x
	s.texture_margin_top = rand.y
	s.texture_margin_right = rand.z
	s.texture_margin_bottom = rand.w
	var i := rand if innen.x < 0 else innen
	s.content_margin_left = i.x
	s.content_margin_top = i.y
	s.content_margin_right = i.z
	s.content_margin_bottom = i.w
	return s


## Dunkle Zierplatte mit Goldrahmen.
static func tafel() -> StyleBoxTexture:
	return platte("tafel.png", Vector4(30, 30, 30, 30), Vector4(22, 16, 22, 16))


static func tafel_knoten(pos: Vector2, groesse: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = groesse
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", tafel())
	return p


## Roter Zierknopf: normal, gedrueckt, gesperrt.
static func knopf_stil(knopf: Button, groesse := 44) -> void:
	var normal := platte("knopf.png", Vector4(34, 30, 34, 36))
	var druck := platte("knopf_druck.png", Vector4(34, 30, 34, 36))
	var aus := platte("knopf_aus.png", Vector4(34, 30, 34, 36))
	for zustand in ["normal", "hover", "focus"]:
		knopf.add_theme_stylebox_override(zustand, normal)
	knopf.add_theme_stylebox_override("pressed", druck)
	knopf.add_theme_stylebox_override("disabled", aus)
	knopf.add_theme_font_override("font", titel())
	knopf.add_theme_font_size_override("font_size", groesse)
	for farbe in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		knopf.add_theme_color_override(farbe, PAPIER)
	knopf.add_theme_color_override("font_disabled_color", Color("8F7A5A"))
	knopf.add_theme_color_override("font_outline_color", Color("4A0E10"))
	knopf.add_theme_constant_override("outline_size", 8)


static func bild(datei: String, pos: Vector2, groesse: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = load(KUNST + "ui/" + datei)
	t.position = pos
	t.size = groesse
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Roemische Zahl (fuer Akte und Runden).
static func roemisch(n: int) -> String:
	if n <= 0:
		return "0"
	var werte := [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"],
		[50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var s := ""
	for w in werte:
		while n >= w[0]:
			s += w[1]
			n -= w[0]
	return s


## Deutsche Kommazahl ohne ueberfluessige Nullen.
static func komma(x: float) -> String:
	return ("%.2f" % x).replace(".", ",").trim_suffix("0").trim_suffix(",0")
