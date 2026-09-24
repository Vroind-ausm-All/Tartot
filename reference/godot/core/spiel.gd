# Autoload-Singleton: haelt Katalog, Meta-Fortschritt und den laufenden Run.
# Absichtlich duenn - die Spiellogik lebt in den RefCounted-Klassen, damit
# sie ohne Szenenbaum testbar bleibt.
extends Node

var katalog: Katalog
var run: Run = null
var meta: Meta

func _ready() -> void:
	katalog = Katalog.new()
	if not katalog.laden():
		for f in katalog.fehler:
			push_error("Katalogfehler: %s" % f)
	meta = Meta.new()
	meta.laden()

func neuer_run(deuter_id: String, seed_wert: int = 0, endlos: bool = false) -> Run:
	run = Run.neu(katalog, deuter_id, seed_wert, endlos)
	return run
