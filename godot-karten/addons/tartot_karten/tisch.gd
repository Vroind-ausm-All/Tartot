class_name KartenTisch
extends Node2D
## Hand, Plaetze und Zeiger - das Balatro-Gefuehl.
##
## - Die Hand liegt als Faecher; die Abstaende ziehen sich zusammen, je mehr
##   Karten sie hat.
## - Unter dem Zeiger hebt sich eine Karte, kippt ihm entgegen und schiebt
##   ihre Nachbarn beiseite.
## - Antippen waehlt eine Karte (sie bleibt angehoben), Ziehen nimmt sie auf.
##   Beim Ziehen haengt sie an einer Feder und schwingt in die Bewegung.
## - Losgelassen ueber einem Platz rastet sie dort ein; ueber der Hand wird
##   sie an der Stelle einsortiert, an der sie losgelassen wurde.
##
## Der Zeiger kommt aus Maus und Touch - oder aus einem Skript
## (skript_modus), damit Vorfuehrungen und Tests ohne Eingabe laufen.

signal legung_geaendert
signal schwebt_ueber(karte: TarotKarte)

@export var hand_mitte := Vector2(540, 1618)
@export var hand_breite := 860.0
@export var max_abstand := 136.0
@export var bogen := 5.0          ## Pixel, um die aeussere Karten tiefer liegen
@export var faecher := 0.055        ## Drehung je Karte vom Zentrum (Bogenmass)
@export var anheben_schweben := 60.0
@export var anheben_gewaehlt := 40.0
@export var zug_schwelle := 12.0
## Grundgroesse der Karten auf diesem Tisch (siehe TarotKarte.basis).
@export var karten_basis := 1.0

var hand: Array[TarotKarte] = []
var plaetze: Array[KartenPlatz] = []
var zeiger := Vector2(-1000, -1000)
var skript_modus := false

var _gedrueckt := false
var _druck_pos := Vector2.ZERO
var _druck_karte: TarotKarte = null
var _gezogen: TarotKarte = null
var _zug_versatz := Vector2.ZERO
var _schwebend: TarotKarte = null


# ------------------------------------------------------------------ Eingabe
func _unhandled_input(ereignis: InputEvent) -> void:
	if skript_modus:
		return
	if ereignis is InputEventMouseMotion:
		zeiger_bewegen(get_global_mouse_position())
	elif ereignis is InputEventMouseButton and ereignis.button_index == MOUSE_BUTTON_LEFT:
		zeiger_bewegen(get_global_mouse_position())
		if ereignis.pressed:
			zeiger_druecken()
		else:
			zeiger_loslassen()


func zeiger_bewegen(punkt: Vector2) -> void:
	zeiger = punkt
	if _gedrueckt and _gezogen == null and _druck_karte != null \
			and punkt.distance_to(_druck_pos) > zug_schwelle:
		_aufnehmen(_druck_karte)


func zeiger_druecken() -> void:
	_gedrueckt = true
	_druck_pos = zeiger
	_druck_karte = karte_unter(zeiger)


func zeiger_loslassen() -> void:
	if _gezogen != null:
		_ablegen()
	elif _druck_karte != null:
		_antippen(_druck_karte)
	_gedrueckt = false
	_druck_karte = null


# ------------------------------------------------------------------ Karten
func austeilen(karte: TarotKarte, von: Vector2, verzoegerung := 0.0) -> void:
	karte.position = von
	karte.rotation = -0.6
	karte.verdeckt_beginnen()
	karte.basis = karten_basis
	add_child(karte)
	karte.ziel_position = von
	hand.append(karte)
	if verzoegerung > 0.0:
		karte.visible = false
		await get_tree().create_timer(verzoegerung).timeout
		karte.visible = true
	KartenKlang.spielen("austeilen")
	# erst fliegen, dann aufdecken - wie ein Croupier
	await get_tree().create_timer(0.22).timeout
	if is_instance_valid(karte):
		karte.umdrehen(true)


func karte_unter(punkt: Vector2) -> TarotKarte:
	var beste: TarotKarte = null
	for karte in _alle_karten():
		if karte == _gezogen or not karte.visible:
			continue
		if karte.enthaelt(punkt) and (beste == null or karte.z_index > beste.z_index):
			beste = karte
	return beste


func _alle_karten() -> Array[TarotKarte]:
	var alle: Array[TarotKarte] = hand.duplicate()
	for platz in plaetze:
		if platz.karte != null:
			alle.append(platz.karte)
	return alle


func legung() -> Dictionary:
	var ergebnis := {}
	for i in plaetze.size():
		if plaetze[i].karte != null:
			ergebnis[i] = plaetze[i].karte
	return ergebnis


func gewaehlte() -> Array[TarotKarte]:
	var liste: Array[TarotKarte] = []
	for karte in hand:
		if karte.gewaehlt:
			liste.append(karte)
	return liste


## Karte aus Hand oder Platz nehmen (nach dem Ausspielen, beim Abwerfen).
func entfernen(karte: TarotKarte) -> void:
	hand.erase(karte)
	for platz in plaetze:
		if platz.karte == karte:
			platz.karte = null
	if _schwebend == karte:
		_schwebend = null


