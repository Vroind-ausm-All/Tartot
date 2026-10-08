class_name GreifArm
extends Node2D
## Ein Gummischlauch-Arm mit weissem Handschuh: der Boss greift aus seiner
## Buehne ueber den Rahmen hinweg nach dem Tisch - nach einem Platz (Turm),
## einer Karte (Tod) oder mit einem Tuch ueber die Hand (Mond).
##
## Der Arm ist eine Bezierkurve von der Schulter zur Hand. Beim Ausholen
## zieht sich die Hand zurueck, beim Greifen schiesst sie ueber das Ziel
## hinaus und federt zurueck, der Schlauch wellt sich dabei
## (Fleischer-Zeichentrick). Die Hand oeffnet und schliesst sich (zu).
##
## Die Schulter folgt der Figur (schulter_quelle). Was die Hand haelt
## (getragen), haengt an ihr und wird mitgezogen.

const TINTE := Color("1A1412")
const PAPIER := Color("EFE3C8")
const SEPIA := Color("C9B48E")

## Liefert die Schulter (global) - meist BossBuehne.schulter().
var schulter_quelle: Callable
var schulter := Vector2.ZERO
var hand := Vector2.ZERO
## 0 offene Hand ... 1 Faust.
var zu := 0.0
## Wellen im Schlauch (klingt von selbst ab).
var welle := 0.0
var aermel := Color("2A221E")
## Groesse von Hand und Arm.
var mass := 1.0
## Mond: ein Schleiertuch, das an der Hand haengt (0 aus ... 1 ganz).
var tuch := 0.0
var tuch_farbe := Color(0.23, 0.29, 0.55)
## Karte (oder anderer Knoten), die die Hand haelt.
var getragen: Node2D = null

var _zeit := 0.0
var _spur: Array[Vector2] = []


func _init() -> void:
	visible = false
	z_index = 330


func _process(delta: float) -> void:
	_zeit += delta
	if schulter_quelle.is_valid():
		schulter = schulter_quelle.call()
	welle = maxf(0.0, welle - delta * 0.9)
	if getragen != null and is_instance_valid(getragen):
		if getragen is TarotKarte:
			(getragen as TarotKarte).ziel_position = hand + Vector2(0, 40) * mass
		else:
			getragen.global_position = hand
	# Das Tuch zieht hinter der Hand her: die Spur merkt sich ihre Wege.
	_spur.push_front(hand)
	if _spur.size() > 18:
		_spur.pop_back()
	if visible:
		queue_redraw()


# ------------------------------------------------------------------ Bewegung
## Ausholen, dann zum Ziel schiessen (mit Ueberschwingen).
func ausstrecken(ziel: Vector2, dauer := 0.42) -> void:
	if schulter_quelle.is_valid():
		schulter = schulter_quelle.call()
	hand = schulter
	zu = 0.0
	_spur.clear()
	visible = true
	var richtung := (ziel - schulter).normalized()
	var t := create_tween()
	t.tween_property(self, "hand", schulter - richtung * 50.0 * mass + Vector2(0, -30) * mass, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): welle = 1.0; KartenKlang.spielen("ausholen", 1.3, -6.0))
	t.tween_property(self, "hand", ziel, dauer).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished


## Hand schliessen (Faust) oder oeffnen.
func greifen(schliessen := true, dauer := 0.12) -> void:
	var t := create_tween()
	t.tween_property(self, "zu", 1.0 if schliessen else 0.0, dauer).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished


## Die Hand an einen Punkt fuehren (waehrend der Arm draussen ist).
func fuehren(ziel: Vector2, dauer: float, uebergang := Tween.TRANS_SINE, art := Tween.EASE_IN_OUT) -> void:
	var t := create_tween()
	t.tween_property(self, "hand", ziel, dauer).set_trans(uebergang).set_ease(art)
	await t.finished


## Zurueck in die Buehne; danach ist der Arm weg.
func zurueckziehen(dauer := 0.38) -> void:
	welle = maxf(welle, 0.6)
	var t := create_tween()
	t.tween_method(func(w): hand = hand.lerp(schulter, w), 0.0, 1.0, dauer).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false
	getragen = null
	tuch = 0.0


# ------------------------------------------------------------------ Zeichnen
func _draw() -> void:
	var punkte := _arm_punkte()
	if tuch > 0.0:
		_tuch_zeichnen()
	# Schlauch: Kontur, Fuellung, Glanzstreif.
	var breite := 30.0 * mass
	draw_polyline(punkte, TINTE, breite + 12.0 * mass, true)
	draw_polyline(punkte, aermel, breite, true)
	var glanz := PackedVector2Array()
	for i in range(2, punkte.size() - 2):
		var n := (punkte[i + 1] - punkte[i - 1]).orthogonal().normalized()
		glanz.append(punkte[i] + n * breite * 0.22)
	draw_polyline(glanz, Color(1, 1, 1, 0.13), 5.0 * mass, true)
	draw_circle(punkte[0], (breite + 12.0 * mass) * 0.5, TINTE)
	draw_circle(punkte[0], breite * 0.5, aermel)
	var richtung := (punkte[-1] - punkte[-3]).angle()
	_handschuh(hand, richtung)


