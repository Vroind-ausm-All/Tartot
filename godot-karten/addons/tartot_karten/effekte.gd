class_name BuehnenEffekte
extends Node2D
## Die Effekte der Buehne - Blitze, Strahlen, Wellen, Feuerringe, Saeulen,
## Hiebe, Ranken, Regen aus Wuerfeln, Karten oder Fruechten, Rauch.
##
## Alles wird gezeichnet, nichts ist ein Bild: Fuellung in der Farbe des
## Bosses, Kontur in Tinte, wie auf den Blaettern. Jede Wirkung ist ein
## kurzlebiger Knoten, der sich nach seiner Dauer selbst entfernt.
##
## Koordinaten sind die der Buehne (0,0 oben links, groesse unten rechts).
## Der Spieler sitzt "vor" der Buehne: was ihn treffen soll, fliegt nach
## unten aus dem Bild und loest einschlag aus.

signal einschlag(staerke: float)

const TINTE := Color("1A1412")
const PAPIER := Color("EFE3C8")

var groesse := Vector2(986, 748)


# ------------------------------------------------------------------ Grundbaustein
class Wirkung extends Node2D:
	var dauer := 1.0
	var alter := 0.0
	var zeichnen: Callable
	var schritt: Callable
	var additiv := false

	func _ready() -> void:
		if additiv:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = m

	func _process(delta: float) -> void:
		alter += delta
		if schritt.is_valid():
			schritt.call(self, alter / dauer, delta)
		queue_redraw()
		if alter >= dauer:
			queue_free()

	func _draw() -> void:
		if zeichnen.is_valid():
			zeichnen.call(self, clampf(alter / dauer, 0.0, 1.0))


func _wirkung(dauer: float, zeichnen: Callable, schritt := Callable(), additiv := false, z := 0) -> Wirkung:
	var w := Wirkung.new()
	w.dauer = dauer
	w.zeichnen = zeichnen
	w.schritt = schritt
	w.additiv = additiv
	w.z_index = z
	add_child(w)
	return w


static func _aus(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)


static func _kurve(von: float, bis: float, t: float) -> float:
	return clampf((t - von) / maxf(0.0001, bis - von), 0.0, 1.0)


func _treffer_spaeter(sekunden: float, staerke: float) -> void:
	get_tree().create_timer(sekunden).timeout.connect(func(): einschlag.emit(staerke))


# ------------------------------------------------------------------ Blitz
## Gezackter Blitz mit Verzweigungen, flackert dreimal.
func blitz(von: Vector2, nach: Vector2, farbe := Color("F4D27A"), treffer := true) -> void:
	var pfade: Array = [_zacken(von, nach, 9, 0.16)]
	for i in 2:
		var p: Array = pfade[0]
		var start: Vector2 = p[randi_range(2, p.size() - 3)]
		pfade.append(_zacken(start, start + (nach - von).rotated(randf_range(-0.7, 0.7)) * randf_range(0.25, 0.45), 5, 0.22))
	var zeichne1 := func(n: Node2D, t: float) -> void:
		var an := fmod(t * 7.0, 1.0) < 0.62 or t < 0.12
		if not an:
			return
		var a := 1.0 - _kurve(0.6, 1.0, t)
		for i in pfade.size():
			var p: PackedVector2Array = PackedVector2Array(pfade[i])
			var dick := 16.0 if i == 0 else 8.0
			n.draw_polyline(p, Color(TINTE, a), dick + 8.0, true)
			n.draw_polyline(p, Color(farbe, a), dick, true)
			n.draw_polyline(p, Color(1, 1, 0.95, a), dick * 0.35, true)
	_wirkung(0.45, zeichne1, Callable(), false, 6)
	var zeichne2 := func(n: Node2D, t: float) -> void:
		var a := (1.0 - t) * 0.5
		var p := PackedVector2Array(pfade[0])
		n.draw_polyline(p, Color(farbe, a * 0.5), 60.0, true)
		n.draw_polyline(p, Color(farbe, a), 28.0, true)
	_wirkung(0.45, zeichne2, Callable(), true, 5)
	blitzlicht(farbe, 0.45)
	if treffer:
		_treffer_spaeter(0.05, 0.9)


