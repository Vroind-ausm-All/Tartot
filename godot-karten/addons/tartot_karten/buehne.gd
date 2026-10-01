class_name BossBuehne
extends Control
## Die Buehne ueber dem Tisch: Bühnenbild, Figur, Effekte.
##
## Die Figur ist ein einziges gemaltes Bild (aus tools/buehne/zerlegen.py).
## Bewegt wird sie wie eine Gummischlauch-Puppe der Fleischer-Zeit:
##
## - Jede Groesse (Lage, Drehung, Stauchung, Biegung, Beule, Welle) haengt
##   an einer leicht unterdaempften Feder. Bewegungen setzen nur Ziele -
##   die Federn machen daraus fliessende Uebergaenge mit Nachschwingen.
## - In Ruhe hopst, schwebt oder wiegt sich die Figur, im Takt der Musik.
## - Angriffe folgen dem Dreiklang des Zeichentricks: Ausholen (stauchen,
##   zuruecklehnen), Schlag (strecken, nach vorn), Nachschwingen.
##
## Was je Boss passiert, steht in Choreografie. Fuer Gegner ohne gemalte
## Figur zeigt die Buehne die Blockout-Animation vor dem Bild des Akts.

signal spieler_getroffen(staerke: float)

const BUEHNEN := "res://buehnen/"
const GEGNER := "res://demo/gegner/"
const RAND := 90
const AKT_BUEHNEN := ["boss_turm", "boss_turm", "boss_rad", "boss_tod", "boss_sonne", "boss_tod"]

var boss_id := ""
var cfg := {}
var phase_zwei := false
var tot := false
var effekte: BuehnenEffekte

# Ziele, die Bewegungen setzen (Versatz zur Ruhebewegung) - die Federn folgen.
var a_x := 0.0
var a_y := 0.0
var a_rot := 0.0
var a_sx := 0.0
var a_sy := 0.0
var a_biegen := 0.0
var a_beule := 0.0
var a_welle := 0.0

var _kamera: Node2D
var _hinten: Sprite2D
var _staub: CPUParticles2D
var _schatten: Node2D
var _figur_knoten: Node2D
var _figur: Node2D
var _mat: ShaderMaterial
var _textur: Texture2D
var _vignette: Control
var _skala := 1.0
var _versatz := Vector2.ZERO
var _fuss := Vector2.ZERO
var _mitte := Vector2.ZERO
var _oben := Vector2.ZERO
var _hoehe := 500.0
var _gemalt := true

# Federn: [Wert, Tempo]
var _f := {}
var _zeit := 0.0
var _tempo := 1.0
var _wackeln := 0.0
var _zoom := 0.0
var _blitz := 0.0
var _toenung := 0.0
var _aura := 0.0
var _aufloesen := 0.0
var _beschaeftigt := false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kamera = Node2D.new()
	add_child(_kamera)
	effekte = BuehnenEffekte.new()
	effekte.einschlag.connect(func(s): spieler_getroffen.emit(s))
	_vignette = Control.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.draw.connect(_vignette_zeichnen)
	add_child(_vignette)
	for k in ["x", "y", "rot", "sx", "sy", "biegen", "beule", "welle"]:
		_f[k] = [1.0 if k in ["sx", "sy"] else 0.0, 0.0]


