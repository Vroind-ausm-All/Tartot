extends RefCounted
class_name GameCatalog
## Karten, Charms, Items und der Start eines Runs (Content/GameCatalog.cs).

## Unter diese Groesse kann ein Deck nicht schrumpfen.
const MINIMUM_DECK_SIZE := 5

static var _cards: Array[CardDefinition] = []
static var _card_index: Dictionary = {}
static var _charms: Array[CharmDefinition] = []
static var _charm_by_effect: Dictionary = {}
static var _items: Array[ItemDefinition] = []

static func cards() -> Array[CardDefinition]:
	if _cards.is_empty():
		_build_cards()
	return _cards

static func card(id: String) -> CardDefinition:
	cards()
	return _card_index.get(id, null)

static func charms() -> Array[CharmDefinition]:
	if _charms.is_empty():
		_build_charms()
	return _charms

static func charm(id: String) -> CharmDefinition:
	for c in charms():
		if c.id == id:
			return c
	return null

## Der erste Charm mit dieser Wirkung (CombatSystem.CharmStacks).
static func charm_for_effect(effect: int) -> CharmDefinition:
	charms()
	return _charm_by_effect.get(effect, null)

static func items() -> Array[ItemDefinition]:
	if _items.is_empty():
		_build_items()
	return _items

static func item(id: String) -> ItemDefinition:
	for i in items():
		if i.id == id:
			return i
	return null

## Der Standard-Run: Die Wahrsagerin ohne Schleier.
static func create_starter_run() -> RunState:
	return create_run(DeuterCatalog.default_deuter())

## Baut den Startzustand fuer einen Deuter.
static func create_run(deuter: DeuterDefinition) -> RunState:
	if deuter == null:
		deuter = DeuterCatalog.default_deuter()
	var run := RunState.new()
	run.deuter_id = deuter.id
	run.deuter_rule = deuter.rule
	run.max_hp = deuter.max_hp
	run.hp = deuter.max_hp
	run.gold = deuter.gold
	run.luck = deuter.luck
	var reversed: Array = Array(deuter.reversed_cards).duplicate()
	for id in deuter.deck:
		var c := CardInstance.new(card(id))
		# Jede Nennung dreht genau eine Karte - doppelte Ids bleiben unabhaengig.
		if reversed.has(id):
			reversed.erase(id)
			c.orientation = Enums.Orientation.REVERSED
		run.deck.append(c)
	for id in deuter.charms:
		run.add_charm(charm(id))
	for id in deuter.items:
		run.add_item(item(id))
	return run

## Charms, die man von Anfang an finden kann. Die uebrigen schalten Prophezeiungen frei.
static func starter_charm_ids() -> Array[String]:
	var locked := ProphecyCatalog.locked_charm_ids()
	var out: Array[String] = []
	for c in charms():
		if not locked.has(c.id):
			out.append(c.id)
	return out

