extends RefCounted
class_name Katalog

var cards: Dictionary = {}
var charms: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var deuters: Dictionary = {}
var veils: Array[Dictionary] = []
var prophecies: Array[Dictionary] = []
var events: Array[Dictionary] = []

func _init() -> void:
	_build_cards()
	_build_charms()
	_build_items()
	_build_deuters()
	_build_veils()
	_build_enemies()
	_build_prophecies()
	_build_events()

func card_def(id: String) -> Dictionary:
	return cards.get(id, {})

func charm_def(id: String) -> Dictionary:
	return charms.get(id, {})

func item_def(id: String) -> Dictionary:
	return items.get(id, {})

func enemy_def(id: String) -> Dictionary:
	return enemies.get(id, {})

func deuter_def(id: String) -> Dictionary:
	return deuters.get(id, deuters.get("wahrsagerin", {}))

func make_card(id: String, iid: String) -> Karte:
	var def := card_def(id)
	return Karte.new(def, iid) if not def.is_empty() else null

func normals_for_act(act: int) -> Array[String]:
	var out: Array[String] = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if int(e.get("tier", Konst.Tier.NORMAL)) == Konst.Tier.NORMAL and int(e.get("act", 1)) == act:
			out.append(String(id))
	return out

func elites_for_act(act: int) -> Array[String]:
	var out: Array[String] = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if int(e.get("tier", Konst.Tier.NORMAL)) == Konst.Tier.ELITE and int(e.get("act", 1)) == act:
			out.append(String(id))
	return out

func bosses_for_act(act: int) -> Array[String]:
	var out: Array[String] = []
	for id in enemies:
		var e: Dictionary = enemies[id]
		if int(e.get("tier", Konst.Tier.NORMAL)) == Konst.Tier.BOSS and int(e.get("act", 1)) == act:
			out.append(String(id))
	return out

func _minor(suit: int, slug: String, german: String, base_power: int, desc: String) -> void:
	for rank in range(1, 15):
		var label := str(rank)
		if rank == 1: label = "Ass"
		elif rank == 11: label = "Bube"
		elif rank == 12: label = "Ritter"
		elif rank == 13: label = "Königin"
		elif rank == 14: label = "König"
		var id := "%s_%d" % [slug, rank]
		cards[id] = {
			"id": id, "name": "%s der %s" % [label, german], "suit": suit,
			"rank": rank, "base_power": base_power + rank, "major": false,
			"display_number": rank, "description": desc
		}

func _build_cards() -> void:
	_minor(Konst.Suit.SWORDS, "swords", "Schwerter", 3, "Direkter Schaden. Höhere Werte brechen Haltung schneller.")
	_minor(Konst.Suit.WANDS, "wands", "Stäbe", 2, "Brand und Combo. Ketten werden stärker.")
	_minor(Konst.Suit.CUPS, "cups", "Kelche", 2, "Heilung und Traum. Umgekehrt stärker und riskanter.")
	_minor(Konst.Suit.PENTACLES, "pentacles", "Münzen", 2, "Schild, Gold und Vorbereitung.")
	var names := [
		"Der Narr","Der Magier","Die Hohepriesterin","Die Herrscherin","Der Herrscher","Der Hierophant",
		"Die Liebenden","Der Wagen","Kraft","Der Eremit","Rad des Schicksals","Gerechtigkeit",
		"Der Gehängte","Der Tod","Mäßigkeit","Der Teufel","Der Turm","Der Stern","Der Mond",
		"Die Sonne","Das Gericht","Die Welt"
	]
	var desc := [
		"Ziehe zusätzliche Karten.","Wiederholt oder kopiert.","Ordnet kommende Karten.",
		"Heilt und verstärkt.","Erzeugt starken Schild.","Verbessert oder erschöpft.",
		"Verbindet zwei Karten.","Belohnt die dritte Karte.","Verdoppelt Angriffskraft.",
		"Verdünnt den Kampf.","Dreht Möglichkeiten neu.","Entfernt oder überträgt Debuffs.",
		"Opfert jetzt für später.","Markiert und nimmt Karten.","Mischt Wirkungen.",
		"Stärkt Umkehrung.","Zerstört Schild und burstet.","Heilt, zieht und gibt Luck.",
		"Verbirgt und verstärkt Umkehrung.","Schaden, Heilung und Ziehen.","Holt gespielte Karten zurück.",
		"Belohnt vier Farben und Summe 21."
	]
	for i in range(22):
		var id := "major_%d" % i
		cards[id] = {
			"id": id, "name": names[i], "suit": Konst.Suit.MAJOR,
			"rank": 1 if i == 0 else i, "base_power": 4 + int(i / 3),
			"major": true, "display_number": i, "description": desc[i]
		}

