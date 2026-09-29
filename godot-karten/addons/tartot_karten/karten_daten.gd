class_name KartenDaten
extends RefCounted
## Liest den Kartenkatalog, den der Spielkern exportiert
## (dotnet run --project src/Tartot.Sim -- --export-cards=...).
## Die Regeln bleiben im Kern - hier steht nur, was auf der Karte zu sehen ist.

const PFAD := "res://addons/tartot_karten/daten/karten.json"
const EDITIONEN := ["", "Shimmering", "Glowing", "Burning", "Glass"]

static var _geladen := false
static var _karten := {}
static var _seltenheiten := {}
static var _editionen := {}


static func _laden() -> void:
	if _geladen:
		return
	_geladen = true
	var text := FileAccess.get_file_as_string(PFAD)
	var json = JSON.parse_string(text)
	if typeof(json) != TYPE_DICTIONARY:
		push_error("Kartenkatalog fehlt oder ist kaputt: " + PFAD)
		return
	for karte in json["cards"]:
		_karten[karte["id"]] = karte
	_seltenheiten = json["rarities"]
	_editionen = json["editions"]


static func karte(id: String) -> Dictionary:
	_laden()
	return _karten.get(id, {})


static func alle() -> Array:
	_laden()
	return _karten.values()


## Name und Farbe einer Seltenheit ("Common", "Uncommon", "Rare", "Legendary").
static func seltenheit(schluessel: String) -> Dictionary:
	_laden()
	return _seltenheiten.get(schluessel, {"name": "", "color": "#8F7A5A"})


## Name und Wirkung einer Edition ("Shimmering", "Glowing", "Burning", "Glass").
static func edition(schluessel: String) -> Dictionary:
	_laden()
	return _editionen.get(schluessel, {})


## Nummer fuer den Shader (0 keine ... 4 glaesern).
static func edition_nummer(schluessel: String) -> int:
	return max(0, EDITIONEN.find(schluessel))