func _arm_punkte() -> PackedVector2Array:
	var p0 := schulter
	var p3 := hand
	var d := maxf(1.0, p0.distance_to(p3))
	var seite := signf(p3.x - p0.x) if absf(p3.x - p0.x) > 1.0 else 1.0
	var p1 := p0 + Vector2(seite * d * 0.28, -d * 0.12)
	var p2 := p3 + Vector2(-seite * d * 0.06, -d * 0.38)
	var pts := PackedVector2Array()
	var n := 30
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		var p := u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
		var tangente := (3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)).normalized()
		var quer := tangente.orthogonal()
		p += quer * sin(t * PI * 3.0 - _zeit * 11.0) * sin(t * PI) * welle * 26.0 * mass
		pts.append(p)
	return pts


## Weisser Vier-Finger-Handschuh mit Stulpe; zeigt in Richtung `winkel`.
func _handschuh(p: Vector2, winkel: float) -> void:
	draw_set_transform(p, winkel, Vector2(mass, mass))
	var finger: Array = []
	for i in 4:
		var a := lerpf(-0.6, 0.6, i / 3.0) * lerpf(1.0, 0.35, zu)
		var laenge := lerpf(36.0, 12.0, zu) - absf(i - 1.5) * 4.0
		var ansatz := Vector2(cos(a), sin(a)) * 20.0
		finger.append([ansatz, ansatz + Vector2(cos(a), sin(a)) * laenge])
	var daumen_a := lerpf(-1.35, -0.8, zu)
	var daumen := [Vector2(cos(daumen_a), sin(daumen_a)) * 18.0, Vector2(cos(daumen_a), sin(daumen_a)) * lerpf(44.0, 30.0, zu)]
	# erst alle Konturen, dann alle Flaechen - so verschmelzen die Formen
	draw_rect(Rect2(-56, -27, 26, 54), TINTE)
	for f in finger + [daumen]:
		draw_line(f[0], f[1], TINTE, 25.0)
		draw_circle(f[1], 12.5, TINTE)
	draw_circle(Vector2.ZERO, 34.0, TINTE)
	draw_rect(Rect2(-52, -23, 18, 46), PAPIER)
	for f in finger + [daumen]:
		draw_line(f[0], f[1], PAPIER, 15.0)
		draw_circle(f[1], 7.5, PAPIER)
	draw_circle(Vector2.ZERO, 28.0, PAPIER)
	# Naehte auf dem Handruecken, Rillen der Stulpe
	for y in [-9.0, 0.0, 9.0]:
		draw_line(Vector2(-16, y), Vector2(4, y * 1.2), TINTE, 3.0, true)
	for x in [-47.0, -40.0]:
		draw_line(Vector2(x, -21), Vector2(x, 21), SEPIA, 3.0)
	if zu > 0.5:
		# Faust: Knoechel als Bogen
		draw_arc(Vector2(16, 0), 18.0, -1.1, 1.1, 12, TINTE, 3.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mond: ein Tuch, das an der Hand haengt und ihrer Spur nachweht.
func _tuch_zeichnen() -> void:
	if _spur.size() < 2:
		return
	var oben := PackedVector2Array()
	var unten := PackedVector2Array()
	var anzahl := _spur.size()
	for i in anzahl:
		var p: Vector2 = _spur[i]
		var t := float(i) / (anzahl - 1)
		oben.append(p + Vector2(0, 10))
		var fall := 260.0 * tuch * (0.55 + 0.45 * t)
		unten.append(p + Vector2(sin(_zeit * 4.0 + i * 0.7) * 18.0, fall + sin(_zeit * 3.0 + i) * 14.0))
	var flaeche := PackedVector2Array(oben)
	for i in range(anzahl - 1, -1, -1):
		flaeche.append(unten[i])
	if flaeche.size() >= 3 and Geometry2D.triangulate_polygon(flaeche).size() > 0:
		draw_colored_polygon(flaeche, Color(tuch_farbe, 0.62 * tuch))
	draw_polyline(unten, Color(TINTE, 0.8 * tuch), 5.0, true)
	draw_polyline(oben, Color(TINTE, 0.8 * tuch), 5.0, true)
	# Sterne auf dem Tuch
	for i in range(1, anzahl - 1, 3):
		var s: Vector2 = oben[i].lerp(unten[i], 0.5)
		draw_circle(s, 5.0, Color(0.95, 0.85, 0.55, 0.8 * tuch))
