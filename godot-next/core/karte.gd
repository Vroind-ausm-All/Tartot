extends RefCounted
class_name Karte

var definition: Dictionary = {}
var instance_id: String = ""
var level: int = 1
var shimmer: int = Konst.Shimmer.MATTE
var orientation: int = Konst.Orientation.UPRIGHT
var rage: int = 0
var is_copy: bool = false

func _init(def: Dictionary = {}, iid: String = "") -> void:
	definition = def
	instance_id = iid

func clone(new_id: String = "") -> Karte:
	var k := Karte.new(definition, new_id if new_id != "" else instance_id)
	k.level = level
	k.shimmer = shimmer
	k.orientation = orientation
	k.rage = rage
	k.is_copy = true
	return k

func id() -> String:
	return String(definition.get("id", ""))

func name() -> String:
	return String(definition.get("name", id()))

func suit() -> int:
	return int(definition.get("suit", Konst.Suit.SWORDS))

func rank() -> int:
	return int(definition.get("rank", 1))

func is_major() -> bool:
	return bool(definition.get("major", false))

func display_number() -> int:
	return int(definition.get("display_number", rank()))

func effective_rank() -> int:
	var shimmer_bonus := maxi(0, shimmer - Konst.Shimmer.WHITE)
	return maxi(1, rank() + int((level - 1) / 2) + shimmer_bonus)

func reversed() -> bool:
	return orientation == Konst.Orientation.REVERSED

func flip() -> void:
	orientation = Konst.Orientation.REVERSED if orientation == Konst.Orientation.UPRIGHT else Konst.Orientation.UPRIGHT

func upgrade(n: int = 1) -> void:
	level = maxi(1, level + n)

func darken(n: int = 1) -> void:
	shimmer = mini(Konst.Shimmer.BLACK, shimmer + n)

func strength() -> int:
	return shimmer * 10 + level * 4 + rank() + (8 if is_major() else 0)

func save() -> Dictionary:
	return {
		"id": id(), "instance_id": instance_id, "level": level, "shimmer": shimmer,
		"orientation": orientation, "rage": rage, "copy": is_copy
	}

static func load_from(data: Dictionary, katalog: Katalog) -> Karte:
	var def := katalog.card_def(String(data.get("id", "")))
	if def.is_empty():
		return null
	var k := Karte.new(def, String(data.get("instance_id", "")))
	k.level = maxi(1, int(data.get("level", 1)))
	k.shimmer = clampi(int(data.get("shimmer", 0)), Konst.Shimmer.MATTE, Konst.Shimmer.BLACK)
	k.orientation = clampi(int(data.get("orientation", 0)), Konst.Orientation.UPRIGHT, Konst.Orientation.REVERSED)
	k.rage = clampi(int(data.get("rage", 0)), 0, 3)
	k.is_copy = bool(data.get("copy", false))
	return k
