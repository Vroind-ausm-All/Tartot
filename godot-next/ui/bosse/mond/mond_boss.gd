extends BossDarstellung
class_name MondBoss
## XVIII · Der Mond - eine grinsende Sichel im Stil der fruehen
## Zeichentrickfilme. Prozedurale Darstellung nach
## assets/sprites/bosses/mond/ASSET_SPEC.md, bis das Aseprite-Blatt
## existiert (boss_mond_frames.tres ersetzt dann die Zeichnung).
##
## Eigene Motive je Angriff (AnimationCues): attack1 = Aussaugen (Drain),
## attack2 = Hieb, attack3 = Fluch aus Sternen (Hex), summon = Wolken (Guard).
## "veil" laesst Nebel ueber die Buehne ziehen - die Karten verdeckt der Kern.

const INK := Color("#1A1412")
const PAPER := Color("#EFE3C8")
const SEPIA := Color("#C9B48E")
const INDIGO := Color("#3B4A8C")
const GOLD := Color("#E3A83B")
const RED := Color("#B3262B")

## Was gerade gezeigt wird: "", "fluch", "saugen", "wolke".
var motiv := ""
## Nebel ueber der Figur (0..1).
var nebel := 0.0
var _sichel := PackedVector2Array()

func sprite_pfad() -> String:
	return "res://assets/sprites/bosses/mond/boss_mond_frames.tres"

func zoom() -> float:
	return minf(size.x / 300.0, size.y / 330.0)

func _init(p_definition: EnemyDefinition = null) -> void:
	super._init(p_definition)
	_sichel = _baue_sichel()

## Sichel aus zwei Kreisen: aussen R = 100 um (0, 0), innen r = 80 um (45, 0).
static func _baue_sichel() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var aussen := deg_to_rad(51.34)
	var innen := deg_to_rad(77.37)
	for i in 33:
		var phi := -aussen - (TAU - 2.0 * aussen) * i / 32.0
		pts.append(Vector2(cos(phi), sin(phi)) * 100.0)
	for i in 33:
		var psi := innen + (TAU - 2.0 * innen) * i / 32.0
		pts.append(Vector2(45, 0) + Vector2(cos(psi), sin(psi)) * 80.0)
	return pts

func spiele(cue: String) -> void:
	match cue:
		"attack1":
			motiv = "saugen"
			await play_attack("attack1")
		"attack3":
			motiv = "fluch"
			await play_attack("attack3")
		"summon":
			motiv = "wolke"
			await play_bob("summon")
		"veil":
			await _nebel()
		_:
			motiv = ""
			await super.spiele(cue)
	motiv = ""

func _nebel() -> void:
	var token := _start("veil")
	var t := _tween()
	t.tween_property(self, "nebel", 1.0, 0.25)
	t.tween_interval(0.15)
	t.tween_property(self, "nebel", 0.0, 0.35)
	await t.finished
	_ende(token, "veil")

