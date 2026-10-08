class_name Kampftisch
extends Control
## Der Kampftisch - aufgebaut wie die Boss-Blaetter (1080 x 1920):
##
##   Kopf:    Akt | Name und Leben des Gegners | Runde
##   Buehne:  der Gegner auf seiner Buehne (BossBuehne), Absicht, Regel, Haltung
##   Plaetze: Vergangenheit, Gegenwart, Zukunft
##   Hand:    die Karten (KartenTisch)
##   Fuss:    Leben und Schild | SCHICKSAL AUSFUEHREN | Stapel, Glueck, Beutel
##
## Portiert aus godot-karten/demo/demo.gd. Alles, was gerechnet wird, kommt
## aus dem GDScript-Kern ueber die KernBruecke. Hier wird nur gezeigt,
## bewegt und vertont. Die Animation ist nie die Wahrheit: nach jeder Folge
## gleicht _abgleichen() den Tisch mit dem Kern ab.

signal finished
## Jeder Darstellungs-Cue des CueBuilders (Tests, spaeter Haptik).
signal cue_gespielt(cue: Dictionary)

const ABSICHTEN := {
	"Attack": "ANGRIFF", "Guard": "ABWEHR", "Hex": "FLUCH", "Drain": "AUSSAUGEN",
	"Frenzy": "RASEREI", "Verborgen": "VERBORGEN",
}
const PLATZ_NAMEN := ["VERGANGENHEIT", "GEGENWART", "ZUKUNFT"]
const PLATZ_WIRKUNG := ["90 % · Vorbereitung", "100 % · sicher", "150 % · nach dem Gegner"]
const PLATZ_X := [232.0, 540.0, 848.0]
const PLATZ_Y := 1130.0
const STAPEL := Vector2(900, 1720)
const ABLAGE := Vector2(-200, 1400)

var game: GameController
var kern: KernBruecke
## true, solange eine Folge laeuft oder der Auftritt spielt (Eingabe gesperrt).
var gesperrt := false

var _kampf := {}
var _karten := {}
var _mischungen := 0
var _offene_treffer := 0
var _wackeln := 0.0
var _rot := 0.0
var _fertig := false

var _welt: Node2D
var _buehne: BossBuehne
var _tisch: KartenTisch
var _kaskade: WertungsKaskade
var _detail: KartenDetail
var _handschuh: ZeigeHandschuh
var _arm: GreifArm
var _arm_seite := 1.0
var _schwebe: Node2D
var _projektor: ShaderMaterial
var _oben: CanvasLayer

var _akt: Label
var _akt_name: Label
var _name: Label
var _lp_fuellung: NinePatchRect
var _lp_text: Label
var _runde: Label
var _absicht: Label
var _haltung: Label
var _siegel: HBoxContainer
var _regel: Label
var _regel_tafel: Panel
var _hinweis: Label
var _spieler_lp: Label
var _spieler_schild: Label
var _stapel: Label
var _glueck: Label
var _knopf: Button
var _pakt: Control
var _beutel: Control
var _ton_an := true
## Karten, die der Tod in diesem Zug nimmt (KernBruecke.karte_nach).
var _verloren: Array = []
## Instanz der zuletzt gezeigten Todeszeichnung.
var _mal_gezeigt := ""


func _init(p_game: GameController) -> void:
	game = p_game
	kern = KernBruecke.new(p_game)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## "Akt II · Kampf 3/5", "Finale" oder "Spirale 4".
static func wo(run: RunState) -> String:
	if ActCatalog.is_finale(run.fight_index):
		return "Finale"
	if ActCatalog.is_spiral(run.fight_index):
		return "Spirale %d" % ActCatalog.spiral_depth(run.fight_index)
	return "Kampf %d/%d" % [run.fight_index % ActCatalog.FIGHTS_PER_ACT + 1, ActCatalog.FIGHTS_PER_ACT]


func _ready() -> void:
	_bauen()
	_abgleichen(true)


