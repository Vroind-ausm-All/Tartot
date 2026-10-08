class_name KartenDaten
extends RefCounted
## Was auf einer Karte zu sehen ist - gelesen aus dem Regelkern
## (GameCatalog, CardEditions). Die Regeln bleiben im Kern; hier stehen nur
## Name, Zahl, Farbe, Seltenheit und Text, so wie der Tisch sie braucht.
##
## In godot-karten kam das aus einer exportierten JSON-Datei; in godot-next
## liegt der Kern in GDScript daneben, also wird direkt gelesen.

const EDITIONEN := ["", "Shimmering", "Glowing", "Burning", "Glass"]
const SELTENHEITEN := ["Common", "Uncommon", "Rare", "Legendary"]

static var _karten := {}
static var _seltenheiten := {}
static var _editionen := {}


static func _laden() -> void:
	if not _karten.is_empty():
		return
	for c in GameCatalog.cards():
		_karten[c.id] = {
			"id": c.id,
			"name": c.name,
			"suit": Enums.NAMES_SUIT[c.suit],
			"rank": c.rank,
			"number": Num.roman(c.display_number()) if c.is_major() else str(c.display_number()),
			"rarity": SELTENHEITEN[c.rarity()],
			"power": c.base_power,
			"text": c.description,
		}
	for i in SELTENHEITEN.size():
		_seltenheiten[SELTENHEITEN[i]] = {"name": CardEditions.rarity_name(i), "color": CardEditions.rarity_color(i)}
	for i in range(1, EDITIONEN.size()):
		_editionen[EDITIONEN[i]] = {
			"name": CardEditions.name_of(i),
			"text": CardEditions.text_of(i),
			"chips": CardEditions.chips(i),
			"mult": CardEditions.mult_add(i),
			"xmult": CardEditions.mult_x(i),
		}


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
