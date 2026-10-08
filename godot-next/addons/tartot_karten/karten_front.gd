class_name KartenFront
extends Control
## Die Vorderseite einer Karte, randlos wie eine Tarotkarte: das Motiv fuellt
## die ganze Flaeche, Zahl und Name liegen als Kartuschen darueber, ein
## Goldrahmen faengt alles ein. Hat die Karte (noch) kein Motiv, malt die
## Vorderseite ihre Farbe als Sinnbilder auf einen Strahlengrund - nie ein
## fremdes Motiv, damit keine Karte wie eine andere aussieht.
##
## Gezeichnet wird in Kartenmass (240 x 360) und mit `aufl` vergroessert.
## Ebenen von unten nach oben: Motiv oder Grund, Zier (Verlaeufe, Rahmen,
## Kartuschen, Sinnbilder), Schrift, Mal des Todes.
##
## Das Motiv ist etwas groesser als die Karte und laesst sich verschieben
## (motiv_versatz) - so liegt es beim Kippen scheinbar hinter dem Rahmen.

const G := Vector2(240, 360)
## Rand, um den das Motiv groesser ist als die Karte (fuer die Parallaxe).
const UEBERSTAND := 12.0
const TINTE := Color("1A1412")
const PAPIER := Color("EFE3C8")
const GOLD_HELL := Color("F0CD80")
const BLUT := Color("B3262B")
## Rahmenfarbe je Schimmer (Enums.Shimmer: matt, weiss, indigo, gold, blut, schwarz).
const SCHIMMER_FARBEN := [Color("C9A258"), Color("E4E1D8"), Color("8C9BE0"), Color("F6C64A"), Color("D8434A"), Color("5A4F48")]
## Grund der Karten ohne Motiv: oben, unten.
const GRUENDE := {
	"Swords": [Color("2E3748"), Color("0E1118")],
	"Wands": [Color("3E2C1A"), Color("120C07")],
	"Cups": [Color("1F2C4A"), Color("0B0F1C")],
	"Pentacles": [Color("3D2F14"), Color("140E05")],
	"Major": [Color("2E1C33"), Color("0E0A12")],
}
## Lage der Sinnbilder je Zahl (Anteile im Bildfeld), wie auf alten Spielkarten.
const PIPS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.5, 0.12), Vector2(0.5, 0.88)],
	3: [Vector2(0.5, 0.12), Vector2(0.5, 0.5), Vector2(0.5, 0.88)],
	4: [Vector2(0.27, 0.15), Vector2(0.73, 0.15), Vector2(0.27, 0.85), Vector2(0.73, 0.85)],
	5: [Vector2(0.27, 0.15), Vector2(0.73, 0.15), Vector2(0.5, 0.5), Vector2(0.27, 0.85), Vector2(0.73, 0.85)],
	6: [Vector2(0.27, 0.15), Vector2(0.73, 0.15), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.85), Vector2(0.73, 0.85)],
	7: [Vector2(0.27, 0.15), Vector2(0.73, 0.15), Vector2(0.5, 0.32), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.85), Vector2(0.73, 0.85)],
	8: [Vector2(0.27, 0.15), Vector2(0.73, 0.15), Vector2(0.5, 0.32), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.5, 0.68), Vector2(0.27, 0.85), Vector2(0.73, 0.85)],
	9: [Vector2(0.27, 0.12), Vector2(0.73, 0.12), Vector2(0.27, 0.37), Vector2(0.73, 0.37), Vector2(0.5, 0.5), Vector2(0.27, 0.63), Vector2(0.73, 0.63), Vector2(0.27, 0.88), Vector2(0.73, 0.88)],
	10: [Vector2(0.27, 0.12), Vector2(0.73, 0.12), Vector2(0.5, 0.25), Vector2(0.27, 0.37), Vector2(0.73, 0.37), Vector2(0.27, 0.63), Vector2(0.73, 0.63), Vector2(0.5, 0.75), Vector2(0.27, 0.88), Vector2(0.73, 0.88)],
}
## Bildfeld der Sinnbilder (Kartenmass).
const PIP_FELD := Rect2(44, 74, 152, 196)