static func _build_cards() -> void:
	_add_minor_suit(Enums.Suit.SWORDS, "Schwerter", 3, "Direkter Schaden. Höhere Werte brechen Haltung schneller.")
	_add_minor_suit(Enums.Suit.WANDS, "Stäbe", 2, "Brand und Combo. Aufeinanderfolgende Stäbe verstärken sich.")
	_add_minor_suit(Enums.Suit.CUPS, "Kelche", 2, "Heilung und Traum. Umgekehrt wird Heilung riskanter, aber stärker.")
	_add_minor_suit(Enums.Suit.PENTACLES, "Münzen", 2, "Schild, Gold und Vorbereitung. Zukunftseffekte sind besonders stark.")
	var names := [
		"Der Narr", "Der Magier", "Die Hohepriesterin", "Die Herrscherin", "Der Herrscher", "Der Hierophant",
		"Die Liebenden", "Der Wagen", "Kraft", "Der Eremit", "Rad des Schicksals", "Gerechtigkeit",
		"Der Gehängte", "Der Tod", "Mäßigkeit", "Der Teufel", "Der Turm", "Der Stern", "Der Mond",
		"Die Sonne", "Das Gericht", "Die Welt"
	]
	var desc := [
		"Ziehe zusätzliche Karten; umgekehrt riskanter, aber mit Luck.",
		"Wiederholt die letzte Karte oder erzeugt eine temporäre Kopie.",
		"Ordnet kommende Karten und enthüllt Gegnerabsichten.",
		"Heilt und verstärkt die nächsten Karten; umgekehrt gegen Lebensopfer.",
		"Erzeugt starken Schild, der nicht sofort verfällt.",
		"Verbessert eine Karte im Kampf oder erschöpft sie für stärkere Wirkung.",
		"Verbindet zwei Karten, sodass Effekte gemeinsam ausgelöst werden.",
		"Belohnt die dritte Karte einer Legung mit Wiederholung.",
		"Verdoppelt die nächste Angriffskraft; umgekehrt mit Selbstschaden.",
		"Entfernt Karten temporär aus dem Kampf und verdünnt den Draw-Pile.",
		"Ersetzt oder wählt Karten neu; starker Luck-Effekt.",
		"Entfernt Debuffs oder überträgt sie auf den Gegner.",
		"Opfert Aktionen für einen explosiven Folgeturn.",
		"Vernichtet Karten temporär; kann nach dem Kampf permanentes Löschen auslösen.",
		"Mischt die Wirkung zweier Karten und belohnt hybride Builds.",
		"Verdoppelt Macht gegen einen Fluch oder stärkt umgekehrte Karten.",
		"Zerstört Schild und verursacht massiven Burst.",
		"Heilt, zieht und erzeugt Luck.",
		"Verstärkt umgekehrte Karten, verbirgt aber Informationen.",
		"Schaden, Heilung und Kartenziehen in einem Zug.",
		"Holt bereits gespielte oder erschöpfte Karten zurück.",
		"Belohnt alle vier Farben und Summe 21 mit einem massiven Fate-Schub."
	]
	for i in range(22):
		var d := CardDefinition.new()
		d.id = "major_%d" % i
		d.name = names[i]
		d.suit = Enums.Suit.MAJOR
		# Der Narr traegt die Arkana-Nummer 0, spielt aber mit Rang 1.
		d.rank = 1 if i == 0 else i
		@warning_ignore("integer_division")
		d.base_power = 4 + i / 3
		d.major = i
		d.description = desc[i]
		_put(d)

static func _add_minor_suit(suit: int, german_suit: String, base_power: int, description: String) -> void:
	var slug: String = Enums.NAMES_SUIT[suit].to_lower()
	for rank in range(1, 15):
		var label := str(rank)
		match rank:
			1: label = "Ass"
			11: label = "Bube"
			12: label = "Ritter"
			13: label = "Königin"
			14: label = "König"
		var d := CardDefinition.new()
		d.id = "%s_%d" % [slug, rank]
		d.name = "%s der %s" % [label, german_suit]
		d.suit = suit
		d.rank = rank
		d.base_power = base_power + rank
		d.description = description
		_put(d)

static func _put(d: CardDefinition) -> void:
	_cards.append(d)
	_card_index[d.id] = d