func _charm(id: String, name: String, effect: String, magnitude: float, max_stacks: int, text: String) -> void:
	charms[id] = {"id": id, "name": name, "effect": effect, "magnitude": magnitude, "max": max_stacks, "text": text}

func _build_charms() -> void:
	var data := [
		["blade_pendant","Klingenanhänger","swords_chips",2.0,8,"Schwerter erhalten +2 Chips."],
		["ember_knot","Glutknoten","wands_burn",1.0,8,"Stäbe erzeugen Brand."],
		["blood_moon","Blutmondsplitter","reversed_power",0.12,8,"Riskante Karten erhalten mehr Wirkung."],
		["predator_fang","Raubzahn","lifesteal",1.0,5,"Debuffte Gegner nähren dich."],
		["hunt_bell","Jagdglocke","first_attack",4.0,5,"Erster Angriff pro Kampf wird stärker."],
		["black_nail","Schwarzer Nagel","third_card",3.0,5,"Jede dritte Karte trifft härter."],
		["falcon_eye","Falkenauge","vs_attack",2.0,5,"Gegen Angriffe stärker."],
		["ash_wreath","Aschekranz","kill_ramp",1.0,5,"Kills nähren Angriff."],
		["thorn_ring","Dornenring","thorns",2.0,5,"Schild reflektiert."],
		["hangman_chain","Henkerkette","future_power",0.10,5,"Zukunft wird stärker."],
		["iron_coin","Eiserne Münze","pentacle_shield",2.0,8,"Münzen geben Schild."],
		["cup_rim","Kelchrand","overheal_shield",0.20,5,"Überheilung wird Schild."],
		["white_thread","Weißer Faden","start_shield",3.0,5,"Beginne mit Schild."],
		["salt_seal","Salzsiegel","debuff_ward",1.0,3,"Negiert frühe Debuffs."],
		["bone_pearl","Knochenperle","low_hp_shield",2.0,5,"Unter 50 % mehr Schild."],
		["moon_brooch","Mondbrosche","reversed_shield",1.0,5,"Umgekehrt gibt Schild."],
		["emperor_seal","Siegel des Herrschers","shield_retention",0.10,5,"Schild bleibt teilweise."],
		["saint_needle","Heiligennadel","fifth_heal",1.0,5,"Jede fünfte Karte heilt."],
		["phoenix_feather","Phönixfeder","phoenix",5.0,3,"Verhindert einmal den Tod."],
		["glass_heart","Glasherz","glass_heart",0.25,4,"Weniger HP, stärkere Heilung."],
		["silver_mirror","Silberspiegel","copy_power",0.10,8,"Kopien sind stärker."],
		["razor_charm","Rasieramulett","remove_discount",0.15,5,"Vergessen günstiger."],
		["blank_card","Leere Karte","opening_draw",1.0,2,"Ziehe zu Beginn mehr."],
		["thread_spool","Fadenspule","discard_boost",1.0,5,"Abwerfen stärkt."],
		["wax_seal","Wachssiegel","upgraded_power",0.08,8,"Verbesserte Karten stärker."],
		["crow_feather","Krähenfeder","reshuffle_draw",1.0,2,"Beim Mischen mehr ziehen."],
		["memory_shard","Erinnerungssplitter","memory_return",1.0,5,"Frühe Karten kehren zurück."],
		["twin_coin","Zwillingsmünze","copy_base",1.0,5,"Kopien erhalten Basiswert."],
		["empty_frame","Leerer Rahmen","remove_maxhp",1.0,5,"Vergessen kann Max-HP geben."],
		["oracle_eye","Auge des Orakels","oracle_sight",1.0,3,"Sieh weiter voraus."],
		["blade_rose","Klingenrose","sword_bridge",2.0,5,"Schwerter bauen Brücken."],
		["wand_weave","Stabgeflecht","wand_combo",0.08,8,"Stabketten erhöhen Mult."],
		["cup_pearl","Kelchperle","cup_after_attack",2.0,8,"Kelche nach Angriff heilen."],
		["pentacle_chain","Pentakelkette","pentacle_gold",2.0,5,"Hoher Schild erzeugt Gold."],
		["fourfold_knot","Vierfachknoten","four_suit",0.12,8,"Vier Farben erhöhen Mult."],
		["black_cup","Schwarzer Kelch","heal_damage",0.20,5,"Heilung verletzt Gegner."],
		["brass_wand","Messingstab","burn_power",1.0,8,"Brand wird stärker."],
		["silver_blade","Silberklinge","armor_pierce",1.0,5,"Schwerter ignorieren Schild."],
		["gold_pentacle","Goldenes Pentakel","pentacle_luck",1.0,5,"Münzen erzeugen Luck."],
		["blue_ribbon","Blaues Band","cup_cleanse",1.0,3,"Kelche reinigen."],
		["lucky_clover","Narrenklee","start_luck",1.0,3,"Beginne mit Luck."],
		["merchant_eye","Auge des Händlers","shop_discount",0.05,5,"Händler günstiger."],
		["bent_coin","Gebogene Münze","reward_reroll",1.0,3,"Belohnung neu würfeln."],
		["cat_fang","Katzenzahn","rare_chance",0.04,5,"Seltene Karten häufiger."],
		["luck_bell","Glücksglocke","positive_event",0.06,5,"Gute Ereignisse häufiger."],
		["greed_moth","Giermotte","greed",0.10,5,"Mehr Gold, härtere Gegner."],
		["gold_die","Goldener Würfel","extra_reward",1.0,4,"Mehr Auswahl."],
		["star_dust","Sternenstaub","upgraded_reward",0.08,5,"Belohnungen verbessert."],
		["broken_crown","Gebrochene Krone","elite_charm",0.20,5,"Elites geben mehr Charms."],
		["world_thread","Weltenfaden","world_thread",0.02,8,"Viele Charms verstärken alles."]
	]
	for x in data:
		_charm(String(x[0]),String(x[1]),String(x[2]),float(x[3]),int(x[4]),String(x[5]))

