extends Node2D
## Der Kampftisch - aufgebaut wie die Boss-Blaetter:
##
##   Kopf:    Akt | Name und Leben des Gegners | Runde
##   Buehne:  der Gegner auf seiner Buehne (BossBuehne), Absicht, Haltung
##   Plaetze: Vergangenheit, Gegenwart, Zukunft
##   Hand:    die Karten (KartenTisch)
##   Fuss:    Leben und Schild | SCHICKSAL AUSFUEHREN | Stapel, Glueck, Ton
##
## Alles, was gerechnet wird, kommt aus dem C#-Regelkern (Autoload "Kern").
## Hier wird nur gezeigt, bewegt und vertont.
##
## Spielen: Karten antippen oder auf die Plaetze ziehen, dann ausfuehren.
## Aufnehmen: godot --path godot-karten --write-movie f.png --fixed-fps 30 -- --autoplay
## Mit --gegner=boss_mond (o. ae.) beginnt der Kampf gegen diesen Gegner.

const ABSICHTEN := {
	"Attack": "ANGRIFF", "Guard": "ABWEHR", "Hex": "FLUCH", "Drain": "AUSSAUGEN",
	"Frenzy": "RASEREI", "Verborgen": "VERBORGEN",
}
const PLATZ_NAMEN := ["VERGANGENHEIT", "GEGENWART", "ZUKUNFT"]
const PLATZ_WIRKUNG := ["×0,9 Wirkung", "Mult +0,15", "×1,5 · nach dem Gegner"]
const PLATZ_X := [232.0, 540.0, 848.0]
const PLATZ_Y := 1130.0
const STAPEL := Vector2(900, 1720)
const ABLAGE := Vector2(-200, 1400)
const VORFUEHR_EDITIONEN := ["Glass", "Burning", "Shimmering", "Glowing"]

var _kern: Node
var _kampf := {}
var _karten := {}
var _kampf_nummer := -1
var _mischungen := 0
var _beschaeftigt := false
var _vorfuehrung := false
var _offene_treffer := 0
var _wackeln := 0.0
var _rot := 0.0

var _welt: Node2D
var _buehne: BossBuehne
var _tisch: KartenTisch
var _kaskade: WertungsKaskade
var _info: KartenInfo
var _handschuh: ZeigeHandschuh
var _schwebe: Node2D
var _projektor: ShaderMaterial

var _akt: Label
var _akt_name: Label
var _name: Label
var _lp_fuellung: NinePatchRect
var _lp_text: Label
var _runde: Label
var _absicht: Label
var _haltung: Label
var _siegel: HBoxContainer
var _hinweis: Label
var _spieler_lp: Label
var _spieler_schild: Label
var _stapel: Label
var _glueck: Label
var _knopf: Button
var _ton_an := true


func _ready() -> void:
	randomize()
	_vorfuehrung = OS.get_cmdline_user_args().has("--autoplay")
	_bauen()
	_kern = get_node_or_null("/root/Kern")
	if _kern == null or not _kern.has_method("NeuerRun"):
		_name.text = "OHNE KERN"
		_hinweis.text = "Dieser Tisch braucht Godot mit .NET (C#-Regelkern)."
		return
	var gegner := "boss_turm" if _vorfuehrung else ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gegner="):
			gegner = arg.substr(9)
	_neuer_run(21 if _vorfuehrung else randi(), gegner)
	if _vorfuehrung:
		_vorfuehren()


func _neuer_run(saat: int, gegner := "") -> void:
	_kern.NeuerRun(saat)
	if gegner != "":
		_kern.KampfGegen(gegner)
	# Vorfuehrdeck: jede Edition einmal in der ersten Hand.
	var hand: Array = _kern.Kampf()["hand"]
	for i in mini(hand.size(), VORFUEHR_EDITIONEN.size()):
		_kern.EditionGeben(hand[i]["instanz"], VORFUEHR_EDITIONEN[i])
	_abgleichen()