# ------------------------------------------------------------------ Aufbau
func _bauen() -> void:
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
	_name.clip_text = true
	_welt.add_child(_name)
	var balken := NinePatchRect.new()
	balken.texture = load(TarotStil.KUNST + "ui/balken.png")
	for seite in ["left", "right", "top", "bottom"]:
		balken.set("patch_margin_" + seite, 14)
	balken.position = Vector2(296, 92)
	balken.size = Vector2(536, 32)
	_welt.add_child(balken)
	_lp_fuellung = NinePatchRect.new()
	_lp_fuellung.texture = load(TarotStil.KUNST + "ui/fuellung.png")
	for seite in ["left", "right", "top", "bottom"]:
		_lp_fuellung.set("patch_margin_" + seite, 6)
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

	# Die Regel des Bosses als Tafel oben in der Mitte, Text aus dem Kern.
	_regel_tafel = TarotStil.tafel_knoten(Vector2(372, 196), Vector2(336, 108))
	_regel_tafel.modulate = Color(1, 1, 1, 0.95)
	_welt.add_child(_regel_tafel)
	_regel = TarotStil.label("", 24, TarotStil.GOLD_HELL, true, 4)
	_regel.position = Vector2(386, 200)
	_regel.size = Vector2(308, 100)
	_regel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_regel.add_theme_constant_override("line_spacing", -4)
	_welt.add_child(_regel)

	_hinweis = TarotStil.label("", 28, TarotStil.GOLD_HELL, true, 6)
	_hinweis.position = Vector2(120, 690)
	_hinweis.size = Vector2(840, 80)
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
		ausfuehren())
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
	var beutel := TextureButton.new()
	beutel.texture_normal = load(TarotStil.KUNST + "ui/zahnrad.png")
	beutel.ignore_texture_size = true
	beutel.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	beutel.position = Vector2(896, 1792)
	beutel.size = Vector2(56, 56)
	beutel.tooltip_text = "Beutel: Gegenstände und Ton"
	beutel.pressed.connect(_beutel_umschalten)
	_welt.add_child(beutel)

	_schwebe = Node2D.new()
	_schwebe.z_index = 400
	_welt.add_child(_schwebe)

	# Der Boss greift aus der Buehne nach dem Tisch.
	_arm = GreifArm.new()
	_arm.schulter_quelle = func() -> Vector2: return _buehne.schulter(_arm_seite)
	_welt.add_child(_arm)
	_kaskade.schwebe_ebene_setzen(_schwebe)

	_oben = CanvasLayer.new()
	_oben.layer = 10
	add_child(_oben)
	# Langes Druecken: die Karte gross, darunter die Erklaerung.
	_detail = KartenDetail.new()
	_oben.add_child(_detail)
	_tisch.lange_gedrueckt.connect(func(k, punkt): _detail.zeigen(k, punkt))
	_tisch.lang_bewegt.connect(func(punkt): _detail.finger(punkt))
	_tisch.lang_losgelassen.connect(func(): _detail.verbergen())
	_handschuh = ZeigeHandschuh.new()
	_handschuh.visible = false
	_oben.add_child(_handschuh)

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
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/tisch/filmgrund.gdshader")
	grund.material = mat
	_welt.add_child(grund)


