extends Node2D
## Vorfuehrung des Kartentischs: Hand, Legung, Kaskade, Editionen, Seltenheit.
##
## Spielen: Karten antippen (waehlen) oder auf Vergangenheit, Gegenwart,
## Zukunft ziehen, dann SCHICKSAL AUSFUEHREN.
## Aufnehmen: godot --path godot-karten --write-movie out.png --fixed-fps 30 -- --autoplay
## Dann fuehrt ein Handschuh das Ganze selbst vor und beendet sich.

const HAND := [
	["cups_2", ""], ["major_4", "Glass"], ["swords_7", "Shimmering"], ["major_10", "Glowing"],
	["major_16", "Burning"], ["wands_7", ""], ["major_21", ""],
]
const NACHSCHUB := [
	["major_19", "Shimmering"], ["major_13", ""], ["pentacles_10", "Glowing"], ["major_18", ""],
	["swords_1", ""], ["major_5", "Burning"], ["cups_3", "Glass"], ["wands_5", ""], ["major_17", ""],
	["major_6", ""], ["major_14", "Glowing"], ["major_15", ""], ["major_20", ""], ["major_0", "Shimmering"],
]
const SCHRIFT := "res://addons/tartot_karten/schrift/"
const STAPEL := Vector2(1180, 1560)

var gegner_max := 323
var gegner_lp := 214

var _welt: Node2D
var _tisch: KartenTisch
var _kaskade: WertungsKaskade
var _info: KartenInfo
var _gegner: AnimatedSprite2D
var _lp_fuellung: ColorRect
var _lp_text: Label
var _knopf: Button
var _handschuh: ZeigeHandschuh
var _schwebe: Node2D
var _wackeln := 0.0
var _beschaeftigt := false
var _nachschub_index := 0
var _vorfuehrung := false


func _ready() -> void:
	randomize()
	_vorfuehrung = OS.get_cmdline_user_args().has("--autoplay")
	_bauen()
	if _vorfuehrung:
		_vorfuehren()
	else:
		_austeilen(HAND)


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

	_welt.add_child(_label("AKT I · JAHRMARKT DER OMEN", "Jersey10.ttf", 38, Color("C9B48E"), Vector2(0, 26), 1080))
	_welt.add_child(_label("XVI · DER TURM", "AbrilFatface.ttf", 60, Color("EFE3C8"), Vector2(0, 62), 1080))

	_gegner = AnimatedSprite2D.new()
	_gegner.sprite_frames = _gegner_bilder()
	_gegner.position = Vector2(540, 400)
	_gegner.scale = Vector2(2.2, 2.2)
	_gegner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gegner.play("idle")
	_gegner.animation_finished.connect(func():
		if _gegner.animation != "death":
			_gegner.play("idle"))
	_welt.add_child(_gegner)

	var lp_grund := ColorRect.new()
	lp_grund.color = Color("1A1412")
	lp_grund.position = Vector2(150, 628)
	lp_grund.size = Vector2(780, 38)
	_welt.add_child(lp_grund)
	_lp_fuellung = ColorRect.new()
	_lp_fuellung.color = Color("B3262B")
	_lp_fuellung.position = Vector2(4, 4)
	_lp_fuellung.size = Vector2(772.0 * gegner_lp / gegner_max, 30)
	lp_grund.add_child(_lp_fuellung)
	_lp_text = _label("%d / %d" % [gegner_lp, gegner_max], "AlfaSlabOne.ttf", 26, Color("EFE3C8"), Vector2(0, 2), 780)
	lp_grund.add_child(_lp_text)

	_tisch = KartenTisch.new()
	_welt.add_child(_tisch)
	var titel := ["VERGANGENHEIT", "GEGENWART", "ZUKUNFT"]
	var wirkung := ["Wirkung ×0,9", "Mult +0,15", "Wirkung ×1,5 · Mult +0,1"]
	for i in 3:
		var platz := KartenPlatz.new()
		platz.titel = titel[i]
		platz.wirkung = wirkung[i]
		platz.position = Vector2(200 + 340 * i, 912)
		_tisch.add_child(platz)
		_tisch.plaetze.append(platz)
	_tisch.legung_geaendert.connect(func(): _kaskade.vorschau(DemoWertung.rechnen(_tisch.legung())))

	_kaskade = WertungsKaskade.new()
	_kaskade.position = Vector2(60, 1162)
	_kaskade.size = Vector2(620, 230)
	_kaskade.z_index = 250
	_welt.add_child(_kaskade)
	_kaskade.wackeln.connect(func(s): _wackeln = maxf(_wackeln, s))
	_kaskade.treffer.connect(_gegner_treffen)

	_knopf = Button.new()
	_knopf.text = "SCHICKSAL\nAUSFÜHREN"
	_knopf.position = Vector2(716, 1190)
	_knopf.size = Vector2(304, 150)
	_knopf.z_index = 250
	_knopf.add_theme_font_override("font", load(SCHRIFT + "AlfaSlabOne.ttf"))
	_knopf.add_theme_font_size_override("font_size", 34)
	for zustand in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color("7E1B1F") if zustand == "pressed" else Color("B3262B")
		s.border_color = Color("1A1412")
		s.set_border_width_all(5)
		s.set_corner_radius_all(16)
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 6)
		_knopf.add_theme_stylebox_override(zustand, s)
	_knopf.pressed.connect(func(): _ausfuehren())
	_welt.add_child(_knopf)

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