var aufl := 2
var daten := {}
var id := ""
var motiv: Texture2D
var umgekehrt := false
var stufe := 1
var schimmer := 0
## Zuege, die das Mal des Todes noch traegt (0: kein Mal).
var gezeichnet := 0
var motiv_versatz := Vector2.ZERO:
	set(v):
		motiv_versatz = v
		if _motiv:
			_motiv.position = (Vector2(-UEBERSTAND, -UEBERSTAND) + v) * aufl

var _motiv: TextureRect
var _grund: Control
var _zier: Control
var _zahl: Label
var _name: Label
var _mal: Control
var _mal_zahl: Label


func _init(p_daten: Dictionary, p_aufl := 2) -> void:
	daten = p_daten
	id = str(daten.get("id", ""))
	aufl = p_aufl
	size = G * aufl
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if motiv != null:
		_motiv = TextureRect.new()
		_motiv.texture = motiv
		_motiv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_motiv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_motiv.size = (G + Vector2(UEBERSTAND, UEBERSTAND) * 2.0) * aufl
		_motiv.position = Vector2(-UEBERSTAND, -UEBERSTAND) * aufl
		_motiv.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_motiv)
	else:
		_grund = Control.new()
		_grund.size = size
		_grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grund.draw.connect(_grund_zeichnen)
		add_child(_grund)

	_zier = Control.new()
	_zier.size = size
	_zier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zier.draw.connect(_zier_zeichnen)
	add_child(_zier)

	var nummer := str(daten.get("number", "?"))
	_zahl = TarotStil.label(nummer, 25 * aufl, GOLD_HELL, false, 0)
	if nummer.is_valid_int():
		_zahl.add_theme_font_override("font", TarotStil.zahlen())
		_zahl.add_theme_font_size_override("font_size", 27 * aufl)
	_zahl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_zahl.position = Vector2(70, 12) * aufl
	_zahl.size = Vector2(100, 34) * aufl
	add_child(_zahl)

	var name_text := str(daten.get("name", id)).to_upper()
	var groesse := 19
	while groesse > 12 and TarotStil.titel().get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, groesse).x > 176.0:
		groesse -= 1
	_name = TarotStil.label(name_text, groesse * aufl, PAPIER, false, 0)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_name.position = Vector2(26, 298) * aufl
	_name.size = Vector2(188, 34) * aufl
	_name.clip_text = true
	add_child(_name)

	_mal = Control.new()
	_mal.size = size
	_mal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mal.draw.connect(_mal_zeichnen)
	add_child(_mal)
	_mal_zahl = TarotStil.zahl("", 20 * aufl, PAPIER, 0)
	_mal_zahl.position = Vector2(168, 64) * aufl
	_mal_zahl.size = Vector2(40, 36) * aufl
	_mal.add_child(_mal_zahl)
	zustand_zeigen()


## Umkehrung, Stufe, Schimmer oder Mal haben sich geaendert: neu malen.
func zustand_zeigen() -> void:
	if _zier == null:
		return
	if _motiv:
		_motiv.flip_h = umgekehrt
		_motiv.flip_v = umgekehrt
	if _grund:
		_grund.queue_redraw()
	_zahl.add_theme_color_override("font_color", Color("F08A7E") if umgekehrt else GOLD_HELL)
	_zier.queue_redraw()
	_mal.visible = gezeichnet > 0
	_mal_zahl.text = str(gezeichnet)
	_mal.queue_redraw()


func rahmen_farbe() -> Color:
	return SCHIMMER_FARBEN[clampi(schimmer, 0, SCHIMMER_FARBEN.size() - 1)]


