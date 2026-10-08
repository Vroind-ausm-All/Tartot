class_name TarotKarte
extends Node2D
## Eine Karte auf dem Tisch - gebaut aus der Vorlage, bewegt wie bei Balatro.
##
## Aufbau: Die Vorderseite (KartenFront: randloses Motiv, Rahmen, Zahl, Name,
## Seltenheit) wird in einem eigenen SubViewport gezeichnet. Dessen Bild zeigt
## ein Sprite mit dem Kartenshader: Neigung, Holo-Folie, Editionen,
## Aufloesen. Darunter liegt ein Schatten.
##
## Bewegung: Die Karte hat Zielwerte (Position, Drehung, Groesse). Sie folgt
## ihnen ueber eine leicht unterdaempfte Feder - daher das Nachschwingen beim
## Einrasten. Beim Ziehen legt sie sich in die Bewegung, im Stillstand wiegt
## sie sich, unter dem Zeiger kippt sie ihm entgegen.

const GROESSE := Vector2(240, 360)
const LUFT := 24
## Die Vorderseite wird doppelt so fein gezeichnet, wie sie im Spiel steht:
## die Malerei der Motive soll auch auf grossen Handys scharf bleiben.
const AUFL := 2
const KUNST := "res://addons/tartot_karten/kunst/"
const TINTE := Color("1A1412")
const PAPIER := Color("EFE3C8")

## Federhaerte und Daempfung. Kleinere Daempfung = mehr Nachschwingen.
@export var feder := 170.0
@export var daempfung := 14.0
@export var feder_gezogen := 900.0
@export var daempfung_gezogen := 34.0
## Wie stark die Karte beim Ziehen in die Bewegung kippt (Bogenmass je Pixel/s).
@export var schwung := 0.0011
## Hoechste Neigung in Grad.
@export var max_neigung := 22.0
## Grundgroesse am Tisch (die Hand zeigt die Karten etwas kleiner als 240 x 360).
var basis := 1.0

var id := ""
## Instanz-Id aus dem Regelkern (leer, wenn die Karte ohne Kern lebt).
var instanz := ""
var daten := {}
var edition := ""
var aufgedeckt := true
## Zustand aus dem Kern (KernBruecke.karte_nach): umgekehrt, Stufe, Schimmer,
## vom Mond verhuellt, vom Tod gezeichnet (Zuege).
var umgekehrt := false
var stufe := 1
var schimmer := 0
var verschleiert := false
var gezeichnet := 0
## Effektiver Rang und Wirkungsfaktor laut Kern (fuer die Erklaerung).
var rang := 0
var faktor := 1.0
var kopie := false
## Gross gezeigt (langes Druecken): die Vorderseite folgt der Neigung laufend.
var gross := false

var ziel_position := Vector2.ZERO
var ziel_rotation := 0.0
var ziel_skala := 1.0
var geschwindigkeit := Vector2.ZERO

var schwebt := false
var gezogen := false
var gewaehlt := false
## Zeiger relativ zur Kartenmitte, -1..1 - daraus wird die Neigung.
var zeiger_relativ := Vector2.ZERO

var _phase := 0.0
var _zeit := 0.0
var _stoss := 0.0
var _stoss_alter := 99.0
var _wendung := 1.0
var _neigung := Vector2.ZERO
var _neu_zeichnen := 6

var _viewport: SubViewport
var _bild: Sprite2D
var _schatten: Sprite2D
var _mat: ShaderMaterial
var _schatten_mat: ShaderMaterial
var _vorderseite: Control
var _front: KartenFront
var _rueckseite: TextureRect
var _schleier: Control
## Holo-Folie je Seltenheit: gewoehnlich keine, legendaer volle Folie.
const HOLO := {"Common": 0.0, "Uncommon": 0.3, "Rare": 0.65, "Legendary": 1.0}


static func erzeugen(karten_id: String, karten_edition := "") -> TarotKarte:
	var k := TarotKarte.new()
	k.id = karten_id
	k.daten = KartenDaten.karte(karten_id)
	k.edition = karten_edition
	return k


## Aus dem Zustand der KernBruecke (karte_nach) bauen.
static func aus_daten(d: Dictionary) -> TarotKarte:
	var k := erzeugen(str(d.get("id", "")), str(d.get("edition", "")))
	k.instanz = str(d.get("instanz", ""))
	k._zustand_lesen(d)
	return k


