# Deterministischer Zufallsgenerator (64-Bit-LCG, Knuth/MMIX-Konstanten).
#
# Warum nicht RandomNumberGenerator? Wir brauchen:
#   * exakte Reproduzierbarkeit ueber Godot-Versionen und Plattformen hinweg
#     (Tageskarte, Bestenliste, Seed-Sharing, Replays),
#   * serialisierbaren Zustand fuer Speichern mitten im Run,
#   * getrennte Stroeme, damit ein Reroll im Laden nicht die Kampf-Zuege verschiebt.
extends RefCounted
class_name TRng

const _MUL: int = 6364136223846793005
const _INC: int = 1442695040888963407

var zustand: int = 0
var zaehler: int = 0  # wie oft gezogen wurde - fuer Debug und Divergenz-Erkennung

func _init(seed_wert: int = 0) -> void:
	setze_seed(seed_wert)

func setze_seed(seed_wert: int) -> void:
	# Seed wird gemischt, damit benachbarte Seeds (1, 2, 3) sehr
	# unterschiedliche Stroeme ergeben.
	zustand = seed_wert
	zaehler = 0
	for _i in 4:
		_schritt()

## Eigener Strom, abgeleitet vom aktuellen Zustand. Der abgeleitete Strom
## kann beliebig gezogen werden, ohne den Eltern-Strom zu veraendern.
func strom(bezeichner: String) -> TRng:
	var h: int = 1469598103934665603
	for i in bezeichner.length():
		h = (h ^ bezeichner.unicode_at(i)) * 1099511628211
	return TRng.new(zustand ^ h)

func _schritt() -> int:
	zustand = zustand * _MUL + _INC
	zaehler += 1
	return (zustand >> 17) & 0x7FFFFFFFFFFF

## Ganzzahl in [0, grenze). Bei grenze <= 0 immer 0.
func int_bis(grenze: int) -> int:
	if grenze <= 0:
		return 0
	return _schritt() % grenze

## Ganzzahl in [von, bis] inklusive.
func int_zwischen(von: int, bis: int) -> int:
	if bis <= von:
		return von
	return von + int_bis(bis - von + 1)

## Gleitkommazahl in [0, 1).
func f() -> float:
	return float(_schritt() % 1000000) / 1000000.0

## Wahr mit Wahrscheinlichkeit p (0.0 - 1.0).
func chance(p: float) -> bool:
	return f() < p

## Wahr mit Wahrscheinlichkeit prozent/100.
func chance_prozent(prozent: float) -> bool:
	return f() * 100.0 < prozent

## Zufaelliges Element. Leeres Array -> null.
func waehle(liste: Array) -> Variant:
	if liste.is_empty():
		return null
	return liste[int_bis(liste.size())]

## Gewichtete Wahl. gewichte muss dieselbe Laenge wie liste haben.
func waehle_gewichtet(liste: Array, gewichte: Array) -> Variant:
	if liste.is_empty():
		return null
	var summe: float = 0.0
	for g in gewichte:
		summe += maxf(0.0, float(g))
	if summe <= 0.0:
		return waehle(liste)
	var ziel: float = f() * summe
	var lauf: float = 0.0
	for i in liste.size():
		lauf += maxf(0.0, float(gewichte[i]))
		if ziel < lauf:
			return liste[i]
	return liste[liste.size() - 1]

## Zieht n verschiedene Elemente (ohne Zuruecklegen).
func waehle_mehrere(liste: Array, n: int) -> Array:
	var kopie: Array = liste.duplicate()
	mische(kopie)
	return kopie.slice(0, mini(n, kopie.size()))

## Fisher-Yates, in-place. Deterministisch.
func mische(liste: Array) -> void:
	for i in range(liste.size() - 1, 0, -1):
		var j: int = int_bis(i + 1)
		var t: Variant = liste[i]
		liste[i] = liste[j]
		liste[j] = t

func speichern() -> Dictionary:
	return {"zustand": zustand, "zaehler": zaehler}

func laden(d: Dictionary) -> void:
	zustand = int(d.get("zustand", 0))
	zaehler = int(d.get("zaehler", 0))