# ------------------------------------------------------------------ Grund
## Karte ohne Motiv: Farbverlauf, Strahlen, Sterne, die Sinnbilder ihrer Zahl.
func _grund_zeichnen() -> void:
	var c := _grund
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(aufl, aufl))
	var farbe: String = daten.get("suit", "Major")
	var verlauf: Array = GRUENDE.get(farbe, GRUENDE["Major"])
	_verlauf(c, Rect2(Vector2.ZERO, G), verlauf[0], verlauf[1])
	var mitte := Vector2(120, 172)
	var gold := rahmen_farbe()
	# Strahlenkranz wie auf der Rueckseite
	for i in 48:
		var a := TAU * i / 48.0
		var lang := 150.0 if i % 2 == 0 else 105.0
		c.draw_line(mitte + Vector2(cos(a), sin(a)) * 46.0, mitte + Vector2(cos(a), sin(a)) * lang, Color(gold, 0.16 if i % 2 == 0 else 0.09), 1.0, true)
	# Lichthof
	for r in range(70, 0, -7):
		c.draw_circle(mitte, r, Color(gold, 0.018))
	# Sternstaub, fest je Karte
	var zufall := RandomNumberGenerator.new()
	zufall.seed = hash(id)
	for i in 26:
		var p := Vector2(zufall.randf_range(14, 226), zufall.randf_range(50, 300))
		c.draw_circle(p, zufall.randf_range(0.6, 1.6), Color(gold, zufall.randf_range(0.18, 0.5)))

	var rang := int(daten.get("rank", 1))
	if farbe == "Major":
		# Grosse Arkana ohne Motiv: die Zahl gross im Hintergrund, davor das Sinnbild.
		var zahl := str(daten.get("number", ""))
		var schrift := TarotStil.titel()
		var breite := schrift.get_string_size(zahl, HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x
		c.draw_string(schrift, Vector2(120 - breite * 0.5, 214), zahl, HORIZONTAL_ALIGNMENT_LEFT, -1, 120, Color(gold, 0.14))
		_sinnbild(c, "Major", mitte, 40.0, 0.0)
		return
	if rang >= 11:
		# Hof: grosses Sinnbild, darueber das Zeichen des Ranges.
		_sinnbild(c, farbe, mitte + Vector2(0, 26), 36.0, 0.0)
		_hofzeichen(c, rang, mitte + Vector2(0, -52), gold)
		return
	var lagen: Array = PIPS.get(rang, PIPS[1])
	var s := 38.0 if rang == 1 else (22.0 if rang <= 3 else (19.0 if rang <= 6 else (16.0 if rang <= 8 else 14.5)))
	for lage: Vector2 in lagen:
		var p := PIP_FELD.position + PIP_FELD.size * lage
		# Die untere Haelfte steht auf dem Kopf, wie auf alten Karten.
		_sinnbild(c, farbe, p, s, PI if lage.y > 0.55 else 0.0)


# ------------------------------------------------------------------ Zier
func _zier_zeichnen() -> void:
	var c := _zier
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(aufl, aufl))
	var gold := rahmen_farbe()
	var dunkel := Color(TINTE, 0.0)

	# Verlaeufe: oben fuer die Zahl, unten fuer den Namen.
	_verlauf(c, Rect2(0, 0, 240, 92), Color(TINTE, 0.78), dunkel)
	_verlauf(c, Rect2(0, 212, 240, 78), dunkel, Color(TINTE, 0.86))
	c.draw_rect(Rect2(0, 290, 240, 70), Color(TINTE, 0.86))

	# Rahmen: dunkler Saum, Goldlinie, feine Innenlinie.
	_rund(c, Rect2(Vector2(3.5, 3.5), G - Vector2(7, 7)), 13.0, Color(TINTE, 0.55), 7.0)
	_rund(c, Rect2(Vector2(8, 8), G - Vector2(16, 16)), 9.0, gold, 2.4)
	_rund(c, Rect2(Vector2(12.5, 12.5), G - Vector2(25, 25)), 6.0, Color(gold, 0.75), 0.9)
	_rund(c, Rect2(Vector2(1, 1), G - Vector2(2, 2)), 15.0, TINTE, 2.0)
	for ecke: Vector2 in [Vector2(19, 19), Vector2(221, 19), Vector2(19, 341), Vector2(221, 341)]:
		_raute(c, ecke, 3.6, gold)

	# Zahlkartusche oben, mit Ranken zu den Seiten.
	var zahl := str(daten.get("number", ""))
	var schrift: Font = TarotStil.zahlen() if zahl.is_valid_int() else TarotStil.titel()
	var breite := maxf(48.0, schrift.get_string_size(zahl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 30.0)
	var kartusche := Rect2(120 - breite * 0.5, 13, breite, 32)
	c.draw_line(Vector2(34, 29), Vector2(kartusche.position.x - 4, 29), Color(gold, 0.8), 1.2, true)
	c.draw_line(Vector2(kartusche.end.x + 4, 29), Vector2(206, 29), Color(gold, 0.8), 1.2, true)
	_raute(c, Vector2(34, 29), 2.6, gold)
	_raute(c, Vector2(206, 29), 2.6, gold)
	_platte(c, kartusche, 10.0, Color(TINTE, 0.9), gold)
	# Farbe in den oberen Ecken
	var farbe: String = daten.get("suit", "Major")
	_sinnbild(c, farbe, Vector2(33, 52), 9.0, 0.0)
	_sinnbild(c, farbe, Vector2(207, 52), 9.0, 0.0)
	if umgekehrt:
		# Umgekehrt: rote Dreiecke neben der Zahl zeigen nach unten.
		for x: float in [kartusche.position.x - 10.0, kartusche.end.x + 10.0]:
			var dreieck := PackedVector2Array([Vector2(x - 5, 24), Vector2(x + 5, 24), Vector2(x, 33)])
			c.draw_colored_polygon(dreieck, BLUT)
			c.draw_polyline(PackedVector2Array(Array(dreieck) + [dreieck[0]]), TINTE, 1.0, true)

	# Namensband unten: Band mit gekerbten Enden.
	var band := Rect2(24, 298, 192, 34)
	for seite: float in [-1.0, 1.0]:
		var x0 := 120.0 + seite * 96.0
		var x1 := 120.0 + seite * 110.0
		var ende := PackedVector2Array([Vector2(x0, 303), Vector2(x1, 303), Vector2(x1 - seite * 6.0, 318.5), Vector2(x1, 334), Vector2(x0, 334)])
		c.draw_colored_polygon(ende, Color(TINTE.lerp(gold, 0.18), 0.95))
		c.draw_polyline(PackedVector2Array(Array(ende) + [ende[0]]), Color(gold, 0.85), 1.2, true)
	_platte(c, band, 4.0, Color(TINTE, 0.94), gold)

	# Seltenheit: Edelstein unten auf der Goldlinie.
	var selten := Color(KartenDaten.seltenheit(daten.get("rarity", "Common"))["color"])
	var stein := PackedVector2Array([Vector2(120, 340), Vector2(128, 348), Vector2(120, 356), Vector2(112, 348)])
	c.draw_colored_polygon(stein, selten)
	c.draw_colored_polygon(PackedVector2Array([Vector2(120, 342), Vector2(123.5, 346), Vector2(120, 348), Vector2(116.5, 346)]), Color(1, 1, 1, 0.4))
	c.draw_polyline(PackedVector2Array(Array(stein) + [stein[0]]), TINTE, 1.4, true)

	# Stufe: kleine Goldpunkte links und rechts vom Stein.
	for i in mini(stufe - 1, 5):
		for seite: float in [-1.0, 1.0]:
			var p := Vector2(120.0 + seite * (16.0 + i * 7.0), 348)
			c.draw_circle(p, 2.3, gold)
			c.draw_circle(p, 2.3, TINTE, false, 0.8, true)


## Mal des Todes: ein Wachssiegel mit den verbleibenden Zuegen.
func _mal_zeichnen() -> void:
	if gezeichnet <= 0:
		return
	var c := _mal
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(aufl, aufl))
	var mitte := Vector2(188, 82)
	var rand := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		rand.append(mitte + Vector2(cos(a), sin(a)) * (22.0 if i % 2 == 0 else 19.5))
	c.draw_colored_polygon(rand, Color("7A1A1E"))
	c.draw_circle(mitte, 16.0, BLUT)
	c.draw_circle(mitte, 16.0, Color("5A1215"), false, 1.6, true)
	# Sense ueber dem Siegel
	c.draw_line(mitte + Vector2(-12, 12), mitte + Vector2(10, -14), Color(PAPIER, 0.35), 1.6, true)
	c.draw_arc(mitte + Vector2(2, -14), 10.0, PI, TAU * 0.95, 10, Color(PAPIER, 0.35), 1.6, true)


