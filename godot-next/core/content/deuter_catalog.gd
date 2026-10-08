extends RefCounted
class_name DeuterCatalog
## Die spielbaren Figuren (Content/Deuters.cs) und die Schleier.

const DEFAULT_ID := "wahrsagerin"
const MAX_VEIL := 8

static var _all: Array[DeuterDefinition] = []

static func all() -> Array[DeuterDefinition]:
	if _all.is_empty():
		_build()
	return _all

static func default_deuter() -> DeuterDefinition:
	return all()[0]

static func find(id: String) -> DeuterDefinition:
	for d in all():
		if d.id == id:
			return d
	return default_deuter()

static func _d(id: String, name: String, subtitle: String, rule_text: String, rule: int, hp: int, gold: int,
		luck: int, deck: Array, reversed: Array, charms: Array, items: Array, unlocked_by: String) -> DeuterDefinition:
	var d := DeuterDefinition.new()
	d.id = id
	d.name = name
	d.subtitle = subtitle
	d.rule_text = rule_text
	d.rule = rule
	d.max_hp = hp
	d.gold = gold
	d.luck = luck
	d.deck.assign(deck)
	d.reversed_cards.assign(reversed)
	d.charms.assign(charms)
	d.items.assign(items)
	d.unlocked_by = unlocked_by
	return d

static func _build() -> void:
	_all = [
		_d(DEFAULT_ID, "Die Wahrsagerin", "Sie liest, was ohnehin geschieht.",
			"Keine Sonderregel. Der ehrliche Weg.", Enums.DeuterRule.NONE, 72, 90, 2,
			["pentacles_4", "swords_7", "wands_10", "cups_6", "swords_3", "pentacles_6", "wands_4", "cups_8", "major_1", "major_0"],
			[], ["white_thread", "lucky_clover"], ["mirror_shard"], ""),
		_d("aderleser", "Der Aderleser", "Er braucht dein Blut, nicht deine Zukunft.",
			"Umgekehrte Karten geben +0,15 Multiplikator statt +0,10 - und kosten ein Viertel mehr.",
			Enums.DeuterRule.BLOOD_READER, 70, 80, 1,
			["swords_5", "swords_7", "swords_9", "wands_6", "wands_8", "cups_5", "cups_7", "cups_9", "pentacles_5", "major_8"],
			["swords_7", "swords_9", "wands_8"], ["blood_moon", "moon_brooch"], ["sun_vial"], "blutige_lesung"),
		_d("buchhalter", "Der Buchhalter", "Er notiert jeden Treffer. Auch deine.",
			"15 % deines Schildes bleibt zwischen den Runden. Vergessen kostet doppelt.",
			Enums.DeuterRule.BOOKKEEPER, 64, 90, 2,
			["pentacles_3", "pentacles_5", "pentacles_7", "pentacles_9", "swords_4", "swords_6", "cups_4", "wands_5", "major_4", "major_11"],
			[], [], ["pentacle_pouch"], "voller_tresor"),
		_d("eremit", "Der Eremit", "Er trägt nur, was er braucht. Den Rest vergisst er.",
			"Deck-Resonanz wirkt doppelt. Kartenbelohnungen erscheinen seltener.",
			Enums.DeuterRule.HERMIT, 68, 80, 3,
			["swords_8", "wands_7", "cups_6", "pentacles_7", "swords_10", "major_9"],
			[], ["lucky_clover"], ["fate_scissors"], "leeres_blatt")
	]

## Schleier 0-8. Jede Stufe nimmt genau eine Sicherheit weg und stapelt sich.
const VEILS := [
	{"level": 0, "name": "Ohne Schleier", "text": "Das Spiel, wie es gedacht ist."},
	{"level": 1, "name": "Geizige Hände", "text": "Kämpfe bringen ein Viertel weniger Gold."},
	{"level": 2, "name": "Wache Omen", "text": "Elites und Bosse haben 20 % mehr HP und Haltung."},
	{"level": 3, "name": "Stumpfe Lesung", "text": "Belohnungen bieten eine Wahl weniger."},
	{"level": 4, "name": "Dünne Haut", "text": "Du beginnst mit 4 Max-HP weniger."},
	{"level": 5, "name": "Scharfe Omen", "text": "Ab Akt II schlagen Elites und Bosse je Akt 1 härter zu."},
	{"level": 6, "name": "Hungrige Schatten", "text": "Ab Akt II schlagen alle Gegner 1 härter zu."},
	{"level": 7, "name": "Blutzoll", "text": "Umkehrpreis +50 %, Rast und Aktwechsel heilen weniger."},
	{"level": 8, "name": "Das letzte Siegel", "text": "Die Welt trägt ein weiteres Schicksalssiegel."}
]

static func veil(level: int) -> Dictionary:
	return VEILS[maxi(0, mini(MAX_VEIL, level))]