func _item(id: String, name: String, effect: String, magnitude: int, text: String) -> void:
	items[id] = {"id":id,"name":name,"effect":effect,"magnitude":magnitude,"text":text}

func _build_items() -> void:
	var data := [
		["mirror_shard","Spiegelscherbe","mirror",1,"Kopiere permanent eine normale Karte."],
		["fate_scissors","Schere des Schicksals","remove",1,"Lösche permanent eine Karte."],
		["black_wax","Schwarzes Wachs","flip",1,"Drehe eine Karte permanent um."],
		["gold_needle","Goldene Nadel","upgrade",1,"Erhöhe das Level einer Karte."],
		["oracle_lens","Orakellinse","reorder",5,"Ordne die nächsten fünf Karten neu."],
		["sun_vial","Sonnenphiole","heal",15,"Heile 15 HP."],
		["moon_salt","Mondsalz","cleanse",3,"Entferne Debuffs und enthülle Absichten."],
		["tower_powder","Turmpulver","blast",20,"20 Schaden; eigener Schild fällt."],
		["devil_pact","Teufelspakt","free_shop",1,"Nächster Händlerkauf kostet 0."],
		["lovers_band","Band der Liebenden","link",3,"Verbindet Karten."],
		["hangman_rope","Strick des Gehängten","skip_intent",1,"Überspringe eine Gegneraktion."],
		["pentacle_pouch","Pentakelbeutel","gold",40,"Erhalte 40 Gold."],
		["bone_key","Knochenschlüssel","unlock",1,"Öffnet verschlossene Wege."],
		["merchant_mark","Händlermarke","reroll_shop",1,"Erneuere Händlerangebot."],
		["ash_vial","Aschephiole","revive",25,"Wiederbelebung mit 25 % HP."],
		["star_water","Sternenwasser","luck",1,"+1 Luck."],
		["emperor_token","Siegel des Kaisers","start_shield",12,"Mehr Startschild."],
		["priestess_ink","Tinte der Priesterin","transform",1,"Transformiere eine Karte."],
		["wheel_token","Radmarke","reroll_reward",1,"Belohnung neu würfeln."],
		["world_compass","Weltenkompass","reveal_path",1,"Zeigt kommende Räume."],
		["hermit_lantern","Laterne des Eremiten","remove_curse",1,"Entfernt eine Fluchkarte."],
		["judgement_bell","Glocke des Gerichts","restore",1,"Hole eine gelöschte Karte zurück."]
	]
	for x in data:
		_item(String(x[0]),String(x[1]),String(x[2]),int(x[3]),String(x[4]))

