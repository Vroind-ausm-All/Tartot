extends RefCounted
class_name RunSetup
## Wie ein neuer Run beginnt: Figur, Schleier, Tageskarte (Progression/MetaProgress.cs).

var deuter_id: String = DeuterCatalog.DEFAULT_ID
var veil: int = 0
var is_daily: bool = false

func _init(p_deuter_id := DeuterCatalog.DEFAULT_ID, p_veil := 0, p_daily := false) -> void:
	deuter_id = p_deuter_id
	veil = p_veil
	is_daily = p_daily

## Die Tageskarte: fuer alle am selben Tag derselbe Seed, dieselbe Figur
## und derselbe Schleier (2). Auch gesperrte Deuter kommen dran.
## utc: {"year", "month", "day"}; leer = jetzt (UTC).
static func daily(utc: Dictionary = {}) -> RunSetup:
	var seed := MetaProgress.daily_seed(utc)
	var deuters := DeuterCatalog.all()
	return RunSetup.new(deuters[seed % deuters.size()].id, 2, true)