# ------------------------------------------------------------------ Laden
## Laedt die Buehne eines Gegners. sprite_id wie im Kern (AnimationCues.SpriteId),
## akt fuer das Ersatzbild, wenn es keine gemalte Figur gibt.
func laden(sprite_id: String, akt := 1) -> void:
	for kind in _kamera.get_children():
		# Die Effekt-Ebene bleibt; nur ihre laufenden Wirkungen gehen.
		if kind == effekte:
			for w in effekte.get_children():
				w.queue_free()
			continue
		kind.queue_free()
	boss_id = sprite_id
	cfg = Choreografie.von(sprite_id)
	phase_zwei = false
	tot = false
	_tempo = 1.0
	_toenung = 0.0
	_aura = 0.0
	_aufloesen = 0.0
	for k in _f:
		_f[k] = [1.0 if k in ["sx", "sy"] else 0.0, 0.0]
	for p in ["a_x", "a_y", "a_rot", "a_sx", "a_sy", "a_biegen", "a_beule", "a_welle"]:
		set(p, 0.0)

	var ordner := BUEHNEN + sprite_id + "/"
	_gemalt = ResourceLoader.exists(ordner + "figur.png")
	var bild_ordner: String = ordner if _gemalt else BUEHNEN + AKT_BUEHNEN[clampi(akt, 0, AKT_BUEHNEN.size() - 1)] + "/"
	var hinten_pfad := bild_ordner + "hintergrund.jpg"
	if not ResourceLoader.exists(hinten_pfad):
		hinten_pfad = bild_ordner + "hintergrund.png"
	var hinten_tex: Texture2D = load(hinten_pfad)
	_hinten = Sprite2D.new()
	_hinten.texture = hinten_tex
	_hinten.centered = false
	var bild_groesse := hinten_tex.get_size()
	_skala = maxf(size.x / bild_groesse.x, size.y / bild_groesse.y) * 1.04
	_versatz = (size - bild_groesse * _skala) * 0.5
	_hinten.scale = Vector2(_skala, _skala)
	_hinten.position = _versatz
	if not _gemalt:
		_hinten.modulate = Color(0.62, 0.56, 0.5)
	_kamera.add_child(_hinten)

	_schatten = Node2D.new()
	_schatten.draw.connect(func():
		var flach := clampf(1.0 + _f["y"][0] / 300.0, 0.3, 1.2)
		_schatten.draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.22))
		_schatten.draw_circle(Vector2.ZERO, _hoehe * 0.32 * flach, Color(0, 0, 0, 0.42 * flach * (1.0 - _aufloesen))))
	_kamera.add_child(_schatten)

	_figur_knoten = Node2D.new()
	_kamera.add_child(_figur_knoten)
	if _gemalt:
		_figur_laden(ordner)
	else:
		_blockout_laden(sprite_id, akt)

	_staub = CPUParticles2D.new()
	_staub.amount = 36
	_staub.lifetime = 9.0
	_staub.preprocess = 9.0
	_staub.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_staub.emission_rect_extents = size * 0.5
	_staub.position = size * 0.5
	_staub.direction = Vector2(0.3, -1)
	_staub.spread = 60.0
	_staub.gravity = Vector2(0, -4)
	_staub.initial_velocity_min = 4.0
	_staub.initial_velocity_max = 14.0
	_staub.scale_amount_min = 1.5
	_staub.scale_amount_max = 4.0
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(1, 0.95, 0.82, 0.0))
	verlauf.add_point(0.3, Color(1, 0.95, 0.82, 0.35))
	verlauf.set_color(verlauf.get_point_count() - 1, Color(1, 0.95, 0.82, 0.0))
	_staub.color_ramp = verlauf
	_kamera.add_child(_staub)

	effekte.groesse = size
	if effekte.get_parent():
		effekte.get_parent().remove_child(effekte)
	_kamera.add_child(effekte)
	move_child(_vignette, -1)


func _figur_laden(ordner: String) -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ordner + "figur.json"))
	var roh: Texture2D = load(ordner + "figur.png")
	var bild := roh.get_image()
	if bild.is_compressed():
		bild.decompress()
	bild.convert(Image.FORMAT_RGBA8)
	var gross := Image.create(bild.get_width() + RAND * 2, bild.get_height() + RAND * 2, false, Image.FORMAT_RGBA8)
	gross.blit_rect(bild, Rect2i(Vector2i.ZERO, bild.get_size()), Vector2i(RAND, RAND))
	_textur = ImageTexture.create_from_image(gross)

	var fig: Array = info["figur"]
	var fuss: Array = info["fuss"]
	var schwer: Array = info["schwerpunkt"]
	var figur_pos := Vector2(fig[0], fig[1])
	_fuss = _versatz + Vector2(fuss[0], fuss[1]) * _skala
	_mitte = _versatz + Vector2(schwer[0], schwer[1]) * _skala
	_oben = _versatz + Vector2(fuss[0], fig[1]) * _skala
	_hoehe = float(fig[3]) * _skala

	var s := Sprite2D.new()
	s.texture = _textur
	s.centered = false
	s.offset = -(Vector2(fuss[0], fuss[1]) - figur_pos + Vector2(RAND, RAND))
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://addons/tartot_karten/shader/figur.gdshader")
	var tg := Vector2(_textur.get_size())
	_mat.set_shader_parameter("rand_min", Vector2(RAND, RAND) / tg)
	_mat.set_shader_parameter("rand_max", (tg - Vector2(RAND, RAND)) / tg)
	var schwer_rel := (Vector2(schwer[0], schwer[1]) - figur_pos) / Vector2(fig[2], fig[3])
	_mat.set_shader_parameter("beule_mitte", schwer_rel)
	_mat.set_shader_parameter("toenung_farbe", cfg["zweite"])
	_mat.set_shader_parameter("aura_farbe", cfg["farbe"])
	s.material = _mat
	_figur = s
	_figur_knoten.add_child(s)
	_figur_knoten.scale = Vector2(_skala, _skala)
	_figur_knoten.position = _fuss
	_schatten.position = _fuss


