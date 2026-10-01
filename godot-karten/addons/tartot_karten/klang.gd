class_name KartenKlang
extends Node
## Klaenge des Kartentischs. Ein KartenKlang-Knoten irgendwo in der Szene
## genuegt; Karte, Tisch und Kaskade rufen KartenKlang.spielen(...) - ohne
## Knoten bleibt es still, nichts bricht.
##
## Die Kaskade zaehlt mit einer Tonleiter wie bei Balatro: jeder Schritt
## einen Halbton hoeher (leiter), gedeckelt bei einer Oktave.
##
## Die WAVs erzeugt tools/klang/klaenge.py; eigene Aufnahmen mit gleichem
## Namen ersetzen sie einfach.
##
## Musik: zwei gleich lange Schleifen pro Stueck, die zusammen laufen - die
## Grundschicht (Drehorgel-Walzer) und eine Bossschicht (Pauke, Blech), die
## im Bosskampf eingeblendet wird. schlaege() liefert den Takt, damit die
## Figuren auf der Buehne im Takt der Musik hopsen.
##
## Haptik: fuehlen() laesst das Handy kurz vibrieren (Android/iOS; am
## Rechner passiert nichts). In den Android-Exporteinstellungen muss die
## Berechtigung VIBRATE gesetzt sein.

const ORDNER := "res://addons/tartot_karten/klang/"
const STIMMEN := 12

## Gesamtlautstaerke in dB.
@export var lautstaerke_db := -6.0
## Leises Projektorrattern im Hintergrund.
@export var projektor := true
## Musiklautstaerke relativ zur Gesamtlautstaerke.
@export var musik_db := -9.0
## Vibration an/aus (Einstellungen).
@export var haptik := true

## Schlaege pro Minute der Musik (siehe tools/klang/musik.py).
const BPM := 138.0

static var _instanz: KartenKlang = null

var _spieler: Array[AudioStreamPlayer] = []
var _naechster := 0
var _klaenge := {}
var _zuletzt := {}
var _letzte_variante := {}
var _musik: AudioStreamPlayer
var _boss_schicht: AudioStreamPlayer
var _boss_ziel := -60.0
var _start_ms := 0


func _enter_tree() -> void:
	_instanz = self


func _exit_tree() -> void:
	if _instanz == self:
		_instanz = null


func _ready() -> void:
	for i in STIMMEN:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_spieler.append(s)
	if projektor:
		var p := AudioStreamPlayer.new()
		# Die Schleife steht in projektor.wav.import (loop_mode vorwaerts).
		var strom := _laden("projektor")
		if strom:
			p.stream = strom
			p.volume_db = lautstaerke_db - 14.0
			add_child(p)
			p.play()
	_musik = AudioStreamPlayer.new()
	_boss_schicht = AudioStreamPlayer.new()
	add_child(_musik)
	add_child(_boss_schicht)
	_start_ms = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if _boss_schicht and _boss_schicht.playing:
		_boss_schicht.volume_db = lerpf(_boss_schicht.volume_db, _boss_ziel, 1.0 - exp(-2.5 * delta))


## Startet die Musik (Grundschicht). boss blendet die Bossschicht ein.
static func musik(name := "walzer", boss := false) -> void:
	if _instanz == null:
		return
	var i := _instanz
	var grund: AudioStream = i._laden("musik_" + name)
	var oben: AudioStream = i._laden("musik_" + name + "_boss")
	if grund == null:
		return
	if i._musik.stream != grund:
		i._musik.stream = grund
		i._musik.volume_db = i.lautstaerke_db + i.musik_db
		i._musik.play()
		i._boss_schicht.stream = oben
		i._boss_schicht.volume_db = -60.0
		if oben:
			i._boss_schicht.play()
	i._boss_ziel = (i.lautstaerke_db + i.musik_db) if boss else -60.0


static func musik_aus() -> void:
	if _instanz != null:
		_instanz._musik.stop()
		_instanz._boss_schicht.stop()


## Wie viele Schlaege der Musik vergangen sind (laeuft auch ohne Musik weiter).
static func schlaege() -> float:
	if _instanz == null:
		return Time.get_ticks_msec() / 1000.0 * BPM / 60.0
	var i := _instanz
	if i._musik and i._musik.playing:
		return (i._musik.get_playback_position() + AudioServer.get_time_since_last_mix()) * BPM / 60.0
	return (Time.get_ticks_msec() - i._start_ms) / 1000.0 * BPM / 60.0


## Kurze Vibration: ms Dauer, staerke 0..1.
static func fuehlen(ms: int, staerke := 0.5) -> void:
	if _instanz == null or not _instanz.haptik:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, clampf(staerke, 0.05, 1.0))


func _laden(name: String) -> AudioStream:
	var liste := _varianten(name)
	if liste.is_empty():
		return null
	if liste.size() == 1:
		return liste[0]
	# Varianten: zufaellig, aber nie dieselbe zweimal hintereinander.
	var letzte: int = _letzte_variante.get(name, -1)
	var i := randi() % liste.size()
	if i == letzte:
		i = (i + 1) % liste.size()
	_letzte_variante[name] = i
	return liste[i]


## name.wav oder name_1.wav, name_2.wav ... - einmal geladen, dann gemerkt.
func _varianten(name: String) -> Array:
	if not _klaenge.has(name):
		var liste := []
		var pfad := ORDNER + name + ".wav"
		if ResourceLoader.exists(pfad):
			liste.append(load(pfad))
		var i := 1
		while ResourceLoader.exists(ORDNER + "%s_%d.wav" % [name, i]):
			liste.append(load(ORDNER + "%s_%d.wav" % [name, i]))
			i += 1
		_klaenge[name] = liste
	return _klaenge[name]


## Spielt einen Klang. tonhoehe 1 = Original; streuung variiert leicht,
## damit dieselbe Karte nicht zehnmal gleich klingt.
static func spielen(name: String, tonhoehe := 1.0, db := 0.0, streuung := 0.04) -> void:
	if _instanz != null:
		_instanz._spielen(name, tonhoehe, db, streuung)


## Tonhoehe fuer Schritt n der Kaskade: ein Halbton je Schritt, hoechstens 12.
static func leiter(schritt: int) -> float:
	return pow(2.0, mini(schritt, 12) / 12.0)


func _spielen(name: String, tonhoehe: float, db: float, streuung: float) -> void:
	var strom := _laden(name)
	if strom == null:
		return
	# Derselbe Klang nicht oefter als alle 30 ms (Hand voller Karten = kein Maschinengewehr).
	var jetzt := Time.get_ticks_msec()
	if jetzt - int(_zuletzt.get(name, -1000)) < 30:
		return
	_zuletzt[name] = jetzt
	var s := _spieler[_naechster]
	_naechster = (_naechster + 1) % STIMMEN
	s.stream = strom
	s.pitch_scale = tonhoehe * (1.0 + randf_range(-streuung, streuung))
	s.volume_db = lautstaerke_db + db
	s.play()