# ------------------------------------------------------------------ Abgleich
## Zeigt den Kernzustand. erster: der Kampf beginnt gerade (Auftritt).
func _abgleichen(erster := false) -> void:
	_kampf = kern.kampf()
	if _kampf.is_empty():
		return
	var g: Dictionary = _kampf["gegner"]
	var sp: Dictionary = _kampf["spieler"]
	var akt := int(_kampf["akt"])
	_akt.text = "AKT " + TarotStil.roemisch(mini(akt, 4)) if akt <= 4 else "SPIRALE"
	_akt_name.text = str(_kampf.get("akt_name", "")).to_upper() + "\n" + str(_kampf.get("wo", "")).to_upper()
	_name.text = str(g["name"]).to_upper()
	_runde.text = str(int(_kampf["zug"]))
	_lp_zeigen(int(g["lp"]), int(g["max_lp"]), bool(g.get("mond", false)))
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
	var regeln: Array = g.get("regeln", [])
	_regel_tafel.visible = not regeln.is_empty()
	_regel.visible = _regel_tafel.visible
	_regel.text = " ".join(regeln)
	_spieler_lp.text = "%d/%d" % [int(sp["lp"]), int(sp["max_lp"])]
	_spieler_schild.text = str(int(sp["schild"]))
	_stapel.text = str(int(_kampf["stapel"]))
	_glueck.text = str(int(sp["glueck"]))
	var wirkt: Array = _kampf["wirkt_als"]
	for i in 3:
		_tisch.plaetze[i].gesperrt = i == int(_kampf["gesperrt"])
		_tisch.plaetze[i].wirkung_setzen(PLATZ_WIRKUNG[i] if int(wirkt[i]) == i else "wirkt als " + PLATZ_NAMEN[int(wirkt[i])].to_lower())

	var verzug := 0.0
	if erster:
		_mischungen = int(_kampf["mischungen"])
		verzug = 1.5
		_neuer_gegner(str(g["sprite"]), akt, bool(g["boss"]))
	elif int(_kampf["mischungen"]) > _mischungen:
		_mischungen = int(_kampf["mischungen"])
		KartenKlang.spielen("mischen_kurz", 1.0, -2.0, 0.02)
		verzug = 0.55

	# Karten, die der Kern nicht mehr auf der Hand hat, verlassen den Tisch.
	var im_kern := {}
	for d in _kampf["hand"]:
		im_kern[d["instanz"]] = true
	for d in _kampf["plaetze"].values():
		im_kern[d["instanz"]] = true
	for instanz in _karten.keys():
		if not im_kern.has(instanz):
			var weg: TarotKarte = _karten[instanz]
			_karten.erase(instanz)
			_tisch.entfernen(weg)
			weg.ziel_position = ABLAGE
			get_tree().create_timer(1.0).timeout.connect(weg.queue_free)

	var neu := 0
	for d in _kampf["hand"]:
		var instanz: String = d["instanz"]
		if _karten.has(instanz):
			var bestehend: TarotKarte = _karten[instanz]
			bestehend.zustand_setzen(d)
			continue
		var karte := TarotKarte.aus_daten(d)
		karte.basis = _tisch.karten_basis
		_karten[instanz] = karte
		_tisch.austeilen(karte, STAPEL, verzug + neu * 0.11)
		neu += 1
	_pakt_zeigen(bool(_kampf.get("pakt", false)))
	_legung_an_kern()


func _neuer_gegner(sprite: String, akt: int, boss: bool) -> void:
	_buehne.laden(sprite, akt)
	var ordner := "res://buehnen/%s/" % (sprite if ResourceLoader.exists("res://buehnen/%s/platz_0.png" % sprite) else BossBuehne.AKT_BUEHNEN[clampi(akt, 0, 5)])
	for i in 3:
		_tisch.plaetze[i].bild_setzen(load(ordner + "platz_%d.png" % i))
	KartenKlang.musik("walzer", boss)
	KartenKlang.spielen("mischen", 1.0, 0.0, 0.02)
	KartenKlang.fuehlen(60, 0.4)
	_auftritt(boss)


func _auftritt(boss: bool) -> void:
	gesperrt = true
	_knopf.disabled = true
	if boss:
		_schweben_text("HEUTE IM LICHTSPIELHAUS", Vector2(540, 420), TarotStil.PAPIER_DUNKEL, 0.6)
	await _buehne.auftritt()
	if _regel_tafel.visible:
		_regel_tafel.pivot_offset = _regel_tafel.size * 0.5
		_regel_tafel.scale = Vector2(1.4, 1.4)
		_regel_tafel.modulate.a = 0.0
		var t := create_tween().set_parallel()
		t.tween_property(_regel_tafel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_regel_tafel, "modulate:a", 0.95, 0.15)
		KartenKlang.spielen("ablegen", 0.8)
		await t.finished
	gesperrt = false
	_knopf.disabled = false
	_mal_pruefen()


