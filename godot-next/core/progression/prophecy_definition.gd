extends RefCounted
class_name ProphecyDefinition
## Ein Ziel ueber Runs hinweg, das etwas freischaltet (Progression/Prophecies.cs).
##
## Belohnt wird mit neuen Moeglichkeiten (Charms, Deuter), nie mit
## pauschaler Kraft.

var id: String = ""
var title: String = ""
var text: String = ""
var target: int = 0
## func(meta: MetaProgress, run: RunState) -> int; run darf null sein (nur Meta).
var value: Callable
var unlock_charms: Array[String] = []
var unlock_deuter: String = ""

func value_of(meta: MetaProgress, run: RunState) -> int:
	return int(value.call(meta, run))

## Math.Min(1f, (float)Value / Target) - float32.
func progress(meta: MetaProgress, run: RunState) -> float:
	if target <= 0:
		return 1.0
	return minf(1.0, Num.dv(value_of(meta, run), target))

func is_fulfilled(meta: MetaProgress, run: RunState) -> bool:
	return value_of(meta, run) >= target

func reward_text() -> String:
	var parts: Array[String] = []
	if unlock_deuter != "":
		parts.append("Deuter: " + DeuterCatalog.find(unlock_deuter).name)
	for charm_id in unlock_charms:
		var charm := GameCatalog.charm(charm_id)
		if charm != null:
			parts.append("Charm: " + charm.name)
	return " · ".join(parts)
