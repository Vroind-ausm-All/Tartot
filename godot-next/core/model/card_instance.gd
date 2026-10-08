extends RefCounted
class_name CardInstance
## Eine Karte im Run (Model/Cards.cs): Level, Schimmer, Rage, Orientierung,
## Erfahrung, Siegesmale, Edition. Die Definition bleibt unveraendert.

static var _zaehler: int = 0
static var _praefix: String = ""

var instance_id: String = ""
var definition: CardDefinition
var level: int = 1
var shimmer: int = Enums.Shimmer.MATTE
var orientation: int = Enums.Orientation.UPRIGHT
var is_copy: bool = false
var experience: int = 0
var victory_marks: int = 0
var rage: int = 0
## Veredelung dieser einen Karte: schimmernd, leuchtend, brennend, glaesern.
var edition: int = Enums.CardEdition.NONE

func _init(p_definition: CardDefinition = null, p_is_copy := false) -> void:
	definition = p_definition
	is_copy = p_is_copy
	instance_id = neue_id()

## Eindeutige Instanz-Id (C#: Guid). Beeinflusst den Spielverlauf nicht.
static func neue_id() -> String:
	if _praefix == "":
		_praefix = "%08x" % (Time.get_ticks_usec() & 0xFFFFFFFF)
	_zaehler += 1
	return "%s%016x" % [_praefix, _zaehler]

func effective_rank() -> int:
	@warning_ignore("integer_division")
	return maxi(1, definition.rank + (level - 1) / 2 + _shimmer_bonus())

func power_multiplier() -> float:
	var s := Num.add(1.0, Num.mul(shimmer, 0.10))
	var l := Num.add(1.0, Num.mul(level - 1, 0.06))
	var r := 1.18 if orientation == Enums.Orientation.REVERSED else 1.0
	return Num.mul(Num.mul(s, l), r)

func is_upgraded() -> bool:
	return level > 1 or shimmer > Enums.Shimmer.MATTE

func xp_to_next_level() -> int:
	return 20 + (level - 1) * 15

func add_experience(amount: int) -> void:
	experience += maxi(0, amount)
	while experience >= xp_to_next_level():
		var need := xp_to_next_level()
		experience -= need
		level += 1
		if level % 3 == 0 and shimmer < Enums.Shimmer.GOLD:
			shimmer += 1

func add_victory_mark() -> void:
	victory_marks += 1
	if victory_marks >= 3:
		victory_marks -= 3
		level += 1
		if shimmer < Enums.Shimmer.GOLD:
			shimmer += 1

func _shimmer_bonus() -> int:
	return shimmer

func is_reversed() -> bool:
	return orientation == Enums.Orientation.REVERSED

func short_label() -> String:
	var rev := "↕ " if is_reversed() else ""
	var copy := "✦ " if is_copy else ""
	var rg := " · RAGE %d/3" % rage if rage > 0 else ""
	return "%s%s%s L%d%s" % [copy, rev, definition.name, level, rg]