func _zacken(von: Vector2, nach: Vector2, glieder: int, streuung: float) -> Array:
	var p: Array = []
	var laenge := von.distance_to(nach)
	var quer := (nach - von).normalized().orthogonal()
	for i in glieder + 1:
		var t := float(i) / glieder
		var versatz := 0.0 if i == 0 or i == glieder else randf_range(-1, 1) * laenge * streuung
		p.append(von.lerp(nach, t) + quer * versatz)
	return p


# ------------------------------------------------------------------ Licht
## Blitzlicht ueber die ganze Buehne.
func blitzlicht(farbe: Color, staerke := 0.6, dauer := 0.35) -> void:
	var zeichne3 := func(n: Node2D, t: float) -> void:
		n.draw_rect(Rect2(Vector2.ZERO, groesse), Color(farbe, staerke * pow(1.0 - t, 2.0)))
	_wirkung(dauer, zeichne3, Callable(), true, 20)


## Die Buehne wird dunkel (Supernova, Tod). Gibt die Dauer zurueck.
func dunkel(dauer := 1.2, staerke := 0.85) -> void:
	var zeichne4 := func(n: Node2D, t: float) -> void:
		var a := _kurve(0.0, 0.25, t) * (1.0 - _kurve(0.8, 1.0, t)) * staerke
		n.draw_rect(Rect2(Vector2.ZERO, groesse), Color(0, 0, 0, a))
	_wirkung(dauer, zeichne4, Callable(), false, 15)


# ------------------------------------------------------------------ Strahlen
## Strahlen aus einem Punkt, die sich drehen und ausfahren (Sonne, Segen).
func strahlen(mitte: Vector2, anzahl := 14, farbe := Color("F4D27A"), dauer := 0.9, dreh := 0.6) -> void:
	var start := randf() * TAU
	var zeichne5 := func(n: Node2D, t: float) -> void:
		var weit := _aus(_kurve(0.0, 0.35, t)) * groesse.length() * 0.8
		var a := 1.0 - _kurve(0.55, 1.0, t)
		for i in anzahl:
			var w := start + float(i) / anzahl * TAU + t * dreh
			var breite := 0.07 + 0.03 * sin(i * 1.7)
			var p := PackedVector2Array([mitte, mitte + Vector2.from_angle(w - breite) * weit, mitte + Vector2.from_angle(w + breite) * weit])
			n.draw_colored_polygon(p, Color(farbe, 0.42 * a))
		n.draw_circle(mitte, 70.0 * (1.0 + t), Color(farbe, 0.5 * a))
	_wirkung(dauer, zeichne5, Callable(), true, 1)


# ------------------------------------------------------------------ Ringe
## Stosswelle: ein Ring mit Tintenkontur, der sich ausbreitet.
func ring(mitte: Vector2, farbe := Color("F4D27A"), radius := 520.0, dauer := 0.6, dicke := 22.0) -> void:
	var zeichne6 := func(n: Node2D, t: float) -> void:
		var r := _aus(t) * radius
		var a := 1.0 - t
		n.draw_arc(mitte, r, 0, TAU, 72, Color(TINTE, a), dicke + 8.0, true)
		n.draw_arc(mitte, r, 0, TAU, 72, Color(farbe, a), dicke, true)
		n.draw_arc(mitte, r, 0, TAU, 72, Color(1, 1, 1, a * 0.6), dicke * 0.3, true)
	_wirkung(dauer, zeichne6, Callable(), false, 4)


## Feuerringe: drei Ringe nacheinander, mit Glut dazwischen.
func feuerringe(mitte: Vector2, farbe := Color("E0543A")) -> void:
	for i in 3:
		get_tree().create_timer(i * 0.16).timeout.connect(func(): ring(mitte, farbe, 460.0 + i * 60.0, 0.7, 26.0 - i * 4.0))
	funken(mitte, 40, Color("F4D27A"), 520.0)
	_treffer_spaeter(0.45, 0.8)


