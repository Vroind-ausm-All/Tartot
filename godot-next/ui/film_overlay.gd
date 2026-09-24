extends Control
class_name FilmOverlay

var frame := 0
var darkness := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer := Timer.new()
	timer.wait_time = 1.0 / 12.0
	timer.autostart = true
	timer.timeout.connect(func(): frame += 1; queue_redraw())
	add_child(timer)

func _process(_delta: float) -> void:
	if Spiel.run != null:
		var d := Spiel.run.darkness
		if d != darkness:
			darkness = d
			queue_redraw()

func _draw() -> void:
	var alpha := 0.05 + darkness * 0.0018
	var seed := frame * 1932 + darkness
	for i in range(24 + int(darkness / 3)):
		var x := float(posmod(seed * 17 + i * 41, maxi(1, int(size.x))))
		var y := float(posmod(seed * 29 + i * 67, maxi(1, int(size.y))))
		draw_rect(Rect2(x, y, 1, 1), Color(0.94, 0.89, 0.78, alpha))
	if darkness >= 20:
		var x := float(posmod(frame * 19 + 37, maxi(1, int(size.x))))
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.94, 0.89, 0.78, 0.12 + darkness * 0.001), 1)
	var vignette := clampf(0.05 + darkness * 0.004, 0.05, 0.48)
	var w := maxf(3.0, size.x * (0.03 + darkness * 0.0005))
	draw_rect(Rect2(0, 0, size.x, w), Color(Thema.INK, vignette))
	draw_rect(Rect2(0, size.y - w, size.x, w), Color(Thema.INK, vignette))
	draw_rect(Rect2(0, 0, w, size.y), Color(Thema.INK, vignette))
	draw_rect(Rect2(size.x - w, 0, w, size.y), Color(Thema.INK, vignette))
	if darkness >= 60:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(Thema.RED, (darkness - 55) * 0.0014), true)
