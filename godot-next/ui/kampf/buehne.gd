extends Control
class_name Buehne
## Die Bühne hinter dem Gegner: Jahrmarktzelt in zwei Tonwerten, Rampe,
## Projektorlicht. In Phase 2 wird das Licht haerter, bei Blitz hell.

var phase_two := false
var blitz := 0.0
## Buehnenbild aus EnemyDefinition.stage ("Jahrmarkt der Omen", "Spiegelsee" ...).
var stil := ""
## Nebelschleier (Mond), 0..1.
var schleier := 0.0
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

func nebel(tempo := 1.0) -> void:
	var t := create_tween()
	t.set_speed_scale(tempo)
	t.tween_property(self, "schleier", 1.0, 0.25)
	t.tween_property(self, "schleier", 0.35, 0.5)
	await t.finished

func _draw() -> void:
	if stil == "Spiegelsee":
		_spiegelsee()
	else:
		_jahrmarkt()
	if schleier > 0.0:
		for i in 5:
			var y := size.y * (0.15 + 0.17 * i)
			var pts := PackedVector2Array()
			for k in 12:
				pts.append(Vector2(-10.0 + k * size.x / 10.0, y + sin(k * 0.8 + i + _zeit * 1.5) * 4.0))
			draw_polyline(pts, Color(Thema.INDIGO_LIGHT, 0.22 * schleier), 14.0)
	if blitz > 0.0:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(Thema.PAPER, blitz * 0.35))

## Nachthimmel mit Sternen, der See spiegelt (Der Mond).
func _spiegelsee() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Thema.DEEP)
	draw_rect(Rect2(0, 0, w, h * 0.72), Color("#1C2340") if not phase_two else Color("#3A1418"))
	for i in 18:
		var p := Vector2(fposmod(i * 47.3, w), fposmod(i * 23.7, h * 0.6))
		var r := 1.0 + float(i % 3 == 0) + (0.6 if int(_zeit * 3.0 + i) % 4 == 0 else 0.0)
		draw_circle(p, r, Thema.PAPER)
	# Wasser mit Spiegelstreifen
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color("#101629") if not phase_two else Color("#24080A"))
	for i in 6:
		var y := h * (0.76 + 0.04 * i)
		var x0 := w * 0.5 - 30.0 + sin(_zeit * 2.0 + i) * 6.0
		draw_line(Vector2(x0, y), Vector2(x0 + 60.0 - i * 6.0, y), Color(Thema.RED if phase_two else Thema.PAPER, 0.35), 2.0)
	draw_line(Vector2(0, h * 0.72), Vector2(w, h * 0.72), Thema.INK, 2.0)

## Jahrmarktzelt (Der Turm und alle anderen).
func _jahrmarkt() -> void:
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