func _lp_zeigen(lp: int, max_lp: int, ungefaehr := false) -> void:
	var anteil := clampf(float(lp) / maxf(1.0, max_lp), 0.0, 1.0)
	var t := create_tween()
	t.tween_property(_lp_fuellung, "size:x", maxf(12.0, 524.0 * anteil), 0.5).set_ease(Tween.EASE_OUT)
	_lp_fuellung.visible = lp > 0
	# Der Mond zeigt sein Leben nur ungefaehr.
	@warning_ignore("integer_division")
	_lp_text.text = ("≈%d" % ((maxi(0, lp) + 9) / 10 * 10) if ungefaehr else str(maxi(0, lp))) + "/%d" % max_lp


func _legung_an_kern() -> void:
	kern.abraeumen()
	for i in _tisch.plaetze.size():
		var karte: TarotKarte = _tisch.plaetze[i].karte
		if karte != null:
			kern.legen(karte.instanz, i)
	var vorschau: Dictionary = kern.vorschau()
	_kaskade.vorschau(vorschau)
	var hinweise: Array = vorschau.get("hinweise", [])
	_hinweis.text = str(hinweise[0]) if hinweise.size() > 0 else ""
	if vorschau.get("toedlich", false) and _tisch.legung().size() > 0:
		_hinweis.text = "TÖDLICH – dieser Treffer beendet den Kampf."


# ------------------------------------------------------------------ Zug
func ausfuehren() -> void:
	var legung := _tisch.legung()
	if gesperrt or _fertig or legung.is_empty():
		if legung.is_empty() and not gesperrt:
			_hinweis.text = "Lege mindestens eine Karte."
		return
	gesperrt = true
	_knopf.disabled = true
	_hinweis.text = ""
	_detail.verbergen(true)
	_legung_an_kern()
	var gegner_vorher: Dictionary = _kampf["gegner"]
	var ergebnis: Dictionary = kern.ausfuehren()
	if ergebnis.is_empty():
		gesperrt = false
		_knopf.disabled = false
		return
	_verloren = ergebnis.get("verloren", [])
	var moment := Spiel.after_turn(ergebnis["zug"])

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
			_lp_zeigen(maxi(0, int(gegner_vorher["lp"]) - an), int(gegner_vorher["max_lp"]), bool(gegner_vorher.get("mond", false)))
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
			await _buehne.angreifen(bild)
			await _warte(0.25)
	if _offene_treffer > 0:
		_spieler_getroffen(0.8)

	# Folgen, die nur der CueBuilder aus Kernfakten kennt.
	for c in ergebnis["cues"]:
		cue_gespielt.emit(c)
		await _cue(c)

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
	if moment != "":
		_schweben_text(moment.get_slice("\n", 0), Vector2(540, 470), TarotStil.GOLD_HELL, 0.8)

	if ergebnis["sieg"] or ergebnis["niederlage"]:
		_fertig = true
		if ergebnis["sieg"]:
			_schweben_text("SIEG", Vector2(540, 520), Color("F4D27A"), 1.6)
			KartenKlang.spielen("sieg")
			KartenKlang.fuehlen(150, 1.0)
		else:
			_schweben_text("DER RUN ENDET", Vector2(540, 520), TarotStil.GLUT, 1.4)
			KartenKlang.spielen("niederlage")
		await _warte(2.0)
		await _iris(false)
		_hand_abraeumen()
		finished.emit()
		return
	_abgleichen()
	gesperrt = false
	_knopf.disabled = false
	_mal_pruefen()


## Einzelne Cues des CueBuilders darstellen. Einsturz und Verhuellen zeigt
## der Tisch schon ueber den Kernzustand; hier kommt der Moment dazu.
func _cue(c: Dictionary) -> void:
	match String(c["typ"]):
		"einsturz":
			await _turm_greift(int(c["slot"]))
		"verlust":
			_schweben_text(String(c["text"]), Vector2(540, 600), TarotStil.GLUT, 0.8)
			for d in _verloren:
				await _tod_nimmt(d)
			if _verloren.is_empty():
				await _warte(0.6)
		"verhuellen":
			await _mond_verhuellt()