# ------------------------------------------------------------------ Saeulen
## Lichtsaeulen, die vom Boden aufsteigen (Hierophant, Glaube).
func saeulen(anzahl := 4, farbe := Color("F4D27A")) -> void:
	var xs: Array = []
	for i in anzahl:
		xs.append(groesse.x * (0.15 + 0.7 * (float(i) + randf_range(-0.2, 0.2)) / maxf(1, anzahl - 1)))
	var zeichne7 := func(n: Node2D, t: float) -> void:
		for i in xs.size():
			var ti := _kurve(i * 0.08, i * 0.08 + 0.3, t)
			var h := _aus(ti) * groesse.y
			var a := 1.0 - _kurve(0.7, 1.0, t)
			var flackern := 0.85 + 0.15 * sin(t * 50.0 + i)
			var x: float = xs[i]
			n.draw_rect(Rect2(x - 46, groesse.y - h, 92, h), Color(farbe, 0.30 * a * flackern))
			n.draw_rect(Rect2(x - 22, groesse.y - h, 44, h), Color(farbe, 0.55 * a * flackern))
			n.draw_rect(Rect2(x - 7, groesse.y - h, 14, h), Color(1, 1, 0.92, 0.9 * a))
	_wirkung(1.1, zeichne7, Callable(), true, 3)
	_treffer_spaeter(0.55, 0.7)


# ------------------------------------------------------------------ Hiebe
## Ein Hieb als Sichel: Sense, Schwert, Peitsche, Radschwung.
func hieb(mitte: Vector2, radius: float, von_w: float, bis_w: float, farbe := PAPIER, dicke := 38.0, dauer := 0.42) -> void:
	var zeichne8 := func(n: Node2D, t: float) -> void:
		var vorne := _aus(_kurve(0.0, 0.45, t))
		var hinten := _aus(_kurve(0.25, 1.0, t))
		var w0 := lerpf(von_w, bis_w, hinten)
		var w1 := lerpf(von_w, bis_w, vorne)
		if w1 - w0 == 0.0:
			return
		var schritte := 28
		var aussen := PackedVector2Array()
		var innen := PackedVector2Array()
		for i in schritte + 1:
			var s := float(i) / schritte
			var w := lerpf(w0, w1, s)
			var d := dicke * sin(s * PI) * (0.4 + 0.6 * s)
			aussen.append(mitte + Vector2.from_angle(w) * (radius + d * 0.5))
			innen.append(mitte + Vector2.from_angle(w) * (radius - d * 0.5))
		innen.reverse()
		var form := aussen + innen
		n.draw_colored_polygon(form, Color(farbe, 0.92))
		n.draw_polyline(form + PackedVector2Array([form[0]]), TINTE, 5.0, true)
		n.draw_polyline(aussen, Color(1, 1, 1, 0.7), 3.0, true)
	_wirkung(dauer, zeichne8, Callable(), false, 7)
	var zeichne9 := func(n: Node2D, t: float) -> void:
		var w := lerpf(von_w, bis_w, _aus(t))
		n.draw_arc(mitte, radius, von_w, w, 32, Color(farbe, 0.35 * (1.0 - t)), dicke * 2.2, true)
	_wirkung(dauer * 0.8, zeichne9, Callable(), true, 6)
	_treffer_spaeter(dauer * 0.5, 0.75)


## Kette: eine Reihe Glieder, die nach vorn schnellt und zurueckgezogen wird.
func kette(von: Vector2, nach: Vector2, farbe := Color("8F7A5A")) -> void:
	var zeichne10 := func(n: Node2D, t: float) -> void:
		var weit := _aus(_kurve(0.0, 0.35, t)) * (1.0 - _aus(_kurve(0.6, 1.0, t)))
		var ende := von.lerp(nach, weit)
		var glieder := int(von.distance_to(ende) / 26.0)
		var richtung := (ende - von).normalized()
		for i in glieder:
			var p := von + richtung * (i * 26.0 + 13.0) + richtung.orthogonal() * sin(i * 0.8 + t * 20.0) * 8.0
			var quer := i % 2 == 0
			n.draw_set_transform(p, richtung.angle() + (0.0 if quer else PI / 2), Vector2(1.0, 0.55 if quer else 0.35))
			n.draw_arc(Vector2.ZERO, 16, 0, TAU, 20, TINTE, 11.0, true)
			n.draw_arc(Vector2.ZERO, 16, 0, TAU, 20, farbe, 6.0, true)
		n.draw_set_transform(Vector2.ZERO)
	_wirkung(0.8, zeichne10, Callable(), false, 7)
	_treffer_spaeter(0.3, 0.7)


