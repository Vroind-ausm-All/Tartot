extends Control
class_name Kartenblatt

signal chosen(card: Karte)

var card: Karte
var selected := false
var veiled := false
var death_mark := 0

func _init(p_card: Karte, p_veiled := false, p_death_mark := 0) -> void:
	card = p_card
	veiled = p_veiled
	death_mark = p_death_mark
	custom_minimum_size = Vector2(42, 62)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		chosen.emit(card)
	elif event is InputEventScreenTouch and event.pressed:
		chosen.emit(card)

func _draw() -> void:
	var fill := Thema.PAPER_DARK
	var border := Thema.INK
	if card != null:
		match card.shimmer:
			Konst.Shimmer.WHITE: fill = Color("#E8DEC5")
			Konst.Shimmer.INDIGO: fill = Color("#A8A8B1")
			Konst.Shimmer.GOLD: fill = Color("#7C6A3A")
			Konst.Shimmer.BLOOD: fill = Color("#532528")
			Konst.Shimmer.BLACK: fill = Color("#1B1716")
		match card.suit():
			Konst.Suit.SWORDS: border = Thema.RED
			Konst.Suit.WANDS: border = Thema.GOLD
			Konst.Suit.CUPS: border = Thema.INDIGO_LIGHT
			Konst.Suit.PENTACLES: border = Thema.INDIGO
			Konst.Suit.MAJOR: border = Thema.GOLD_LIGHT
	if veiled:
		fill = Thema.INDIGO
	if selected:
		border = Thema.PAPER
	draw_rect(Rect2(0, 0, size.x, size.y), fill)
	draw_rect(Rect2(0, 0, size.x, size.y), border, false, 2)
	for y in range(5, int(size.y) - 4, 8):
		draw_rect(Rect2(2, y, 2, 4), Thema.INK)
		draw_rect(Rect2(size.x - 4, y, 2, 4), Thema.INK)
	if veiled:
		draw_string(ThemeDB.fallback_font, Vector2(17, 32), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Thema.PAPER)
		return
	if card == null:
		return
	var dark := card.shimmer >= Konst.Shimmer.GOLD or card.is_major()
	var text_color := Thema.PAPER if dark else Thema.INK
	var head := _roman(card.display_number()) if card.is_major() else str(card.rank())
	draw_string(ThemeDB.fallback_font, Vector2(7, 12), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)
	_draw_suit(Vector2(size.x / 2.0, 29), card.suit(), text_color)
	if card.orientation == Konst.Orientation.REVERSED:
		draw_string(ThemeDB.fallback_font, Vector2(7, 52), "REV", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Thema.RED)
	if death_mark > 0:
		draw_rect(Rect2(6, 44, size.x - 12, 8), Thema.RED)
		draw_string(ThemeDB.fallback_font, Vector2(9, 50), "TOD %d" % death_mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Thema.PAPER)

func _draw_suit(p: Vector2, suit: int, color: Color) -> void:
	match suit:
		Konst.Suit.SWORDS:
			draw_line(p + Vector2(-6, -7), p + Vector2(6, 7), color, 2)
			draw_line(p + Vector2(6, -7), p + Vector2(-6, 7), color, 2)
		Konst.Suit.WANDS:
			draw_line(p + Vector2(0, -8), p + Vector2(0, 8), color, 2)
			draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Thema.GOLD, 2)
		Konst.Suit.CUPS:
			draw_arc(p + Vector2(0, -2), 7, 0, PI, 10, color, 2)
			draw_line(p + Vector2(0, 4), p + Vector2(0, 8), color, 2)
		Konst.Suit.PENTACLES:
			for i in 5:
				var a := -PI / 2.0 + i * TAU / 5.0
				var b := -PI / 2.0 + ((i * 2) % 5) * TAU / 5.0
				draw_line(p + Vector2(cos(a), sin(a)) * 7, p + Vector2(cos(b), sin(b)) * 7, color, 1)
		_:
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(p, p + Vector2(cos(a), sin(a)) * 8, Thema.GOLD, 1)

func _roman(value: int) -> String:
	var values := ["0","I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX","XXI"]
	return values[value] if value >= 0 and value < values.size() else str(value)
