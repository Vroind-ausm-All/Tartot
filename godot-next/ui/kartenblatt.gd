extends Control
class_name Kartenblatt
## Eine Karte als kleines Blatt: Farbe am Rand, Schimmer als Grund,
## Zahl oben, Farbsymbol in der Mitte. Verdeckt (Mond) zeigt sie ein "?",
## gezeichnet (Tod) einen roten Balken mit den verbleibenden Zuegen.

signal chosen(card: CardInstance)

var card: CardInstance
var selected := false
var veiled := false
var death_mark := 0

func _init(p_card: CardInstance, p_veiled := false, p_death_mark := 0) -> void:
	card = p_card
	veiled = p_veiled
	death_mark = p_death_mark
	custom_minimum_size = Vector2(42, 62)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		chosen.emit(card)
		accept_event()

func _draw() -> void:
	var fill := Thema.PAPER_DARK
	var border := Thema.INK
	var S := Enums.Shimmer
	if card != null:
		match card.shimmer:
			S.WHITE: fill = Color("#E8DEC5")
			S.INDIGO: fill = Color("#A8A8B1")
			S.GOLD: fill = Color("#7C6A3A")
			S.BLOOD: fill = Color("#532528")
			S.BLACK: fill = Color("#1B1716")
		match card.definition.suit:
			Enums.Suit.SWORDS: border = Thema.RED
			Enums.Suit.WANDS: border = Thema.GOLD
			Enums.Suit.CUPS: border = Thema.INDIGO_LIGHT
			Enums.Suit.PENTACLES: border = Thema.INDIGO
			_: border = Thema.GOLD_LIGHT
	if veiled:
		fill = Thema.INDIGO
	if selected:
		border = Thema.PAPER
	draw_rect(Rect2(0, 0, size.x, size.y), fill)
	draw_rect(Rect2(0, 0, size.x, size.y), border, false, 2)
	# Perforation wie bei Filmstreifen.
	for y in range(5, int(size.y) - 4, 8):
		draw_rect(Rect2(2, y, 2, 4), Thema.INK)
		draw_rect(Rect2(size.x - 4, y, 2, 4), Thema.INK)
	if veiled:
		draw_string(ThemeDB.fallback_font, Vector2(size.x / 2.0 - 4, size.y / 2.0 + 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Thema.PAPER)
		return
	if card == null:
		return
	var def := card.definition
	var dark := card.shimmer >= S.GOLD or def.is_major()
	var text_color := Thema.PAPER if dark else Thema.INK
	var head := Num.roman(def.display_number()) if def.is_major() else str(def.rank)
	if def.is_major() and def.display_number() == 0:
		head = "0"
	draw_string(ThemeDB.fallback_font, Vector2(7, 12), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)
	if card.level > 1:
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 16, 12), "+%d" % (card.level - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Thema.GOLD_LIGHT)
	_draw_suit(Vector2(size.x / 2.0, size.y * 0.47), def.suit, text_color)
	if card.is_reversed():
		draw_string(ThemeDB.fallback_font, Vector2(7, size.y - 10), "REV", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Thema.RED)
	if card.edition != Enums.CardEdition.NONE:
		draw_rect(Rect2(size.x - 9, size.y - 13, 4, 4), Color(CardEditions.rarity_color(def.rarity())))
	if death_mark > 0:
		draw_rect(Rect2(6, size.y - 18, size.x - 12, 8), Thema.RED)
		draw_string(ThemeDB.fallback_font, Vector2(9, size.y - 12), "TOD %d" % death_mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Thema.PAPER)

func _draw_suit(p: Vector2, suit: int, color: Color) -> void:
	match suit:
		Enums.Suit.SWORDS:
			draw_line(p + Vector2(-6, -7), p + Vector2(6, 7), color, 2)
			draw_line(p + Vector2(6, -7), p + Vector2(-6, 7), color, 2)
		Enums.Suit.WANDS:
			draw_line(p + Vector2(0, -8), p + Vector2(0, 8), color, 2)
			draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Thema.GOLD, 2)
		Enums.Suit.CUPS:
			draw_arc(p + Vector2(0, -2), 7, 0, PI, 10, color, 2)
			draw_line(p + Vector2(0, 4), p + Vector2(0, 8), color, 2)
		Enums.Suit.PENTACLES:
			for i in 5:
				var a := -PI / 2.0 + i * TAU / 5.0
				var b := -PI / 2.0 + ((i * 2) % 5) * TAU / 5.0
				draw_line(p + Vector2(cos(a), sin(a)) * 7, p + Vector2(cos(b), sin(b)) * 7, color, 1)
		_:
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(p, p + Vector2(cos(a), sin(a)) * 8, Thema.GOLD, 1)