# ------------------------------------------------------------------ Welle
## Eine Welle rollt ueber die Buehne nach vorn (Wasser, Schleier, Nebel).
func welle(farbe: Color, hoehe := 0.55, schaum := true, dauer := 1.1) -> void:
	var hell := farbe.lightened(0.35)
	var zeichne11 := func(n: Node2D, t: float) -> void:
		var steigen := _aus(_kurve(0.0, 0.4, t)) * (1.0 - _kurve(0.7, 1.0, t))
		var oben := groesse.y * (1.0 - hoehe * steigen)
		var p := PackedVector2Array()
		var kamm := PackedVector2Array()
		for i in 41:
			var x := groesse.x * i / 40.0
			var y := oben + sin(i * 0.55 + t * 14.0) * 26.0 + sin(i * 0.21 - t * 6.0) * 18.0
			p.append(Vector2(x, y))
			kamm.append(Vector2(x, y))
		p.append(Vector2(groesse.x, groesse.y + 10))
		p.append(Vector2(0, groesse.y + 10))
		n.draw_colored_polygon(p, Color(farbe, 0.92))
		n.draw_polyline(kamm, TINTE, 9.0, true)
		n.draw_polyline(kamm, hell, 4.0, true)
		if schaum:
			for i in 14:
				var x := fmod(i * 77.0 + t * 260.0, groesse.x)
				var y := oben + sin(x * 0.03 + t * 10.0) * 20.0 - 6.0
				n.draw_circle(Vector2(x, y), 9.0 + (i % 3) * 3.0, TINTE)
				n.draw_circle(Vector2(x, y), 6.0 + (i % 3) * 3.0, PAPIER)
	_wirkung(dauer, zeichne11, Callable(), false, 8)
	_treffer_spaeter(dauer * 0.45, 0.8)


## Schleier: eine durchscheinende, gewellte Bahn mit Sternen.
func schleier(farbe := Color("3B4A8C")) -> void:
	var zeichne12 := func(n: Node2D, t: float) -> void:
		var x0 := lerpf(-groesse.x * 0.6, groesse.x * 1.1, _aus(t))
		var a := sin(t * PI)
		var p := PackedVector2Array()
		for i in 25:
			var y := groesse.y * i / 24.0
			p.append(Vector2(x0 + sin(y * 0.012 + t * 9.0) * 60.0, y))
		for i in range(24, -1, -1):
			var y := groesse.y * i / 24.0
			p.append(Vector2(x0 - 420.0 + sin(y * 0.015 - t * 7.0) * 50.0, y))
		n.draw_colored_polygon(p, Color(farbe, 0.45 * a))
		for i in 18:
			var s := Vector2(x0 - 380.0 + fmod(i * 61.0, 400.0), fmod(i * 97.0 + t * 120.0, groesse.y))
			_stern(n, s, 9.0 + (i % 3) * 4.0, Color("F4D27A", a))
	_wirkung(1.3, zeichne12, Callable(), false, 8)
	_treffer_spaeter(0.6, 0.6)


