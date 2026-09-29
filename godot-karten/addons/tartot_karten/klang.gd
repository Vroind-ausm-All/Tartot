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

const ORDNER := "res://addons/tartot_karten/klang/"
const STIMMEN := 12

## Gesamtlautstaerke in dB.
@export var lautstaerke_db := -4.0
## Leises Projektorrattern im Hintergrund.
@export var projektor := true

static var _instanz: KartenKlang = null

var _spieler: Array[AudioStreamPlayer] = []
var _naechster := 0
var _klaenge := {}
var _zuletzt := {}


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


func _laden(name: String) -> AudioStream:
	if not _klaenge.has(name):
		var pfad := ORDNER + name + ".wav"
		_klaenge[name] = load(pfad) if ResourceLoader.exists(pfad) else null
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