# ------------------------------------------------------------------ Aufbau
func _bauen() -> void:
	add_child(KartenKlang.new())
	_welt = Node2D.new()
	add_child(_welt)
	_hintergrund()

	# --- Kopf
	_welt.add_child(TarotStil.tafel_knoten(Vector2(48, 20), Vector2(206, 140)))
	_akt = TarotStil.label("AKT I", 38, TarotStil.PAPIER)
	_akt.position = Vector2(48, 30)
	_akt.size = Vector2(206, 50)
	_welt.add_child(_akt)
	_akt_name = TarotStil.label("", 25, TarotStil.PAPIER_DUNKEL)
	_akt_name.position = Vector2(62, 76)
	_akt_name.size = Vector2(178, 70)
	_akt_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_akt_name.add_theme_constant_override("line_spacing", -8)
	_welt.add_child(_akt_name)

	_welt.add_child(TarotStil.tafel_knoten(Vector2(262, 20), Vector2(604, 140)))
	_name = TarotStil.label("", 52, TarotStil.PAPIER)
	_name.position = Vector2(262, 26)
	_name.size = Vector2(604, 64)
	_welt.add_child(_name)
	var balken := NinePatchRect.new()
	balken.texture = load(TarotStil.KUNST + "ui/balken.png")
	balken.patch_margin_left = 14
	balken.patch_margin_right = 14
	balken.patch_margin_top = 14
	balken.patch_margin_bottom = 14
	balken.position = Vector2(296, 92)
	balken.size = Vector2(536, 32)
	_welt.add_child(balken)
	_lp_fuellung = NinePatchRect.new()
	_lp_fuellung.texture = load(TarotStil.KUNST + "ui/fuellung.png")
	_lp_fuellung.patch_margin_left = 6
	_lp_fuellung.patch_margin_right = 6
	_lp_fuellung.patch_margin_top = 6
	_lp_fuellung.patch_margin_bottom = 6
	_lp_fuellung.position = Vector2(6, 5)
	_lp_fuellung.size = Vector2(524, 22)
	balken.add_child(_lp_fuellung)
	_lp_text = TarotStil.zahl("", 30, TarotStil.PAPIER, 6)
	_lp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lp_text.position = Vector2(560, 118)
	_lp_text.size = Vector2(272, 40)
	_welt.add_child(_lp_text)

	_welt.add_child(TarotStil.bild("abzeichen.png", Vector2(876, 14), Vector2(152, 152)))
	var runde_titel := TarotStil.label("RUNDE", 24, TarotStil.PAPIER)
	runde_titel.position = Vector2(876, 34)
	runde_titel.size = Vector2(152, 36)
	_welt.add_child(runde_titel)
	_runde = TarotStil.zahl("1", 70, TarotStil.PAPIER)
	_runde.position = Vector2(876, 60)
	_runde.size = Vector2(152, 90)
	_welt.add_child(_runde)

	# --- Buehne
	_welt.add_child(TarotStil.tafel_knoten(Vector2(38, 170), Vector2(1004, 744)))
	_buehne = BossBuehne.new()
	_buehne.position = Vector2(52, 184)
	_buehne.size = Vector2(976, 716)
	_welt.add_child(_buehne)
	_buehne.spieler_getroffen.connect(_spieler_getroffen)

	var absicht_tafel := TarotStil.tafel_knoten(Vector2(64, 196), Vector2(300, 64))
	absicht_tafel.modulate = Color(1, 1, 1, 0.93)
	_welt.add_child(absicht_tafel)
	_absicht = TarotStil.zahl("", 32, TarotStil.GLUT)
	_absicht.position = Vector2(64, 200)
	_absicht.size = Vector2(300, 58)
	_welt.add_child(_absicht)
	var haltung_tafel := TarotStil.tafel_knoten(Vector2(716, 196), Vector2(300, 64))
	haltung_tafel.modulate = Color(1, 1, 1, 0.93)
	_welt.add_child(haltung_tafel)
	_welt.add_child(TarotStil.bild("schild.png", Vector2(730, 204), Vector2(48, 48)))
	_haltung = TarotStil.zahl("", 32, TarotStil.PAPIER)
	_haltung.position = Vector2(780, 200)
	_haltung.size = Vector2(226, 58)
	_welt.add_child(_haltung)
	_siegel = HBoxContainer.new()
	_siegel.position = Vector2(724, 266)
	_siegel.add_theme_constant_override("separation", 2)
	_welt.add_child(_siegel)
	_hinweis = TarotStil.label("", 28, TarotStil.GOLD_HELL, true, 6)
	_hinweis.position = Vector2(380, 196)
	_hinweis.size = Vector2(320, 90)
	_hinweis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_welt.add_child(_hinweis)

	# --- Plaetze und Hand
	_tisch = KartenTisch.new()
	_tisch.hand_mitte = Vector2(540, 1468)
	_tisch.hand_breite = 820.0
	_tisch.max_abstand = 172.0
	_tisch.karten_basis = 0.8
	_welt.add_child(_tisch)
	for i in 3:
		var platz := KartenPlatz.new()
		platz.titel = PLATZ_NAMEN[i]
		platz.wirkung = PLATZ_WIRKUNG[i]
		platz.position = Vector2(PLATZ_X[i], PLATZ_Y)
		_tisch.add_child(platz)
		_tisch.plaetze.append(platz)
	_tisch.legung_geaendert.connect(_legung_an_kern)

	_kaskade = WertungsKaskade.new()
	_kaskade.position = Vector2(230, 780)
	_kaskade.size = Vector2(620, 140)
	_kaskade.z_index = 250
	_welt.add_child(_kaskade)
	_kaskade.wackeln.connect(func(s): _wackeln = maxf(_wackeln, s))

	# --- Fuss
	_welt.add_child(TarotStil.tafel_knoten(Vector2(40, 1652), Vector2(232, 208)))
	_welt.add_child(TarotStil.bild("herz.png", Vector2(62, 1680), Vector2(64, 64)))
	_spieler_lp = TarotStil.zahl("", 50, TarotStil.PAPIER)
	_spieler_lp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spieler_lp.position = Vector2(132, 1680)
	_spieler_lp.size = Vector2(140, 64)
	_welt.add_child(_spieler_lp)
	_welt.add_child(TarotStil.bild("schild.png", Vector2(64, 1764), Vector2(60, 60)))
	_spieler_schild = TarotStil.zahl("", 46, TarotStil.PAPIER)
	_spieler_schild.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spieler_schild.position = Vector2(132, 1762)
	_spieler_schild.size = Vector2(140, 64)
	_welt.add_child(_spieler_schild)

	_knopf = Button.new()
	_knopf.text = "SCHICKSAL\nAUSFÜHREN"
	_knopf.position = Vector2(286, 1660)
	_knopf.size = Vector2(508, 192)
	_knopf.z_index = 250
	TarotStil.knopf_stil(_knopf, 62)
	_knopf.add_theme_constant_override("line_spacing", -14)
	_knopf.pressed.connect(func():
		KartenKlang.spielen("knopf")
		KartenKlang.fuehlen(30, 0.7)
		_ausfuehren())
	_welt.add_child(_knopf)

	_welt.add_child(TarotStil.tafel_knoten(Vector2(808, 1652), Vector2(232, 208)))
	_welt.add_child(TarotStil.bild("stapel.png", Vector2(830, 1672), Vector2(58, 58)))
	_stapel = TarotStil.zahl("", 44, TarotStil.PAPIER)
	_stapel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stapel.position = Vector2(900, 1670)
	_stapel.size = Vector2(120, 60)
	_welt.add_child(_stapel)
	_welt.add_child(TarotStil.bild("glueck.png", Vector2(832, 1734), Vector2(54, 54)))
	_glueck = TarotStil.zahl("", 44, TarotStil.PAPIER)
	_glueck.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_glueck.position = Vector2(900, 1730)
	_glueck.size = Vector2(120, 60)
	_welt.add_child(_glueck)
	var ton := TextureButton.new()
	ton.texture_normal = load(TarotStil.KUNST + "ui/zahnrad.png")
	ton.ignore_texture_size = true
	ton.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	ton.position = Vector2(896, 1792)
	ton.size = Vector2(56, 56)
	ton.pressed.connect(func():
		_ton_an = not _ton_an
		AudioServer.set_bus_mute(0, not _ton_an)
		ton.modulate = Color.WHITE if _ton_an else Color(0.5, 0.45, 0.4))
	_welt.add_child(ton)

	_schwebe = Node2D.new()
	_schwebe.z_index = 400
	_welt.add_child(_schwebe)
	_kaskade.schwebe_ebene_setzen(_schwebe)

	var oben := CanvasLayer.new()
	oben.layer = 10
	add_child(oben)
	_info = KartenInfo.new()
	oben.add_child(_info)
	_tisch.schwebt_ueber.connect(func(k): _info.zeigen(k))
	_handschuh = ZeigeHandschuh.new()
	_handschuh.visible = false
	oben.add_child(_handschuh)

	var film := CanvasLayer.new()
	film.layer = 20
	add_child(film)
	var schicht := ColorRect.new()
	schicht.size = Vector2(1080, 1920)
	schicht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_projektor = ShaderMaterial.new()
	_projektor.shader = load("res://addons/tartot_karten/shader/projektor.gdshader")
	schicht.material = _projektor
	film.add_child(schicht)