func _blockout_laden(sprite_id: String, _akt: int) -> void:
	_mat = null
	var anim: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GEGNER + "anim.json"))
	var eintrag: Dictionary = anim.get(sprite_id, {})
	var bilder := SpriteFrames.new()
	bilder.remove_animation("default")
	var g := int(eintrag.get("size", 120))
	for zustand in eintrag.get("states", {}):
		var streifen: Texture2D = load(GEGNER + "%s_%s.png" % [sprite_id, zustand])
		if streifen == null:
			continue
		bilder.add_animation(zustand)
		bilder.set_animation_speed(zustand, float(eintrag.get("fps", 12)))
		bilder.set_animation_loop(zustand, zustand == "idle")
		for i in int(eintrag["states"][zustand]):
			var a := AtlasTexture.new()
			a.atlas = streifen
			a.region = Rect2(i * g, 0, g, g)
			bilder.add_frame(zustand, a)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = bilder
	s.centered = false
	s.offset = Vector2(-g * 0.5, -g * 0.92)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.animation_finished.connect(func():
		if s.animation != "death" and bilder.has_animation("idle"):
			s.play("idle"))
	if bilder.has_animation("idle"):
		s.play("idle")
	_figur = s
	_figur_knoten.add_child(s)
	var hoch := size.y * 0.62
	_skala = hoch / g
	_fuss = Vector2(size.x * 0.5, size.y * 0.9)
	_hoehe = hoch * 0.85
	_mitte = _fuss - Vector2(0, _hoehe * 0.5)
	_oben = _fuss - Vector2(0, _hoehe)
	_figur_knoten.scale = Vector2(_skala, _skala)
	_figur_knoten.position = _fuss
	_schatten.position = _fuss


func _blockout(zustand: String) -> void:
	if _figur is AnimatedSprite2D:
		var a := _figur as AnimatedSprite2D
		if a.sprite_frames.has_animation(zustand):
			a.play(zustand)
		elif zustand.begins_with("attack") and a.sprite_frames.has_animation("attack"):
			a.play("attack")


