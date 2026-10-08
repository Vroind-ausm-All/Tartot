extends Node2D
## Karten-Galerie: zeigt Vorderseiten in allen Zustaenden (Motiv, Sinnbilder,
## Hof, Arkana ohne Motiv, umgekehrt, Stufe, Schimmer, Editionen, verhuellt,
## gezeichnet) und speichert ein Bildschirmfoto. Nur zum Anschauen:
##   xvfb-run godot --path godot-next --rendering-driver opengl3 res://tests/karten_galerie.tscn -- --foto=/pfad.png

const KARTEN := [
	{"id": "major_18", "instanz": "a"},
	{"id": "major_21", "instanz": "b", "edition": "Glowing"},
	{"id": "major_0", "instanz": "c"},
	{"id": "swords_7", "instanz": "d", "umgekehrt": true},
	{"id": "cups_5", "instanz": "e", "stufe": 3, "schimmer": 2},
	{"id": "pentacles_10", "instanz": "f", "edition": "Shimmering"},
	{"id": "wands_13", "instanz": "g", "schimmer": 3},
	{"id": "swords_12", "instanz": "h", "gezeichnet": 2},
	{"id": "major_16", "instanz": "i", "edition": "Burning"},
	{"id": "cups_1", "instanz": "j"},
	{"id": "pentacles_3", "instanz": "k", "verschleiert": true},
	{"id": "major_10", "instanz": "l", "schimmer": 4},
]

var _karten: Array[TarotKarte] = []
var _zeit := 0.0


func _ready() -> void:
	var grund := ColorRect.new()
	grund.size = Vector2(1080, 1920)
	grund.material = ShaderMaterial.new()
	grund.material.shader = load("res://ui/tisch/filmgrund.gdshader")
	add_child(grund)
	for i in KARTEN.size():
		var k := TarotKarte.aus_daten(KARTEN[i])
		@warning_ignore("integer_division")
		k.position = Vector2(200 + (i % 3) * 340, 260 + (i / 3) * 450)
		k.basis = 1.15
		add_child(k)
		_karten.append(k)
	var foto := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--foto="):
			foto = a.trim_prefix("--foto=")
	await get_tree().create_timer(1.2).timeout
	if foto != "":
		get_viewport().get_texture().get_image().save_png(foto)
		print("GALERIE: Foto ", foto)
		get_tree().quit()


func _process(delta: float) -> void:
	_zeit += delta
	# Ein paar Karten unter einen gedachten Finger legen: Neigung, Folie, Parallaxe.
	for i in _karten.size():
		var k := _karten[i]
		if i % 2 == 0:
			k.schwebt = true
			k.zeiger_setzen(k.global_position + Vector2(cos(_zeit + i), sin(_zeit * 0.7 + i)) * 110.0)