## Was der Gegner dem Spieler antut - im Moment, in dem der Effekt ankommt.
func _spieler_getroffen(staerke: float) -> void:
	_rot = maxf(_rot, 0.5 + staerke * 0.5)
	_wackeln = maxf(_wackeln, 8.0 + 14.0 * staerke)
	KartenKlang.fuehlen(int(40 + 60 * staerke), staerke)
	if _offene_treffer > 0:
		KartenKlang.spielen("spieler_getroffen", 1.0, lerpf(-6.0, 2.0, clampf(_offene_treffer / 20.0, 0.0, 1.0)))
		_schweben_text("−%d LP" % _offene_treffer, Vector2(160, 1600), TarotStil.GLUT)
		_offene_treffer = 0
		var sp: Dictionary = kern.kampf().get("spieler", {})
		if not sp.is_empty():
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
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_schwebe.add_child(l)
	l.pivot_offset = Vector2(300, 50)
	l.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y - 90.0, 1.2)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


# ------------------------------------------------------------------ Pakt, Beutel
func _pakt_zeigen(offen: bool) -> void:
	if _pakt != null:
		_pakt.queue_free()
		_pakt = null
	if not offen:
		return
	_pakt = Control.new()
	_pakt.position = Vector2(90, 560)
	_pakt.size = Vector2(900, 360)
	_pakt.z_index = 320
	var tafel := TarotStil.tafel_knoten(Vector2.ZERO, _pakt.size)
	_pakt.add_child(tafel)
	var text := TarotStil.label("Der Teufel bietet einen Pakt: +%d %% Fate-Schaden für diesen Kampf.\nPreis: %d Max-LP für immer und +%d Verdunkelung.\nLehnst du ab, schlägt er %d %% härter zu." % [
		roundi(float(_kampf["pakt_bonus"]) * 100.0), int(_kampf["pakt_preis"]), CombatSystem.PACT_DARKNESS,
		roundi(CombatSystem.PACT_DECLINE_PENALTY * 100.0)], 30, TarotStil.PAPIER, true, 4)
	text.position = Vector2(30, 20)
	text.size = Vector2(840, 190)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pakt.add_child(text)
	for i in 2:
		var b := Button.new()
		b.text = "UNTERSCHREIBEN" if i == 0 else "ABLEHNEN"
		b.position = Vector2(40 + i * 420, 220)
		b.size = Vector2(400, 110)
		TarotStil.knopf_stil(b, 38)
		var annehmen := i == 0
		b.pressed.connect(func():
			game.answer_pact(annehmen)
			KartenKlang.spielen("knopf")
			Spiel.save_run()
			_abgleichen())
		_pakt.add_child(b)
	_welt.add_child(_pakt)


func _beutel_umschalten() -> void:
	if _beutel != null:
		_beutel.queue_free()
		_beutel = null
		return
	_beutel = Control.new()
	_beutel.position = Vector2(140, 1180)
	_beutel.size = Vector2(800, 460)
	_beutel.z_index = 330
	_beutel.add_child(TarotStil.tafel_knoten(Vector2.ZERO, _beutel.size))
	var spalte := VBoxContainer.new()
	spalte.position = Vector2(30, 24)
	spalte.size = Vector2(740, 410)
	spalte.add_theme_constant_override("separation", 10)
	_beutel.add_child(spalte)
	spalte.add_child(TarotStil.label("BEUTEL", 40, TarotStil.GOLD_HELL))
	var leer := true
	for item in GameCatalog.items():
		var anzahl := int(game.run.items.get(item.id, 0))
		if anzahl <= 0:
			continue
		leer = false
		var b := Button.new()
		b.text = "%s ×%d" % [item.name, anzahl]
		b.tooltip_text = item.description
		b.custom_minimum_size = Vector2(0, 74)
		TarotStil.knopf_stil(b, 30)
		var id := item.id
		b.pressed.connect(func():
			if gesperrt:
				return
			var ziel: CardInstance = null
			var gewaehlt := _tisch.gewaehlte()
			if not gewaehlt.is_empty():
				ziel = _instanz_zu_karte(gewaehlt[0].instanz)
			game.use_item(id, ziel)
			_hinweis.text = game.message
			Spiel.save_run()
			_beutel_umschalten()
			_abgleichen())
		spalte.add_child(b)
	if leer:
		spalte.add_child(TarotStil.label("Der Beutel ist leer.", 30, TarotStil.PAPIER_DUNKEL, true))
	var ton := Button.new()
	ton.text = "TON AUS" if _ton_an else "TON AN"
	ton.custom_minimum_size = Vector2(0, 70)
	TarotStil.knopf_stil(ton, 30)
	ton.pressed.connect(func():
		_ton_an = not _ton_an
		AudioServer.set_bus_mute(0, not _ton_an)
		_beutel_umschalten())
	spalte.add_child(ton)
	_welt.add_child(_beutel)