# ------------------------------------------------------------------ Ranken
## Ranken wachsen vom Boden nach vorn, mit Dornen und Blaettern.
func ranken(farbe := Color("2E6B3E"), bluete := Color("BB323A")) -> void:
	var wege: Array = []
	for i in 4:
		var start := Vector2(groesse.x * (0.05 + 0.3 * i), groesse.y + 20)
		var ziel := Vector2(groesse.x * randf_range(0.3, 0.7), groesse.y * randf_range(0.25, 0.5))
		var k1 := start + Vector2(randf_range(-250, 250), -groesse.y * 0.5)
		wege.append([start, k1, ziel])
	var zeichne13 := func(n: Node2D, t: float) -> void:
		var wachsen := _aus(_kurve(0.0, 0.55, t))
		var a := 1.0 - _kurve(0.8, 1.0, t)
		for w in wege:
			var p := PackedVector2Array()
			var schritte := int(30 * wachsen) + 2
			for i in schritte:
				var s := float(i) / 30.0
				p.append(_bezier(w[0], w[1], w[2], s))
			n.draw_polyline(p, Color(TINTE, a), 24.0, true)
			n.draw_polyline(p, Color(farbe, a), 15.0, true)
			for i in range(3, p.size() - 1, 4):
				var r := (p[i + 1] - p[i]).normalized().orthogonal() * (1 if i % 8 == 3 else -1)
				var dorn := PackedVector2Array([p[i] + r * 6.0, p[i] + r * 22.0 + (p[i + 1] - p[i]) * 0.5, p[i + 1] + r * 6.0])
				n.draw_colored_polygon(dorn, Color(TINTE, a))
			if p.size() > 2:
				var kopf := p[p.size() - 1]
				n.draw_circle(kopf, 20.0 * wachsen, Color(TINTE, a))
				n.draw_circle(kopf, 15.0 * wachsen, Color(bluete, a))
	_wirkung(1.3, zeichne13, Callable(), false, 7)
	_treffer_spaeter(0.6, 0.7)


static func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


# ------------------------------------------------------------------ Regen
## Dinge regnen auf die Buehne oder fliegen dem Spieler entgegen:
## "steine", "wuerfel", "karten", "fruechte", "muenzen", "sterne", "blaetter",
## "splitter", "tropfen".
func regen(art: String, anzahl := 14, farbe := PAPIER, nach_vorn := false) -> void:
	var teile: Array = []
	for i in anzahl:
		var start := Vector2(randf_range(0.05, 0.95) * groesse.x, randf_range(-260.0, -40.0))
		var ziel := Vector2(start.x + randf_range(-120, 120), groesse.y * randf_range(0.75, 1.15))
		if nach_vorn:
			start = Vector2(groesse.x * 0.5 + randf_range(-120, 120), groesse.y * 0.42 + randf_range(-60, 60))
			ziel = Vector2(randf_range(-0.2, 1.2) * groesse.x, groesse.y * 1.3)
		teile.append({"von": start, "nach": ziel, "verzug": randf_range(0.0, 0.35), "dreh": randf_range(-8, 8),
			"groesse": randf_range(0.8, 1.3), "saat": randi() % 6})
	var zeichne14 := func(n: Node2D, t: float) -> void:
		for teil in teile:
			var s := _kurve(teil["verzug"], teil["verzug"] + 0.6, t)
			if s <= 0.0:
				continue
			var p: Vector2 = (teil["von"] as Vector2).lerp(teil["nach"], s * s if not nach_vorn else _aus(s))
			var g: float = teil["groesse"] * (1.0 + (1.6 * s if nach_vorn else 0.0))
			var a := 1.0 - _kurve(0.85, 1.0, s)
			n.draw_set_transform(p, teil["dreh"] * s, Vector2(g, g))
			_ding(n, art, teil["saat"], farbe, a)
		n.draw_set_transform(Vector2.ZERO)
	_wirkung(1.25, zeichne14, Callable(), false, 9)
	_treffer_spaeter(0.65, 0.6)