# ------------------------------------------------------------------ Formen
## Sinnbild einer Farbe, mittig auf p, s = halbe Hoehe in Kartenmass.
func _sinnbild(c: Control, farbe: String, p: Vector2, s: float, dreh: float) -> void:
	var gold := rahmen_farbe()
	var t := Transform2D(dreh, Vector2(s / 10.0, s / 10.0), 0.0, p)
	var linie := 1.3
	match farbe:
		"Swords":
			_form(c, t, [Vector2(0, -10), Vector2(1.7, -7.5), Vector2(1.7, 3.8), Vector2(-1.7, 3.8), Vector2(-1.7, -7.5)], gold, linie)
			_form(c, t, [Vector2(-5.5, 3.6), Vector2(5.5, 3.6), Vector2(5.5, 5.6), Vector2(-5.5, 5.6)], gold, linie)
			_form(c, t, [Vector2(-1, 5.6), Vector2(1, 5.6), Vector2(1, 8.4), Vector2(-1, 8.4)], gold, linie)
			_kreis(c, t, Vector2(0, 9.4), 1.4, gold, linie)
		"Wands":
			var stab := t * Transform2D(0.38, Vector2.ZERO)
			for blatt: Array in [[Vector2(2.0, -6.8), 0.45], [Vector2(-2.0, -3.2), PI - 0.5], [Vector2(2.2, 1.0), 0.6]]:
				var b := stab * Transform2D(blatt[1], blatt[0])
				_form(c, b, [Vector2(0, 0), Vector2(3.4, -2.6), Vector2(7.4, 0), Vector2(3.4, 2.6)], gold, linie * 0.8)
			_form(c, stab, [Vector2(-2.2, -10), Vector2(2.2, -10), Vector2(2.8, 10), Vector2(-2.8, 10)], gold, linie)
			_kreis(c, stab, Vector2(-2.4, -1.0), 1.3, gold, linie * 0.7)
			_kreis(c, stab, Vector2(2.6, 5.0), 1.3, gold, linie * 0.7)
		"Cups":
			_form(c, t, [Vector2(-6.5, -9), Vector2(-6.2, -5.5), Vector2(-4.6, -2.6), Vector2(-2.2, -1.2), Vector2(0, -1), Vector2(2.2, -1.2), Vector2(4.6, -2.6), Vector2(6.2, -5.5), Vector2(6.5, -9)], gold, linie)
			_form(c, t, [Vector2(-1.1, -1.2), Vector2(1.1, -1.2), Vector2(1.1, 5.5), Vector2(-1.1, 5.5)], gold, linie)
			_form(c, t, [Vector2(-2.8, 5.4), Vector2(2.8, 5.4), Vector2(5.4, 9), Vector2(-5.4, 9)], gold, linie)
		"Pentacles":
			_kreis(c, t, Vector2.ZERO, 9.5, gold, linie)
			var stern := PackedVector2Array()
			for i in 6:
				var a := -PI / 2.0 + TAU * float(i * 2 % 5) / 5.0
				stern.append(t * (Vector2(cos(a), sin(a)) * 6.6))
			c.draw_polyline(stern, TINTE, linie * s / 10.0, true)
			c.draw_arc(t.origin, 7.6 * s / 10.0, 0.0, TAU, 28, TINTE, linie * 0.7 * s / 10.0, true)
		_:
			var stern: Array = []
			for i in 16:
				var a := -PI / 2.0 + TAU * i / 16.0
				stern.append(Vector2(cos(a), sin(a)) * (10.0 if i % 4 == 0 else (6.0 if i % 2 == 0 else 3.6)))
			_form(c, t, stern, gold, linie)
			# Auge in der Mitte
			c.draw_circle(t.origin, 2.6 * s / 10.0, TINTE)
			c.draw_circle(t.origin, 1.2 * s / 10.0, gold)