## Der Zustand als Dictionary (wie KernBruecke.karte_nach) - fuer Kopien.
func zustand() -> Dictionary:
	return {"instanz": instanz, "id": id, "edition": edition, "umgekehrt": umgekehrt, "stufe": stufe,
		"schimmer": schimmer, "verschleiert": verschleiert, "gezeichnet": gezeichnet,
		"rang": rang, "faktor": faktor, "kopie": kopie}


## Neuer Zustand aus dem Kern. Verhuellt der Mond die Karte (oder gibt sie
## frei), dreht sie sich um; alles andere wird nur neu gemalt.
func zustand_setzen(d: Dictionary) -> void:
	var war_verschleiert := verschleiert
	_zustand_lesen(d)
	if _front:
		_front.umgekehrt = umgekehrt
		_front.stufe = stufe
		_front.schimmer = schimmer
		_front.gezeichnet = gezeichnet
		_front.zustand_zeigen()
	if _viewport == null:
		return
	if war_verschleiert != verschleiert and aufgedeckt:
		_wenden(func(): pass)
	else:
		_neu_zeichnen_lassen()


func _zustand_lesen(d: Dictionary) -> void:
	umgekehrt = bool(d.get("umgekehrt", false))
	stufe = int(d.get("stufe", 1))
	schimmer = int(d.get("schimmer", 0))
	verschleiert = bool(d.get("verschleiert", false))
	gezeichnet = int(d.get("gezeichnet", 0))
	rang = int(d.get("rang", daten.get("rank", 0)))
	faktor = float(d.get("faktor", 1.0))
	kopie = bool(d.get("kopie", false))


## Zeigt die Vorderseite nur, wenn die Karte aufgedeckt und nicht verhuellt ist.
func vorderseite_sichtbar() -> bool:
	return aufgedeckt and not verschleiert


func _ready() -> void:
	_phase = randf() * TAU
	_bauen()
	ziel_position = position


# ------------------------------------------------------------------ Aufbau
func _bauen() -> void:
	_viewport = SubViewport.new()
	_viewport.size = (Vector2i(GROESSE) + Vector2i(LUFT * 2, LUFT * 2)) * AUFL
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_viewport)

	_vorderseite = Control.new()
	_vorderseite.position = Vector2(LUFT, LUFT) * AUFL
	_vorderseite.size = GROESSE * AUFL
	_viewport.add_child(_vorderseite)
	_vorderseite_fuellen(_vorderseite)

	_rueckseite = TextureRect.new()
	_rueckseite.texture = load(KUNST + "rueckseite.png")
	_rueckseite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rueckseite.position = Vector2(LUFT, LUFT) * AUFL
	_rueckseite.size = GROESSE * AUFL
	_viewport.add_child(_rueckseite)
	_schleier = Control.new()
	_schleier.position = _rueckseite.position
	_schleier.size = _rueckseite.size
	_schleier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_schleier.draw.connect(_schleier_zeichnen)
	_viewport.add_child(_schleier)

	var glas := edition == "Glass"
	var shader: Shader = load("res://addons/tartot_karten/shader/%s.gdshader" % ("karte_glas" if glas else "karte"))
	_schatten_mat = ShaderMaterial.new()
	_schatten_mat.shader = shader
	_schatten_mat.set_shader_parameter("schatten", 1.0)
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("saat", randf() * 10.0)
	var seltenheit: String = daten.get("rarity", "Common")
	_mat.set_shader_parameter("legendaer", 1.0 if seltenheit == "Legendary" else 0.0)
	_mat.set_shader_parameter("selten_farbe", Color(KartenDaten.seltenheit(seltenheit)["color"]))

	_schatten = Sprite2D.new()
	_schatten.texture = _viewport.get_texture()
	_schatten.material = _schatten_mat
	_schatten.z_index = -1
	add_child(_schatten)

	if glas:
		# Glas liest den Bildschirm hinter sich: erst den Tisch darunter kopieren.
		var kopie := BackBufferCopy.new()
		kopie.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		add_child(kopie)

	_bild = Sprite2D.new()
	_bild.texture = _viewport.get_texture()
	_bild.material = _mat
	add_child(_bild)
	# Innen Pixel, aussen weich: gekippt und gedreht soll die Karte nicht flimmern.
	_bild.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_schatten.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bild.scale = Vector2.ONE / AUFL
	_schatten.scale = Vector2.ONE / AUFL
	_seite_zeigen()


