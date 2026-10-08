extends RefCounted
class_name Thema
## Die Seiten ausserhalb des Kampfes im Stil des Kartentischs (TarotStil):
## IM-Fell-Schrift, dunkle Zierplatten mit Goldrahmen, rote Zierknoepfe.
##
## main.gd gibt Groessen noch im alten 270er-Mass an (6 = Fliesstext,
## 14 = Titel); S rechnet sie auf 1080 x 1920 hoch.

const S := 4
const INK := Color("#1A1412")
const DEEP := Color("#0D0A09")
const PAPER := Color("#EFE3C8")
const PAPER_DARK := Color("#D8C8A6")
const SEPIA1 := Color("#C9B48E")
const SEPIA2 := Color("#8F7A5A")
const SEPIA3 := Color("#4E4032")
const GOLD := Color("#E3A83B")
const GOLD_LIGHT := Color("#F1C35C")
const RED := Color("#B3262B")
const INDIGO := Color("#3B4A8C")
const INDIGO_LIGHT := Color("#6170B4")

## Kleinste Schriftgroesse im alten Mass (6 x S = 24 px bei 1080 Breite).
const MIN_FONT := 6


static func label(text: String, size: int = 12, color: Color = PAPER, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false) -> Label:
	var lese := size <= 7
	var l := TarotStil.label(text, maxi(MIN_FONT, size) * S + (6 if lese else 0), color, lese, 0 if lese else 5)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Dunkle Zierplatte mit Goldrahmen.
static func panel() -> StyleBox:
	return TarotStil.tafel()


## Knopf: der wichtigste rot (Zierknopf), die uebrigen als dunkle Platten.
static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 150 if primary else 128)
	if primary:
		TarotStil.knopf_stil(b, 46)
		return b
	var normal := TarotStil.platte("tafel.png", Vector4(30, 30, 30, 30), Vector4(40, 24, 40, 26))
	var hell := normal.duplicate() as StyleBoxTexture
	hell.modulate_color = Color(1.25, 1.15, 1.0)
	var aus := normal.duplicate() as StyleBoxTexture
	aus.modulate_color = Color(0.6, 0.6, 0.6, 0.8)
	for zustand in ["normal", "focus"]:
		b.add_theme_stylebox_override(zustand, normal)
	b.add_theme_stylebox_override("hover", hell)
	b.add_theme_stylebox_override("pressed", hell)
	b.add_theme_stylebox_override("disabled", aus)
	b.add_theme_font_override("font", TarotStil.text())
	b.add_theme_font_size_override("font_size", 34)
	for farbe in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(farbe, PAPER)
	b.add_theme_color_override("font_disabled_color", SEPIA2)
	return b