# ------------------------------------------------------------------ Takt
func _process(delta: float) -> void:
	if _figur_knoten == null:
		return
	_zeit += delta * _tempo
	var ruhe := _ruhe()
	var ziele := {
		"x": ruhe["x"] + a_x, "y": ruhe["y"] + a_y, "rot": ruhe["rot"] + a_rot,
		"sx": ruhe["sx"] + a_sx, "sy": ruhe["sy"] + a_sy, "biegen": ruhe["biegen"] + a_biegen,
		"beule": a_beule, "welle": ruhe["welle"] + a_welle,
	}
	for k in _f:
		var steif := 230.0 if k in ["x", "y", "rot", "sx", "sy"] else 150.0
		var daempf := 13.0 if k in ["x", "y", "rot", "sx", "sy"] else 8.0
		var w: Array = _f[k]
		w[1] += (ziele[k] - w[0]) * steif * delta
		w[1] *= exp(-daempf * delta)
		w[0] += w[1] * delta

	_figur_knoten.position = _fuss + Vector2(_f["x"][0], _f["y"][0])
	_figur_knoten.rotation = _f["rot"][0]
	_figur_knoten.scale = Vector2(_f["sx"][0], _f["sy"][0]) * _skala
	_blitz = maxf(0.0, _blitz - delta * 5.0)
	if _mat:
		_mat.set_shader_parameter("biegen", _f["biegen"][0])
		_mat.set_shader_parameter("beule", _f["beule"][0])
		_mat.set_shader_parameter("welle_hoehe", _f["welle"][0])
		_mat.set_shader_parameter("welle_phase", _zeit * 5.0)
		_mat.set_shader_parameter("zeit", _zeit)
		_mat.set_shader_parameter("blitz", _blitz)
		_mat.set_shader_parameter("toenung", _toenung)
		_mat.set_shader_parameter("aura", _aura * (0.75 + 0.25 * sin(_zeit * 6.0)))
		_mat.set_shader_parameter("aufloesen", _aufloesen)
	elif _figur:
		_figur.modulate = Color(1, 1, 1, 1.0 - _aufloesen).lerp(Color(3, 3, 3, 1), _blitz)

	# Kamera: Wackeln und kurzer Zoom bei Schlaegen, Buehnenbild mit leichter Tiefe.
	_wackeln = maxf(0.0, _wackeln - delta * 38.0)
	_zoom = lerpf(_zoom, 0.0, 1.0 - exp(-6.0 * delta))
	var z := 1.0 + _zoom
	_kamera.scale = Vector2(z, z)
	_kamera.position = size * 0.5 * (1.0 - z) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _wackeln
	_hinten.position = _versatz - Vector2(_f["x"][0] * 0.05, _f["y"][0] * 0.03) + Vector2(sin(_zeit * 0.21), cos(_zeit * 0.17)) * 4.0
	_schatten.queue_redraw()


## Die Ruhebewegung, im Takt der Musik.
func _ruhe() -> Dictionary:
	var r := {"x": 0.0, "y": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0, "biegen": 0.0, "welle": 0.0}
	if tot:
		return r
	var schlag := KartenKlang.schlaege() * (1.25 if phase_zwei else 1.0)
	var staerke := 1.4 if phase_zwei else 1.0
	match cfg.get("art", "wiegen"):
		"stampfen":
			var ph := fmod(schlag, 1.0)
			var hops := sin(ph * PI)
			var auf := pow(1.0 - hops, 4.0)
			r["y"] = -hops * 20.0 * staerke
			r["sy"] = 1.0 - 0.06 * auf * staerke + 0.025 * hops
			r["sx"] = 1.0 + 0.05 * auf * staerke
			r["biegen"] = 0.03 * sin(schlag * PI) * staerke
			r["welle"] = 0.004
		"schweben":
			r["y"] = sin(_zeit * 1.7) * 18.0 * staerke
			r["rot"] = sin(_zeit * 0.8) * 0.025
			r["biegen"] = sin(_zeit * 1.2) * 0.02 * staerke
			r["sy"] = 1.0 + sin(_zeit * 3.4) * 0.012
			r["sx"] = 1.0 - sin(_zeit * 3.4) * 0.008
			r["welle"] = 0.006 * staerke
		_:
			r["rot"] = sin(schlag * TAU / 6.0) * 0.035 * staerke
			r["biegen"] = -sin(schlag * TAU / 6.0) * 0.025 * staerke
			r["y"] = -absf(sin(schlag * PI)) * 6.0
			r["sy"] = 1.0 + 0.018 * sin(schlag * TAU / 3.0)
			r["sx"] = 1.0 - 0.012 * sin(schlag * TAU / 3.0)
			r["welle"] = 0.003
	return r


# ------------------------------------------------------------------ Bewegungen
func _ziel(werte: Dictionary, dauer: float, uebergang := Tween.TRANS_SINE, art := Tween.EASE_OUT) -> Tween:
	var t := create_tween().set_parallel()
	for k in werte:
		t.tween_property(self, k, werte[k], dauer).set_trans(uebergang).set_ease(art)
	return t


func _zurueck(dauer := 0.4) -> void:
	await _ziel({"a_x": 0.0, "a_y": 0.0, "a_rot": 0.0, "a_sx": 0.0, "a_sy": 0.0, "a_biegen": 0.0, "a_beule": 0.0, "a_welle": 0.0}, dauer).finished