func _zeichne() -> void:
	var koerper := RED if phase_two else PAPER
	var schatten := Color("#7A1A1E") if phase_two else SEPIA

	# Gehaengte Sterne an Faeden (der Mond haengt im Buehnenhimmel).
	for s in [Vector2(70, -110), Vector2(105, -60), Vector2(88, 20)]:
		draw_line(Vector2(s.x, -170), s, SEPIA, 2.0)
		_stern(s + Vector2(0, (2.0 if frame in [1, 2] else 0.0)), 9.0, GOLD)
	draw_line(Vector2(-10, -170), Vector2(-10, -98), SEPIA, 3.0)

	# Gummiarme mit Handschuhen, von der Rueckseite der Sichel.
	var schwung := 6.0 if frame in [1, 2] else 0.0
	draw_polyline(PackedVector2Array([Vector2(-78, 40), Vector2(-112, 64 + schwung), Vector2(-128, 96)]), INK, 9.0)
	draw_polyline(PackedVector2Array([Vector2(-20, 95), Vector2(10, 128), Vector2(40, 136 - schwung)]), INK, 9.0)
	_handschuh(Vector2(-130, 100), -1.0)
	_handschuh(Vector2(44, 136 - schwung), 1.0)

	# Die Sichel.
	draw_colored_polygon(_sichel, koerper)
	# Schattenseite: ein zweiter, schmalerer Streifen am Aussenrand.
	var rand := PackedVector2Array()
	for i in 20:
		var phi := deg_to_rad(120.0 + 120.0 * i / 19.0)
		rand.append(Vector2(cos(phi), sin(phi)) * 92.0)
	draw_polyline(rand, schatten, 8.0)
	draw_polyline(_sichel + PackedVector2Array([_sichel[0]]), INK, 7.0)

	# Schlafmuetze, schief.
	draw_colored_polygon(PackedVector2Array([Vector2(-40, -88), Vector2(18, -78), Vector2(-60, -150)]), INDIGO)
	draw_polyline(PackedVector2Array([Vector2(-40, -88), Vector2(18, -78), Vector2(-60, -150), Vector2(-40, -88)]), INK, 5.0)
	draw_circle(Vector2(-62, -152), 9.0, PAPER)
	draw_circle(Vector2(-62, -152), 9.0, INK, false, 4.0)

	# Ein grosses Auge, Pupille schaut zur Seite.
	draw_circle(Vector2(-62, -28), 19.0, INK)
	var blick := Vector2(5.0 if frame in [1, 2] else -1.0, 1.0)
	draw_circle(Vector2(-58, -30) + blick, 8.0, GOLD if phase_two else PAPER)
	# Braue
	draw_line(Vector2(-84, -56), Vector2(-46, -52 - (6.0 if phase_two else 0.0)), INK, 6.0)

	# Nase ragt in die Hoehlung.
	draw_colored_polygon(PackedVector2Array([Vector2(-36, -6), Vector2(-6, 6), Vector2(-36, 16)]), koerper)
	draw_polyline(PackedVector2Array([Vector2(-36, -6), Vector2(-6, 6), Vector2(-36, 16)]), INK, 5.0)

	# Viel zu breites Grinsen entlang der Innenkante.
	draw_colored_polygon(PackedVector2Array([Vector2(-86, 28), Vector2(-34, 30), Vector2(-28, 54), Vector2(-74, 62)]), INK)
	for x in range(-80, -36, 11):
		draw_rect(Rect2(x, 33, 7, 8), PAPER)
		draw_rect(Rect2(x + 4, 48, 7, 7), PAPER)

	# Phase 2: der Blutmond tropft.
	if phase_two:
		for d in [Vector2(-70, 66), Vector2(-48, 62), Vector2(-90, 50)]:
			var laenge := 10.0 + 6.0 * float((frame + int(d.x)) % 3)
			draw_line(d, d + Vector2(0, laenge), RED, 5.0)
			draw_circle(d + Vector2(0, laenge + 2.0), 4.0, RED)

	# Motive der Angriffe.
	match motiv:
		"fluch":
			for i in 7:
				var a := float(i) / 7.0 * TAU + frame * 0.5
				_stern(Vector2(10, 10) + Vector2(cos(a), sin(a)) * (60.0 + 8.0 * frame), 7.0, GOLD if i % 2 == 0 else RED)
		"saugen":
			draw_polyline(PackedVector2Array([Vector2(-10, 40), Vector2(40, 60), Vector2(90, 110), Vector2(130, 150)]), RED, 6.0)
			for i in 4:
				draw_circle(Vector2(130, 150).lerp(Vector2(-10, 40), (float(i) + frame * 0.25) / 4.0), 4.0, RED)
		"wolke":
			for c in [Vector2(-40, 100), Vector2(0, 108), Vector2(40, 98)]:
				draw_circle(c, 26.0, Color(INDIGO, 0.85))
				draw_circle(c, 26.0, INK, false, 3.0)

	# Truemmer und Sternstaub bei Treffern.
	if state in ["hit", "phase2", "death"]:
		for i in 6:
			var a := float(i) * 1.05 + float(frame)
			_stern(Vector2(cos(a), sin(a)) * (90.0 + i * 4.0), 5.0, PAPER)

	# Nebel (Verhuellen).
	if nebel > 0.0:
		for i in 4:
			var y := -60.0 + i * 45.0
			var pts := PackedVector2Array()
			for k in 13:
				var x := -150.0 + k * 25.0
				pts.append(Vector2(x + nebel * 40.0 - 20.0, y + sin(k * 0.9 + i) * 8.0))
			draw_polyline(pts, Color(INDIGO, 0.55 * nebel), 26.0)

func _stern(p: Vector2, r: float, farbe: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, farbe)

func _handschuh(p: Vector2, richtung: float) -> void:
	draw_circle(p, 15.0, PAPER)
	draw_circle(p, 15.0, INK, false, 5.0)
	for n in [-1.0, 0.0, 1.0]:
		draw_line(p + Vector2(richtung * 3, -2), p + Vector2(richtung * (20 + 3 * n), -16 + 7 * n), INK, 4.0)