func _vorderseite_fuellen(wurzel: Control) -> void:
	# Ganz selbst gemalte Karte: ersetzt die ganze Vorderseite (siehe VORLAGE.md).
	var ganz_pfad := KUNST + "karten/%s.png" % id
	if ResourceLoader.exists(ganz_pfad):
		var bild := TextureRect.new()
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_SCALE
		bild.texture = load(ganz_pfad)
		bild.size = GROESSE * AUFL
		wurzel.add_child(bild)
		return
	# Sonst randlos: das eigene Motiv ueber die ganze Karte, oder die
	# Sinnbilder der Farbe - nie das Motiv einer anderen Karte.
	_front = KartenFront.new(daten, AUFL)
	var motiv_pfad := KUNST + "motive/%s.png" % id
	if ResourceLoader.exists(motiv_pfad):
		_front.motiv = load(motiv_pfad)
	_front.umgekehrt = umgekehrt
	_front.stufe = stufe
	_front.schimmer = schimmer
	_front.gezeichnet = gezeichnet
	wurzel.add_child(_front)


## Verhuellt (Mond): Nebelbaender und ein Fragezeichen ueber der Rueckseite.
func _schleier_zeichnen() -> void:
	if not verschleiert:
		return
	var c := _schleier
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(AUFL, AUFL))
	c.draw_rect(Rect2(Vector2(6, 6), GROESSE - Vector2(12, 12)), Color(0.23, 0.29, 0.55, 0.35))
	var zufall := RandomNumberGenerator.new()
	zufall.seed = hash(instanz + id)
	for i in 6:
		var y := 40.0 + i * 54.0 + zufall.randf_range(-10, 10)
		var pts := PackedVector2Array()
		for k in 13:
			pts.append(Vector2(-10.0 + k * 22.0, y + sin(k * 0.8 + i * 1.7) * 9.0))
		c.draw_polyline(pts, Color(0.75, 0.80, 0.95, 0.16), 18.0, true)
	var schrift := TarotStil.titel()
	var breite := schrift.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x
	var ort := Vector2(120 - breite * 0.5, 222)
	c.draw_string_outline(schrift, ort, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 120, 10, TINTE)
	c.draw_string(schrift, ort, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 120, Color("C9D2F0"))


## Vorder- oder Rueckseite zeigen; Editionen und Folie gehoeren nach vorn.
func _seite_zeigen() -> void:
	if _vorderseite == null or _mat == null:
		return
	var vorn := vorderseite_sichtbar()
	_vorderseite.visible = vorn
	_rueckseite.visible = not vorn
	_schleier.visible = not vorn and verschleiert
	_schleier.queue_redraw()
	_mat.set_shader_parameter("edition", KartenDaten.edition_nummer(edition) if vorn else 0)
	_mat.set_shader_parameter("holo", HOLO.get(daten.get("rarity", "Common"), 0.0) if vorn else 0.0)
	_neu_zeichnen_lassen()