func _ding(n: Node2D, art: String, saat: int, farbe: Color, a: float) -> void:
	var tinte := Color(TINTE, a)
	match art:
		"steine":
			var p := PackedVector2Array()
			for i in 7:
				p.append(Vector2.from_angle(i / 7.0 * TAU) * (20.0 + float((saat * 7 + i * 13) % 9)))
			n.draw_colored_polygon(p, Color(Color("8F7A5A").darkened(0.1 * saat), a))
			n.draw_polyline(p + PackedVector2Array([p[0]]), tinte, 4.0, true)
		"wuerfel":
			n.draw_rect(Rect2(-22, -22, 44, 44), Color(PAPIER, a))
			n.draw_rect(Rect2(-22, -22, 44, 44), tinte, false, 4.0)
			var augen: Array = [[Vector2.ZERO], [Vector2(-10, -10), Vector2(10, 10)], [Vector2(-10, -10), Vector2.ZERO, Vector2(10, 10)],
				[Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10)]][saat % 4]
			for au in augen:
				n.draw_circle(au, 4.5, Color(Color("B3262B") if saat % 4 == 0 else TINTE, a))
		"karten":
			n.draw_rect(Rect2(-20, -30, 40, 60), Color(PAPIER, a))
			n.draw_rect(Rect2(-20, -30, 40, 60), tinte, false, 3.5)
			n.draw_circle(Vector2.ZERO, 8.0, Color(Color("B3262B") if saat % 2 == 0 else TINTE, a))
		"fruechte":
			n.draw_circle(Vector2.ZERO, 22.0, tinte)
			n.draw_circle(Vector2.ZERO, 18.0, Color(Color("BB323A"), a))
			n.draw_circle(Vector2(-6, -7), 5.0, Color(1, 1, 1, 0.5 * a))
			n.draw_line(Vector2(0, -18), Vector2(4, -30), tinte, 4.0)
			n.draw_colored_polygon(PackedVector2Array([Vector2(4, -28), Vector2(18, -34), Vector2(10, -22)]), Color(Color("2E6B3E"), a))
		"muenzen":
			n.draw_circle(Vector2.ZERO, 20.0, tinte)
			n.draw_circle(Vector2.ZERO, 16.0, Color(Color("D4A23A"), a))
			n.draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color(Color("7A5C2E"), a), 2.5)
		"sterne":
			_stern(n, Vector2.ZERO, 22.0, Color(Color("F4D27A"), a))
		"blaetter":
			var p := PackedVector2Array([Vector2(0, -18), Vector2(12, 0), Vector2(0, 18), Vector2(-12, 0)])
			n.draw_colored_polygon(p, Color(farbe, a))
			n.draw_polyline(p + PackedVector2Array([p[0]]), tinte, 3.0)
		"splitter":
			var p := PackedVector2Array([Vector2(0, -24), Vector2(10, 8), Vector2(-8, 16)])
			n.draw_colored_polygon(p, Color(0.8, 0.9, 1.0, 0.75 * a))
			n.draw_polyline(p + PackedVector2Array([p[0]]), Color(1, 1, 1, a), 2.5)
		"tropfen":
			var p := PackedVector2Array([Vector2(0, -22), Vector2(12, 4), Vector2(0, 16), Vector2(-12, 4)])
			n.draw_colored_polygon(p, Color(farbe, a))
			n.draw_polyline(p + PackedVector2Array([p[0]]), tinte, 3.5)
		_:
			n.draw_circle(Vector2.ZERO, 16.0, Color(farbe, a))


static func _stern(n: Node2D, mitte: Vector2, r: float, farbe: Color) -> void:
	var p := PackedVector2Array()
	for i in 10:
		p.append(mitte + Vector2.from_angle(i / 10.0 * TAU - PI / 2) * (r if i % 2 == 0 else r * 0.45))
	n.draw_colored_polygon(p, farbe)
	n.draw_polyline(p + PackedVector2Array([p[0]]), Color(TINTE, farbe.a), 3.0, true)


# ------------------------------------------------------------------ Kugeln
## Leuchtende Kugeln kreisen um die Figur und schiessen dann nach vorn.
func kugeln(mitte: Vector2, anzahl := 6, farbe := Color("C8D8F4"), radius := 220.0) -> void:
	var zeichne15 := func(n: Node2D, t: float) -> void:
		for i in anzahl:
			var w := float(i) / anzahl * TAU + t * 7.0
			var kreis := mitte + Vector2(cos(w) * radius, sin(w) * radius * 0.45)
			var flug := _kurve(0.55 + i * 0.04, 0.9 + i * 0.04, t)
			var p := kreis.lerp(Vector2(groesse.x * 0.5 + (i - anzahl / 2.0) * 90.0, groesse.y * 1.25), flug * flug)
			var g := 20.0 + 30.0 * flug
			n.draw_circle(p, g * 1.9, Color(farbe, 0.25))
			n.draw_circle(p, g, Color(TINTE, 0.9))
			n.draw_circle(p, g - 5.0, farbe)
			n.draw_circle(p - Vector2(g, g) * 0.25, g * 0.3, Color(1, 1, 1, 0.8))
	_wirkung(1.3, zeichne15, Callable(), false, 9)
	_treffer_spaeter(0.95, 0.7)