func _antippen(karte: TarotKarte) -> void:
	if karte in hand:
		karte.gewaehlt = not karte.gewaehlt
		karte.stossen(0.08)
		KartenKlang.spielen("waehlen", 1.0 if karte.gewaehlt else 0.8)
		KartenKlang.fuehlen(12, 0.35)
	else:
		# Karte auf einem Platz antippen: zurueck auf die Hand
		_zurueck_auf_hand(karte, hand.size())


func _aufnehmen(karte: TarotKarte) -> void:
	_gezogen = karte
	karte.gezogen = true
	karte.gewaehlt = false
	_zug_versatz = karte.global_position - zeiger
	karte.stossen(0.1)
	KartenKlang.spielen("nehmen")
	KartenKlang.fuehlen(10, 0.3)
	for platz in plaetze:
		if platz.karte == karte:
			platz.karte = null
			legung_geaendert.emit()


func _ablegen() -> void:
	var karte := _gezogen
	_gezogen = null
	karte.gezogen = false
	var ziel := _platz_unter(zeiger)
	if ziel != null:
		hand.erase(karte)
		if ziel.karte != null:
			# belegt: die alte Karte geht auf die Hand zurueck
			_zurueck_auf_hand(ziel.karte, hand.size())
		ziel.karte = karte
		karte.ziel_position = ziel.global_position
		karte.ziel_rotation = 0.0
		karte.stossen(0.16)
		KartenKlang.spielen("ablegen")
		KartenKlang.fuehlen(28, 0.7)
		legung_geaendert.emit()
	else:
		_zurueck_auf_hand(karte, _einfuege_index(zeiger.x, karte))
		KartenKlang.spielen("ablegen", 1.25, -6.0)
	for platz in plaetze:
		platz.markiert = false


func _zurueck_auf_hand(karte: TarotKarte, index: int) -> void:
	for platz in plaetze:
		if platz.karte == karte:
			platz.karte = null
			legung_geaendert.emit()
	hand.erase(karte)
	hand.insert(clampi(index, 0, hand.size()), karte)
	karte.stossen(0.08)


func _platz_unter(punkt: Vector2) -> KartenPlatz:
	for platz in plaetze:
		if not platz.gesperrt and platz.enthaelt(punkt):
			return platz
	return null


func _einfuege_index(x: float, ohne: TarotKarte) -> int:
	var i := 0
	for karte in hand:
		if karte == ohne:
			continue
		if karte.ziel_position.x < x:
			i += 1
	return i


# ------------------------------------------------------------------ Takt
func _process(_delta: float) -> void:
	_schweben_aktualisieren()
	_hand_legen()
	_plaetze_legen()
	if _gezogen != null:
		_gezogen.ziel_position = zeiger + _zug_versatz
		_gezogen.ziel_rotation = 0.0
		_gezogen.ziel_skala = 1.12
		_gezogen.z_index = 300
		_gezogen.zeiger_setzen(zeiger)
		for platz in plaetze:
			platz.markiert = platz.enthaelt(zeiger) and not platz.gesperrt


func _schweben_aktualisieren() -> void:
	var neu := null if _gezogen != null else karte_unter(zeiger)
	if neu != _schwebend:
		if _schwebend != null and is_instance_valid(_schwebend):
			_schwebend.schwebt = false
		_schwebend = neu
		if neu != null:
			neu.schwebt = true
			neu.stossen(0.06)
			KartenKlang.spielen("schweben", 1.0, -8.0, 0.1)
			KartenKlang.fuehlen(5, 0.15)
		schwebt_ueber.emit(neu)
	if _schwebend != null:
		_schwebend.zeiger_setzen(zeiger)


func _hand_legen() -> void:
	var karten: Array[TarotKarte] = []
	for k in hand:
		if k != _gezogen:
			karten.append(k)
	# Luecke, wo die gezogene Karte einsortiert wuerde
	var luecke := -1
	if _gezogen != null and _gezogen in hand and zeiger.y > hand_mitte.y - 260:
		luecke = _einfuege_index(zeiger.x, _gezogen)
	var n := karten.size() + (1 if luecke >= 0 else 0)
	if n == 0:
		return
	var abstand := minf(max_abstand, hand_breite / maxf(1.0, n))
	var schwebe_index := karten.find(_schwebend)
	var slot := 0
	for i in karten.size():
		if slot == luecke:
			slot += 1
		var karte := karten[i]
		var t := slot - (n - 1) * 0.5
		var pos := hand_mitte + Vector2(t * abstand, t * t * bogen)
		var dreh := t * faecher
		var skala := 1.0
		if schwebe_index >= 0 and i != schwebe_index:
			# Nachbarn weichen der angehobenen Karte aus
			var weg := i - schwebe_index
			pos.x += signf(weg) * maxf(0.0, 42.0 - abs(weg) * 10.0)
		if karte.gewaehlt:
			pos.y -= anheben_gewaehlt
		if karte == _schwebend:
			pos.y -= anheben_schweben
			dreh = 0.0
			skala = 1.14
		karte.ziel_position = pos
		karte.ziel_rotation = dreh
		karte.ziel_skala = skala
		karte.z_index = 200 if karte == _schwebend else 10 + slot * 2
		slot += 1


func _plaetze_legen() -> void:
	for platz in plaetze:
		var karte := platz.karte
		if karte == null or karte == _gezogen:
			continue
		karte.ziel_position = platz.global_position
		karte.ziel_rotation = 0.0
		karte.ziel_skala = 1.1 if karte == _schwebend else 0.96
		karte.z_index = 150 if karte == _schwebend else 60