func _instanz_zu_karte(instanz: String) -> CardInstance:
	for c in game.combat.hand:
		if c.instance_id == instanz:
			return c
	return null


func _process(delta: float) -> void:
	# 2.5D-Buehne: der Neigungssensor (Handy) oder der Finger bestimmt den Blick.
	var neigung := Input.get_accelerometer()
	if neigung.length() > 0.1:
		_buehne.blick = Vector2(clampf(neigung.x / 4.0, -1.0, 1.0), clampf((neigung.y + 6.0) / 4.0, -1.0, 1.0))
	elif _tisch.zeiger.x > -500.0:
		_buehne.blick = ((_tisch.zeiger - Vector2(540, 900)) / Vector2(540, 900)).clamp(Vector2(-1, -1), Vector2(1, 1))
	_wackeln = maxf(0.0, _wackeln - delta * 40.0)
	_rot = maxf(0.0, _rot - delta * 1.6)
	_welt.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _wackeln
	_projektor.set_shader_parameter("rot", _rot)
	if _handschuh.visible:
		_handschuh.position = _tisch.zeiger + _welt.position


func _warte(s: float) -> void:
	await get_tree().create_timer(s).timeout


# ------------------------------------------------------------------ Greifen
## Turm: die Hand packt den Platz, holt aus und schlaegt ihn in Truemmer.
func _turm_greift(slot: int) -> void:
	var platz: KartenPlatz = _tisch.plaetze[slot]
	_arm_seite = -1.0 if platz.global_position.x < 540.0 else 1.0
	_arm.aermel = Color("4A4038")
	_arm.mass = 1.35
	_buehne.greif_haltung(true, _arm_seite)
	await _arm.ausstrecken(platz.global_position + Vector2(0, -150))
	await _arm.greifen(true)
	await _arm.fuehren(platz.global_position + Vector2(0, -260), 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	await _arm.fuehren(platz.global_position + Vector2(0, -30), 0.09, Tween.TRANS_EXPO, Tween.EASE_IN)
	_wackeln = maxf(_wackeln, 24.0)
	KartenKlang.spielen("angriff_steine")
	KartenKlang.spielen("landen", 0.8)
	KartenKlang.fuehlen(90, 1.0)
	platz.gesperrt = true
	_truemmer(platz.global_position)
	await _warte(0.25)
	_buehne.greif_haltung(false)
	await _arm.zurueckziehen()


## Tod: die Hand greift sich die Karte und zieht sie in die Buehne.
func _tod_nimmt(d: Dictionary) -> void:
	var k: TarotKarte = _karten.get(d["instanz"], null)
	if k != null:
		_karten.erase(d["instanz"])
		_tisch.entfernen(k)
	else:
		# Die Karte lag im Stapel: sie wird erst gezeigt, dann genommen.
		k = TarotKarte.aus_daten(d)
		k.basis = _tisch.karten_basis
		k.position = STAPEL
		_welt.add_child(k)
		k.ziel_position = Vector2(540, 1380)
		await _warte(0.45)
	k.z_index = 320
	_arm_seite = -1.0 if k.global_position.x < 540.0 else 1.0
	_arm.aermel = Color("201818")
	_arm.mass = 1.25
	_buehne.greif_haltung(true, _arm_seite)
	await _arm.ausstrecken(k.global_position + Vector2(0, -60))
	await _arm.greifen(true)
	k.stossen(0.2)
	KartenKlang.spielen("nehmen", 0.7)
	KartenKlang.fuehlen(60, 0.8)
	_arm.getragen = k
	k.ziel_rotation = 0.4
	var t := create_tween()
	t.tween_property(k, "ziel_skala", 0.55, 0.5)
	_buehne.greif_haltung(false)
	await _arm.zurueckziehen(0.55)
	k.aufloesen(0.6, Color("7A1A1E"))
	KartenKlang.spielen("angriff_sense", 1.0, -4.0)


## Hat der Tod eine neue Karte gezeichnet? Dann zeigt er auf sie.
func _mal_pruefen() -> void:
	var mal: Dictionary = _kampf.get("mal", {})
	var instanz := str(mal.get("instanz", ""))
	if instanz == "" or instanz == _mal_gezeigt:
		_mal_gezeigt = instanz
		return
	_mal_gezeigt = instanz
	_tod_zeichnet(mal)


## Tod zeichnet eine Karte: ein Fingertippen, dann sitzt das Siegel. Liegt
## die Karte noch im Stapel, kommt sie kurz hervor und geht dann zurueck.
func _tod_zeichnet(mal: Dictionary) -> void:
	gesperrt = true
	_knopf.disabled = true
	cue_gespielt.emit({"typ": "zeichnen", "instanz": mal["instanz"]})
	var k: TarotKarte = _karten.get(mal["instanz"], null)
	var geist := k == null
	if geist:
		k = TarotKarte.aus_daten(mal)
		k.gezeichnet = 0
		k.basis = _tisch.karten_basis
		k.position = STAPEL
		k.z_index = 320
		_welt.add_child(k)
		k.ziel_position = Vector2(540, 1290)
		k.ziel_skala = 1.15
		await _warte(0.45)
	_arm_seite = -1.0 if k.global_position.x < 540.0 else 1.0
	_arm.aermel = Color("201818")
	_arm.mass = 1.25
	await _arm.ausstrecken(k.global_position + Vector2(0, -130))
	await _arm.fuehren(k.global_position + Vector2(0, -50), 0.08, Tween.TRANS_QUAD, Tween.EASE_IN)
	k.zustand_setzen(mal)
	k.stossen(0.2)
	KartenKlang.spielen("ablegen", 0.6)
	KartenKlang.spielen("angriff_sense", 1.3, -10.0)
	KartenKlang.fuehlen(30, 0.6)
	_schweben_text("GEZEICHNET", k.global_position + Vector2(0, -230), TarotStil.GLUT, 0.7)
	await _arm.fuehren(k.global_position + Vector2(0, -120), 0.15)
	await _arm.zurueckziehen(0.35)
	if geist and is_instance_valid(k):
		await _warte(0.5)
		k.ziel_position = STAPEL
		k.ziel_skala = 0.5
		get_tree().create_timer(0.6).timeout.connect(k.queue_free)
	gesperrt = false
	_knopf.disabled = false


## Mond: die Hand zieht ein Sternentuch ueber die ganze Hand.
func _mond_verhuellt() -> void:
	_arm_seite = -1.0
	_arm.aermel = Color("2B3266")
	_arm.mass = 1.25
	_buehne.greif_haltung(true, -1.0)
	KartenKlang.spielen("angriff_schleier", 1.0, -4.0)
	await _arm.ausstrecken(Vector2(110, 1330), 0.4)
	var t := create_tween()
	t.tween_property(_arm, "tuch", 1.0, 0.3)
	await _arm.fuehren(Vector2(990, 1360), 0.9)
	var t2 := create_tween()
	t2.tween_property(_arm, "tuch", 0.0, 0.35)
	_buehne.greif_haltung(false)
	await _arm.zurueckziehen(0.45)


## Steinsplitter, wo der Turm zuschlaegt.
func _truemmer(ort: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = ort
	p.z_index = 340
	p.one_shot = true
	p.emitting = true
	p.amount = 26
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.gravity = Vector2(0, 1400)
	p.initial_velocity_min = 380.0
	p.initial_velocity_max = 760.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 16.0
	p.color = Color("7A6E60")
	_welt.add_child(p)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ Selbst spielen
## Spielt Zuege wie ein Mensch: der Handschuh zieht die Karten der besten
## Legung (Autopilot-Vorschlag) auf die Plaetze und drueckt den Knopf.
## Fuer Vorfuehrungen, Videos und Laufzeittests.
func selbst_spielen(max_zuege := 40, zeige_hand := true) -> void:
	_tisch.skript_modus = true
	_handschuh.visible = zeige_hand
	_tisch.zeiger_bewegen(Vector2(900, 1300))
	while gesperrt:
		await _warte(0.1)
	var zuege := 0
	while not _fertig and zuege < max_zuege and is_inside_tree():
		zuege += 1
		if bool(_kampf.get("pakt", false)):
			game.answer_pact(false)
			_abgleichen()
		for v in kern.vorschlag():
			var k: TarotKarte = _karten.get(v["instanz"], null)
			if k != null and k in _tisch.hand:
				await _ziehen(k, int(v["platz"]))
		await _warte(0.3)
		if _tisch.legung().is_empty() and not _tisch.hand.is_empty():
			await _ziehen(_tisch.hand[0], 1 if int(_kampf["gesperrt"]) != 1 else 0)
		await _zeiger_zu(_knopf.position + _knopf.size * 0.5, 0.4)
		_handschuh.gedrueckt = true
		await _warte(0.1)
		_handschuh.gedrueckt = false
		_zeiger_zu(Vector2(1000, 1880), 0.5)
		ausfuehren()
		await _warte(0.2)
		while gesperrt and not _fertig:
			await _warte(0.1)
	_tisch.skript_modus = false


## Fuer Vorfuehrungen: langes Druecken auf eine Handkarte, dann mit dem
## Finger kreisen (die grosse Karte kippt, die Folie wandert), loslassen.
func lang_druecken_vorfuehren(index := 0, dauer := 2.6) -> void:
	if _tisch.hand.is_empty():
		return
	_tisch.skript_modus = true
	_handschuh.visible = true
	var k := _tisch.hand[clampi(index, 0, _tisch.hand.size() - 1)]
	await _zeiger_zu(k.global_position, 0.4)
	_tisch.zeiger_druecken()
	_handschuh.gedrueckt = true
	await _warte(0.6)
	var mitte := _tisch.zeiger
	var t := create_tween()
	t.tween_method(func(w): _tisch.zeiger_bewegen(mitte + Vector2(cos(w * TAU), sin(w * TAU * 2.0) * 0.6) * 120.0), 0.0, 1.0, dauer)
	await t.finished
	_tisch.zeiger_loslassen()
	_handschuh.gedrueckt = false
	await _warte(0.3)
	_tisch.skript_modus = false


func _zeiger_zu(ziel: Vector2, dauer: float, bogen := 0.0) -> void:
	var start := _tisch.zeiger
	var t := create_tween()
	t.tween_method(func(w):
		var p := start.lerp(ziel, w) + Vector2(0, -sin(w * PI) * bogen)
		_tisch.zeiger_bewegen(p), 0.0, 1.0, dauer).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _ziehen(k: TarotKarte, platz: int) -> void:
	await _zeiger_zu(k.global_position, 0.3)
	_tisch.zeiger_druecken()
	_handschuh.gedrueckt = true
	await _warte(0.06)
	await _zeiger_zu(_tisch.plaetze[platz].global_position, 0.45, 80.0)
	await _warte(0.08)
	_tisch.zeiger_loslassen()
	_handschuh.gedrueckt = false
	await _warte(0.2)
