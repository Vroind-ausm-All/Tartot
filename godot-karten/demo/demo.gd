extends Node2D
## Ein echter Kampf am Kartentisch: Hand, Legung, Vorschau, Wertung,
## Gegner, Sieg und naechster Kampf kommen aus dem C#-Regelkern
## (Autoload "Kern", kern/TartotKern.cs). Hier wird nichts gerechnet.
##
## Spielen: Karten antippen oder auf Vergangenheit, Gegenwart, Zukunft
## ziehen, dann SCHICKSAL AUSFUEHREN. Braucht Godot mit .NET.
## Aufnehmen: godot --path godot-karten --write-movie out.png --fixed-fps 30 -- --autoplay
## Dann spielt ein Handschuh mit den Vorschlaegen des Autopiloten.
##
## Vorfuehrdeck: die erste Hand bekommt je eine Edition (glaesern,
## brennend, schimmernd, leuchtend), damit man alle vier sieht.

const SCHRIFT := "res://addons/tartot_karten/schrift/"
const GEGNER := "res://demo/gegner/"
const STAPEL := Vector2(1180, 1560)
const ABLAGE := Vector2(-260, 1100)
const ABSICHTEN := {
	"Attack": "ANGRIFF", "Guard": "ABWEHR", "Hex": "FLUCH", "Drain": "AUSSAUGEN",
	"Frenzy": "RASEREI", "Verborgen": "???",
}
const VORFUEHR_EDITIONEN := ["Glass", "Burning", "Shimmering", "Glowing"]

var _kern: Node
var _kampf := {}
var _karten := {}          # Instanz-Id -> TarotKarte
var _anim := {}
var _gegner_sprite := ""

var _welt: Node2D
var _tisch: KartenTisch
var _kaskade: WertungsKaskade
var _info: KartenInfo
var _gegner: AnimatedSprite2D
var _lp_fuellung: ColorRect
var _lp_text: Label
var _kopf: Label
var _titel: Label
var _absicht: Label
var _spieler: Label
var _hinweis: Label
var _knopf: Button
var _handschuh: ZeigeHandschuh
var _schwebe: Node2D
var _wackeln := 0.0
var _beschaeftigt := false
var _vorfuehrung := false


func _ready() -> void:
	randomize()
	_vorfuehrung = OS.get_cmdline_user_args().has("--autoplay")
	_anim = JSON.parse_string(FileAccess.get_file_as_string(GEGNER + "anim.json"))
	_bauen()
	_kern = get_node_or_null("/root/Kern")
	if _kern == null or not _kern.has_method("NeuerRun"):
		_titel.text = "OHNE KERN"
		_absicht.text = "Dieser Tisch braucht Godot mit .NET (C#-Regelkern)."
		return
	_neuer_run(21 if _vorfuehrung else randi())
	if _vorfuehrung:
		_vorfuehren()


func _neuer_run(saat: int) -> void:
	_kern.NeuerRun(saat)
	# Vorfuehrdeck: jede Edition einmal in der ersten Hand.
	var hand: Array = _kern.Kampf()["hand"]
	for i in mini(hand.size(), VORFUEHR_EDITIONEN.size()):
		_kern.EditionGeben(hand[i]["instanz"], VORFUEHR_EDITIONEN[i])
	_abgleichen()


