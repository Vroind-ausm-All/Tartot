class_name TarotKarte
extends Node2D
## Eine Karte auf dem Tisch - gebaut aus der Vorlage, bewegt wie bei Balatro.
##
## Aufbau: Die Vorderseite (Rahmen, Motiv, Zahl, Name, Seltenheit) wird in
## einem eigenen SubViewport gezeichnet. Dessen Bild zeigt ein Sprite mit dem
## Kartenshader: Neigung, Editionen, Aufloesen. Darunter liegt ein Schatten.
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
const MOTIV := Rect2(34, 52, 172, 208)
const ZAHL := Rect2(20, 12, 200, 30)
const NAME := Rect2(24, 278, 192, 58)
const SELTENHEIT := Vector2(120, 345)
const KUNST := "res://addons/tartot_karten/kunst/"
const TINTE := Color("1A1412")
const PAPIER := Color("EFE3C8")

const FARBEN := {"Swords": "schwerter", "Cups": "kelche", "Pentacles": "muenzen", "Wands": "staebe", "Major": "arkana"}

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
var _rueckseite: TextureRect


static func erzeugen(karten_id: String, karten_edition := "") -> TarotKarte:
	var k := TarotKarte.new()
	k.id = karten_id
	k.daten = KartenDaten.karte(karten_id)
	k.edition = karten_edition
	return k


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
	_rueckseite.visible = not aufgedeckt
	_vorderseite.visible = aufgedeckt

	var glas := edition == "Glass"
	var shader: Shader = load("res://addons/tartot_karten/shader/%s.gdshader" % ("karte_glas" if glas else "karte"))
	_schatten_mat = ShaderMaterial.new()
	_schatten_mat.shader = shader
	_schatten_mat.set_shader_parameter("schatten", 1.0)
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("edition", KartenDaten.edition_nummer(edition) if aufgedeckt else 0)
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


func _vorderseite_fuellen(wurzel: Control) -> void:
	# Ganz selbst gemalte Karte: ersetzt Rahmen, Motiv, Zahl und Name.
	# Nur die Seltenheitsraute kommt noch darauf (siehe VORLAGE.md).
	var ganz_pfad := KUNST + "karten/%s.png" % id
	if ResourceLoader.exists(ganz_pfad):
		wurzel.add_child(_bild_in(load(ganz_pfad), Rect2(Vector2.ZERO, GROESSE), false))
		_seltenheit_zeichnen(wurzel)
		return

	# Motiv zuerst, der Rahmen liegt darueber (sein Fenster ist offen).
	var motiv_pfad := _motiv_pfad()
	if motiv_pfad != "":
		wurzel.add_child(_bild_in(load(motiv_pfad), MOTIV, true))
	else:
		# Noch kein Motiv: das Sinnbild der Rueckseite als Platzhalter.
		var platzhalter := _bild_in(load(KUNST + "rueckseite.png"), MOTIV, true)
		platzhalter.modulate = Color(1, 1, 1, 0.85)
		wurzel.add_child(platzhalter)
	wurzel.add_child(_bild_in(load(KUNST + "rahmen.png"), Rect2(Vector2.ZERO, GROESSE), false))

	var nummer := str(daten.get("number", "?"))
	var zahl_label := _label(nummer, 27, ZAHL)
	if nummer.is_valid_int():
		zahl_label.add_theme_font_override("font", TarotStil.zahlen())
		zahl_label.add_theme_font_size_override("font_size", 30 * AUFL)
	wurzel.add_child(zahl_label)
	var name_label := _label(str(daten.get("name", id)).to_upper(), 19, NAME)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_constant_override("line_spacing", -6 * AUFL)
	wurzel.add_child(name_label)
	_seltenheit_zeichnen(wurzel)


## Eigenes Motiv, sonst eines derselben Farbe mit naechstem Rang (Platzhalter),
## sonst leer.
func _motiv_pfad() -> String:
	var eigen := KUNST + "motive/%s.png" % id
	if ResourceLoader.exists(eigen):
		return eigen
	var farbe: String = daten.get("suit", "Major")
	if farbe == "Major":
		return ""
	var rang := int(daten.get("rank", 1))
	var vorsilbe := id.get_slice("_", 0)
	for abstand in range(1, 14):
		for r in [rang - abstand, rang + abstand]:
			var p := KUNST + "motive/%s_%d.png" % [vorsilbe, r]
			if r >= 1 and r <= 14 and ResourceLoader.exists(p):
				return p
	return ""


func _bild_in(textur: Texture2D, rahmen: Rect2, fuellen: bool) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if fuellen else TextureRect.STRETCH_SCALE
	t.texture = textur
	t.position = rahmen.position * AUFL
	t.size = rahmen.size * AUFL
	t.clip_contents = true
	return t


## Seltenheit: eine Raute in der Farbe der Stufe, wie ein Edelstein.
func _seltenheit_zeichnen(wurzel: Control) -> void:
	var form := PackedVector2Array([Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)])
	var raute := Polygon2D.new()
	raute.polygon = form
	raute.position = SELTENHEIT * AUFL
	raute.scale = Vector2(AUFL, AUFL)
	raute.color = Color(KartenDaten.seltenheit(daten.get("rarity", "Common"))["color"])
	var glanz := Polygon2D.new()
	glanz.polygon = PackedVector2Array([Vector2(0, -6), Vector2(3, -2), Vector2(0, 0), Vector2(-3, -2)])
	glanz.color = Color(1, 1, 1, 0.35)
	raute.add_child(glanz)
	var kontur := Line2D.new()
	kontur.points = PackedVector2Array(Array(form) + [form[0]])
	kontur.width = 1.6
	kontur.default_color = TINTE
	raute.add_child(kontur)
	wurzel.add_child(raute)


func _label(text: String, groesse: int, rahmen: Rect2) -> Label:
	var l := TarotStil.label(text, groesse * AUFL, TINTE, false, 0)
	l.position = rahmen.position * AUFL
	l.size = rahmen.size * AUFL
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


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
	var t := create_tween()
	t.tween_property(self, "_wendung", 0.0, 0.09).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		aufgedeckt = offen
		_vorderseite.visible = offen
		_rueckseite.visible = not offen
		# Editionen gehoeren zur Vorderseite: verdeckt brennt und glaenzt nichts.
		_mat.set_shader_parameter("edition", KartenDaten.edition_nummer(edition) if offen else 0)
		KartenKlang.spielen("umdrehen")
		if offen and edition != "":
			KartenKlang.spielen("brennen" if edition == "Burning" else "schimmer", 1.0, -10.0)
		_neu_zeichnen_lassen())
	t.tween_property(self, "_wendung", 1.0, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


## Verdeckt starten (etwa beim Austeilen), ohne Animation.
func verdeckt_beginnen() -> void:
	aufgedeckt = false
	if _vorderseite:
		_vorderseite.visible = false
		_rueckseite.visible = true
		_mat.set_shader_parameter("edition", 0)
		_neu_zeichnen_lassen()


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
