# Der Inhaltskatalog: laedt data/*.json und liefert Nachschlagetabellen.
#
# Wird einmal beim Start geladen. Alles hier ist unveraenderlich - der
# Laufzeitzustand liegt in Run und Kampf.
extends RefCounted
class_name Katalog

const Konst := preload("res://core/konst.gd")

const PFAD_KLEINE := "res://data/kleine_arkana.json"
const PFAD_GROSSE := "res://data/grosse_arkana.json"
const PFAD_CHARMS := "res://data/charms.json"
const PFAD_ITEMS := "res://data/items.json"
const PFAD_GEGNER := "res://data/gegner.json"
const PFAD_DEUTER := "res://data/deuter.json"

var kleine: Dictionary = {}      # id -> Definition
var grosse: Dictionary = {}      # id -> Definition
var charms: Dictionary = {}
var items: Dictionary = {}
var gegner: Dictionary = {}
var deuter: Dictionary = {}

var kleine_liste: Array = []
var grosse_liste: Array = []
var charm_liste: Array = []
var item_liste: Array = []

var fehler: Array[String] = []

const FARBE_VON_NAME := {
	"SCHWERTER": Konst.Farbe.SCHWERTER,
	"STAEBE": Konst.Farbe.STAEBE,
	"KELCHE": Konst.Farbe.KELCHE,
	"MUENZEN": Konst.Farbe.MUENZEN,
	"ARKANA": Konst.Farbe.ARKANA,
}

const SELTEN_VON_NAME := {
	"GEMEIN": Konst.Selten.GEMEIN,
	"SELTEN": Konst.Selten.SELTEN,
	"ARKAN": Konst.Selten.ARKAN,
	"VERKEHRT": Konst.Selten.VERKEHRT,
	"MYTHOS": Konst.Selten.MYTHOS,
}

func laden() -> bool:
	fehler.clear()
	var d_kleine: Dictionary = _json(PFAD_KLEINE)
	for e in d_kleine.get("karten", []):
		kleine[String(e.get("id", ""))] = e
		kleine_liste.append(e)
	var d_grosse: Dictionary = _json(PFAD_GROSSE)
	for e in d_grosse.get("arkana", []):
		grosse[String(e.get("id", ""))] = e
		grosse_liste.append(e)
	var d_charms: Dictionary = _json(PFAD_CHARMS)
	for e in d_charms.get("charms", []):
		charms[String(e.get("id", ""))] = e
		charm_liste.append(e)
	var d_items: Dictionary = _json(PFAD_ITEMS)
	for e in d_items.get("items", []):
		items[String(e.get("id", ""))] = e
		item_liste.append(e)
	var d_gegner: Dictionary = _json(PFAD_GEGNER)
	for e in d_gegner.get("gegner", []):
		gegner[String(e.get("id", ""))] = e
	var d_deuter: Dictionary = _json(PFAD_DEUTER)
	for e in d_deuter.get("deuter", []):
		deuter[String(e.get("id", ""))] = e
	_pruefen()
	return fehler.is_empty()

func _json(pfad: String) -> Dictionary:
	if not FileAccess.file_exists(pfad):
		fehler.append("Datei fehlt: %s" % pfad)
		return {}
	var f := FileAccess.open(pfad, FileAccess.READ)
	if f == null:
		fehler.append("Kann nicht oeffnen: %s" % pfad)
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var res: Variant = JSON.parse_string(txt)
	if typeof(res) != TYPE_DICTIONARY:
		fehler.append("Ungueltiges JSON: %s" % pfad)
		return {}
	return res

## Grobe Integritaetspruefung, laeuft auch im Test.
func _pruefen() -> void:
	if kleine.size() != 56:
		fehler.append("Erwartet 56 kleine Arkana, gefunden %d" % kleine.size())
	if grosse.size() < 22:
		fehler.append("Erwartet mindestens 22 grosse Arkana, gefunden %d" % grosse.size())
	if charms.size() != 50:
		fehler.append("Erwartet 50 Charms, gefunden %d" % charms.size())
	if items.size() != 22:
		fehler.append("Erwartet 22 Items, gefunden %d" % items.size())
	for id in charms.keys():
		var c: Dictionary = charms[id]
		if not (c.has("mod") or c.has("haken") or c.has("regel")):
			fehler.append("Charm ohne Wirkung: %s" % id)

