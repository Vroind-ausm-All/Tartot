extends Control
class_name TurmBoss

signal animation_finished(name: String)

const INK := Color("#1A1412")
const PAPER := Color("#EFE3C8")
const SEPIA := Color("#C9B48E")
const DARK := Color("#4E4032")
const GOLD := Color("#E3A83B")
const RED := Color("#B3262B")

var state := "idle"
var frame := 0
var phase_two := false
var flash := 0.0
var shake := 0.0
var squash := Vector2.ONE
var offset_px := Vector2.ZERO
var _timer: Timer
var _sequence_token := 0

func _init() -> void:
	custom_minimum_size = Vector2(320, 390)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0 / 12.0
	_timer.autostart = true
	_timer.timeout.connect(_tick)
	add_child(_timer)
	queue_redraw()

func _tick() -> void:
	frame = (frame + 1) % 4
	if state == "idle":
		offset_px.y = -4.0 if frame in [1, 2] else 0.0
		squash = Vector2(1.0 + (0.012 if frame == 2 else 0.0), 1.0 - (0.012 if frame == 2 else 0.0))
	if flash > 0.0:
		flash = maxf(0.0, flash - 0.18)
	if shake > 0.0:
		shake = maxf(0.0, shake - 0.16)
	queue_redraw()

func set_phase_two(enabled: bool) -> void:
	if enabled and not phase_two:
		phase_two = true
		play_phase_two()
	else:
		phase_two = enabled
	queue_redraw()

func play_intro() -> void:
	_sequence_token += 1
	var token := _sequence_token
	state = "intro"
	scale = Vector2(0.72, 1.28)
	modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(self, "scale", Vector2(1.08, 0.94), 0.24)
	await t.finished
	if token != _sequence_token:
		return
	var t2 := create_tween()
	t2.tween_property(self, "scale", Vector2.ONE, 0.12)
	await t2.finished
	if token == _sequence_token:
		state = "idle"
		animation_finished.emit("intro")

func play_attack() -> void:
	_sequence_token += 1
	var token := _sequence_token
	state = "attack"
	var start := position
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.88, 1.14), 0.10)
	t.tween_property(self, "position", start + Vector2(0, 26), 0.07)
	t.tween_property(self, "scale", Vector2(1.18, 0.80), 0.05)
	flash = 0.55
	shake = 0.8
	queue_redraw()
	t.tween_property(self, "position", start, 0.12)
	t.tween_property(self, "scale", Vector2.ONE, 0.09)
	await t.finished
	if token == _sequence_token:
		state = "idle"
		animation_finished.emit("attack")

func play_hit(strong := false) -> void:
	_sequence_token += 1
	var token := _sequence_token
	state = "hit"
	flash = 1.0
	shake = 1.0 if strong else 0.65
	var start := position
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.16, 0.78) if strong else Vector2(1.08, 0.90), 0.045)
	t.tween_property(self, "position", start + Vector2(-12 if frame % 2 == 0 else 12, 0), 0.045)
	t.tween_property(self, "position", start + Vector2(8, 0), 0.045)
	t.tween_property(self, "position", start, 0.055)
	t.tween_property(self, "scale", Vector2.ONE, 0.07)
	await t.finished
	if token == _sequence_token:
		state = "idle"
		animation_finished.emit("hit")

func play_collapse() -> void:
	_sequence_token += 1
	var token := _sequence_token
	state = "collapse"
	flash = 1.0
	shake = 1.0
	var start := rotation
	var t := create_tween()
	t.tween_property(self, "rotation", start - 0.045, 0.05)
	t.tween_property(self, "rotation", start + 0.055, 0.05)
	t.tween_property(self, "rotation", start - 0.025, 0.05)
	t.tween_property(self, "rotation", start, 0.08)
	await t.finished
	if token == _sequence_token:
		state = "idle"
		animation_finished.emit("collapse")

func play_phase_two() -> void:
	_sequence_token += 1
	var token := _sequence_token
	state = "phase2"
	phase_two = true
	flash = 1.0
	shake = 1.0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.20, 0.78), 0.08)
	t.tween_property(self, "scale", Vector2(0.92, 1.16), 0.08)
	t.tween_property(self, "scale", Vector2(1.10, 0.88), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.14)
	await t.finished
	if token == _sequence_token:
		state = "idle"
		animation_finished.emit("phase2")

