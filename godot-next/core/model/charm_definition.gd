extends RefCounted
class_name CharmDefinition
## Ein Charm aus dem Katalog (Model/Definitions.cs).

var id: String
var name: String
var effect: int
## float32 wie in C#.
var magnitude: float
var max_stacks: int
var description: String

func _init(p_id := "", p_name := "", p_effect := 0, p_magnitude := 0.0, p_max := 1, p_desc := "") -> void:
	id = p_id
	name = p_name
	effect = p_effect
	magnitude = Num.f(p_magnitude)
	max_stacks = p_max
	description = p_desc
