# Wahlstrategie: wer entscheidet, wenn ein Effekt eine Wahl verlangt?
#
# Der Regelkern darf nie blockieren und nie die UI kennen. Also fragt er
# dieses Objekt. Die UI setzt eine interaktive Unterklasse ein, die
# Simulation und die Tests eine heuristische. Damit ist jeder Effekt,
# der eine Wahl braucht, automatisch simulierbar.
extends RefCounted
class_name Wahl

## Welche Handkarte fuer "grund" (vernichten, aufwerten, kopieren ...)?
## Rueckgabe null heisst "keine Wahl moeglich".
func handkarte(kampf, grund: String) -> Karte:
	var hand: Array = kampf.stapel.hand
	if hand.is_empty():
		return null
	match grund:
		"vernichten", "verbannen", "loeschen":
			# Die schwaechste Karte weg.
			return _extrem(hand, false)
		"aufwerten", "kopieren", "verdoppeln", "markieren":
			# Die staerkste Karte staerken.
			return _extrem(hand, true)
		_:
			return hand[0]

## Eine Karte aus dem permanenten Run-Deck.
func deckkarte(run, grund: String) -> Karte:
	var deck: Array = run.deck
	if deck.is_empty():
		return null
	match grund:
		"loeschen":
			return _extrem(deck, false)
		_:
			return _extrem(deck, true)

## Reihenfolge der obersten Ziehstapelkarten festlegen.
## Standard: hoechster Wert zuerst ziehen.
func stapel_ordnen(kampf, karten: Array) -> void:
	if karten.size() < 2:
		return
	var sortiert: Array = karten.duplicate()
	sortiert.sort_custom(func(a, b): return a.musterwert() < b.musterwert())
	# Ziehstapel zieht von hinten - die staerkste Karte muss also ans Ende.
	var pos: Array[int] = []
	for k in karten:
		pos.append(kampf.stapel.ziehstapel.find(k))
	pos.sort()
	for i in pos.size():
		kampf.stapel.ziehstapel[pos[i]] = sortiert[i]

## Eine von mehreren Optionen (Pakte, Rad des Schicksals, Beute).
func option(_kampf, optionen: Array, _grund: String) -> int:
	return 0 if optionen.is_empty() else 0

## Soll ein Pakt angenommen werden? Heuristik: ja, wenn HP komfortabel.
func pakt_annehmen(kampf, _pakt: Dictionary) -> bool:
	return kampf.spieler.hp_anteil() > 0.5

## Grobe Kartenstaerke fuer Heuristiken. Nicht fuer Balancing benutzen -
## nur damit die Simulation plausible Entscheidungen trifft.
static func staerke(k: Karte) -> int:
	var s: int = k.musterwert() + k.stufe * 3
	if k.ist_grosse_arkana():
		s += 12
	if k.ist_fluch:
		s -= 40
	if k.ist_hofkarte():
		s += 4
	return s

static func _extrem(liste: Array, hoechste: bool) -> Karte:
	var beste: Karte = null
	var bester_wert: int = 0
	for k in liste:
		var s: int = staerke(k)
		if beste == null or (s > bester_wert if hoechste else s < bester_wert):
			beste = k
			bester_wert = s
	return beste