static func _build_charms() -> void:
	var E := Enums.CharmEffectType
	var data := [
		["blade_pendant","Klingenanhänger",E.SWORDS_CHIPS,2,8,"Schwerter erhalten +2 Chips pro Stack."],
		["ember_knot","Glutknoten",E.WANDS_BURN,1,8,"Stäbe erzeugen +1 Brand pro Stack."],
		["blood_moon","Blutmondsplitter",E.SELF_DAMAGE_POWER,.12,8,"Riskante/umgekehrte Karten erhalten +12% Wirkung pro Stack."],
		["predator_fang","Raubzahn",E.DEBUFFED_LIFESTEAL,1,5,"Angriffe gegen debuffte Gegner heilen 1 HP pro Stack."],
		["hunt_bell","Jagdglocke",E.FIRST_ATTACK_BONUS,4,5,"Erster Angriff pro Kampf erhält +4 Schaden pro Stack."],
		["black_nail","Schwarzer Nagel",E.EVERY_THIRD_CARD_DAMAGE,3,5,"Jede dritte gespielte Karte verursacht +3 Schaden pro Stack."],
		["falcon_eye","Falkenauge",E.ATTACK_VS_ATTACKER,2,5,"Greift der Gegner an, erhalten Angriffe +2 Chips pro Stack."],
		["ash_wreath","Aschekranz",E.KILL_RAMP,1,5,"Kills erhöhen Angriffschips für den Kampf."],
		["thorn_ring","Dornenring",E.THORNS,2,5,"Reflektiert geblockten Schaden."],
		["hangman_chain","Henkerkette",E.FUTURE_POWER,.10,5,"Zukunftseffekte +10% pro Stack."],
		["iron_coin","Eiserne Münze",E.PENTACLE_SHIELD,2,8,"Münzen geben +2 Schild pro Stack."],
		["cup_rim","Kelchrand",E.OVERHEAL_TO_SHIELD,.20,5,"Überheilung wird teilweise zu Schild."],
		["white_thread","Weißer Faden",E.START_SHIELD,3,5,"Beginne Kämpfe mit +3 Schild pro Stack."],
		["salt_seal","Salzsiegel",E.DEBUFF_WARD,1,3,"Negiert frühe Debuffs."],
		["bone_pearl","Knochenperle",E.LOW_HP_SHIELD,2,5,"Unter 50% HP geben Schildkarten +2 Schild pro Stack."],
		["moon_brooch","Mondbrosche",E.REVERSED_SHIELD,1,5,"Umgekehrte Karten geben +1 Schild pro Stack."],
		["emperor_seal","Siegel des Herrschers",E.SHIELD_RETENTION,.10,5,"Ein Teil des Schilds bleibt zwischen Runden."],
		["saint_needle","Heiligennadel",E.EVERY_FIFTH_HEAL,1,5,"Jede fünfte Karte heilt 1 HP pro Stack."],
		["phoenix_feather","Phönixfeder",E.PHOENIX,5,3,"Verhindert einmal pro Abschnitt den Tod; weitere Stacks heilen stärker."],
		["glass_heart","Glasherz",E.GLASS_HEART,.25,4,"Weniger Max-HP, aber stärkere Heilung."],
		["silver_mirror","Silberspiegel",E.COPY_POWER,.10,8,"Kopierte Karten +10% Wirkung pro Stack."],
		["razor_charm","Rasieramulett",E.REMOVE_DISCOUNT,.15,5,"Kartenlöschen wird günstiger."],
		["blank_card","Leere Karte",E.OPENING_DRAW,1,2,"Ziehe zu Kampfbeginn +1 Karte pro Stack."],
		["thread_spool","Fadenspule",E.DISCARD_BOOST,1,5,"Abwerfen stärkt die nächste Karte."],
		["wax_seal","Wachssiegel",E.UPGRADED_POWER,.08,8,"Verbesserte Karten +8% Wirkung pro Stack."],
		["crow_feather","Krähenfeder",E.RESHUFFLE_DRAW,1,2,"Beim Mischen +1 Karte ziehen."],
		["memory_shard","Erinnerungssplitter",E.MEMORY_RETURN,1,5,"Frühe Karten kehren in Folgerunden zurück."],
		["twin_coin","Zwillingsmünze",E.COPY_BASE,1,5,"Kopien erhalten +1 Basiswert pro Stack."],
		["empty_frame","Leerer Rahmen",E.REMOVE_MAX_HP,1,5,"Gelöschte Karten können Max-HP erhöhen."],
		["oracle_eye","Auge des Orakels",E.ORACLE_SIGHT,1,3,"Zeigt zusätzliche kommende Karten."],
		["blade_rose","Klingenrose",E.SWORD_BRIDGE,2,5,"Nach zwei Schwertern wird die nächste Nicht-Schwert-Karte stärker."],
		["wand_weave","Stabgeflecht",E.WAND_COMBO,.08,8,"Stabketten erhöhen den Multiplikator."],
		["cup_pearl","Kelchperle",E.CUP_AFTER_ATTACK,2,8,"Kelche nach Angriffen heilen mehr."],
		["pentacle_chain","Pentakelkette",E.PENTACLE_GOLD,2,5,"Hoher Schild am Kampfende erzeugt Gold."],
		["fourfold_knot","Vierfachknoten",E.FOUR_SUIT_BONUS,.12,8,"Vier Farben in einer Runde erhöhen den Mult."],
		["black_cup","Schwarzer Kelch",E.HEAL_DAMAGE,.20,5,"Heilung schädigt Gegner anteilig."],
		["brass_wand","Messingstab",E.BURN_POWER,1,8,"Brandticks verursachen +1 Schaden pro Stack."],
		["silver_blade","Silberklinge",E.ARMOR_PIERCE,1,5,"Schwerter ignorieren gegnerischen Schild."],
		["gold_pentacle","Goldenes Pentakel",E.PENTACLE_LUCK,1,5,"Münzserien erzeugen temporäres Luck."],
		["blue_ribbon","Blaues Band",E.CUP_CLEANSE,1,3,"Kelchserien entfernen Debuffs."],
		["lucky_clover","Narrenklee",E.START_LUCK,1,3,"Beginne Abschnitte mit +1 Luck pro Stack."],
		["merchant_eye","Auge des Händlers",E.SHOP_DISCOUNT,.05,5,"Händlerpreise -5% pro Stack."],
		["bent_coin","Gebogene Münze",E.REWARD_REROLL,1,3,"+1 Reward-Reroll pro Abschnitt."],
		["cat_fang","Katzenzahn",E.RARE_CHANCE,.04,5,"Seltene Karten erscheinen häufiger."],
		["luck_bell","Glücksglocke",E.POSITIVE_EVENT,.06,5,"Positive Ereignisse werden wahrscheinlicher."],
		["greed_moth","Giermotte",E.GREED,.10,5,"Mehr Gold, aber stärkere Gegner."],
		["gold_die","Goldener Würfel",E.EXTRA_REWARD_CHOICE,1,4,"Jeder zweite Stack erweitert Reward-Auswahlen."],
		["star_dust","Sternenstaub",E.UPGRADED_REWARD_CHANCE,.08,5,"Belohnungskarten sind häufiger verbessert."],
		["broken_crown","Gebrochene Krone",E.ELITE_CHARM_CHANCE,.20,5,"Elitegegner geben häufiger zusätzliche Charms."],
		["world_thread","Weltenfaden",E.WORLD_THREAD,.02,8,"Für je fünf verschiedene Charms +2% Kartenwirkung pro Stack."]
	]
	for x in data:
		var c := CharmDefinition.new(x[0], x[1], x[2], float(x[3]), x[4], x[5])
		_charms.append(c)
		if not _charm_by_effect.has(c.effect):
			_charm_by_effect[c.effect] = c

