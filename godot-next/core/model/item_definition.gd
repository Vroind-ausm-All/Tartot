extends RefCounted
class_name ItemDefinition
## Ein Item aus dem Katalog (Model/Definitions.cs).

var id: String
var name: String
var effect: int
var magnitude: int
var description: String

func _init(p_id := "", p_name := "", p_effect := 0, p_magnitude := 0, p_desc := "") -> void:
	id = p_id
	name = p_name
	effect = p_effect
	magnitude = p_magnitude
	description = p_desc
