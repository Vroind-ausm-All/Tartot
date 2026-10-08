# Meta-Fortschritt ueber Runs hinweg.
#
# Kein "+5 % Schaden". Stattdessen: du verstehst das Tarot besser.
# Jede Begegnung mit einem Arkanum schaltet Interpretationen frei, die dem
# Arkanum in kuenftigen Runs neue Effekte geben. Und jeder Tod hinterlaesst
# eine Totenkarte, die spaeteren Runs begegnen kann.
extends RefCounted
class_name Meta

const PFAD := "user://tartot_meta.json"

var deuter_frei: Array[String] = ["wahrsagerin", "aderleser", "traumtrinkerin"]
var arkana_begegnungen: Dictionary = {}     # arkana_id -> Anzahl
var interpretationen: Dictionary = {}       # arkana_id -> Array[String]
var totenkarten: Array = []                 # [{name, deuter, raum, deck_groesse, seed}]
var bestwerte: Dictionary = {
	"tiefste_spirale": 0, "schnellster_sieg": 0, "kleinstes_deck": 99,
}
var schleier: int = 0                       # Schwierigkeitsstufe 0-8
var gesehene_karten: Dictionary = {}
var statistik: Dictionary = {"runs": 0, "siege": 0, "tode": 0}

## Ab wie vielen Begegnungen ein Arkanum eine neue Lesart offenbart.
const INTERPRETATION_SCHWELLEN: Array[int] = [1, 5, 12]
const INTERPRETATION_NAMEN: Array[String] = ["Erste Lesart", "Transformation", "Verkehrte Lesart"]

func arkanum_begegnet(arkana_id: String) -> String:
	var n: int = int(arkana_begegnungen.get(arkana_id, 0)) + 1
	arkana_begegnungen[arkana_id] = n
	var idx: int = INTERPRETATION_SCHWELLEN.find(n)
	if idx < 0:
		return ""
	var liste: Array = interpretationen.get(arkana_id, [])
	var name: String = INTERPRETATION_NAMEN[idx]
	if not liste.has(name):
		liste.append(name)
		interpretationen[arkana_id] = liste
	return name

func hat_interpretation(arkana_id: String, name: String) -> bool:
	return (interpretationen.get(arkana_id, []) as Array).has(name)

func deuter_freischalten(id: String) -> bool:
	if deuter_frei.has(id):
		return false
	deuter_frei.append(id)
	return true

## Nach einem Tod: eine Totenkarte aus dem Run formen. Sie kann in spaeteren
## Runs als Gegner oder als Fundstueck auftauchen.
func totenkarte_anlegen(run: Run) -> Dictionary:
	var tk := {
		"name": "%s, gefallen in Raum %d" % [run.spieler.name, run.raum_nr],
		"deuter": run.deuter_id,
		"abschnitt": run.abschnitt,
		"raum": run.raum_nr,
		"deck_groesse": run.deck.size(),
		"verderbnis": run.verderbnis,
		"seed": run.seed_wert,
		"charms": run.charms.stacks.duplicate(),
	}
	totenkarten.append(tk)
	if totenkarten.size() > 30:
		totenkarten.remove_at(0)
	statistik["tode"] = int(statistik["tode"]) + 1
	return tk

func run_beenden(run: Run) -> void:
	statistik["runs"] = int(statistik["runs"]) + 1
	if run.gewonnen:
		statistik["siege"] = int(statistik["siege"]) + 1
	bestwerte["tiefste_spirale"] = maxi(int(bestwerte["tiefste_spirale"]), run.endlos_tiefe)
	bestwerte["kleinstes_deck"] = mini(int(bestwerte["kleinstes_deck"]), run.deck.size())
	if run.deck.size() <= 8:
		deuter_freischalten("leeres_blatt")
	speichern()

## Tageskarte: derselbe Seed fuer alle Spieler an einem Tag.
static func tagesseed() -> int:
	var d: Dictionary = Time.get_date_dict_from_system(true)
	return int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])

func speichern() -> void:
	var d := {
		"version": 1, "deuter_frei": deuter_frei,
		"arkana_begegnungen": arkana_begegnungen,
		"interpretationen": interpretationen, "totenkarten": totenkarten,
		"bestwerte": bestwerte, "schleier": schleier,
		"gesehene_karten": gesehene_karten, "statistik": statistik,
	}
	var f := FileAccess.open(PFAD, FileAccess.WRITE)
	if f == null:
		push_warning("Meta konnte nicht gespeichert werden.")
		return
	f.store_string(JSON.stringify(d, "  "))
	f.close()

func laden() -> void:
	if not FileAccess.file_exists(PFAD):
		return
	var f := FileAccess.open(PFAD, FileAccess.READ)
	if f == null:
		return
	var res: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(res) != TYPE_DICTIONARY:
		return
	var d: Dictionary = res
	deuter_frei.clear()
	for x in d.get("deuter_frei", ["wahrsagerin"]):
		deuter_frei.append(String(x))
	arkana_begegnungen = (d.get("arkana_begegnungen", {}) as Dictionary).duplicate()
	interpretationen = (d.get("interpretationen", {}) as Dictionary).duplicate()
	totenkarten = (d.get("totenkarten", []) as Array).duplicate()
	bestwerte = (d.get("bestwerte", bestwerte) as Dictionary).duplicate()
	schleier = int(d.get("schleier", 0))
	gesehene_karten = (d.get("gesehene_karten", {}) as Dictionary).duplicate()
	statistik = (d.get("statistik", statistik) as Dictionary).duplicate()
