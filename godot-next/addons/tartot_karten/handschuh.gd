class_name ZeigeHandschuh
extends Node2D
## Ein weisser Vier-Finger-Handschuh als Zeiger fuer Vorfuehrungen - so sieht
## man in Aufnahmen, wohin "getippt" wird.

const TINTE := Color("1A1412")
const PAPIER := Color("EFE3C8")
const SEPIA := Color("C9B48E")

var gedrueckt := false:
	set(v):
		gedrueckt = v
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(0.86, 0.86) if v else Vector2.ONE, 0.08)


func _draw() -> void:
	# Zeigefinger nach oben links, Spitze bei (0, 0)
	var teile := [
		[Vector2(14, 58), Vector2(30, 26)],   # Hand
		[Vector2(4, 18), Vector2(9, 22)],     # Zeigefinger
		[Vector2(26, 34), Vector2(10, 12)],   # Mittelfinger (gebogen)
		[Vector2(34, 44), Vector2(10, 11)],   # Ringfinger
		[Vector2(-6, 52), Vector2(9, 13)],    # Daumen
	]
	for t in teile:
		draw_circle(t[0], t[1].x + 3.0, TINTE)
	draw_rect(Rect2(-2, 0, 14, 44), TINTE)
	for t in teile:
		draw_circle(t[0], t[1].x, PAPIER)
	draw_rect(Rect2(1, 2, 8, 42), PAPIER)
	draw_circle(Vector2(5, 3), 5.0, PAPIER)
	draw_rect(Rect2(2, 72, 26, 12), TINTE)
	draw_rect(Rect2(4, 74, 22, 8), SEPIA)
