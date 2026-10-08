extends RefCounted
class_name DeterministicRandom
## Reproduzierbarer Zufall (PCG32) - bitgenau wie
## unity/Assets/Tartot/Core/Infrastructure/DeterministicRandom.cs.
##
## Derselbe Seed liefert in C# und hier dieselbe Folge. Das ist die
## Grundlage fuer Tageskarte, geteilte Seeds, Speicherstaende - und fuer den
## Paritaetsbeweis gegen den C#-Kern (tools/paritaet).
##
## GDScript kennt nur vorzeichenbehaftete 64-Bit-Ganzzahlen. Multiplikation
## und Addition wickeln genau wie ulong in C# um; nur das Rechtsschieben
## muss logisch statt arithmetisch sein (lsr).

const MULTIPLIER: int = 6364136223846793005
const DEFAULT_INCREMENT: int = 1442695040888963407
## 14695981039346656037 (FNV-1a-Startwert) als vorzeichenbehaftete Zahl.
const FNV_OFFSET: int = -3750763034362895579
const FNV_PRIME: int = 1099511628211
const MASK32: int = 0xFFFFFFFF

var _state: int = 0
var _increment: int = DEFAULT_INCREMENT
## Wie oft gezogen wurde. Nur fuer Diagnose und Divergenzsuche.
var draw_count: int = 0

func _init(seed_value: int = 0, increment: int = DEFAULT_INCREMENT) -> void:
	_increment = increment | 1
	_state = 0
	next_uint()
	_state = _state + seed_value
	next_uint()

## Logisches Rechtsschieben (ulong >> n) fuer 1 <= n <= 63.
static func lsr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)

## Ein eigener Strom, abgeleitet vom aktuellen Zustand. Ziehungen aus dem
## abgeleiteten Strom veraendern diesen hier nicht.
func stream(name: String) -> DeterministicRandom:
	var h: int = FNV_OFFSET
	for i in name.length():
		h = (h ^ name.unicode_at(i)) * FNV_PRIME
	return DeterministicRandom._roh(_state ^ h, _increment + h, -1)

static func _roh(seed_or_state: int, increment: int, draws: int) -> DeterministicRandom:
	# draws < 0: wie der oeffentliche Konstruktor (Seed einmischen).
	if draws < 0:
		return DeterministicRandom.new(seed_or_state, increment)
	var r := DeterministicRandom.new(0)
	r._state = seed_or_state
	r._increment = increment | 1
	r.draw_count = draws
	return r

func next_uint() -> int:
	var old := _state
	_state = old * MULTIPLIER + _increment
	draw_count += 1
	var xorshifted := lsr(lsr(old, 18) ^ old, 27) & MASK32
	var rot := lsr(old, 59)
	return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & 31))) & MASK32

## Ganzzahl in [0, exclusive_max). Ohne Modulo-Verzerrung.
func next_int(exclusive_max: int) -> int:
	if exclusive_max <= 1:
		return 0
	var bound := exclusive_max
	var threshold := ((1 << 32) - bound) % bound
	while true:
		var r := next_uint()
		if r >= threshold:
			return r % bound
	return 0

## Ganzzahl in [min, max], beide einschliesslich.
func next_inclusive(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return min_value + next_int(max_value - min_value + 1)

## Gleitkommazahl in [0, 1) - exakt der float aus C#.
func next_float() -> float:
	return float(next_uint() >> 8) / 16777216.0

## Chance(float): der Parameter ist in C# ein float - also auch hier float32.
func chance(probability: float) -> bool:
	return next_float() < Num.f(probability)

func chance_percent(percent: float) -> bool:
	return Num.f(next_float() * 100.0) < Num.f(percent)

func pick(list: Array) -> Variant:
	if list.is_empty():
		return null
	return list[next_int(list.size())]

## Gewichtete Wahl. Nicht-positive Gewichte zaehlen als 0. Summen in float32.
func pick_weighted(items: Array, weights: Array) -> Variant:
	if items.is_empty():
		return null
	if weights.size() != items.size():
		return pick(items)
	var total := 0.0
	for w in weights:
		if float(w) > 0.0:
			total = Num.f(total + float(w))
	if total <= 0.0:
		return pick(items)
	var target := Num.f(next_float() * total)
	var running := 0.0
	for i in items.size():
		if float(weights[i]) <= 0.0:
			continue
		running = Num.f(running + float(weights[i]))
		if target < running:
			return items[i]
	return items[items.size() - 1]

## Fisher-Yates, in-place.
func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := next_int(i + 1)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp

## Zieht bis zu count verschiedene Elemente.
func pick_distinct(source: Array, count: int) -> Array:
	var copy := source.duplicate()
	shuffle(copy)
	if count < copy.size():
		copy.resize(count)
	return copy

# ------------------------------------------------------------ Speichern
func snapshot() -> Dictionary:
	return {"state": _state, "inc": _increment, "draws": draw_count}

static func restore(s: Dictionary) -> DeterministicRandom:
	return _roh(int(s.get("state", 0)), int(s.get("inc", DEFAULT_INCREMENT)), int(s.get("draws", 0)))

## ulong als Dezimaltext (wie C# ulong.ToString()).
static func ulong_to_string(x: int) -> String:
	if x >= 0:
		return str(x)
	var ziffern := ""
	var u := x
	while u != 0:
		# Vorzeichenlose Division durch 10: floor(u/2)/5 == floor(u/10).
		var q := lsr(u, 1) / 5
		var r := u - q * 10
		ziffern = str(r) + ziffern
		u = q
	return ziffern

## Dezimaltext eines ulong zurueck in die 64 Bit.
static func ulong_from_string(s: String) -> int:
	var u := 0
	for c in s.strip_edges():
		if c < "0" or c > "9":
			break
		u = u * 10 + int(c)
	return u