func _build_deuters() -> void:
	deuters["wahrsagerin"] = {"id":"wahrsagerin","name":"Die Wahrsagerin","subtitle":"Sie liest, was ohnehin geschieht.","rule":"none","hp":72,"gold":90,"luck":2,"deck":["pentacles_4","swords_7","wands_10","cups_6","swords_3","pentacles_6","wands_4","cups_8","major_1","major_0"],"reversed":[],"charms":["white_thread","lucky_clover"],"items":["mirror_shard"],"unlock":""}
	deuters["aderleser"] = {"id":"aderleser","name":"Der Aderleser","subtitle":"Er braucht dein Blut, nicht deine Zukunft.","rule":"blood_reader","hp":70,"gold":80,"luck":1,"deck":["swords_5","swords_7","swords_9","wands_6","wands_8","cups_5","cups_7","cups_9","pentacles_5","major_8"],"reversed":["swords_7","swords_9","wands_8"],"charms":["blood_moon","moon_brooch"],"items":["sun_vial"],"unlock":"blutige_lesung"}
	deuters["buchhalter"] = {"id":"buchhalter","name":"Der Buchhalter","subtitle":"Er notiert jeden Treffer. Auch deine.","rule":"bookkeeper","hp":64,"gold":90,"luck":2,"deck":["pentacles_3","pentacles_5","pentacles_7","pentacles_9","swords_4","swords_6","cups_4","wands_5","major_4","major_11"],"reversed":[],"charms":[],"items":["pentacle_pouch"],"unlock":"voller_tresor"}
	deuters["eremit"] = {"id":"eremit","name":"Der Eremit","subtitle":"Er trägt nur, was er braucht.","rule":"hermit","hp":68,"gold":80,"luck":3,"deck":["swords_8","wands_7","cups_6","pentacles_7","swords_10","major_9"],"reversed":[],"charms":["lucky_clover"],"items":["fate_scissors"],"unlock":"leeres_blatt"}

func _build_veils() -> void:
	veils = [
		{"level":0,"name":"Ohne Schleier","text":"Das Spiel, wie es gedacht ist."},
		{"level":1,"name":"Geizige Hände","text":"Kämpfe bringen ein Viertel weniger Gold."},
		{"level":2,"name":"Wache Omen","text":"Elites und Bosse haben 20 % mehr HP und Haltung."},
		{"level":3,"name":"Stumpfe Lesung","text":"Belohnungen bieten eine Wahl weniger."},
		{"level":4,"name":"Dünne Haut","text":"Du beginnst mit 4 Max-HP weniger."},
		{"level":5,"name":"Scharfe Omen","text":"Ab Akt II schlagen Elites und Bosse je Akt 1 härter zu."},
		{"level":6,"name":"Hungrige Schatten","text":"Ab Akt II schlagen alle Gegner 1 härter zu."},
		{"level":7,"name":"Blutzoll","text":"Umkehrpreis +50 %, Rast heilt weniger."},
		{"level":8,"name":"Das letzte Siegel","text":"Die Welt trägt ein weiteres Siegel."}
	]

func _enemy(id:String,name:String,tier:int,act:int,hp:int,stance:int,attack:int,sigils:int,pattern:Array,rules:Array,flavor:String) -> void:
	enemies[id]={"id":id,"name":name,"tier":tier,"act":act,"hp":hp,"stance":stance,"attack":attack,"sigils":sigils,"pattern":pattern,"rules":rules,"flavor":flavor,"gold_factor":1.0}