# ------------------------------------------------------------------ Tempo
## Tempo-Linien zum Bildrand: Ansturm, Bruellen.
func tempo(mitte: Vector2, dauer := 0.6) -> void:
	var linien: Array = []
	for i in 34:
		linien.append([randf() * TAU, randf_range(0.35, 0.6)])
	var zeichne16 := func(n: Node2D, t: float) -> void:
		var a := sin(t * PI)
		for l in linien:
			var v := Vector2.from_angle(l[0])
			var innen: float = groesse.length() * (l[1] - t * 0.25)
			n.draw_line(mitte + v * innen, mitte + v * groesse.length(), Color(TINTE, 0.55 * a), 7.0)
			n.draw_line(mitte + v * innen, mitte + v * groesse.length(), Color(PAPIER, 0.35 * a), 3.0)
	_wirkung(dauer, zeichne16, Callable(), false, 2)


# ------------------------------------------------------------------ Rauch und Funken
## Zeichentrick-Rauch: Wolken aus Kreisen mit Tintenkontur.
func rauch(mitte: Vector2, anzahl := 7, groesse_ := 1.0, farbe := PAPIER) -> void:
	var wolken: Array = []
	for i in anzahl:
		wolken.append([Vector2.from_angle(randf() * TAU) * randf_range(60, 200) * groesse_, randf_range(30, 60) * groesse_])
	var zeichne17 := func(n: Node2D, t: float) -> void:
		var s := _aus(t)
		var a := 1.0 - _kurve(0.5, 1.0, t)
		for w in wolken:
			var p: Vector2 = mitte + w[0] * s + Vector2(0, -40 * t)
			var r: float = w[1] * (0.4 + 0.8 * s)
			n.draw_circle(p, r + 5.0, Color(TINTE, a))
		for w in wolken:
			var p: Vector2 = mitte + w[0] * s + Vector2(0, -40 * t)
			var r: float = w[1] * (0.4 + 0.8 * s)
			n.draw_circle(p, r, Color(farbe, a))
			n.draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, 0.35 * a))
	_wirkung(0.9, zeichne17, Callable(), false, 10)


func funken(mitte: Vector2, anzahl := 24, farbe := Color("F4D27A"), weite := 320.0) -> void:
	var teile: Array = []
	for i in anzahl:
		teile.append([Vector2.from_angle(randf() * TAU) * randf_range(0.4, 1.0) * weite, randf_range(3, 8)])
	var zeichne18 := func(n: Node2D, t: float) -> void:
		for f in teile:
			var p: Vector2 = mitte + f[0] * _aus(t) + Vector2(0, 260 * t * t)
			n.draw_circle(p, f[1] * (1.0 - t), Color(farbe, 1.0 - t))
	_wirkung(0.7, zeichne18, Callable(), true, 11)


## Comic-Sterne um einen Treffer.
func sterne(mitte: Vector2, anzahl := 5) -> void:
	var zeichne19 := func(n: Node2D, t: float) -> void:
		for i in anzahl:
			var w := float(i) / anzahl * TAU + t * 3.0
			var p := mitte + Vector2(cos(w) * 90.0, sin(w) * 30.0) * (0.6 + 0.6 * _aus(t))
			_stern(n, p, 16.0 * (1.0 - t * 0.5), Color(Color("F4D27A"), 1.0 - _kurve(0.7, 1.0, t)))
	_wirkung(0.8, zeichne19, Callable(), false, 12)
