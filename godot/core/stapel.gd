# Die Kartenstapel *innerhalb* eines Kampfes.
#
# Das permanente Run-Deck liegt in Run.deck. Zu Kampfbeginn wird es hierher
# kopiert und gemischt; Aenderungen hier (vernichten, fluechtige Kopien)
# beruehren das Run-Deck nicht - ausser sie sind ausdruecklich permanent.
extends RefCounted
class_name Kampfstapel

const Konst := preload("res://core/konst.gd")
const Rng := preload("res://core/rng.gd")

var ziehstapel: Array[Karte] = []
var hand: Array[Karte] = []
var ablage: Array[Karte] = []
var verbannt: Array[Karte] = []     # VERNICHTET: bis Kampfende weg
var rng: TRng

## Wie oft in diesem Kampf neu gemischt wurde (Charm "Kraehenfeder").
var mischungen: int = 0

func _init(run_deck: Array[Karte], p_rng: TRng) -> void:
	rng = p_rng
	for k in run_deck:
		if k.ist_fluch:
			# Fluchkarten liegen im Deck und verstopfen die Hand - das ist ihr Zweck.
			ziehstapel.append(k)
		else:
			ziehstapel.append(k)
	rng.mische(ziehstapel)

func groesse_gesamt() -> int:
	return ziehstapel.size() + hand.size() + ablage.size()

## Zieht n Karten. Mischt die Ablage ein, wenn der Ziehstapel leer ist.
## Gibt die tatsaechlich gezogenen Karten zurueck.
func ziehen(n: int) -> Array[Karte]:
	var gezogen: Array[Karte] = []
	for _i in n:
		if ziehstapel.is_empty():
			if ablage.is_empty():
				break   # nichts mehr da - das ist erlaubt, kein Fehler
			_ablage_einmischen()
		var k: Karte = ziehstapel.pop_back()
		hand.append(k)
		gezogen.append(k)
	return gezogen

func _ablage_einmischen() -> void:
	ziehstapel.append_array(ablage)
	ablage.clear()
	rng.mische(ziehstapel)
	mischungen += 1

## Legt eine Karte aus der Hand in die Ablage.
func ablegen(k: Karte) -> bool:
	var i: int = hand.find(k)
	if i < 0:
		return false
	hand.remove_at(i)
	ablage.append(k)
	return true

## Entfernt eine Karte aus der Hand, ohne sie abzulegen (sie wandert woandershin).
func aus_hand_nehmen(k: Karte) -> bool:
	var i: int = hand.find(k)
	if i < 0:
		return false
	hand.remove_at(i)
	return true

## VERNICHTEN: die Karte ist bis Kampfende aus dem Spiel.
func vernichten(k: Karte) -> void:
	aus_hand_nehmen(k)
	ziehstapel.erase(k)
	ablage.erase(k)
	verbannt.append(k)

## Karte kommt oben auf den Ziehstapel (Hohepriesterin, Erinnerungssplitter).
func obenauf(k: Karte) -> void:
	ziehstapel.append(k)

## Karte kommt direkt auf die Hand (Das Gericht).
func in_hand(k: Karte) -> void:
	hand.append(k)

## Die obersten n Karten ansehen, ohne zu ziehen (Orakellinse, Auge des Orakels).
func spaehen(n: int) -> Array[Karte]:
	var res: Array[Karte] = []
	var i: int = ziehstapel.size() - 1
	while i >= 0 and res.size() < n:
		res.append(ziehstapel[i])
		i -= 1
	return res

## Ganze Hand ablegen (Rad des Schicksals umgekehrt).
func hand_ablegen() -> int:
	var n: int = hand.size()
	ablage.append_array(hand)
	hand.clear()
	return n

func hat_farbe_in_hand(farbe: int) -> bool:
	for k in hand:
		if k.farbe == farbe:
			return true
	return false