func _build_enemies() -> void:
	_enemy("lachender_henker","Der lachende Henker",Konst.Tier.NORMAL,1,148,29,19,0,["A","A","F"],[],"Ein viel zu langer Hals, ein viel zu breites Grinsen.")
	_enemy("zahnmuenze","Die Münze mit Zähnen",Konst.Tier.NORMAL,1,133,34,17,0,["G","A","A"],[],"Sie rollt. Sie klappert. Dann klappt sie auf.")
	_enemy("kelchtrinker","Der Kelchtrinker",Konst.Tier.NORMAL,1,160,24,17,0,["A","D","A"],[],"Im Kelch schwimmt ein Auge.")
	_enemy("schreiende_klinge","Die schreiende Klinge",Konst.Tier.NORMAL,1,110,19,25,0,["A","H"],[],"Ein Mund in der Schneide.")
	_enemy("zwillingsschatten","Die Zwillingsschatten",Konst.Tier.NORMAL,1,125,29,17,0,["F","G","A"],[],"Zwei Schatten einer Figur, die es nicht gibt.")
	_enemy("kleiner_mond","Der kleine grinsende Mond",Konst.Tier.NORMAL,1,144,29,19,0,["H","A","A"],[],"Er hängt zu niedrig.")
	_enemy("hutmann","Der Hutmann",Konst.Tier.NORMAL,2,289,44,19,0,["G","A","A","H"],[],"Unter dem Hut ist noch ein Hut.")
	_enemy("augensammlerin","Die Augensammlerin",Konst.Tier.NORMAL,2,255,40,20,0,["H","A","F"],[],"Sie trägt fremde Augen.")
	_enemy("blutorgel","Die Blutorgel",Konst.Tier.NORMAL,2,323,48,17,0,["D","A","D","G"],[],"Jede Pfeife ein Finger.")
	_enemy("wachsbote","Der Wachsbote",Konst.Tier.NORMAL,2,238,35,23,0,["A","A","G"],[],"Eine Nachricht, die schmilzt.")
	_enemy("mondfresser","Der Mondfresser",Konst.Tier.NORMAL,2,306,44,19,0,["A","H","F"],[],"Er frisst den Rand des Bildes.")
	_enemy("nadelwitwe","Die Nadelwitwe",Konst.Tier.NORMAL,2,280,53,19,0,["G","A","G","A"],[],"Sie näht zwischen den Stichen.")
	_enemy("uhrenwurm","Der Uhrenwurm",Konst.Tier.NORMAL,3,420,68,20,0,["A","G","A","H"],[],"Er frisst Minuten.")
	_enemy("sieben_finger","Die Sieben Finger",Konst.Tier.NORMAL,3,378,60,22,0,["F","A","A"],[],"Sie zählen mit.")
	_enemy("laecheln_ohne_gesicht","Das Lächeln ohne Gesicht",Konst.Tier.NORMAL,3,448,68,19,0,["D","A","H","A"],[],"Nur ein Mund.")
	_enemy("gerichtsdiener","Der lächelnde Gerichtsdiener",Konst.Tier.NORMAL,3,406,64,21,0,["A","A","G"],[],"Er stellt dir deine Vorladung zu.")
	_enemy("papierpriester","Der Papierpriester",Konst.Tier.ELITE,1,228,40,20,1,["G","A","H","A"],[],"Sein Gewand ist aus Verträgen.")
	_enemy("fette_ratte","Die fette Ratte des Händlers",Konst.Tier.ELITE,1,262,35,18,0,["A","D","G"],[],"Münzen klimpern in ihr.")
	enemies["fette_ratte"]["gold_factor"]=2.5
	_enemy("spiegelschwester","Die Spiegelschwester",Konst.Tier.ELITE,2,448,56,22,1,["A","F","G","H"],[],"Eine Sekunde zu spät.")
	_enemy("muenzmaul","Das Münzmaul",Konst.Tier.ELITE,2,480,60,21,0,["G","A","D"],[],"Es spuckt am Ende alles aus.")
	enemies["muenzmaul"]["gold_factor"]=2.5
	_enemy("henker_verkehrt","Der Henker (umgekehrt)",Konst.Tier.ELITE,3,598,72,24,1,["F","A","G","A"],[],"Der Strick hält jetzt ihn.")
	_enemy("rote_sonne","Die rote Sonne",Konst.Tier.ELITE,3,624,72,23,1,["A","D","F","H"],[],"Sie geht nicht unter.")
	_enemy("boss_turm","XVI · Der Turm",Konst.Tier.BOSS,1,323,44,20,1,["A","A","G","F"],[Konst.BossRule.TOWER],"Jeder Blitz nimmt eine Möglichkeit.")
	_enemy("boss_mond","XVIII · Der Mond",Konst.Tier.BOSS,1,360,44,21,1,["H","A","D","A"],[Konst.BossRule.MOON],"Du siehst sein Grinsen. Sonst nichts.")
	_enemy("boss_tod","XIII · Der Tod",Konst.Tier.BOSS,2,510,64,22,1,["A","H","A","D"],[Konst.BossRule.DEATH],"Er nimmt nicht dich. Er nimmt deine Karten.")
	_enemy("boss_rad","X · Rad des Schicksals",Konst.Tier.BOSS,2,495,60,22,1,["A","F","G","A"],[Konst.BossRule.WHEEL],"Deine Positionen bleiben nicht, wo sie waren.")
	_enemy("boss_teufel","XV · Der Teufel",Konst.Tier.BOSS,3,640,72,20,1,["A","D","A","F"],[Konst.BossRule.DEVIL],"Er verhandelt.")
	_enemy("boss_gehaengter","XII · Der Gehängte",Konst.Tier.BOSS,3,650,79,22,1,["G","A","A","H"],[Konst.BossRule.HANGED],"Deine Zukunft liegt links.")
	_enemy("boss_welt","XXI · Die Welt",Konst.Tier.FINALE,4,504,65,24,2,["A","H","F","G","D"],[],"Alles Besiegte ist noch da.")
	_enemy("weltenwurm","Der Weltenwurm",Konst.Tier.BOSS,5,620,46,24,1,["A","F","D","H","A"],[],"Er frisst die Welt von hinten.")

