extends RefCounted
class_name Num
## Zahlen genau so, wie der C#-Kern sie rechnet.
##
## Der Regelkern (unity/Assets/Tartot/Core) rechnet mit float (32 Bit) und
## rundet mit Math.Round (kaufmaennisch zur geraden Zahl, "Banker's
## Rounding"). GDScript rechnet mit 64-Bit-Gleitkomma und rundet 0,5 immer
## weg von der Null. Ohne diese Helfer laufen Wertungen an Randfaellen
## (x,5 oder 0,15f + 0,10f) um eins auseinander - und dann divergiert der
## ganze Run. Jede float-Rechnung des Kerns geht deshalb durch f().

static var _puffer := PackedFloat32Array([0.0])

## Rundet einen Wert auf float32 (round-to-nearest-even), wie eine
## einzelne float-Operation in C#.
static func f(x: float) -> float:
	_puffer[0] = x
	return _puffer[0]

## float-Arithmetik wie C#: beide Operanden und das Ergebnis in float32.
## Konstanten wie 0.15 werden dabei automatisch zu 0.15f.
static func mul(a: float, b: float) -> float:
	return f(f(a) * f(b))

static func add(a: float, b: float) -> float:
	return f(f(a) + f(b))

static func sub(a: float, b: float) -> float:
	return f(f(a) - f(b))

static func dv(a: float, b: float) -> float:
	return f(f(a) / f(b))

## Math.Round(double): x,5 rundet zur geraden Zahl.
static func round_even(x: float) -> float:
	var unten := floorf(x)
	var rest := x - unten
	if rest > 0.5:
		return unten + 1.0
	if rest < 0.5:
		return unten
	return unten if fmod(unten, 2.0) == 0.0 else unten + 1.0

## (int)Math.Round(x)
static func rnd(x: float) -> int:
	return int(round_even(x))

## Ganzzahlige Division wie in C# (schneidet zur Null ab) - nur zur Lesbarkeit.
static func div(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	return a / b

## Stabile Sortierung (wie LINQ OrderBy/OrderByDescending). Godots
## sort_custom ist nicht stabil - bei gleichen Schluesseln entschiede sonst
## die Speicherlage, und der Run liefe anders als in C#.
static func sortiert(liste: Array, schluessel: Callable, absteigend := false) -> Array:
	var paare: Array = []
	for i in liste.size():
		paare.append([schluessel.call(liste[i]), i, liste[i]])
	if absteigend:
		paare.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	else:
		paare.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var aus: Array = []
	for p in paare:
		aus.append(p[2])
	return aus

## Erstes Element mit dem kleinsten Schluessel (OrderBy(...).First()).
static func kleinstes(liste: Array, schluessel: Callable) -> Variant:
	var bestes: Variant = null
	var bester_wert: Variant = null
	for x in liste:
		var w: Variant = schluessel.call(x)
		if bestes == null or w < bester_wert:
			bestes = x
			bester_wert = w
	return bestes

## Erstes Element mit dem groessten Schluessel (OrderByDescending(...).First()).
static func groesstes(liste: Array, schluessel: Callable) -> Variant:
	var bestes: Variant = null
	var bester_wert: Variant = null
	for x in liste:
		var w: Variant = schluessel.call(x)
		if bestes == null or w > bester_wert:
			bestes = x
			bester_wert = w
	return bestes

## Summe wie LINQ Sum(float): Akkumulator double, Ergebnis float.
static func summe_f(werte: Array) -> float:
	var s := 0.0
	for w in werte:
		s += float(w)
	return f(s)

## Roemische Zahl; 0 bleibt "0" (Der Narr).
static func roman(value: int) -> String:
	if value <= 0 or value >= 4000:
		return str(value)
	var werte := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var zeichen := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var s := ""
	for i in werte.size():
		while value >= werte[i]:
			s += zeichen[i]
			value -= werte[i]
	return s

## Deutsches Dezimalkomma mit zwei Stellen ("2,35").
static func de(x: float, stellen := 2) -> String:
	return (("%." + str(stellen) + "f") % x).replace(".", ",")
