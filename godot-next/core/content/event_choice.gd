extends RefCounted
class_name EventChoice
## Eine Wahl in einem Ereignis (Content/Events.cs).

var label: String = ""
## Was die Wahl kostet und bringt - mit Wahrscheinlichkeiten.
var hint: String = ""
## func(run: RunState) -> bool
var available: Callable = func(_run: RunState) -> bool: return true
## func(ctx: EventContext) -> String: fuehrt die Wahl aus, liefert den Schlusssatz.
var resolve: Callable = func(_ctx: EventContext) -> String: return ""

func is_available(run: RunState) -> bool:
	return bool(available.call(run))

func run(ctx: EventContext) -> String:
	var s: Variant = resolve.call(ctx)
	return "" if s == null else String(s)