func _hintergrund() -> void:
	var grund := ColorRect.new()
	grund.size = Vector2(1080, 1920)
	grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 px = UV * vec2(1080.0, 1920.0);
	vec3 c = vec3(0.075, 0.058, 0.048) * (0.85 + 0.3 * h(floor(px / 3.0)));
	// Filmstreifen links und rechts: Perforation wie auf den Blaettern
	if (px.x < 36.0 || px.x > 1044.0) {
		c = vec3(0.035, 0.028, 0.024);
		float lx = px.x < 36.0 ? px.x : px.x - 1044.0;
		float ly = mod(px.y, 46.0);
		vec2 q = vec2(lx - 18.0, ly - 23.0);
		vec2 b = abs(q) - vec2(9.0, 11.0);
		float d = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - 3.0;
		if (d < 0.0) c = vec3(0.74, 0.62, 0.45) * (0.85 + 0.2 * h(floor(px / 2.0)));
	}
	COLOR = vec4(c, 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	grund.material = mat
	_welt.add_child(grund)


# ------------------------------------------------------------------ Abgleich
func _abgleichen() -> void:
	_kampf = _kern.Kampf()
	var g: Dictionary = _kampf["gegner"]
	var sp: Dictionary = _kampf["spieler"]
	var akt := int(_kampf["akt"])
	_akt.text = "AKT " + TarotStil.roemisch(akt)
	_akt_name.text = str(_kampf.get("akt_name", "")).to_upper()
	_name.text = str(g["name"]).to_upper()
	_runde.text = str(int(_kampf["zug"]))
	_lp_zeigen(int(g["lp"]), int(g["max_lp"]))
	var absicht: String = ABSICHTEN.get(str(g["absicht"]), str(g["absicht"]))
	_absicht.text = absicht + ((" %d" % int(g["absicht_wert"])) if int(g["absicht_wert"]) > 0 else "")
	_haltung.text = "HALTUNG %d" % int(g["haltung"]) if int(g["haltung"]) > 0 else "OFFEN"
	for kind in _siegel.get_children():
		kind.queue_free()
	for i in int(g["siegel"]):
		var s := TextureRect.new()
		s.texture = load(TarotStil.KUNST + "ui/siegel.png")
		s.custom_minimum_size = Vector2(40, 40)
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_siegel.add_child(s)
	_spieler_lp.text = "%d/%d" % [int(sp["lp"]), int(sp["max_lp"])]
	_spieler_schild.text = str(int(sp["schild"]))
	_stapel.text = str(int(_kampf["stapel"]))
	_glueck.text = str(int(sp["glueck"]))
	for i in 3:
		_tisch.plaetze[i].gesperrt = i == int(_kampf["gesperrt"])

	var verzug := 0.0
	var nummer := int(_kampf["kampf"]) * 1000 + akt
	if nummer != _kampf_nummer:
		_kampf_nummer = nummer
		_mischungen = int(_kampf["mischungen"])
		verzug = 1.5
		_neuer_gegner(str(g["sprite"]), akt, bool(g["boss"]))
	elif int(_kampf["mischungen"]) > _mischungen:
		_mischungen = int(_kampf["mischungen"])
		KartenKlang.spielen("mischen_kurz", 1.0, -2.0, 0.02)
		verzug = 0.55

	var neu := 0
	for d in _kampf["hand"]:
		var instanz: String = d["instanz"]
		if _karten.has(instanz):
			continue
		var karte := TarotKarte.erzeugen(d["id"], d["edition"])
		karte.instanz = instanz
		karte.basis = _tisch.karten_basis
		_karten[instanz] = karte
		_tisch.austeilen(karte, STAPEL, verzug + neu * 0.11)
		neu += 1
	_legung_an_kern()


func _neuer_gegner(sprite: String, akt: int, boss: bool) -> void:
	_buehne.laden(sprite, akt)
	var ordner := "res://buehnen/%s/" % (sprite if ResourceLoader.exists("res://buehnen/%s/platz_0.png" % sprite) else BossBuehne.AKT_BUEHNEN[clampi(akt, 0, 5)])
	for i in 3:
		_tisch.plaetze[i].bild_setzen(load(ordner + "platz_%d.png" % i))
	KartenKlang.musik("walzer", boss)
	KartenKlang.spielen("mischen", 1.0, 0.0, 0.02)
	KartenKlang.fuehlen(60, 0.4)
	_buehne.auftritt()


func _lp_zeigen(lp: int, max_lp: int) -> void:
	var anteil := clampf(float(lp) / maxf(1.0, max_lp), 0.0, 1.0)
	var t := create_tween()
	t.tween_property(_lp_fuellung, "size:x", maxf(12.0, 524.0 * anteil), 0.5).set_ease(Tween.EASE_OUT)
	_lp_fuellung.visible = lp > 0
	_lp_text.text = "%d/%d" % [lp, max_lp]


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

	_offene_treffer = int(ergebnis["lp_verlust"])
	for bild in ergebnis["animationen"]:
		if bild == "hit":
			var an := int(ergebnis["angekommen"])
			_buehne.treffer(clampf(float(an) / 60.0, 0.3, 1.0))
			_lp_zeigen(maxi(0, int(gegner_vorher["lp"]) - an), int(gegner_vorher["max_lp"]))
			_schweben_text("−%d" % an if an > 0 else "GEBLOCKT", Vector2(780, 420), TarotStil.GLUT)
			if an < int(ergebnis["schicksal"]) and not ergebnis["sieg"]:
				_schweben_text("HALTUNG DECKELT", Vector2(540, 560), TarotStil.PAPIER_DUNKEL)
			if ergebnis["haltung_gebrochen"]:
				_schweben_text("HALTUNG BRICHT", Vector2(540, 640), TarotStil.GOLD_HELL)
			await _warte(0.7)
		elif bild == "phase2":
			_schweben_text("DAS SIEGEL BRICHT", Vector2(540, 500), TarotStil.GOLD_HELL)
			await _buehne.zweite_phase()
		elif bild == "death":
			await _buehne.sterben()
		elif bild == "idle":
			pass
		else:
			_hinweis.text = _absicht.text
			await _buehne.angreifen(bild)
			await _warte(0.25)
	if _offene_treffer > 0:
		_spieler_getroffen(0.8)

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
	await _warte(0.4)
	_kaskade.zuruecksetzen()

	if ergebnis["sieg"]:
		_schweben_text("SIEG", Vector2(540, 520), Color("F4D27A"), 1.6)
		KartenKlang.spielen("sieg")
		KartenKlang.fuehlen(150, 1.0)
		await _warte(2.0)
		await _iris(false)
		_hand_abraeumen()
		if not _kern.Weiter():
			_neuer_run(randi())
		else:
			_abgleichen()
		await _iris(true)
	elif ergebnis["niederlage"]:
		_schweben_text("DER RUN ENDET", Vector2(540, 520), TarotStil.GLUT, 1.4)
		KartenKlang.spielen("niederlage")
		await _warte(2.4)
		await _iris(false)
		_hand_abraeumen()
		_neuer_run(randi())
		await _iris(true)
	else:
		_abgleichen()
	_knopf.disabled = false
	_beschaeftigt = false


## Was der Gegner dem Spieler antut - im Moment, in dem der Effekt ankommt.
func _spieler_getroffen(staerke: float) -> void:
	_rot = maxf(_rot, 0.5 + staerke * 0.5)
	_wackeln = maxf(_wackeln, 8.0 + 14.0 * staerke)
	KartenKlang.fuehlen(int(40 + 60 * staerke), staerke)
	if _offene_treffer > 0:
		KartenKlang.spielen("spieler_getroffen", 1.0, lerpf(-6.0, 2.0, clampf(_offene_treffer / 20.0, 0.0, 1.0)))
		_schweben_text("−%d LP" % _offene_treffer, Vector2(160, 1600), TarotStil.GLUT)
		_offene_treffer = 0
		var sp: Dictionary = _kern.Kampf()["spieler"]
		_spieler_lp.text = "%d/%d" % [int(sp["lp"]), int(sp["max_lp"])]
		var t := create_tween()
		_spieler_lp.pivot_offset = _spieler_lp.size * 0.5
		t.tween_property(_spieler_lp, "scale", Vector2(1.35, 1.35), 0.06)
		t.tween_property(_spieler_lp, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _iris(auf: bool) -> void:
	var t := create_tween()
	t.tween_method(func(w): _projektor.set_shader_parameter("iris", w), 0.0 if auf else 1.25, 1.25 if auf else 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	KartenKlang.spielen("iris", 1.0 if auf else 0.85, -4.0)
	await t.finished


func _hand_abraeumen() -> void:
	for k in _karten.values():
		_tisch.entfernen(k)
		k.ziel_position = ABLAGE
		k.ziel_rotation = -0.9
		get_tree().create_timer(1.0).timeout.connect(k.queue_free)
	_karten.clear()


func _schweben_text(text: String, ort: Vector2, farbe: Color, groesse := 1.0) -> void:
	ort.x = clampf(ort.x, 290.0, 790.0)
	var l := TarotStil.zahl(text, int(64 * groesse), farbe, 10) if text.begins_with("−") else TarotStil.label(text, int(60 * groesse), farbe, false, 10)
	l.position = ort - Vector2(300, 50)
	l.size = Vector2(600, 100)
	_schwebe.add_child(l)
	l.pivot_offset = Vector2(300, 50)
	l.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y - 90.0, 1.2)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


func _process(delta: float) -> void:
	_wackeln = maxf(0.0, _wackeln - delta * 40.0)
	_rot = maxf(0.0, _rot - delta * 1.6)
	_welt.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _wackeln
	_projektor.set_shader_parameter("rot", _rot)
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


func _greifpunkt(k: TarotKarte) -> Vector2:
	return k.global_position + Vector2(-50, 20).rotated(k.rotation)


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
	get_tree().create_timer(95.0).timeout.connect(func(): get_tree().quit())
	_tisch.skript_modus = true
	_handschuh.visible = true
	_tisch.zeiger_bewegen(Vector2(900, 1300))
	await _warte(3.2)
	for k in _tisch.hand.duplicate():
		await _zeiger_zu(_greifpunkt(k), 0.3)
		await _zeiger_zu(k.global_position + Vector2(-20, -30), 0.5 if k.edition != "" else 0.3)
	var kampf_vorher := int(_kampf["kampf"])
	for zug in 5:
		for v in _kern.Vorschlag():
			var k: TarotKarte = _karten.get(v["instanz"], null)
			if k != null and k in _tisch.hand:
				await _ziehen(k, int(v["platz"]))
		await _warte(0.5)
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