static func _build_items() -> void:
	var E := Enums.ItemEffectType
	var data := [
		["mirror_shard","Spiegelscherbe",E.MIRROR_CARD,1,"Kopiere permanent eine normale Karte."],
		["fate_scissors","Schere des Schicksals",E.REMOVE_CARD,1,"Lösche permanent eine Karte."],
		["black_wax","Schwarzes Wachs",E.FLIP_CARD,1,"Drehe eine Karte permanent um."],
		["gold_needle","Goldene Nadel",E.UPGRADE_CARD,1,"Erhöhe das Level einer Karte."],
		["oracle_lens","Orakellinse",E.REORDER_DECK,5,"Ordne die nächsten fünf Karten neu."],
		["sun_vial","Sonnenphiole",E.HEAL,15,"Heile 15 HP."],
		["moon_salt","Mondsalz",E.CLEANSE_REVEAL,3,"Entferne Debuffs und enthülle Absichten."],
		["tower_powder","Turmpulver",E.TOWER_BLAST,20,"20 Schaden an allen Gegnern, eigener Schild fällt."],
		["devil_pact","Teufelspakt",E.DEVILS_BARGAIN,1,"Nächster Händlerkauf kostet 0; dafür Fluch-Risiko."],
		["lovers_band","Band der Liebenden",E.LINK_CARDS,3,"Verbindet zwei Karten für drei Kämpfe."],
		["hangman_rope","Strick des Gehängten",E.SKIP_ENEMY_INTENT,1,"Überspringe eine Gegneraktion."],
		["pentacle_pouch","Pentakelbeutel",E.GAIN_GOLD,40,"Erhalte 40 Gold."],
		["bone_key","Knochenschlüssel",E.UNLOCK,1,"Öffnet verschlossene Wege."],
		["merchant_mark","Händlermarke",E.REROLL_SHOP,1,"Erneuere das Händlerangebot kostenlos."],
		["ash_vial","Aschephiole",E.REVIVE,25,"Automatische Wiederbelebung mit 25% HP."],
		["star_water","Sternenwasser",E.GAIN_LUCK,1,"+1 Luck für den Abschnitt."],
		["emperor_token","Siegel des Kaisers",E.START_SHIELD_BUFF,12,"Die nächsten Kämpfe starten mit zusätzlichem Schild."],
		["priestess_ink","Tinte der Priesterin",E.TRANSFORM_CARD,1,"Transformiert eine Karte derselben Farbe/Seltenheit."],
		["wheel_token","Radmarke",E.REROLL_REWARD,1,"Würfle eine Belohnung komplett neu."],
		["world_compass","Weltenkompass",E.REVEAL_PATH,1,"Zeigt kommende Räume und erleichtert die Wegwahl."],
		["hermit_lantern","Laterne des Eremiten",E.REMOVE_CURSE,1,"Entfernt eine Fluchkarte."],
		["judgement_bell","Glocke des Gerichts",E.RESTORE_REMOVED_CARD,1,"Hole eine gelöschte Karte verbessert zurück."]
	]
	for x in data:
		_items.append(ItemDefinition.new(x[0], x[1], x[2], x[3], x[4]))
