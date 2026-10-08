extends RefCounted
class_name EventContext
## Was eine Ereigniswahl sehen und veraendern darf.

var run: RunState
var rng: DeterministicRandom

func _init(p_run: RunState = null, p_rng: DeterministicRandom = null) -> void:
	run = p_run
	rng = p_rng