# ------------------------------------------------------------------ Bewegung
func _process(delta: float) -> void:
	_zeit += delta
	_stoss_alter += delta
	if _neu_zeichnen > 0:
		_neu_zeichnen -= 1
		if _neu_zeichnen == 0:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	# Feder: gezogen straff, sonst weich mit Nachschwingen.
	var k := feder_gezogen if gezogen else feder
	var d := daempfung_gezogen if gezogen else daempfung
	geschwindigkeit += (ziel_position - position) * k * delta
	geschwindigkeit *= exp(-d * delta)
	position += geschwindigkeit * delta

	# In die Bewegung legen, dazu leises Wiegen im Stillstand.
	var wiegen := 0.0 if (gezogen or schwebt) else sin(_zeit * 1.3 + _phase) * 0.018
	var lehnen := clampf(geschwindigkeit.x * schwung, -0.45, 0.45)
	var ziel_dreh := ziel_rotation + lehnen + wiegen
	rotation = lerp_angle(rotation, ziel_dreh, 1.0 - exp(-14.0 * delta))

	# Groesse mit Stoss (Juice): kurzer Ausschlag, der gedaempft nachschwingt.
	var stoss := _stoss * exp(-_stoss_alter * 7.0) * cos(_stoss_alter * 28.0)
	var s := lerpf(scale.y, ziel_skala * basis, 1.0 - exp(-16.0 * delta))
	scale = Vector2(s * _wendung, s) + Vector2(stoss, stoss)

	# Neigung: dem Zeiger entgegen, sonst sanftes Kreisen.
	var ziel_neigung: Vector2
	if schwebt or gezogen:
		ziel_neigung = zeiger_relativ
		if gezogen:
			ziel_neigung += Vector2(-geschwindigkeit.x, geschwindigkeit.y) * 0.0012
	else:
		ziel_neigung = Vector2(sin(_zeit * 0.9 + _phase), cos(_zeit * 0.7 + _phase * 1.3)) * 0.22
	_neigung = _neigung.lerp(ziel_neigung.limit_length(1.2), 1.0 - exp(-10.0 * delta))
	var y_rot := _neigung.x * max_neigung
	var x_rot := -_neigung.y * max_neigung
	for m in [_mat, _schatten_mat]:
		m.set_shader_parameter("y_rot", y_rot)
		m.set_shader_parameter("x_rot", x_rot)

	# 2.5D: unter dem Finger liegt das Motiv hinter dem Rahmen und verschiebt
	# sich gegen die Neigung. Nur dann wird die Vorderseite laufend neu gemalt.
	if _front != null and vorderseite_sichtbar():
		var aktiv := schwebt or gezogen or gross
		var ziel_versatz := -_neigung * KartenFront.UEBERSTAND * 0.8 if aktiv else Vector2.ZERO
		if aktiv or _front.motiv_versatz.length() > 0.2:
			_front.motiv_versatz = _front.motiv_versatz.lerp(ziel_versatz, 1.0 - exp(-12.0 * delta))
			_neu_zeichnen_lassen()

	# Schatten: faellt weiter, je hoeher die Karte schwebt.
	var hoehe := (scale.y / maxf(basis, 0.01) - 1.0) * 60.0 + (18.0 if gezogen else 0.0)
	_schatten.position = Vector2(6.0 - geschwindigkeit.x * 0.01, 10.0 + hoehe).rotated(-rotation) / max(scale.y, 0.01)


## Kurzer Ausschlag - beim Zaehlen, beim Einrasten, bei Treffern.
func stossen(staerke := 0.18) -> void:
	_stoss = staerke
	_stoss_alter = 0.0


## Liegt der Punkt (global) auf der Karte?
func enthaelt(punkt: Vector2) -> bool:
	var lokal := to_local(punkt)
	return Rect2(-GROESSE * 0.5, GROESSE).has_point(lokal)


## Zeigerposition fuer die Neigung setzen (global).
func zeiger_setzen(punkt: Vector2) -> void:
	var lokal := to_local(punkt)
	zeiger_relativ = Vector2(lokal.x / (GROESSE.x * 0.5), lokal.y / (GROESSE.y * 0.5)).clamp(Vector2(-1, -1), Vector2(1, 1))


## Umdrehen: schmal werden, Seite tauschen, wieder breit.
func umdrehen(offen := true) -> void:
	if offen == aufgedeckt:
		return
	_wenden(func(): aufgedeckt = offen)


func _wenden(tauschen: Callable) -> void:
	var t := create_tween()
	t.tween_property(self, "_wendung", 0.0, 0.09).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		tauschen.call()
		_seite_zeigen()
		KartenKlang.spielen("umdrehen")
		if vorderseite_sichtbar() and edition != "":
			KartenKlang.spielen("brennen" if edition == "Burning" else "schimmer", 1.0, -10.0))
	t.tween_property(self, "_wendung", 1.0, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Verdeckt starten (etwa beim Austeilen), ohne Animation.
func verdeckt_beginnen() -> void:
	aufgedeckt = false
	_seite_zeigen()


## Zerspringen oder Verbrennen: die Karte loest sich auf und verschwindet.
func aufloesen(dauer := 0.8, farbe := Color("E0543A")) -> void:
	_mat.set_shader_parameter("aufloese_farbe", farbe)
	var t := create_tween()
	t.tween_method(func(w): _mat.set_shader_parameter("aufloesen", w), 0.0, 1.0, dauer)
	t.parallel().tween_method(func(w): _schatten_mat.set_shader_parameter("aufloesen", w), 0.0, 1.0, dauer)
	t.tween_callback(queue_free)


func _neu_zeichnen_lassen() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_neu_zeichnen = 3