func _warte(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Ein Angriff nach einem Hinweis aus dem Kern ("attack", "attack1", "summon", ...).
func angreifen(hinweis: String) -> void:
	if tot or _figur_knoten == null:
		return
	if hinweis == "supernova":
		await _supernova()
		return
	var plan := Choreografie.angriff(boss_id, hinweis)
	var bewegung: String = plan[0]
	var effekt: String = plan[1]
	var klang: String = plan[2]
	_blockout(hinweis)
	_beschaeftigt = true
	var schlag := func():
		KartenKlang.spielen("angriff_" + klang, 0.85 if phase_zwei else 1.0, 2.0, 0.03)
		_effekt(effekt)
	match bewegung:
		"sprung":
			await _sprung(schlag)
		"drehung":
			await _drehung(schlag)
		"recken":
			await _recken(schlag)
		"ansturm":
			await _ansturm(schlag)
		"wirbel":
			await _wirbel(schlag)
		"bruellen":
			await _bruellen(schlag)
		_:
			await _ausfall(schlag)
	_beschaeftigt = false


func _ausfall(schlag: Callable) -> void:
	KartenKlang.spielen("ausholen", 1.0, -4.0)
	await _ziel({"a_sy": -0.15, "a_sx": 0.11, "a_biegen": -0.11, "a_y": 16.0, "a_rot": -0.05}, 0.32).finished
	await _ziel({"a_sy": 0.2, "a_sx": 0.04, "a_biegen": 0.16, "a_y": 46.0, "a_rot": 0.04, "a_beule": 0.12}, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN).finished
	_zoom = 0.06
	_wackeln = 14.0
	schlag.call()
	await _warte(0.22)
	await _zurueck(0.45)


func _sprung(schlag: Callable) -> void:
	await _ziel({"a_sy": -0.22, "a_sx": 0.16}, 0.22).finished
	KartenKlang.spielen("sprung")
	await _ziel({"a_y": -170.0, "a_sy": 0.22, "a_sx": -0.12, "a_rot": 0.06}, 0.26, Tween.TRANS_QUAD, Tween.EASE_OUT).finished
	await _warte(0.08)
	await _ziel({"a_y": 10.0, "a_sy": 0.1, "a_sx": -0.06, "a_rot": 0.0}, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN).finished
	KartenKlang.spielen("landen")
	_ziel({"a_sy": -0.26, "a_sx": 0.22, "a_y": 0.0}, 0.06)
	_wackeln = 22.0
	_zoom = 0.05
	effekte.rauch(_fuss + Vector2(0, -10), 8, 1.1)
	schlag.call()
	await _warte(0.3)
	await _zurueck(0.4)


func _drehung(schlag: Callable) -> void:
	await _ziel({"a_rot": -0.35, "a_sy": -0.1, "a_sx": 0.08, "a_biegen": -0.1}, 0.28).finished
	KartenKlang.spielen("drehung")
	var t := _ziel({"a_rot": TAU, "a_sy": 0.12, "a_sx": -0.06, "a_biegen": 0.12, "a_welle": 0.02}, 0.55, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	await _warte(0.28)
	schlag.call()
	_wackeln = 10.0
	await t.finished
	# eine volle Drehung ist keine Drehung: Ziel und Feder gemeinsam zuruecksetzen
	a_rot -= TAU
	_f["rot"][0] -= TAU
	await _zurueck(0.45)


func _recken(schlag: Callable) -> void:
	KartenKlang.spielen("recken", 1.0, -4.0)
	var aura_vorher := _aura
	var t := create_tween()
	t.tween_property(self, "_aura", 1.0, 0.3)
	await _ziel({"a_y": -40.0, "a_sy": 0.15, "a_sx": -0.07, "a_beule": 0.14, "a_biegen": -0.04}, 0.36).finished
	_zoom = 0.04
	schlag.call()
	await _warte(0.5)
	create_tween().tween_property(self, "_aura", aura_vorher, 0.5)
	await _zurueck(0.5)


func _ansturm(schlag: Callable) -> void:
	await _ziel({"a_y": -24.0, "a_sx": -0.06, "a_sy": -0.06, "a_biegen": -0.12}, 0.26).finished
	await _ziel({"a_y": 150.0, "a_sx": 0.5, "a_sy": 0.48, "a_biegen": 0.06}, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN).finished
	_wackeln = 26.0
	_zoom = 0.08
	schlag.call()
	await _warte(0.2)
	await _zurueck(0.5)


func _wirbel(schlag: Callable) -> void:
	_ziel({"a_welle": 0.035, "a_sy": 0.06}, 0.2)
	for i in 6:
		await _ziel({"a_rot": 0.09 if i % 2 == 0 else -0.09, "a_x": 14.0 if i % 2 == 0 else -14.0}, 0.07).finished
		if i == 2:
			schlag.call()
	await _zurueck(0.4)


func _bruellen(schlag: Callable) -> void:
	await _ziel({"a_sy": -0.1, "a_sx": 0.08, "a_y": 10.0}, 0.25).finished
	await _ziel({"a_sy": 0.14, "a_sx": 0.14, "a_beule": 0.26, "a_welle": 0.03}, 0.12).finished
	effekte.tempo(_mitte, 0.8)
	for i in 6:
		_wackeln = 16.0
		await _warte(0.08)
	schlag.call()
	await _zurueck(0.5)


# ------------------------------------------------------------------ Effekte
func _effekt(name: String) -> void:
	var farbe: Color = cfg["farbe"]
	var zweite: Color = cfg["zweite"]
	var unten := Vector2(size.x * 0.5, size.y + 40)
	match name:
		"blitz":
			effekte.blitz(_oben + Vector2(0, 40), unten + Vector2(randf_range(-160, 160), 0), farbe)
			get_tree().create_timer(0.16).timeout.connect(func():
				effekte.blitz(_oben + Vector2(-30, 80), Vector2(size.x * randf_range(0.1, 0.9), size.y + 40), zweite, false))
		"steine":
			effekte.regen("steine", 16)
			effekte.rauch(Vector2(size.x * 0.5, size.y - 20), 9, 1.3)
		"strahlen":
			effekte.strahlen(_mitte, 16, farbe)
			effekte.blitzlicht(farbe, 0.35)
		"wasser":
			effekte.welle(Color("3B6DB7"))
		"feuer":
			effekte.feuerringe(_mitte, Color("E0543A"))
		"mischen":
			effekte.welle(Color("3B6DB7"), 0.45)
			get_tree().create_timer(0.3).timeout.connect(func(): effekte.feuerringe(_mitte, Color("E0543A")))
		"tropfen":
			effekte.regen("tropfen", 18, Color("4B7FC4"))
		"segen":
			effekte.strahlen(_mitte, 10, farbe, 0.8, 1.2)
			effekte.kugeln(_mitte, 6, farbe, _hoehe * 0.42)
		"saeulen":
			effekte.saeulen(4, farbe)
		"helfer":
			_helfer(false)
		"geister":
			_helfer(true)
		"wuerfel":
			effekte.regen("wuerfel", 10, Color.WHITE, true)
		"kette":
			effekte.kette(_mitte + Vector2(-_hoehe * 0.2, 0), unten)
		"sterne":
			effekte.regen("sterne", 12, farbe, true)
		"nebel":
			effekte.dunkel(1.0, 0.5)
			effekte.welle(Color(0.12, 0.12, 0.2), 0.4, false)
		"orakel":
			effekte.kugeln(_mitte, 5, farbe, _hoehe * 0.38)
		"sonnen":
			effekte.kugeln(_mitte, 6, Color("F49A3A"), _hoehe * 0.45)
		"karten":
			effekte.regen("karten", 16, Color.WHITE, true)
		"sense":
			effekte.hieb(_mitte + Vector2(40, 40), _hoehe * 0.55, -2.7, 0.5, Color("EFE3C8"), 52.0, 0.45)
		"zauberstab":
			effekte.hieb(_mitte, _hoehe * 0.42, -2.2, 0.6, farbe, 26.0)
			effekte.regen("sterne", 8, farbe, true)
		"schwert":
			effekte.hieb(_mitte, _hoehe * 0.48, 2.7, -0.3, Color("D8DCE4"), 44.0, 0.35)
		"muenzen":
			effekte.regen("muenzen", 18)
		"schleier":
			effekte.schleier(Color("3B4A8C"))
		"ranken":
			effekte.ranken(farbe, zweite)
		"fruechte":
			effekte.regen("fruechte", 12, zweite, true)
		"bluete":
			effekte.strahlen(_mitte, 12, zweite, 0.9)
			effekte.regen("blaetter", 18, zweite)
		"ansturm":
			effekte.tempo(_mitte, 0.6)
			effekte.rauch(_fuss, 8, 1.2)
			spieler_getroffen.emit(0.9)
		"radschwung":
			effekte.hieb(_mitte, _hoehe * 0.42, 0.0, TAU * 0.85, farbe, 30.0, 0.5)
			get_tree().create_timer(0.12).timeout.connect(func(): effekte.hieb(_mitte, _hoehe * 0.32, PI, PI + TAU * 0.85, zweite, 24.0, 0.5))
		"peitsche":
			effekte.hieb(_mitte + Vector2(-_hoehe * 0.15, -_hoehe * 0.1), _hoehe * 0.6, -2.9, 0.1, farbe, 16.0, 0.32)
		"funken":
			effekte.funken(_mitte, 30, farbe)
			effekte.ring(_mitte, farbe, 420.0)
			spieler_getroffen.emit(0.6)
		"hieb":
			effekte.hieb(_mitte, _hoehe * 0.42, -2.4, 0.4, Color("EFE3C8"), 36.0)
		_:
			effekte.funken(_mitte, 24, farbe)


## Helfer: drei kleine Abbilder springen aus dem Boden (Geister schweben).
func _helfer(geister: bool) -> void:
	if _textur == null:
		effekte.rauch(Vector2(size.x * 0.5, size.y * 0.85), 6, 1.0)
		return
	for i in 3:
		var mini := Sprite2D.new()
		mini.texture = _textur
		var m := ShaderMaterial.new()
		m.shader = _mat.shader
		for p in ["rand_min", "rand_max", "beule_mitte"]:
			m.set_shader_parameter(p, _mat.get_shader_parameter(p))
		if geister:
			m.set_shader_parameter("silhouette", 0.85)
			m.set_shader_parameter("silhouette_farbe", Color("EFE3C8"))
		m.set_shader_parameter("kochen", 1.6)
		mini.material = m
		var ziel := Vector2(size.x * (0.2 + 0.3 * i), size.y * 0.97)
		mini.position = ziel + Vector2(0, 80)
		mini.scale = Vector2.ZERO
		mini.modulate = Color(1, 1, 1, 0.75 if geister else 1.0)
		effekte.add_child(mini)
		var g := _skala * 0.26
		var t := create_tween()
		t.tween_interval(i * 0.12)
		t.tween_callback(func(): effekte.rauch(ziel + Vector2(0, -40), 5, 0.6))
		t.tween_property(mini, "scale", Vector2(g, g), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(mini, "position", ziel - Vector2(0, _hoehe * 0.26 * 0.5 + (60 if geister else 0)), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for h in 3:
			t.tween_property(mini, "position:y", mini.position.y - 30.0, 0.14).as_relative().set_ease(Tween.EASE_OUT)
			t.tween_property(mini, "position:y", 30.0, 0.14).as_relative().set_ease(Tween.EASE_IN)
		t.tween_property(mini, "position", Vector2(size.x * 0.5, size.y * 1.3), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(mini, "scale", Vector2(g, g) * 2.2, 0.3)
		t.tween_callback(mini.queue_free)
	get_tree().create_timer(1.3).timeout.connect(func(): spieler_getroffen.emit(0.6))


# ------------------------------------------------------------------ Reaktionen
## Die Figur wird getroffen: Blitz, Stauchen, Zurueckschnellen, Comic-Sterne.
func treffer(wucht := 1.0) -> void:
	if tot or _figur_knoten == null:
		return
	_blockout("hit")
	_blitz = 1.0
	_f["sy"][1] -= 3.5 * wucht
	_f["sx"][1] += 2.5 * wucht
	_f["y"][1] -= 380.0 * wucht
	_f["rot"][1] += randf_range(-2.0, 2.0) * wucht
	_f["welle"][1] += 0.5 * wucht
	_f["biegen"][1] += randf_range(-1.5, 1.5) * wucht
	_wackeln = 10.0 + 14.0 * wucht
	effekte.sterne(_mitte + Vector2(0, -_hoehe * 0.25), 5)
	effekte.funken(_mitte, int(16 + 20 * wucht), Color("F4D27A"), 260.0)
	KartenKlang.spielen("gegner_getroffen", lerpf(1.15, 0.8, clampf(wucht, 0, 1)), lerpf(-6.0, 2.0, clampf(wucht, 0, 1)))


## Das Siegel bricht: die wahre Gestalt.
func zweite_phase() -> void:
	if phase_zwei or tot:
		return
	phase_zwei = true
	_blockout("phase2")
	KartenKlang.spielen("phase")
	var t := create_tween().set_parallel()
	t.tween_property(self, "_toenung", 0.38, 0.8)
	t.tween_property(self, "_aura", 0.7, 0.8)
	if _mat:
		_mat.set_shader_parameter("aura_farbe", cfg["zweite"])
	effekte.ring(_mitte, cfg["zweite"], 600.0, 0.8, 30.0)
	effekte.blitzlicht(cfg["zweite"], 0.6, 0.6)
	await _bruellen(func(): effekte.funken(_mitte, 50, cfg["zweite"], 480.0))


## Der Gegner faellt: Stauchen, Drehen, Zerfallen in Rauch und Glut.
func sterben() -> void:
	if tot:
		return
	tot = true
	_blockout("death")
	KartenKlang.spielen("tod")
	_blitz = 1.0
	await _ziel({"a_sy": -0.3, "a_sx": 0.25, "a_y": 20.0}, 0.18).finished
	_ziel({"a_rot": 0.5, "a_sy": 0.1, "a_sx": -0.1, "a_y": -60.0, "a_welle": 0.05}, 0.5, Tween.TRANS_BACK)
	var t := create_tween()
	t.tween_property(self, "_aufloesen", 1.0, 1.3).set_delay(0.25)
	effekte.rauch(_mitte, 12, 1.6)
	effekte.funken(_mitte, 60, Color("F4D27A"), 520.0)
	_wackeln = 24.0
	await t.finished


## Auftritt: die Figur federt aus dem Boden, eine Rauchwolke, ein Tusch.
func auftritt() -> void:
	if _figur_knoten == null:
		return
	a_y = 360.0
	a_sy = -0.4
	a_sx = 0.2
	_f["y"][0] = 420.0
	_aufloesen = 0.0
	KartenKlang.spielen("auftritt")
	effekte.rauch(_fuss + Vector2(0, -30), 10, 1.5)
	await _ziel({"a_y": 0.0, "a_sy": 0.0, "a_sx": 0.0}, 0.45, Tween.TRANS_BACK).finished


## Supernova: alles wird dunkel, die Figur gluehst, dann der Knall.
func _supernova() -> void:
	effekte.dunkel(2.0, 0.92)
	var t := create_tween()
	t.tween_property(self, "_aura", 1.4, 0.9)
	await _ziel({"a_sy": -0.2, "a_sx": -0.2, "a_beule": -0.2}, 0.9).finished
	KartenKlang.spielen("angriff_supernova", 1.0, 3.0, 0.0)
	await _ziel({"a_sy": 0.35, "a_sx": 0.35, "a_beule": 0.35}, 0.08).finished
	effekte.blitzlicht(Color.WHITE, 1.0, 0.7)
	effekte.ring(_mitte, Color("F4C14E"), 900.0, 0.9, 40.0)
	effekte.funken(_mitte, 90, Color("F4D27A"), 700.0)
	effekte.strahlen(_mitte, 24, Color("F4C14E"), 1.1, 1.5)
	_wackeln = 34.0
	_zoom = 0.1
	spieler_getroffen.emit(1.0)
	await _warte(0.4)
	create_tween().tween_property(self, "_aura", 0.0, 0.6)
	await _zurueck(0.6)


# ------------------------------------------------------------------ Rahmen
func _vignette_zeichnen() -> void:
	# Weiche, dunkle Raender wie bei einem Bild im Kinosaal.
	var r := Rect2(Vector2.ZERO, size)
	for i in 18:
		var e := float(i) * 3.0
		_vignette.draw_rect(Rect2(r.position + Vector2(e, e), r.size - Vector2(e, e) * 2), Color(0, 0, 0, 0.055), false, 3.0)
