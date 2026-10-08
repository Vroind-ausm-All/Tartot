extends BossDarstellung
class_name TurmBoss
## XVI · Der Turm - Referenzboss der Darstellung (portiert aus godot/,
## Zeichnung unveraendert, Bewegung ueber BossDarstellung).
##
## Prozedurale Ersatzdarstellung, bis das Aseprite-Blatt existiert
## (assets/sprites/bosses/turm/ASSET_SPEC.md). Liegt dort
## boss_turm_frames.tres (SpriteFrames, Animationen = Zustandsnamen),
## ersetzt es nur die Zeichnung.

const INK := Color("#1A1412")
const PAPER := Color("#EFE3C8")
const SEPIA := Color("#C9B48E")
const DARK := Color("#4E4032")
const GOLD := Color("#E3A83B")
const RED := Color("#B3262B")

func sprite_pfad() -> String:
	return "res://assets/sprites/bosses/turm/boss_turm_frames.tres"

## Die Zeichnung ist fuer etwa 300 x 330 Pixel entworfen.
func zoom() -> float:
	return minf(size.x / 300.0, size.y / 330.0)

func _zeichne() -> void:
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
	_ellipse(Vector2(-23, -48), Vector2(16, 26), INK)
	_ellipse(Vector2(23, -48), Vector2(16, 26), INK)
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
	_glove(Vector2(-112, 27), -1.0)
	_glove(Vector2(112, 27), 1.0)

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

func _glove(p: Vector2, direction: float) -> void:
	draw_circle(p, 17.0, PAPER)
	draw_circle(p, 17.0, INK, false, 5.0)
	for n in [-1.0, 0.0, 1.0]:
		draw_line(p + Vector2(direction * 3, -2), p + Vector2(direction * (23 + 3 * n), -18 + 8 * n), INK, 5.0)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var a := float(i) / 24.0 * TAU
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