# ------------------------------------------------------------------ Aufbau
func _bauen() -> void:
	_welt = Node2D.new()
	add_child(_welt)

	var grund := ColorRect.new()
	grund.size = Vector2(1080, 1920)
	grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float vign = smoothstep(0.95, 0.3, length((uv - 0.5) * vec2(1.0, 0.8)));
	vec2 zelle = floor(FRAGCOORD.xy / 3.0) + floor(TIME * 12.0);
	float korn = fract(sin(dot(zelle, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = vec3(0.14, 0.11, 0.09) * (0.5 + 0.7 * vign) + (korn - 0.5) * 0.03;
	float px = uv.x * 1080.0;
	float py = uv.y * 1920.0;
	if (px < 34.0 || px > 1046.0) {
		c = vec3(0.07, 0.055, 0.045);
		float ly = mod(py, 48.0);
		if (ly > 12.0 && ly < 36.0 && ((px > 8.0 && px < 26.0) || (px > 1054.0 && px < 1072.0)))
			c = vec3(0.30, 0.25, 0.19);
	}
	COLOR = vec4(c, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	grund.material = mat
	_welt.add_child(grund)

	_kopf = _label("", "Jersey10.ttf", 38, Color("C9B48E"), Vector2(0, 26), 1080)
	_welt.add_child(_kopf)
	_titel = _label("", "AbrilFatface.ttf", 60, Color("EFE3C8"), Vector2(0, 62), 1080)
	_welt.add_child(_titel)

	_gegner = AnimatedSprite2D.new()
	_gegner.position = Vector2(540, 330)
	_gegner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gegner.animation_finished.connect(func():
		if _gegner.animation != "death":
			_gegner.play("idle"))
	_welt.add_child(_gegner)

	var lp_grund := ColorRect.new()
	lp_grund.color = Color("1A1412")
	lp_grund.position = Vector2(150, 574)
	lp_grund.size = Vector2(780, 38)
	_welt.add_child(lp_grund)
	_lp_fuellung = ColorRect.new()
	_lp_fuellung.color = Color("B3262B")
	_lp_fuellung.position = Vector2(4, 4)
	_lp_fuellung.size = Vector2(772, 30)
	lp_grund.add_child(_lp_fuellung)
	_lp_text = _label("", "AlfaSlabOne.ttf", 26, Color("EFE3C8"), Vector2(0, 2), 780)
	lp_grund.add_child(_lp_text)
	_absicht = _label("", "Jersey10.ttf", 34, Color("E0543A"), Vector2(150, 620), 390)
	_absicht.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_welt.add_child(_absicht)
	_spieler = _label("", "Jersey10.ttf", 34, Color("C9B48E"), Vector2(540, 620), 390)
	_spieler.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_welt.add_child(_spieler)

	_tisch = KartenTisch.new()
	_tisch.hand_breite = 760.0
	_tisch.max_abstand = 150.0
	_welt.add_child(_tisch)
	var titel := ["VERGANGENHEIT", "GEGENWART", "ZUKUNFT"]
	var wirkung := ["Wirkung ×0,9", "Mult +0,15", "×1,5 · nach dem Gegner"]
	for i in 3:
		var platz := KartenPlatz.new()
		platz.titel = titel[i]
		platz.wirkung = wirkung[i]
		platz.position = Vector2(200 + 340 * i, 912)
		_tisch.add_child(platz)
		_tisch.plaetze.append(platz)
	_tisch.legung_geaendert.connect(_legung_an_kern)

	_kaskade = WertungsKaskade.new()
	_kaskade.position = Vector2(60, 1162)
	_kaskade.size = Vector2(620, 230)
	_kaskade.z_index = 250
	_welt.add_child(_kaskade)
	_kaskade.wackeln.connect(func(s): _wackeln = maxf(_wackeln, s))

	_hinweis = _label("", "Jersey10.ttf", 30, Color("E3A83B"), Vector2(40, 1392), 1000)
	_welt.add_child(_hinweis)

	_knopf = Button.new()
	_knopf.text = "SCHICKSAL\nAUSFÜHREN"
	_knopf.position = Vector2(716, 1190)
	_knopf.size = Vector2(304, 150)
	_knopf.z_index = 250
	_knopf.add_theme_font_override("font", load(SCHRIFT + "AlfaSlabOne.ttf"))
	_knopf.add_theme_font_size_override("font_size", 34)
	for zustand in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("7E1B1F") if zustand in ["pressed", "disabled"] else Color("B3262B")
		s.border_color = Color("1A1412")
		s.set_border_width_all(5)
		s.set_corner_radius_all(16)
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 6)
		_knopf.add_theme_stylebox_override(zustand, s)
	_knopf.pressed.connect(func():
		KartenKlang.spielen("knopf")
		_ausfuehren())
	_welt.add_child(_knopf)

	_schwebe = Node2D.new()
	_schwebe.z_index = 400
	_welt.add_child(_schwebe)
	_kaskade.schwebe_ebene_setzen(_schwebe)

	add_child(KartenKlang.new())

	var oben := CanvasLayer.new()
	oben.layer = 10
	add_child(oben)
	_info = KartenInfo.new()
	oben.add_child(_info)
	_tisch.schwebt_ueber.connect(func(k): _info.zeigen(k))
	_handschuh = ZeigeHandschuh.new()
	_handschuh.visible = false
	oben.add_child(_handschuh)


func _label(text: String, schrift: String, groesse: int, farbe: Color, pos: Vector2, breite: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(breite, groesse * 1.3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", load(SCHRIFT + schrift))
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.add_theme_color_override("font_outline_color", Color("1A1412"))
	l.add_theme_constant_override("outline_size", 6)
	return l


## Sprite-Streifen des Gegners aus demo/gegner (dieselben wie in Unity).
func _gegner_laden(sprite: String) -> void:
	if sprite == _gegner_sprite:
		return
	_gegner_sprite = sprite
	var eintrag: Dictionary = _anim.get(sprite, {})
	var bilder := SpriteFrames.new()
	bilder.remove_animation("default")
	var groesse := int(eintrag.get("size", 120))
	for zustand in eintrag.get("states", {}):
		var streifen: Texture2D = load(GEGNER + "%s_%s.png" % [sprite, zustand])
		if streifen == null:
			continue
		bilder.add_animation(zustand)
		bilder.set_animation_speed(zustand, float(eintrag.get("fps", 12)))
		bilder.set_animation_loop(zustand, zustand == "idle")
		for i in int(eintrag["states"][zustand]):
			var ausschnitt := AtlasTexture.new()
			ausschnitt.atlas = streifen
			ausschnitt.region = Rect2(i * groesse, 0, groesse, groesse)
			bilder.add_frame(zustand, ausschnitt)
	_gegner.sprite_frames = bilder
	var s := 600.0 / groesse
	_gegner.scale = Vector2(s, s)
	if bilder.has_animation("idle"):
		_gegner.play("idle")


func _gegner_spielen(zustand: String) -> void:
	if _gegner.sprite_frames and _gegner.sprite_frames.has_animation(zustand):
		_gegner.play(zustand)
	elif zustand.begins_with("attack") and _gegner.sprite_frames and _gegner.sprite_frames.has_animation("attack"):
		_gegner.play("attack")


# ------------------------------------------------------------------ Abgleich mit dem Kern
## Zeigt den Zustand des Kerns: Gegner, Leben, Absicht, neue Handkarten.
func _abgleichen() -> void:
	_kampf = _kern.Kampf()
	var g: Dictionary = _kampf["gegner"]
	var sp: Dictionary = _kampf["spieler"]
	_kopf.text = "AKT %s · KAMPF %d · ZUG %d" % [_roemisch(int(_kampf["akt"])), int(_kampf["kampf"]), int(_kampf["zug"])]
	_titel.text = str(g["name"]).to_upper()
	_gegner_laden(str(g["sprite"]))
	_lp_zeigen(int(g["lp"]), int(g["max_lp"]))
	var absicht: String = ABSICHTEN.get(str(g["absicht"]), str(g["absicht"]))
	_absicht.text = "ABSICHT: %s%s" % [absicht, (" %d" % int(g["absicht_wert"])) if int(g["absicht_wert"]) > 0 else ""]
	if int(g["haltung"]) > 0:
		_absicht.text += "  ·  HALTUNG %d" % int(g["haltung"])
	_spieler.text = "DU %d/%d LP%s" % [int(sp["lp"]), int(sp["max_lp"]), ("  ·  SCHILD %d" % int(sp["schild"])) if int(sp["schild"]) > 0 else ""]
	for i in 3:
		_tisch.plaetze[i].gesperrt = i == int(_kampf["gesperrt"])

	var neu := 0
	for d in _kampf["hand"]:
		var instanz: String = d["instanz"]
		if _karten.has(instanz):
			continue
		var karte := TarotKarte.erzeugen(d["id"], d["edition"])
		karte.instanz = instanz
		_karten[instanz] = karte
		_tisch.austeilen(karte, STAPEL, neu * 0.09)
		neu += 1
	_legung_an_kern()


func _lp_zeigen(lp: int, max_lp: int) -> void:
	var t := create_tween()
	t.tween_property(_lp_fuellung, "size:x", 772.0 * clampf(float(lp) / maxf(1.0, max_lp), 0.0, 1.0), 0.5).set_ease(Tween.EASE_OUT)
	_lp_text.text = "%d / %d" % [lp, max_lp]


## Die Legung auf dem Tisch in den Kern schreiben und die Vorschau holen.
func _legung_an_kern() -> void:
	if _kern == null:
		return
	_kern.Abraeumen()
	for i in _tisch.plaetze.size():
		var karte: TarotKarte = _tisch.plaetze[i].karte
		if karte != null:
			_kern.Legen(karte.instanz, i)
	var vorschau: Dictionary = _kern.Vorschau()
	_kaskade.vorschau(vorschau)
	var hinweise: Array = vorschau.get("hinweise", [])
	_hinweis.text = str(hinweise[0]) if hinweise.size() > 0 else ""
	if vorschau.get("toedlich", false) and _tisch.legung().size() > 0:
		_hinweis.text = "TÖDLICH – dieser Treffer beendet den Kampf."


func _roemisch(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


# ------------------------------------------------------------------ Zug
func _ausfuehren() -> void:
	var legung := _tisch.legung()
	if _beschaeftigt or legung.is_empty() or _kern == null:
		return
	_beschaeftigt = true
	_knopf.disabled = true
	_hinweis.text = ""
	_legung_an_kern()
	var gegner_vorher: Dictionary = _kampf["gegner"]
	var ergebnis: Dictionary = _kern.Ausfuehren()
	if ergebnis.is_empty():
		_beschaeftigt = false
		_knopf.disabled = false
		return

	var karten := {}
	for k in legung.values():
		karten[k.instanz] = k
	await _kaskade.abspielen(ergebnis["schritte"], karten, int(gegner_vorher["lp"]),
		{"schicksal": ergebnis["schicksal"], "toedlich": ergebnis["sieg"]})

	# Was der Gegner abbekommt (nach Haltung) und was er zurueckgibt.
	for bild in ergebnis["animationen"]:
		_gegner_spielen(bild)
		if bild == "hit":
			var an := int(ergebnis["angekommen"])
			_schweben_text("−%d" % an if an > 0 else "GEBLOCKT", _gegner.global_position + Vector2(150, -140), Color("E0543A"))
			if an < int(ergebnis["schicksal"]) and not ergebnis["sieg"]:
				_schweben_text("HALTUNG DECKELT", _gegner.global_position + Vector2(-150, 60), Color("C9B48E"))
			if ergebnis["haltung_gebrochen"]:
				_schweben_text("HALTUNG BRICHT", _gegner.global_position + Vector2(0, 60), Color("E3A83B"))
		elif bild == "phase2":
			_schweben_text("DAS SIEGEL BRICHT", _gegner.global_position, Color("E3A83B"))
		elif bild.begins_with("attack") or bild == "summon" or bild == "supernova":
			KartenKlang.spielen("treffer", 0.7)
			_wackeln = maxf(_wackeln, 10.0)
			if int(ergebnis["lp_verlust"]) > 0:
				_schweben_text("−%d LP" % int(ergebnis["lp_verlust"]), Vector2(800, 660), Color("E0543A"))
		await _warte(0.55)

	# Gespielte Karten gehen ab: auf die Ablage - oder sie zerspringen.
	for k in legung.values():
		_tisch.entfernen(k)
		_karten.erase(k.instanz)
		if k.instanz in ergebnis["zersprungen"]:
			_schweben_text("ZERSPRUNGEN", k.global_position, Color("C9D6E3"))
			KartenKlang.spielen("glas")
			k.aufloesen(0.7, Color("EFE3C8"))
		else:
			k.ziel_position = ABLAGE + Vector2(0, randf() * 200)
			k.ziel_rotation = -0.9
			get_tree().create_timer(1.2).timeout.connect(k.queue_free)
	await _warte(0.5)
	_kaskade.zuruecksetzen()

	if ergebnis["sieg"]:
		_schweben_text("SIEG", Vector2(540, 760), Color("F4D27A"))
		_lp_zeigen(0, int(gegner_vorher["max_lp"]))
		await _warte(1.8)
		_hand_abraeumen()
		if not _kern.Weiter():
			_schweben_text("DER RUN IST VORBEI", Vector2(540, 760), Color("EFE3C8"))
			await _warte(1.5)
			_neuer_run(randi())
		else:
			_abgleichen()
	elif ergebnis["niederlage"]:
		_schweben_text("DER RUN ENDET", Vector2(540, 760), Color("E0543A"))
		await _warte(2.0)
		_hand_abraeumen()
		_neuer_run(randi())
	else:
		_abgleichen()
	_knopf.disabled = false
	_beschaeftigt = false


func _hand_abraeumen() -> void:
	for k in _karten.values():
		_tisch.entfernen(k)
		k.ziel_position = ABLAGE
		k.ziel_rotation = -0.9
		get_tree().create_timer(1.0).timeout.connect(k.queue_free)
	_karten.clear()


func _schweben_text(text: String, ort: Vector2, farbe: Color) -> void:
	ort.x = clampf(ort.x, 290.0, 790.0)
	var l := _label(text, "AlfaSlabOne.ttf", 56, farbe, ort - Vector2(260, 40), 520)
	_schwebe.add_child(l)
	l.pivot_offset = Vector2(260, 36)
	l.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y - 90.0, 1.1)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	_wackeln = maxf(0.0, _wackeln - delta * 40.0)
	_welt.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _wackeln
	if _vorfuehrung:
		_handschuh.position = _tisch.zeiger + _welt.position


# ------------------------------------------------------------------ Vorfuehrung
func _warte(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _zeiger_zu(ziel: Vector2, dauer: float, bogen := 0.0) -> void:
	var start := _tisch.zeiger
	var t := create_tween()
	t.tween_method(func(w):
		var p := start.lerp(ziel, w) + Vector2(0, -sin(w * PI) * bogen)
		_tisch.zeiger_bewegen(p), 0.0, 1.0, dauer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Im Faecher verdeckt die rechte Nachbarin die rechte Kartenhaelfte:
## sichtbar ist ein Streifen links. Dort anfassen, dann hebt sich die Karte.
func _greifpunkt(k: TarotKarte) -> Vector2:
	return k.global_position + Vector2(-60, 20).rotated(k.rotation)


func _ziehen(k: TarotKarte, platz: int) -> void:
	await _zeiger_zu(_greifpunkt(k), 0.35)
	await _warte(0.2)
	await _zeiger_zu(k.global_position, 0.12)
	_tisch.zeiger_druecken()
	_handschuh.gedrueckt = true
	await _warte(0.08)
	await _zeiger_zu(_tisch.plaetze[platz].global_position, 0.6, 90.0)
	await _warte(0.12)
	_tisch.zeiger_loslassen()
	_handschuh.gedrueckt = false
	await _warte(0.35)


func _vorfuehren() -> void:
	# Notbremse: eine Vorfuehrung endet immer, auch wenn ein Schritt scheitert.
	get_tree().create_timer(70.0).timeout.connect(func(): get_tree().quit())
	_tisch.skript_modus = true
	_handschuh.visible = true
	_tisch.zeiger_bewegen(Vector2(900, 1300))
	await _warte(1.6)

	# ueber die Hand streichen: Neigung, Info, Seltenheit, Editionen
	for k in _tisch.hand.duplicate():
		await _zeiger_zu(_greifpunkt(k), 0.3)
		await _zeiger_zu(k.global_position + Vector2(-20, -30), 0.5 if k.edition != "" else 0.3)

	# Zuege mit den Vorschlaegen des Autopiloten, bis der erste Gegner faellt
	var kampf_vorher := int(_kampf["kampf"])
	for zug in 6:
		for v in _kern.Vorschlag():
			var k: TarotKarte = _karten.get(v["instanz"], null)
			if k != null and k in _tisch.hand:
				await _ziehen(k, int(v["platz"]))
		await _warte(0.4)
		await _zeiger_zu(_knopf.position + _knopf.size * 0.5, 0.45)
		_handschuh.gedrueckt = true
		await _warte(0.12)
		_handschuh.gedrueckt = false
		_zeiger_zu(Vector2(1000, 1880), 0.6)
		_knopf.pressed.emit()
		while _beschaeftigt or _knopf.disabled:
			await _warte(0.1)
		await _warte(1.0)
		if int(_kampf["kampf"]) != kampf_vorher:
			break
	await _warte(1.5)
	get_tree().quit()
