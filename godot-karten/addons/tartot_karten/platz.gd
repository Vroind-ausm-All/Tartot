class_name KartenPlatz
extends Node2D
## Eine Position der Legung: Vergangenheit, Gegenwart oder Zukunft.
## Zeichnet einen Filmrahmen; leuchtet auf, wenn eine gezogene Karte darueber schwebt.

const TINTE := Color("1A1412")
const SEPIA := Color("8F7A5A")
const GOLD := Color("E3A83B")
const BLUT := Color("B3262B")

@export var titel := "GEGENWART"
@export var wirkung := "×1 · Mult +0,15"
@export var groesse := Vector2(250, 372)

var karte: TarotKarte = null
var markiert := false:
	set(v):
		if v != markiert:
			markiert = v
			queue_redraw()
var gesperrt := false:
	set(v):
		gesperrt = v
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-groesse * 0.5, groesse)
	var farbe := GOLD if markiert else (BLUT if gesperrt else SEPIA)
	draw_rect(r, Color(0.14, 0.11, 0.09, 0.85))
	# gestrichelter Rahmen wie ein leeres Filmbild
	var schritt := 14.0
	for kante in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), r.end],
			[r.position, Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), r.end]]:
		var a: Vector2 = kante[0]
		var b: Vector2 = kante[1]
		var laenge := a.distance_to(b)
		var t := 0.0
		while t < laenge:
			draw_line(a.lerp(b, t / laenge), a.lerp(b, minf(t + schritt * 0.6, laenge) / laenge), farbe, 3.0)
			t += schritt
	var schrift: Font = load("res://addons/tartot_karten/schrift/Jersey10.ttf")
	draw_string(schrift, Vector2(r.position.x, r.position.y - 14), titel, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, farbe)
	draw_string(schrift, Vector2(r.position.x, r.end.y + 34), wirkung, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, SEPIA)
	if gesperrt:
		draw_string(schrift, Vector2(r.position.x, 10), "EINGESTÜRZT", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, BLUT)


func enthaelt(punkt: Vector2) -> bool:
	return Rect2(global_position - groesse * 0.6, groesse * 1.2).has_point(punkt)
