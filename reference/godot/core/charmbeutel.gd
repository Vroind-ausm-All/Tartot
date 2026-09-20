# Der Charmbeutel: welche Charms hat der Spieler, wie oft, und was tun sie.
#
# Gleiche Charms verschmelzen zu Stacks (max. 5), damit die Leiste im Kampf
# nie ueberlaeuft. Ein Stack ist ein Multiplikator auf die Wirkung, nicht
# ein zweites Icon.
extends RefCounted
class_name Charmbeutel

const Konst := preload("res://core/konst.gd")

var stacks: Dictionary = {}          # charm_id -> Anzahl
var katalog: Katalog
## Figuren (Hofkarten) laufen ueber dieselbe Engine, stehen aber getrennt,
## weil nur eine aktiv sein darf.
var figur_vorlage: String = ""

func _init(p_katalog: Katalog) -> void:
	katalog = p_katalog

func anzahl(charm_id: String) -> int:
	return int(stacks.get(charm_id, 0))

func hat(charm_id: String) -> bool:
	return anzahl(charm_id) > 0

func verschiedene() -> int:
	return stacks.size()

func gesamt_stacks() -> int:
	var n: int = 0
	for v in stacks.values():
		n += int(v)
	return n

## Gibt zurueck, wie viele Stacks tatsaechlich dazugekommen sind.
func geben(charm_id: String, n: int = 1) -> int:
	if not katalog.charms.has(charm_id):
		push_warning("Unbekannter Charm: %s" % charm_id)
		return 0
	var maxi: int = int(katalog.charms[charm_id].get("max", Konst.CHARM_STACK_MAX))
	var vorher: int = anzahl(charm_id)
	var nachher: int = mini(maxi, vorher + n)
	if nachher == vorher:
		return 0
	stacks[charm_id] = nachher
	return nachher - vorher

func nehmen(charm_id: String, n: int = 1) -> void:
	var neu: int = anzahl(charm_id) - n
	if neu <= 0:
		stacks.erase(charm_id)
	else:
		stacks[charm_id] = neu

## Wert einer benannten Sonderregel, summiert ueber alle Stacks.
## Beispiel: regelwert("dornenring") -> 2 * Stacks
func regelwert(regel: String) -> int:
	var summe: int = 0
	for id in stacks.keys():
		var c: Dictionary = katalog.charms[id]
		if String(c.get("regel", "")) == regel:
			summe += int(c.get("regelwert", 1)) * int(stacks[id])
	if figur_vorlage != "":
		var f: Dictionary = katalog.kleine.get(figur_vorlage, {})
		if String(f.get("regel", "")) == regel:
			summe += 1
	return summe

func hat_regel(regel: String) -> bool:
	return regelwert(regel) > 0

# --------------------------------------------------------- Modifikatoren
## Sammelt alle Wertaenderungen fuer eine Karte, die gerade ausgeloest wird.
## Rueckgabe: { "promille": int, "flach": Dictionary, "durchdringung": int }
func modifikator(kampf, kontext: Dictionary) -> Dictionary:
	var res := {"promille": 0, "flach": {}, "durchdringung": 0}
	for id in stacks.keys():
		_ein_traeger(kampf, kontext, katalog.charms[id], int(stacks[id]), res)
	if figur_vorlage != "":
		_ein_traeger(kampf, kontext, katalog.kleine.get(figur_vorlage, {}), 1, res)
	return res

func _ein_traeger(kampf, kontext: Dictionary, def: Dictionary, n: int, res: Dictionary) -> void:
	var mods: Variant = def.get("mod", [])
	if typeof(mods) != TYPE_ARRAY:
		return
	for m_v in mods:
		if typeof(m_v) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = m_v
		if not Bedingung.erfuellt(kampf, kontext, m.get("wenn", {})):
			continue
		res["promille"] = int(res["promille"]) + int(m.get("promille", 0)) * n
		res["durchdringung"] = int(res["durchdringung"]) + int(m.get("schild_durchdringung", 0)) * n
		var flach: Variant = m.get("flach", {})
		if typeof(flach) == TYPE_DICTIONARY:
			for schluessel in (flach as Dictionary).keys():
				var alt: int = int((res["flach"] as Dictionary).get(schluessel, 0))
				(res["flach"] as Dictionary)[schluessel] = alt + int((flach as Dictionary)[schluessel]) * n

# ---------------------------------------------------------------- Haken
## Loest alle Haken fuer ein Ereignis aus. Ops werden n-mal angewendet
## (ein Stack = eine Anwendung), damit Werte linear stapeln.
func haken(kampf, ereignis: String, kontext: Dictionary) -> void:
	for id in stacks.keys():
		_haken_traeger(kampf, ereignis, kontext, katalog.charms[id], int(stacks[id]), id)
	if figur_vorlage != "":
		_haken_traeger(kampf, ereignis, kontext,
			katalog.kleine.get(figur_vorlage, {}), 1, figur_vorlage)

func _haken_traeger(kampf, ereignis: String, kontext: Dictionary,
		def: Dictionary, n: int, quelle_id: String) -> void:
	var liste: Variant = def.get("haken", [])
	if typeof(liste) != TYPE_ARRAY:
		return
	for h_v in liste:
		if typeof(h_v) != TYPE_DICTIONARY:
			continue
		var h: Dictionary = h_v
		if String(h.get("bei", "")) != ereignis:
			continue
		if not Bedingung.erfuellt(kampf, kontext, h.get("wenn", {})):
			continue
		var k2: Dictionary = kontext.duplicate()
		k2["quelle"] = String(def.get("name", quelle_id))
		k2["modifikator"] = 1000
		k2["flach"] = {}
		for _i in n:
			Effekte.anwenden(kampf, k2, h.get("ops", []))

func speichern() -> Dictionary:
	return {"stacks": stacks.duplicate(), "figur": figur_vorlage}

func laden(d: Dictionary) -> void:
	stacks = (d.get("stacks", {}) as Dictionary).duplicate()
	figur_vorlage = String(d.get("figur", ""))

## Kompakte Kampfleiste: [{id, name, n, text}]
func leiste() -> Array:
	var res: Array = []
	for id in stacks.keys():
		var c: Dictionary = katalog.charms[id]
		res.append({
			"id": id, "name": String(c.get("name", id)),
			"n": int(stacks[id]), "text": String(c.get("text", "")),
			"selten": String(c.get("selten", "GEMEIN")),
		})
	res.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	return res