func _label(text: String, schrift: String, groesse: int, farbe: Color, pos: Vector2, breite: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(breite, groesse * 1.3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(SCHRIFT + schrift))
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.add_theme_color_override("font_outline_color", Color("1A1412"))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _gegner_bilder() -> SpriteFrames:
	var bilder := SpriteFrames.new()
	bilder.remove_animation("default")
	for zustand in [["idle", 4, true], ["hit", 3, false], ["attack1", 6, false], ["death", 8, false]]:
		var streifen: Texture2D = load("res://demo/turm/%s.png" % zustand[0])
		bilder.add_animation(zustand[0])
		bilder.set_animation_speed(zustand[0], 12.0)
		bilder.set_animation_loop(zustand[0], zustand[2])
		for i in zustand[1]:
			var ausschnitt := AtlasTexture.new()
			ausschnitt.atlas = streifen
			ausschnitt.region = Rect2(i * 200, 0, 200, 200)
			bilder.add_frame(zustand[0], ausschnitt)
	return bilder


# ------------------------------------------------------------------ Spiel
func _austeilen(liste: Array) -> void:
	for i in liste.size():
		var karte := TarotKarte.erzeugen(liste[i][0], liste[i][1])
		_tisch.austeilen(karte, STAPEL, i * 0.09)


func _nachfuellen() -> void:
	var fehlt := 7 - _tisch.hand.size()
	var neu: Array = []
	for i in fehlt:
		neu.append(NACHSCHUB[_nachschub_index % NACHSCHUB.size()])
		_nachschub_index += 1
	_austeilen(neu)


func _ausfuehren(glas_zerspringt := false) -> void:
	var legung := _tisch.legung()
	if _beschaeftigt or legung.is_empty():
		return
	_beschaeftigt = true
	_knopf.disabled = true
	var ergebnis := DemoWertung.rechnen(legung)
	var karten := {}
	for k in legung.values():
		karten[k.get_instance_id()] = k
	await _kaskade.abspielen(ergebnis["schritte"], karten, gegner_lp)
	await get_tree().create_timer(0.9).timeout
	for k in legung.values():
		_tisch.entfernen(k)
		if k.edition == "Glass" and (glas_zerspringt or randf() < 0.25):
			_schweben_text("ZERSPRUNGEN", k.global_position, Color("C9D6E3"))
			k.aufloesen(0.7, Color("EFE3C8"))
		else:
			k.ziel_position = Vector2(-260, 1000 + randf() * 200)
			k.ziel_rotation = -0.9
			get_tree().create_timer(1.2).timeout.connect(k.queue_free)
	await get_tree().create_timer(0.5).timeout
	_kaskade.zuruecksetzen()
	_nachfuellen()
	_knopf.disabled = false
	_beschaeftigt = false


func _gegner_treffen(schaden: int) -> void:
	gegner_lp = maxi(0, gegner_lp - schaden)
	var t := create_tween()
	t.tween_property(_lp_fuellung, "size:x", 772.0 * gegner_lp / gegner_max, 0.5).set_ease(Tween.EASE_OUT)
	_lp_text.text = "%d / %d" % [gegner_lp, gegner_max]
	_schweben_text("−%d" % schaden, _gegner.global_position + Vector2(120, -120), Color("E0543A"))
	if gegner_lp <= 0:
		_gegner.play("death")
		get_tree().create_timer(2.5).timeout.connect(func():
			gegner_lp = gegner_max
			_lp_fuellung.size.x = 772.0
			_lp_text.text = "%d / %d" % [gegner_lp, gegner_max]
			_gegner.play("idle"))
	else:
		_gegner.play("hit")


func _schweben_text(text: String, ort: Vector2, farbe: Color) -> void:
	var l := _label(text, "AlfaSlabOne.ttf", 56, farbe, ort - Vector2(200, 40), 400)
	_schwebe.add_child(l)
	l.pivot_offset = Vector2(200, 36)
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


func _karte(id: String) -> TarotKarte:
	for k in _tisch.hand:
		if k.id == id:
			return k
	return null


## Im Faecher verdeckt die rechte Nachbarin die rechte Kartenhaelfte:
## sichtbar ist ein Streifen links. Dort anfassen, dann hebt sich die Karte.
func _greifpunkt(k: TarotKarte) -> Vector2:
	return k.global_position + Vector2(-60, 20).rotated(k.rotation)


func _vorfuehren() -> void:
	# Notbremse: eine Vorfuehrung endet immer, auch wenn ein Schritt scheitert.
	get_tree().create_timer(45.0).timeout.connect(func(): get_tree().quit())
	_tisch.skript_modus = true
	_handschuh.visible = true
	_tisch.zeiger_bewegen(Vector2(900, 1300))
	await _warte(0.3)
	_austeilen(HAND)
	await _warte(1.5)

	# ueber die Hand streichen: Neigung, Info, Seltenheit, Editionen
	for k in _tisch.hand.duplicate():
		await _zeiger_zu(_greifpunkt(k), 0.3)
		var besonders: bool = k.edition != "" or k.daten.get("rarity", "") == "Legendary"
		await _zeiger_zu(k.global_position + Vector2(-20, -30), 0.55 if besonders else 0.3)

	# DIE WELT legen: IV + X + 7 = 21
	for zug in [["major_4", 0], ["major_10", 1], ["swords_7", 2]]:
		var k := _karte(zug[0])
		if k == null:
			continue
		await _zeiger_zu(_greifpunkt(k), 0.35)
		await _warte(0.2)
		await _zeiger_zu(k.global_position, 0.12)
		_tisch.zeiger_druecken()
		_handschuh.gedrueckt = true
		await _warte(0.08)
		await _zeiger_zu(_tisch.plaetze[zug[1]].global_position, 0.6, 90.0)
		await _warte(0.12)
		_tisch.zeiger_loslassen()
		_handschuh.gedrueckt = false
		await _warte(0.35)

	await _zeiger_zu(_knopf.position + _knopf.size * 0.5, 0.45)
	_handschuh.gedrueckt = true
	await _warte(0.12)
	_handschuh.gedrueckt = false
	_zeiger_zu(Vector2(1000, 1880), 0.6)
	await _ausfuehren(true)
	await _warte(1.6)
	get_tree().quit()
