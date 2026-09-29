extends Node2D
## Galerie: dieselbe Vorlage in allen Editionen und Seltenheiten nebeneinander.
## godot --path godot-karten res://demo/galerie.tscn

const SCHRIFT := "res://addons/tartot_karten/schrift/"
const REIHEN := [
	["EDITIONEN", [["major_19", ""], ["major_19", "Shimmering"], ["major_19", "Glowing"], ["major_19", "Burning"], ["major_19", "Glass"]],
		["ohne", "Schimmernd", "Leuchtend", "Brennend", "Gläsern"]],
	["SELTENHEIT", [["swords_7", ""], ["cups_12", ""], ["major_13", ""], ["major_21", ""]],
		["Gewöhnlich", "Ungewöhnlich", "Selten", "Legendär"]],
]

var _karten: Array[TarotKarte] = []
var _zeit := 0.0


func _ready() -> void:
	var grund := ColorRect.new()
	grund.color = Color("241C17")
	grund.size = Vector2(1080, 1920)
	add_child(grund)
	# ein Muster hinter den Karten, damit man das Glas sieht
	for i in 14:
		var streifen := ColorRect.new()
		streifen.color = Color("3B4A8C") if i % 2 == 0 else Color("B3262B")
		streifen.position = Vector2(-200 + i * 110, 380)
		streifen.size = Vector2(40, 520)
		streifen.rotation = 0.35
		add_child(streifen)
	var y := 520.0
	for reihe in REIHEN:
		add_child(_label(reihe[0], 52, Vector2(0, y - 330)))
		var n: int = reihe[1].size()
		for i in n:
			var k := TarotKarte.erzeugen(reihe[1][i][0], reihe[1][i][1])
			k.position = Vector2(540 + (i - (n - 1) * 0.5) * 205, y)
			k.ziel_position = k.position
			k.ziel_skala = 0.82
			k.scale = Vector2(0.82, 0.82)
			add_child(k)
			_karten.append(k)
			add_child(_label(reihe[2][i], 30, Vector2(k.position.x - 100 - 440, y + 170), 200))
		y += 780.0


func _label(text: String, groesse: int, pos: Vector2, breite := 1080.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos + (Vector2(440, 0) if breite < 1080.0 else Vector2.ZERO)
	l.size = Vector2(breite, groesse * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(SCHRIFT + ("AbrilFatface.ttf" if groesse > 40 else "Jersey10.ttf")))
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", Color("EFE3C8"))
	return l


func _process(delta: float) -> void:
	_zeit += delta
	# ein gemeinsamer "Finger", der langsam kreist - alle Karten kippen ihm entgegen
	for k in _karten:
		k.schwebt = true
		k.zeiger_relativ = Vector2(sin(_zeit * 1.1), cos(_zeit * 0.8) * 0.6)
	if OS.get_cmdline_user_args().has("--autoplay") and _zeit > 6.0:
		get_tree().quit()