func play_death() -> void:
	_sequence_token += 1
	var token := _sequence_token
	state = "death"
	flash = 1.0
	shake = 1.0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.28, 0.66), 0.09)
	t.tween_property(self, "rotation", -0.08, 0.06)
	t.tween_property(self, "rotation", 0.11, 0.06)
	t.tween_property(self, "scale", Vector2(1.04, 0.42), 0.10)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 0.0, 0.38)
	t.tween_property(self, "position:y", position.y + 80.0, 0.38)
	await t.finished
	if token == _sequence_token:
		animation_finished.emit("death")

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.54) + offset_px
	if shake > 0.0:
		center += Vector2(sin(Time.get_ticks_msec() * 0.061), cos(Time.get_ticks_msec() * 0.079)) * (9.0 * shake)
	draw_set_transform(center, 0.0, squash)

	# Ruecklicht / Blitz.
	if state in ["collapse", "phase2"] or (phase_two and frame == 2):
		var bolt := PackedVector2Array([
			Vector2(54, -156), Vector2(20, -92), Vector2(42, -92),
			Vector2(8, -28), Vector2(18, -84), Vector2(-6, -84)
		])
		draw_polyline(bolt, GOLD, 8.0)

	# Turmkoerper.
	var body := Rect2(-54, -118, 108, 210)
	draw_rect(body, SEPIA)
	draw_rect(body, INK, false, 7.0)
	for x in [-54, -18, 18]:
		draw_rect(Rect2(x, -144, 24, 34), SEPIA)
		draw_rect(Rect2(x, -144, 24, 34), INK, false, 6.0)

	# Mauerfugen: nur zwei Tonwerte.
	for y in range(-82, 78, 32):
		draw_line(Vector2(-48, y), Vector2(48, y), DARK, 4.0)
	for y in range(-66, 64, 64):
		draw_line(Vector2(0, y - 14), Vector2(0, y + 14), DARK, 4.0)

	# Fenster/Augen.
	draw_ellipse(Vector2(-23, -48), Vector2(16, 26), INK)
	draw_ellipse(Vector2(23, -48), Vector2(16, 26), INK)
	var look := Vector2(3.0 if frame in [1, 2] else -2.0, 1.0)
	draw_circle(Vector2(-23, -48) + look, 6.0, PAPER)
	draw_circle(Vector2(23, -48) + look, 6.0, PAPER)

	# Viel zu breites Grinsen.
	draw_rect(Rect2(-34, -7, 68, 34), INK)
	for x in range(-29, 29, 12):
		draw_rect(Rect2(x, -3, 8, 11), PAPER)
		draw_rect(Rect2(x + 5, 13, 8, 10), PAPER)

	# Rubberhose-Arme.
	var arm_y := -2.0 + (4.0 if frame in [1, 2] else 0.0)
	draw_polyline(PackedVector2Array([Vector2(-51, arm_y), Vector2(-84, -4), Vector2(-107, 24)]), INK, 9.0)
	draw_polyline(PackedVector2Array([Vector2(51, arm_y), Vector2(84, -4), Vector2(107, 24)]), INK, 9.0)
	_draw_glove(Vector2(-112, 27), -1.0)
	_draw_glove(Vector2(112, 27), 1.0)

	# Phase 2: Risse und rotes Innenlicht.
	if phase_two:
		var crack := RED if frame % 2 == 0 else GOLD
		draw_polyline(PackedVector2Array([Vector2(-5, -113), Vector2(-17, -78), Vector2(4, -52), Vector2(-10, -13), Vector2(10, 18), Vector2(-2, 72)]), crack, 5.0)
		draw_line(Vector2(-17, -78), Vector2(-39, -60), crack, 4.0)
		draw_line(Vector2(4, -52), Vector2(31, -39), crack, 4.0)

	# Kleine Truemmer bei Impact.
	if state in ["hit", "collapse", "phase2", "death"]:
		for i in range(7):
			var a := float(i) * 0.91 + float(frame)
			var p := Vector2(cos(a), sin(a)) * (72.0 + i * 5.0)
			draw_rect(Rect2(p.x - 4, p.y - 4, 8, 8), SEPIA)

	if flash > 0.0:
		draw_rect(Rect2(-145, -170, 290, 320), Color(1, 0.93, 0.75, flash * 0.18))

func _draw_glove(p: Vector2, direction: float) -> void:
	draw_circle(p, 17.0, PAPER)
	draw_circle(p, 17.0, INK, false, 5.0)
	for n in [-1.0, 0.0, 1.0]:
		draw_line(p + Vector2(direction * 3, -2), p + Vector2(direction * (23 + 3 * n), -18 + 8 * n), INK, 5.0)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := float(i) / 24.0 * TAU
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
