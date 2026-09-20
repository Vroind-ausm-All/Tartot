# Artdirection in Code: "Occult Clean".
#
# Schwarz und Elfenbein tragen alles, Indigo und Ocker sind die einzigen
# Akzente. Schwerter und Staebe ziehen nach Ocker, Kelche und Muenzen nach
# Indigo - so bleiben vier Farben unterscheidbar, ohne das Zweifarbensystem
# zu brechen. Siehe docs/04_ART.md.
extends RefCounted
class_name Thema

const Konst := preload("res://core/konst.gd")

const SCHWARZ := Color("#161616")
const TIEF := Color("#0E0E10")
const ELFENBEIN := Color("#F2ECDD")
const PAPIER := Color("#E4DCC6")
const INDIGO := Color("#2E3A67")
const INDIGO_HELL := Color("#4A5A96")
const OCKER := Color("#C89B3C")
const OCKER_HELL := Color("#E3BC63")
const BLUT := Color("#8E2B2B")
const GRAU := Color("#6B6659")

## Akzentfarbe je Kartenfarbe.
static func akzent(farbe: int) -> Color:
	match farbe:
		Konst.Farbe.SCHWERTER: return BLUT
		Konst.Farbe.STAEBE: return OCKER
		Konst.Farbe.KELCHE: return INDIGO_HELL
		Konst.Farbe.MUENZEN: return INDIGO
		Konst.Farbe.ARKANA: return OCKER_HELL
	return GRAU

## Kartenflaeche. Je hoeher die Tinte, desto dunkler das Papier -
## das ist die sichtbare Verdunkelung des eigenen Decks.
static func kartenflaeche(tinte: int, umgekehrt: bool) -> Color:
	var t: float = clampf(float(tinte) / 5.0, 0.0, 1.0)
	var basis: Color = PAPIER.lerp(SCHWARZ, t * 0.82)
	if umgekehrt:
		basis = basis.lerp(INDIGO, 0.22)
	return basis

static func kartenschrift(tinte: int) -> Color:
	return SCHWARZ if tinte <= 2 else ELFENBEIN

static func rahmen(farbe: Color, breite: int = 2, fuellung: Color = SCHWARZ,
		radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fuellung
	s.border_color = farbe
	s.set_border_width_all(breite)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func knopf_stil(grund: Color, rand: Color) -> StyleBoxFlat:
	var s := rahmen(rand, 2, grund, 4)
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

static func seltenheitsfarbe(name: String) -> Color:
	match name:
		"GEMEIN": return GRAU
		"SELTEN": return INDIGO_HELL
		"ARKAN": return OCKER
		"VERKEHRT": return BLUT
		"MYTHOS": return OCKER_HELL
	return GRAU

## umbruch nur fuer echte Fliesstexte einschalten. In Leisten fuehrt
## automatischer Umbruch dazu, dass Labels auf ein Zeichen pro Zeile
## zusammenfallen, sobald der Container eng wird.
static func label(text: String, groesse: int, farbe: Color,
		ausrichtung: int = HORIZONTAL_ALIGNMENT_CENTER,
		umbruch: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.horizontal_alignment = ausrichtung
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if umbruch else TextServer.AUTOWRAP_OFF
	return l