func _build_prophecies() -> void:
	prophecies = [
		{"id":"erste_lesung","title":"Die erste Lesung","text":"Beende einen Run.","target":1,"key":"runs","mode":"meta","unlock_charms":["star_dust"]},
		{"id":"welt_oeffnet","title":"Die Welt öffnet sich","text":"Lege insgesamt 50-mal DIE WELT.","target":50,"key":"world_spreads","mode":"sum","unlock_charms":["world_thread"]},
		{"id":"weltenweber","title":"Weltenweber","text":"Lege 5-mal DIE WELT in einem Kampf.","target":5,"key":"most_worlds_fight","mode":"best","unlock_charms":["cat_fang"]},
		{"id":"blutige_lesung","title":"Blutige Lesung","text":"Spiele 40 umgekehrte Karten.","target":40,"key":"reversed_played","mode":"sum","unlock_charms":["blood_moon"],"unlock_deuter":"aderleser"},
		{"id":"voller_tresor","title":"Der volle Tresor","text":"Gewinne einen Kampf mit 40 Schild.","target":40,"key":"most_shield","mode":"best","unlock_charms":["emperor_seal"],"unlock_deuter":"buchhalter"},
		{"id":"leeres_blatt","title":"Das leere Blatt","text":"Besiege einen Boss mit höchstens 8 Karten.","target":1,"key":"thin_boss_kills","mode":"best","unlock_deuter":"eremit"},
		{"id":"ueberschuss","title":"Überschuss","text":"Triff 250 über das Leben hinaus.","target":250,"key":"best_overkill","mode":"best","unlock_charms":["predator_fang"]},
		{"id":"kettenleser","title":"Kettenleser","text":"Halte eine Musterkette über 7 Züge.","target":7,"key":"longest_chain","mode":"best","unlock_charms":["wand_weave"]},
		{"id":"teufel_im_detail","title":"Der Teufel im Detail","text":"Nimm 3 Pakte an.","target":3,"key":"pacts_accepted","mode":"sum","unlock_charms":["greed_moth"]},
		{"id":"tintenherz","title":"Tintenherz","text":"Erreiche Verdunkelung 60.","target":60,"key":"peak_darkness","mode":"best","unlock_charms":["silver_mirror"]},
		{"id":"schwarzer_spiegel","title":"Schwarzer Spiegel","text":"Besitze zwei schwarze Karten.","target":2,"key":"most_black","mode":"best","unlock_charms":["twin_coin"]},
		{"id":"weg_ist_ziel","title":"Der Weg ist das Ziel","text":"Erlebe 20 Ereignisse.","target":20,"key":"events_seen","mode":"sum","unlock_charms":["oracle_eye"]},
		{"id":"grosser_schlag","title":"Der große Schlag","text":"Lege einen Wert von 500.","target":500,"key":"best_hit","mode":"best","unlock_charms":["black_nail"]},
		{"id":"welt_nicht_ende","title":"Die Welt ist nicht das Ende","text":"Gewinne einen Run.","target":1,"key":"wins","mode":"meta","unlock_charms":["phoenix_feather"]},
		{"id":"schleierlaeufer","title":"Schleierläufer","text":"Gewinne auf Schleier 3.","target":3,"key":"highest_veil","mode":"meta","unlock_charms":["black_cup"]},
		{"id":"spiralgaenger","title":"Spiralgänger","text":"Erreiche Spirale 8.","target":8,"key":"best_spiral","mode":"meta","unlock_charms":["broken_crown"]},
		{"id":"letztes_blatt","title":"Das letzte Blatt","text":"Beende die Geschichte des Kartenspielers.","target":1,"key":"spieler_3","mode":"flag","unlock_charms":["gold_die"]},
		{"id":"schwarzes_blatt","title":"Das Schwarze Blatt","text":"Beende die Geschichte der Tinte.","target":1,"key":"tinte_3","mode":"flag","unlock_charms":["empty_frame"]},
		{"id":"sammler","title":"Sammler","text":"Sieh 40 verschiedene Karten.","target":40,"key":"seen_cards","mode":"meta","unlock_charms":["luck_bell"]}
	]

