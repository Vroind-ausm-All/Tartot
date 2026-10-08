extends RefCounted
class_name EventDefinition
## Ein Ereignis auf dem Weg: wenige Saetze ("Beats"), eine Entscheidung,
## ein Schlusssatz (Content/Events.cs).

var id: String = ""
var title: String = ""
var art: String = ""
var min_act: int = 1
var max_act: int = 4
var min_darkness: int = 0
var requires_flag: String = ""
var excludes_flag: String = ""
## func(run: RunState) -> bool
var condition: Callable = func(_run: RunState) -> bool: return true
## float32
var weight: float = 1.0
var beats: Array[String] = []
## Variante ab Verdunkelung 40.
var dark_beats: Array[String] = []
## func(run: RunState) -> Array[String] - fuer Szenen, die sich aus dem Run speisen (das Grab).
var dynamic_beats: Callable = Callable()
var choices: Array[EventChoice] = []

func is_story() -> bool:
	return requires_flag != "" or excludes_flag != ""

func beats_for(run: RunState) -> Array[String]:
	if dynamic_beats.is_valid():
		var out: Array[String] = []
		out.assign(dynamic_beats.call(run))
		return out
	return dark_beats if run.darkness >= 40 and not dark_beats.is_empty() else beats

func is_eligible(run: RunState) -> bool:
	var a := mini(4, run.act())
	if a < min_act or a > max_act:
		return false
	if run.darkness < min_darkness:
		return false
	if requires_flag != "" and not run.story_flags.has(requires_flag):
		return false
	if excludes_flag != "" and run.story_flags.has(excludes_flag):
		return false
	if run.seen_events.has(id):
		return false
	return bool(condition.call(run))