# --------------------------------------------------------------- Karten bauen
## Baut eine Karteninstanz aus einer Vorlagen-ID.
func karte(vorlage_id: String, ori: int = Konst.Ori.AUFRECHT, stufe: int = 0) -> Karte:
	if kleine.has(vorlage_id):
		var d: Dictionary = kleine[vorlage_id]
		var k := Karte.neu(vorlage_id,
			int(FARBE_VON_NAME.get(String(d.get("farbe", "SCHWERTER")), 0)),
			int(d.get("rang", 1)))
		k.ori = ori
		k.stufe = stufe
		return k
	if grosse.has(vorlage_id):
		var d2: Dictionary = grosse[vorlage_id]
		var k2 := Karte.neu(vorlage_id, Konst.Farbe.ARKANA, int(d2.get("nr", 0)))
		k2.ori = ori
		k2.stufe = stufe
		return k2
	push_warning("Unbekannte Kartenvorlage: %s" % vorlage_id)
	return Karte.neu("unbekannt", Konst.Farbe.SCHWERTER, 1)

func definition(k: Karte) -> Dictionary:
	if k.ist_grosse_arkana():
		return grosse.get(k.vorlage, {})
	return kleine.get(k.vorlage, {})

## Die Op-Liste einer Karte in ihrer aktuellen Orientierung.
func ops(k: Karte) -> Array:
	var d: Dictionary = definition(k)
	if d.is_empty():
		return []
	var schluessel: String = "umgekehrt" if k.ist_umgekehrt() else "aufrecht"
	var liste: Variant = d.get(schluessel, [])
	if typeof(liste) != TYPE_ARRAY:
		return []
	return liste

## Kartentext fuer die UI.
func text(k: Karte) -> String:
	var d: Dictionary = definition(k)
	if d.is_empty():
		return ""
	if k.ist_grosse_arkana():
		return String(d.get("umgekehrt_text" if k.ist_umgekehrt() else "aufrecht_text", ""))
	if bool(d.get("figur", false)):
		return String(d.get("text", ""))
	return _ops_als_text(ops(k))

func _ops_als_text(liste: Array) -> String:
	var teile: Array[String] = []
	for op_v in liste:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_v
		var w: int = int(op.get("wert", 0))
		match String(op.get("op", "")):
			"schaden": teile.append("%d Schaden" % w)
			"selbstschaden": teile.append("%d Selbstschaden" % w)
			"schild": teile.append("%d Schild" % w)
			"heilung": teile.append("Heile %d" % w)
			"traum": teile.append("%d Traum" % w)
			"gold": teile.append("%d Gold" % w)
			"ziehen": teile.append("Ziehe %d" % w)
			"faden": teile.append("%d Schicksal" % w)
			"luck": teile.append("%d Luck" % w)
			"debuff_weg": teile.append("Entferne %d Debuff" % w)
			"status":
				var st: String = String(op.get("st", ""))
				teile.append("%d %s" % [w, st.capitalize()])
			_:
				pass
	return ", ".join(teile)

func ist_figur(k: Karte) -> bool:
	return bool(definition(k).get("figur", false))

func seltenheit(k: Karte) -> int:
	var s: String = String(definition(k).get("selten", "GEMEIN"))
	return int(SELTEN_VON_NAME.get(s, Konst.Selten.GEMEIN))

# ---------------------------------------------------------------- Auswahlhilfe
## Alle Vorlagen-IDs, die als Belohnung auftauchen duerfen.
func belohnungs_pool(nur_farbe: int = -1) -> Array[String]:
	var res: Array[String] = []
	for e in kleine_liste:
		if nur_farbe >= 0 and int(FARBE_VON_NAME.get(String(e.get("farbe", "")), -1)) != nur_farbe:
			continue
		res.append(String(e.get("id", "")))
	return res

func arkana_pool() -> Array[String]:
	var res: Array[String] = []
	for e in grosse_liste:
		# Das Schicksal (XXII) ist nicht normal erhaeltlich.
		if int(e.get("nr", 0)) == 22:
			continue
		res.append(String(e.get("id", "")))
	return res

func gegner_nach(typ: String, abschnitt: int) -> Array[String]:
	var res: Array[String] = []
	for id in gegner.keys():
		var e: Dictionary = gegner[id]
		if String(e.get("typ", "")) == typ and int(e.get("abschnitt", 1)) == abschnitt:
			res.append(String(id))
	return res
