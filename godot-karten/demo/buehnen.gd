extends Node2D
## Buehnen-Galerie: jeder Boss tritt auf, zeigt alle Angriffe, wird
## getroffen, geht in die zweite Phase und faellt.
##
## godot --path godot-karten res://demo/buehnen.tscn
## Aufnehmen (alle oder einzelne):
##   ... --write-movie f.png --fixed-fps 30 -- --autoplay --boss=boss_turm,boss_sonne

const REIHENFOLGE := ["boss_turm", "boss_hierophant", "boss_magier", "boss_hohepriesterin", "boss_herrscherin",
	"boss_wagen", "boss_kraft", "boss_rad", "boss_tod", "boss_teufel", "boss_mond", "boss_maessigkeit", "boss_sonne"]
const NAMEN := {
	"boss_turm": "XVI · DER TURM", "boss_hierophant": "V · DER HIEROPHANT", "boss_magier": "I · DER MAGIER",
	"boss_hohepriesterin": "II · DIE HOHEPRIESTERIN", "boss_herrscherin": "III · DIE HERRSCHERIN",
	"boss_wagen": "VII · DER WAGEN", "boss_kraft": "VIII · KRAFT", "boss_rad": "X · RAD DES SCHICKSALS",
	"boss_tod": "XIII · DER TOD", "boss_teufel": "XV · DER TEUFEL", "boss_mond": "XVIII · DER MOND",
	"boss_maessigkeit": "XIV · DIE MÄSSIGKEIT", "boss_sonne": "XIX · DIE ROTE SONNE",
}

const EFFEKTE := {
	"blitz": "BLITZSCHLAG", "steine": "STEINREGEN", "strahlen": "STRAHLEN", "wasser": "FLUTWELLE",
	"feuer": "FEUERRINGE", "mischen": "WASSER & FEUER", "tropfen": "QUELLEN", "segen": "SEGEN",
	"saeulen": "SÄULEN DES GLAUBENS", "helfer": "HELFER", "geister": "GEISTER", "wuerfel": "WÜRFELWURF",
	"kette": "KETTENZUG", "sterne": "STERNSCHNUPPEN", "nebel": "NEBEL", "orakel": "ORAKEL",
	"sonnen": "KREISENDE SONNEN", "karten": "KARTENREGEN", "sense": "SENSE", "zauberstab": "ZAUBERSTAB",
	"schwert": "SCHWERT", "muenzen": "MÜNZREGEN", "schleier": "SCHLEIER", "ranken": "RANKEN",
	"fruechte": "FRUCHTREGEN", "bluete": "BLÜTE", "ansturm": "ANSTURM", "radschwung": "RADSCHWUNG",
	"peitsche": "PEITSCHE", "funken": "FUNKEN", "hieb": "HIEB",
}

var _buehne: BossBuehne
var _titel: Label
var _zeile: Label
var _rot := 0.0
var _platzbilder: Array = []


func _ready() -> void:
	var grund := ColorRect.new()
	grund.color = Color("0E0A08")
	grund.size = Vector2(1080, 1920)
	add_child(grund)
	add_child(KartenKlang.new())
	add_child(TarotStil.tafel_knoten(Vector2(40, 30), Vector2(1000, 120)))
	_titel = TarotStil.label("", 56, TarotStil.PAPIER)
	_titel.position = Vector2(40, 46)
	_titel.size = Vector2(1000, 80)
	add_child(_titel)
	add_child(TarotStil.tafel_knoten(Vector2(38, 170), Vector2(1004, 744)))
	_buehne = BossBuehne.new()
	_buehne.position = Vector2(52, 184)
	_buehne.size = Vector2(976, 716)
	add_child(_buehne)
	_buehne.spieler_getroffen.connect(func(s): _rot = maxf(_rot, s))
	add_child(TarotStil.tafel_knoten(Vector2(140, 950), Vector2(800, 130)))
	_zeile = TarotStil.label("", 60, TarotStil.GOLD_HELL)
	_zeile.position = Vector2(140, 970)
	_zeile.size = Vector2(800, 90)
	add_child(_zeile)
	_platzbilder = []
	for i in 3:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.position = Vector2(60 + i * 330, 1130)
		t.size = Vector2(300, 360)
		add_child(t)
		_platzbilder.append(t)
	var unten := TarotStil.label("Fließende Bewegung · Effekte · im Takt der Musik", 34, TarotStil.PAPIER_DUNKEL, true, 0)
	unten.position = Vector2(40, 1540)
	unten.size = Vector2(1000, 60)
	add_child(unten)
	_vorfuehren()


func _process(delta: float) -> void:
	_rot = maxf(0.0, _rot - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	if _rot > 0.01:
		draw_rect(Rect2(0, 1100, 1080, 820), Color(0.7, 0.08, 0.06, 0.35 * _rot))


func _warte(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _vorfuehren() -> void:
	var liste: Array = REIHENFOLGE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--boss="):
			liste = arg.substr(7).split(",")
	var autoplay := OS.get_cmdline_user_args().has("--autoplay")
	KartenKlang.musik("walzer", true)
	for boss in liste:
		_buehne.laden(boss, 1)
		_titel.text = NAMEN.get(boss, boss)
		for i in 3:
			_platzbilder[i].texture = load("res://buehnen/%s/platz_%d.png" % [boss, i])
		_zeile.text = "AUFTRITT"
		await _buehne.auftritt()
		await _warte(1.2)
		for hinweis in Choreografie.alle(boss):
			if hinweis == "supernova":
				continue
			var effekt: String = Choreografie.angriff(boss, hinweis)[1]
			_zeile.text = EFFEKTE.get(effekt, effekt.to_upper())
			await _buehne.angreifen(hinweis)
			await _warte(0.5)
			_zeile.text = "TREFFER"
			_buehne.treffer(0.9)
			await _warte(0.9)
		_zeile.text = "PHASE 2"
		await _buehne.zweite_phase()
		await _warte(0.8)
		if Choreografie.alle(boss).has("supernova"):
			_zeile.text = "SUPERNOVA"
			await _buehne.angreifen("supernova")
			await _warte(0.6)
		else:
			await _buehne.angreifen("attack")
			await _warte(0.5)
		_zeile.text = "BESIEGT"
		await _buehne.sterben()
		await _warte(0.8)
	if autoplay:
		get_tree().quit()