## Bube, Ritter, Koenigin, Koenig: Feder, Helm, Krone mit Perlen, Zackenkrone.
func _hofzeichen(c: Control, rang: int, p: Vector2, gold: Color) -> void:
	var t := Transform2D(0.0, Vector2(2.2, 2.2), 0.0, p)
	match rang:
		11:
			_form(c, t, [Vector2(-6, 3), Vector2(6, 3), Vector2(4, -1), Vector2(-4, -1)], gold, 0.6)
			_form(c, t, [Vector2(2, -1), Vector2(9, -9), Vector2(5, -1)], gold, 0.6)
		12:
			_form(c, t, [Vector2(0, -6), Vector2(4, -10), Vector2(6.5, -8.5), Vector2(1.5, -5)], gold, 0.6)
			_form(c, t, [Vector2(-5, 5), Vector2(5, 5), Vector2(5.5, -1), Vector2(3.5, -5), Vector2(0, -6.5), Vector2(-3.5, -5), Vector2(-5.5, -1)], gold, 0.6)
			c.draw_line(t * Vector2(-4.5, -0.5), t * Vector2(4.5, -0.5), TINTE, 2.0, true)
			c.draw_line(t * Vector2(0, -0.5), t * Vector2(0, 4.5), TINTE, 1.4, true)
		13:
			_form(c, t, [Vector2(-7, 4), Vector2(7, 4), Vector2(6, -3), Vector2(3, 0), Vector2(0, -5), Vector2(-3, 0), Vector2(-6, -3)], gold, 0.6)
			for x: float in [-6.0, 0.0, 6.0]:
				_kreis(c, t, Vector2(x, -4.2 if x != 0.0 else -6.0), 1.2, gold, 0.5)
		_:
			_form(c, t, [Vector2(-7, 4), Vector2(7, 4), Vector2(7, -6), Vector2(3.5, -1), Vector2(0, -7), Vector2(-3.5, -1), Vector2(-7, -6)], gold, 0.6)
			c.draw_line(t * Vector2(-7, 2), t * Vector2(7, 2), TINTE, 1.2, true)