func _build_events() -> void:
	events = [
		{"id":"kartenspieler_1","title":"Der Kartenspieler","art":"kartenspieler","beats":["Ein Mann mischt Karten, ohne sie zu berühren.","„Noch eine Runde?“"],"choices":[{"label":"Spiele","hint":"+35 Gold, +3 Verdunkelung","op":"story","flag":"spieler_1"},{"label":"Weiter","hint":"Nichts","op":"leave"}]},
		{"id":"tinte_1","title":"Das Tintenfass","art":"tintenfass","beats":["Ein Tintenfass steht mitten im Weg.","Die Oberfläche zeigt dein Gesicht."],"choices":[{"label":"Berühre es","hint":"+5 Verdunkelung","op":"story","flag":"tinte_1"},{"label":"Lass es","hint":"Nichts","op":"leave"}]},
		{"id":"grab","title":"Das Grab mit deinem Namen","art":"grab","beats":["Ein frisches Grab trägt deinen Namen.","Darunter rascheln Karten."],"choices":[{"label":"Ausgraben","hint":"Eine alte Karte kehrt zurück","op":"grave"},{"label":"Blumen","hint":"Heile 15, -6 Verdunkelung","op":"heal_light","heal":15,"light":6}]},
		{"id":"naeherin","title":"Die Näherin","art":"naeherin","beats":["Sie näht Karten aneinander.","Ihre Finger sind aus Faden."],"choices":[{"label":"Vernähen","hint":"2 schwache Karten fort, beste +1","op":"sew"},{"label":"Faden","hint":"Weißer Faden","op":"charm","id2":"white_thread"}]},
		{"id":"spiegelkabinett","title":"Das Spiegelkabinett","art":"spiegel","beats":["Hundert Spiegel.","In einem stehst du still und lächelst."],"choices":[{"label":"Hinein","hint":"Karte kopieren, +4 Verdunkelung","op":"mirror"},{"label":"Zerschlagen","hint":"+45 Gold, -8 HP","op":"gold_hurt","gold":45,"hurt":8}]},
		{"id":"leichenschmaus","title":"Der Leichenschmaus","art":"tafel","beats":["Eine lange Tafel.","Ein Platz trägt deine Initialen."],"choices":[{"label":"Iss mit","hint":"Heile 40 %, Karte kippt","op":"feast"},{"label":"Gib Karte","hint":"Schwächste fort, +4 Max-HP","op":"sacrifice"}]},
		{"id":"kinder_im_nebel","title":"Die Kinder im Nebel","art":"kinder","beats":["Sie spielen Tarot mit Steinen.","Keines hat einen Schatten."],"choices":[{"label":"Mitspielen","hint":"+1 Luck, +5 Verdunkelung","op":"luck_dark","luck":1,"dark":5},{"label":"20 Gold","hint":"Zufälliges Item","op":"buy_item","cost":20}]},
		{"id":"uhrmacher","title":"Der Uhrmacher ohne Zeiger","art":"uhrmacher","beats":["„Ich kann dir Zeit geben.“","Die Uhr hat keine Zeiger."],"choices":[{"label":"Reife","hint":"-8 Max-HP, beste Karte +1 und dunkler","op":"age"},{"label":"Ruhe","hint":"35 Gold: heile 30 %","op":"paid_heal","cost":35,"share":0.30}]},
		{"id":"beichtstuhl","title":"Der Beichtstuhl","art":"beichtstuhl","beats":["Ein Beichtstuhl auf einer Wiese.","Jemand flüstert deinen Namen."],"choices":[{"label":"Beichte","hint":"-25 Gold, -12 Verdunkelung","op":"confess"},{"label":"Lüge","hint":"+60 Fate, +10 Verdunkelung","op":"lie"}]},
		{"id":"brunnen","title":"Das Orakel im Brunnen","art":"brunnen","beats":["Ein Gesicht spiegelt sich unten.","Es ist nicht deins."],"choices":[{"label":"Hör zu","hint":"Mehr Belohnungsauswahl","op":"reward_choice"},{"label":"10 Gold","hint":"1/3 Charm","op":"well"}]},
		{"id":"wanderzirkus","title":"Der Wanderzirkus","art":"zirkus","beats":["Ein Zelt ist innen größer.","Der Hut des Direktors lächelt."],"choices":[{"label":"Los kaufen","hint":"25 Gold: Charm oder Item","op":"lottery"},{"label":"Attraktion","hint":"+50 Gold, -10 HP","op":"gold_hurt","gold":50,"hurt":10}]},
		{"id":"hebamme","title":"Die Hebamme der Omen","art":"hebamme","beats":["Etwas greift aus einem Tarottuch.","Es hat deine Hände."],"choices":[{"label":"Annehmen","hint":"Umgekehrtes Großes Arkanum, +8 Verdunkelung","op":"major"},{"label":"Segnen","hint":"Zufällige Karte +2","op":"bless"}]},
		{"id":"hungriger_haendler","title":"Der Händler hat Hunger","art":"haendler","beats":["Der Mantel ist leer.","„Nur ein Happen.“"],"choices":[{"label":"Karte","hint":"Schwächste fort, nächster Kauf frei","op":"feed_card"},{"label":"40 Gold","hint":"Charm","op":"buy_charm","cost":40}]},
		{"id":"waage","title":"Die Waage","art":"waage","beats":["In einer Schale liegt ein Herz.","Die andere wartet."],"choices":[{"label":"Karte","hint":"Schwächste Karte transformiert","op":"transform"},{"label":"Ganzes Gold","hint":"Charm verstärken","op":"all_gold"}]},
		{"id":"schreiber","title":"Der Schreiber","art":"schreiber","beats":["Er schreibt deine Züge auf.","Eine Zeile ist noch leer."],"choices":[{"label":"Diktieren","hint":"+30 Fate","op":"fate","value":30},{"label":"Streichen","hint":"Schwächste Karte fort","op":"remove"}]},
		{"id":"schwarzes_blatt","title":"Das Schwarze Blatt","art":"schwarzes_blatt","beats":["Ein Blatt ist schwärzer als die Nacht.","Es kennt deinen Namen."],"choices":[{"label":"Unterschreibe","hint":"Beste Karte schwarz, +15 Verdunkelung","op":"black_page"},{"label":"Zerreißen","hint":"Voll heilen, -10 Verdunkelung","op":"full_heal_light"}]},
		{"id":"mondfenster","title":"Das Mondfenster","art":"spiegel","beats":["Im Fenster steht der Mond zu nah.","Er blinzelt zuerst."],"choices":[{"label":"Hineinsehen","hint":"+1 Luck, nächste Karte umgekehrt","op":"moon_window"},{"label":"Vorhang","hint":"Heile 10","op":"heal","value":10}]},
		{"id":"rote_buehne","title":"Die rote Bühne","art":"zirkus","beats":["Der Vorhang geht auf.","Niemand sitzt im Saal."],"choices":[{"label":"Spielen","hint":"+70 Gold, +8 Verdunkelung","op":"gold_dark","gold":70,"dark":8},{"label":"Abgang","hint":"Nichts","op":"leave"}]}
	]
