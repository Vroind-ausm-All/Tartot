extends Control
class_name Buehne
## Die Bühne hinter dem Gegner: Jahrmarktzelt in zwei Tonwerten, Rampe,
## Projektorlicht. In Phase 2 wird das Licht haerter, bei Blitz hell.

var phase_two := false
var blitz := 0.0
var _zeit := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	_zeit += delta
	blitz = maxf(0.0, blitz - delta * 3.0)
	queue_redraw()

func blitzen() -> void:
	blitz = 1.0

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Thema.INK)
	# Zeltbahnen
	var bahnen := 9
	for i in bahnen:
		var x0 := w * i / bahnen
		var farbe := Thema.SEPIA3 if i % 2 == 0 else Thema.INK
		if phase_two and i % 2 == 0:
			farbe = Color(Thema.RED, 0.55)
		var spitze := Vector2(w * 0.5, -h * 0.15)
		draw_colored_polygon(PackedVector2Array([spitze, Vector2(x0, h * 0.8), Vector2(x0 + w / bahnen, h * 0.8)]), farbe)
	# Projektorkegel
	var flacker := 0.06 + 0.03 * sin(_zeit * 23.0) + blitz * 0.4
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 8, 0), Vector2(w * 0.5 + 8, 0),
		Vector2(w * 0.85, h * 0.8), Vector2(w * 0.15, h * 0.8)]), Color(Thema.PAPER, flacker))
	# Rampe
	draw_rect(Rect2(0, h * 0.8, w, h * 0.2), Thema.SEPIA3)
	draw_line(Vector2(0, h * 0.8), Vector2(w, h * 0.8), Thema.INK, 2.0)
	for x in range(0, int(w), 18):
		draw_circle(Vector2(x + 9, h * 0.9), 2.0, Thema.GOLD if not phase_two else Thema.RED)
	if blitz > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(Thema.PAPER, blitz * 0.35))