func _form(c: Control, t: Transform2D, punkte: Array, fuellung: Color, linie: float) -> void:
	var pts := PackedVector2Array()
	for q in punkte:
		pts.append(t * (q as Vector2))
	c.draw_colored_polygon(pts, fuellung)
	pts.append(pts[0])
	c.draw_polyline(pts, TINTE, linie * t.get_scale().x, true)


func _kreis(c: Control, t: Transform2D, mitte: Vector2, r: float, fuellung: Color, linie: float) -> void:
	var s := t.get_scale().x
	c.draw_circle(t * mitte, r * s, fuellung)
	c.draw_arc(t * mitte, r * s, 0.0, TAU, 32, TINTE, linie * s, true)


func _raute(c: Control, p: Vector2, r: float, farbe: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
	c.draw_colored_polygon(pts, farbe)
	pts.append(pts[0])
	c.draw_polyline(pts, TINTE, 0.9, true)


func _platte(c: Control, r: Rect2, ecke: float, fuellung: Color, rand: Color) -> void:
	var pts := _rund_punkte(r, ecke)
	c.draw_colored_polygon(pts, fuellung)
	pts.append(pts[0])
	c.draw_polyline(pts, rand, 1.6, true)
	var innen := _rund_punkte(r.grow(-3.0), maxf(1.0, ecke - 3.0))
	innen.append(innen[0])
	c.draw_polyline(innen, Color(rand, 0.4), 0.7, true)


func _rund(c: Control, r: Rect2, ecke: float, farbe: Color, breite: float) -> void:
	var pts := _rund_punkte(r, ecke)
	pts.append(pts[0])
	c.draw_polyline(pts, farbe, breite, true)


static func _rund_punkte(r: Rect2, ecke: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var mitten := [r.position + Vector2(r.size.x - ecke, ecke), r.end - Vector2(ecke, ecke),
		Vector2(r.position.x + ecke, r.end.y - ecke), r.position + Vector2(ecke, ecke)]
	for i in 4:
		for k in 7:
			var a := -PI / 2.0 + PI / 2.0 * (i + k / 6.0)
			pts.append(mitten[i] + Vector2(cos(a), sin(a)) * ecke)
	return pts


func _verlauf(c: Control, r: Rect2, oben: Color, unten: Color) -> void:
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([oben, oben, unten, unten]))
