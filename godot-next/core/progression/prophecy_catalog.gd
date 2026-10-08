extends RefCounted
class_name ProphecyCatalog
## Alle Prophezeiungen (Progression/Prophecies.cs). Reihenfolge wie in C# -
## sie bestimmt die Reihenfolge der Freischaltungen im Run-Bericht.

static var _all: Array[ProphecyDefinition] = []
static var _locked: Dictionary = {}

static func all() -> Array[ProphecyDefinition]:
	if _all.is_empty():
		_build()
	return _all

static func find(id: String) -> ProphecyDefinition:
	for p in all():
		if p.id == id:
			return p
	return null

## Charms, die erst eine Prophezeiung freigibt (als Menge).
static func locked_charm_ids() -> Dictionary:
	all()
	return _locked

# Wert-Helfer: Lebenszeit-Summe und Bestwert je Run, jeweils mit dem
# laufenden Run, falls einer mitgegeben wird.
static func _sum(key: String) -> Callable:
	return func(meta: MetaProgress, run: RunState) -> int:
		return meta.lifetime(key) + (_stat(run, key) if run != null else 0)

static func _best(key: String) -> Callable:
	return func(meta: MetaProgress, run: RunState) -> int:
		return maxi(meta.best(key), _stat(run, key) if run != null else 0)

static func _flag(flag: String) -> Callable:
	return func(meta: MetaProgress, run: RunState) -> int:
		return 1 if meta.story_flags.has(flag) or (run != null and run.story_flags.has(flag)) else 0

static func _stat(run: RunState, key: String) -> int:
	return run.stats.get_stat(key)

static func _p(id: String, title: String, text: String, target: int, value: Callable,
		deuter := "", charms: Array[String] = []) -> void:
	var p := ProphecyDefinition.new()
	p.id = id
	p.title = title
	p.text = text
	p.target = target
	p.value = value
	p.unlock_deuter = deuter
	p.unlock_charms = charms
	_all.append(p)
	for c in charms:
		_locked[c] = true

static func _build() -> void:
	# Die erste kommt garantiert - der erste Tod soll schon etwas oeffnen.
	_p("erste_lesung", "Die erste Lesung", "Beende einen Run.", 1,
		func(m: MetaProgress, _r: RunState) -> int: return m.runs_started, "", ["star_dust"])
	_p("welt_oeffnet", "Die Welt öffnet sich", "Lege insgesamt 50-mal DIE WELT.", 50,
		_sum("worldSpreads"), "", ["world_thread"])
	_p("weltenweber", "Weltenweber", "Lege 5-mal DIE WELT in einem einzigen Kampf.", 5,
		_best("mostWorldsInFight"), "", ["cat_fang"])
	_p("blutige_lesung", "Blutige Lesung", "Spiele insgesamt 40 umgekehrte Karten.", 40,
		_sum("reversedPlayed"), "aderleser", ["blood_moon"])
	_p("voller_tresor", "Der volle Tresor", "Gewinne einen Kampf mit 40 Schild.", 40,
		_best("mostShield"), "buchhalter", ["emperor_seal"])
	_p("leeres_blatt", "Das leere Blatt", "Besiege einen Boss mit höchstens 8 Karten im Deck.", 1,
		_best("thinBossKills"), "eremit")
	_p("ueberschuss", "Überschuss", "Triff 250 über das Leben eines Gegners hinaus.", 250,
		_best("bestOverkill"), "", ["predator_fang"])
	_p("kettenleser", "Kettenleser", "Halte eine Musterkette über 7 Züge.", 7,
		_best("longestChain"), "", ["wand_weave"])
	_p("teufel_im_detail", "Der Teufel im Detail", "Nimm insgesamt 3 Pakte an.", 3,
		_sum("pactsAccepted"), "", ["greed_moth"])
	_p("tintenherz", "Tintenherz", "Erreiche in einem Run Verdunkelung 60.", 60,
		_best("peakDarkness"), "", ["silver_mirror"])
	_p("schwarzer_spiegel", "Schwarzer Spiegel", "Besitze zwei schwarze Karten zugleich.", 2,
		_best("mostBlackCards"), "", ["twin_coin"])
	_p("weg_ist_ziel", "Der Weg ist das Ziel", "Erlebe insgesamt 20 Ereignisse.", 20,
		_sum("eventsSeen"), "", ["oracle_eye"])
	_p("grosser_schlag", "Der große Schlag", "Lege eine Legung im Wert von 500.", 500,
		_best("bestHit"), "", ["black_nail"])
	_p("welt_nicht_ende", "Die Welt ist nicht das Ende", "Gewinne einen Run.", 1,
		func(m: MetaProgress, r: RunState) -> int: return m.runs_won + (1 if r != null and r.won else 0),
		"", ["phoenix_feather"])
	_p("schleierlaeufer", "Schleierläufer", "Gewinne auf Schleier 3 oder höher.", 3,
		func(m: MetaProgress, r: RunState) -> int: return maxi(m.highest_veil_won, r.veil if r != null and r.won else -1),
		"", ["black_cup"])
	_p("spiralgaenger", "Spiralgänger", "Erreiche Tiefe 8 in der Schwarzen Spirale.", 8,
		func(m: MetaProgress, r: RunState) -> int: return maxi(m.best_spiral_depth, ActCatalog.spiral_depth(r.fight_index) if r != null else 0),
		"", ["broken_crown"])
	_p("letztes_blatt", "Das letzte Blatt", "Beende die Geschichte des Kartenspielers.", 1,
		_flag("spieler_3"), "", ["gold_die"])
	_p("schwarzes_blatt", "Das Schwarze Blatt", "Beende die Geschichte der Tinte.", 1,
		_flag("tinte_3"), "", ["empty_frame"])
	_p("sammler", "Sammler", "Sieh 40 verschiedene Karten in deinen Decks.", 40,
		func(m: MetaProgress, r: RunState) -> int:
			var n := m.seen_cards.size()
			if r != null:
				var neu := {}
				for c in r.deck:
					if not m.seen_cards.has(c.definition.id):
						neu[c.definition.id] = true
				n += neu.size()
			return n,
		"", ["luck_bell"])
