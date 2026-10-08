# Testlauf: godot --headless --path . --script tests/lauf.gd
#
# Bewusst ohne Test-Framework-Abhaengigkeit - der Kern soll mit einer nackten
# Godot-Installation pruefbar sein, auch in CI.
extends SceneTree

const Konst := preload("res://core/konst.gd")

var bestanden: int = 0
var fehlgeschlagen: int = 0
var aktueller_test: String = ""
var fehlerliste: Array[String] = []

func _initialize() -> void:
	print("\n=== TARTOT Testlauf ===\n")
	var kat := Katalog.new()
	if not kat.laden():
		for f in kat.fehler:
			print("KATALOGFEHLER: ", f)
		quit(1)
		return

	_test_rng()
	_test_katalog(kat)
	_test_status()
	_test_karten_orientierung(kat)
	_test_positionsfaktoren(kat)
	_test_echo(kat)
	_test_muster(kat)
	_test_zukunft(kat)
	_test_charm_stacking(kat)
	_test_faeden(kat)
	_test_stab_combo(kat)
	_test_kampf_laeuft_durch(kat)
	_test_run_speichern_laden(kat)
	_test_determinismus_ganzer_kampf(kat)
	_test_endlosmodus(kat)
	_test_verderbnis_verdunkelt(kat)

	print("\n=== Ergebnis: %d bestanden, %d fehlgeschlagen ===" % [bestanden, fehlgeschlagen])
	for f in fehlerliste:
		print("  FEHLER: ", f)
	quit(0 if fehlgeschlagen == 0 else 1)

# ------------------------------------------------------------- Hilfsmittel
func t(name: String) -> void:
	aktueller_test = name

func pruefe(bedingung: bool, was: String) -> void:
	if bedingung:
		bestanden += 1
	else:
		fehlgeschlagen += 1
		var m: String = "%s: %s" % [aktueller_test, was]
		fehlerliste.append(m)
		print("  [X] ", m)

func gleich(a, b, was: String) -> void:
	if a == b:
		bestanden += 1
	else:
		fehlgeschlagen += 1
		var m: String = "%s: %s (erwartet %s, war %s)" % [aktueller_test, was, str(b), str(a)]
		fehlerliste.append(m)
		print("  [X] ", m)

func _deck(kat: Katalog, ids: Array) -> Array[Karte]:
	var d: Array[Karte] = []
	for i in ids:
		d.append(kat.karte(String(i)))
	return d

func _kampf(kat: Katalog, deck_ids: Array, gegner_id: String = "lachender_henker",
		opt: Dictionary = {}) -> Kampf:
	var rng := TRng.new(int(opt.get("seed", 7)))
	var spieler := Kaempfer.neu("Testerin", int(opt.get("hp", 200)), true)
	var beutel := Charmbeutel.new(kat)
	for c in opt.get("charms", []):
		beutel.geben(String(c), int(opt.get("charm_stacks", 1)))
	var kf := Kampf.neu(kat, rng, spieler, _deck(kat, deck_ids), beutel,
		[gegner_id], Wahl.new(), opt)
	kf.starten()
	kf.gegner[0].hp = int(opt.get("gegner_hp", 500))
	kf.gegner[0].hp_max = kf.gegner[0].hp
	return kf

func _hand_karte(kf: Kampf, vorlage: String) -> Karte:
	for k in kf.stapel.hand:
		if k.vorlage == vorlage:
			return k
	return null

# ==================================================================== Tests
func _test_rng() -> void:
	t("RNG")
	var a := TRng.new(12345)
	var b := TRng.new(12345)
	var folge_a: Array[int] = []
	var folge_b: Array[int] = []
	for _i in 50:
		folge_a.append(a.int_bis(1000))
		folge_b.append(b.int_bis(1000))
	gleich(folge_a, folge_b, "gleicher Seed erzeugt gleiche Folge")
	var c := TRng.new(12346)
	pruefe(c.int_bis(1000) != folge_a[0] or c.int_bis(1000) != folge_a[1],
		"anderer Seed erzeugt andere Folge")
	# Gleichverteilung grob pruefen.
	var d := TRng.new(1)
	var treffer: Array[int] = [0, 0, 0, 0]
	for _i in 4000:
		treffer[d.int_bis(4)] += 1
	for n in treffer:
		pruefe(n > 850 and n < 1150, "int_bis(4) ist grob gleichverteilt (%d)" % n)
	# Stroeme sind unabhaengig und reproduzierbar.
	var e1 := TRng.new(99).strom("laden")
	var e2 := TRng.new(99).strom("laden")
	gleich(e1.int_bis(10000), e2.int_bis(10000), "benannte Stroeme sind reproduzierbar")
	var e3 := TRng.new(99).strom("kampf")
	pruefe(TRng.new(99).strom("laden").int_bis(100000) != e3.int_bis(100000),
		"verschiedene Stroeme unterscheiden sich")

func _test_katalog(kat: Katalog) -> void:
	t("Katalog")
	gleich(kat.kleine.size(), 56, "56 kleine Arkana")
	gleich(kat.grosse.size(), 23, "22 grosse Arkana + Das Schicksal")
	gleich(kat.charms.size(), 50, "50 Charms")
	gleich(kat.items.size(), 22, "22 Items")
	pruefe(kat.deuter.size() >= 3, "mindestens 3 Deuter")
	# Jede Zahlenkarte hat beide Orientierungen.
	var ohne: Array[String] = []
	for id in kat.kleine.keys():
		var d: Dictionary = kat.kleine[id]
		if bool(d.get("figur", false)):
			continue
		if (d.get("aufrecht", []) as Array).is_empty() or (d.get("umgekehrt", []) as Array).is_empty():
			ohne.append(String(id))
	gleich(ohne, [], "jede Zahlenkarte hat aufrecht und umgekehrt")
	# Jedes Arkanum hat Text fuer beide Seiten und eine verderbte Regel.
	for id in kat.grosse.keys():
		var a: Dictionary = kat.grosse[id]
		pruefe(String(a.get("aufrecht_text", "")) != "", "%s hat aufrechten Text" % id)
		pruefe(String(a.get("umgekehrt_text", "")) != "", "%s hat umgekehrten Text" % id)
		pruefe(not (a.get("verderbt", {}) as Dictionary).is_empty(),
			"%s hat eine verderbte Regel" % id)

func _test_status() -> void:
	t("Status")
	var k := Kaempfer.neu("Ziel", 100)
	gleich(k.schaden_nehmen(10), 10, "Schaden ohne Schild")
	k.gib(Konst.St.SCHILD, 8)
	gleich(k.schaden_nehmen(10), 2, "Schild absorbiert zuerst")
	gleich(k.stapel(Konst.St.SCHILD), 0, "Schild ist aufgebraucht")
	k.gib(Konst.St.VERWUNDBAR, 2)
	gleich(k.schaden_nehmen(10), 15, "Verwundbar erhoeht Schaden um 50 %")
	var a := Kaempfer.neu("Angreifer", 50)
	gleich(a.schaden_ausgehend(10), 10, "ohne Status unveraendert")
	a.gib(Konst.St.SCHWACH, 1)
	gleich(a.schaden_ausgehend(10), 8, "Schwach senkt Schaden um 25 % (abgerundet auf 8)")
	a.setze(Konst.St.SCHWACH, 0)
	a.gib(Konst.St.STARK, 3)
	gleich(a.schaden_ausgehend(10), 13, "Stark addiert flach")
	# Ticks
	var b := Kaempfer.neu("Bluter", 100)
	b.gib(Konst.St.BLUTUNG, 3)
	b.zugende()
	gleich(b.hp, 97, "Blutung tickt am Zugende")
	gleich(b.stapel(Konst.St.BLUTUNG), 2, "Blutung sinkt um 1")
	b.gib(Konst.St.GIFT, 4)
	b.zugbeginn()
	gleich(b.hp, 93, "Gift tickt am Zugbeginn")
	var g := Kaempfer.neu("Brenner", 100)
	g.gib(Konst.St.GLUT, 8)
	g.zugende()
	gleich(g.hp, 92, "Glut tickt voll")
	gleich(g.stapel(Konst.St.GLUT), 4, "Glut halbiert sich")
	# Schild verfaellt, ausser verankert.
	var v := Kaempfer.neu("Fels", 100)
	v.gib(Konst.St.SCHILD, 10)
	v.zugbeginn()
	gleich(v.stapel(Konst.St.SCHILD), 0, "Schild verfaellt")
	v.gib(Konst.St.SCHILD, 10)
	v.gib(Konst.St.VERANKERT, 1)
	v.zugbeginn()
	gleich(v.stapel(Konst.St.SCHILD), 10, "Verankert haelt das Schild")

func _test_karten_orientierung(kat: Katalog) -> void:
	t("Orientierung")
	var k := kat.karte("schwerter_09")
	var ops_auf: Array = kat.ops(k)
	gleich(int(ops_auf[0]["wert"]), 9, "9 der Schwerter aufrecht: 9 Schaden")
	k.drehen()
	var ops_um: Array = kat.ops(k)
	gleich(int(ops_um[0]["wert"]), 18, "umgekehrt: 18 Schaden")
	gleich(int(ops_um[1]["wert"]), 5, "umgekehrt: 5 Selbstschaden")
	pruefe(k.ist_umgekehrt(), "Karte ist umgekehrt")
	k.drehen()
	pruefe(not k.ist_umgekehrt(), "zurueckgedreht")
	# Aufwerten verdunkelt.
	var vorher: int = k.tinte
	k.aufwerten(1)
	gleich(k.stufe, 1, "Stufe 1 nach Aufwerten")
	pruefe(k.tinte > vorher, "Aufwerten erhoeht die Tinte")
	pruefe(k.anzeigename().contains("+"), "Name zeigt die Stufe")

func _test_positionsfaktoren(kat: Katalog) -> void:
	t("Positionsfaktoren")
	# Gegenwart: voller Wert.
	var kf := _kampf(kat, ["schwerter_08"])
	var k := _hand_karte(kf, "schwerter_08")
	var hp_vorher: int = kf.gegner[0].hp
	kf.legen(k, Konst.Pos.GEGENWART)
	kf.ausfuehren()
	# 8 Schaden + 2 Blutung (tickt am Gegner-Zugende).
	pruefe(hp_vorher - kf.gegner[0].hp >= 8, "Gegenwart: mindestens voller Schaden (8)")

	# Vergangenheit: 70 %.
	var kf2 := _kampf(kat, ["schwerter_08"])
	var k2 := _hand_karte(kf2, "schwerter_08")
	var hp2: int = kf2.gegner[0].hp
	kf2.legen(k2, Konst.Pos.VERGANGENHEIT)
	kf2.ausfuehren()
	var diff2: int = hp2 - kf2.gegner[0].hp
	# 8 * 0.7 = 5.6 -> 6, Blutung 2 * 0.7 = 1.4 -> 1 (tickt einmal)
	gleich(diff2, 7, "Vergangenheit: 6 Schaden + 1 Blutung")

	# Zukunft: wirkt erst naechste Runde, dann doppelt.
	var kf3 := _kampf(kat, ["schwerter_08"])
	var k3 := _hand_karte(kf3, "schwerter_08")
	var hp3: int = kf3.gegner[0].hp
	kf3.legen(k3, Konst.Pos.ZUKUNFT)
	gleich(kf3.zukunft_wartend.size(), 0, "vor dem Ausfuehren wartet nichts")
	kf3.ausfuehren()
	# ausfuehren() laeuft bis in die naechste Runde, die Zukunft hat ausgeloest.
	gleich(kf3.zukunft_wartend.size(), 0, "die Zukunft hat sich erfuellt")
	var diff3: int = hp3 - kf3.gegner[0].hp
	# 16 Schaden + 4 Blutung (tickt am Ende der Gegnerrunde)
	pruefe(diff3 >= 16, "Zukunft: doppelter Schaden (war %d)" % diff3)

func _test_echo(kat: Katalog) -> void:
	t("Echo der Vergangenheit")
	var kf := _kampf(kat, ["schwerter_08", "schwerter_08", "muenzen_05", "muenzen_05"])
	# Runde 1: Schwert in die Gegenwart.
	var a := _hand_karte(kf, "schwerter_08")
	kf.legen(a, Konst.Pos.GEGENWART)
	kf.ausfuehren()
	pruefe(kf.letzte_gegenwart_karte != null, "die Gegenwart wird gemerkt")
	# Runde 2: Muenze in die Vergangenheit - sie wiederholt das Schwert zu 50 %.
	var hp_vor: int = kf.gegner[0].hp
	var m := _hand_karte(kf, "muenzen_05")
	if m != null:
		kf.legen(m, Konst.Pos.VERGANGENHEIT)
		kf.ausfuehren()
		var diff: int = hp_vor - kf.gegner[0].hp
		# Muenze macht keinen Schaden, das Echo des Schwertes schon:
		# 8 * 0.7 * 0.5 = 2.8 -> 3 Schaden, plus Blutung.
		pruefe(diff >= 3, "Echo wiederholt die letzte Gegenwart (war %d)" % diff)
	else:
		pruefe(false, "Muenze war nicht auf der Hand")

func _test_muster(kat: Katalog) -> void:
	t("Muster")
	# Resonanz: alle gelegten Karten gleiche Farbe.
	var kf := _kampf(kat, ["schwerter_02", "schwerter_05", "schwerter_09"])
	kf.legen(kf.stapel.hand[0], Konst.Pos.VERGANGENHEIT)
	kf.legen(kf.stapel.hand[0], Konst.Pos.GEGENWART)
	var m: Array[int] = kf.muster_erkennen()
	pruefe(m.has(Konst.Muster.RESONANZ), "zwei Schwerter erzeugen Resonanz")

	# Schicksalskette: 2, 3, 4
	var kf2 := _kampf(kat, ["schwerter_02", "staebe_03", "kelche_04"])
	for p in [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]:
		if not kf2.stapel.hand.is_empty():
			kf2.legen(kf2.stapel.hand[0], p)
	var m2: Array[int] = kf2.muster_erkennen()
	pruefe(m2.has(Konst.Muster.SCHICKSALSKETTE), "2-3-4 ergibt eine Schicksalskette")
	pruefe(not m2.has(Konst.Muster.RESONANZ), "verschiedene Farben: keine Resonanz")

	# Konvergenz: dreimal derselbe Wert.
	var kf3 := _kampf(kat, ["schwerter_05", "staebe_05", "kelche_05"])
	for p in [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]:
		if not kf3.stapel.hand.is_empty():
			kf3.legen(kf3.stapel.hand[0], p)
	var m3: Array[int] = kf3.muster_erkennen()
	pruefe(m3.has(Konst.Muster.KONVERGENZ), "5-5-5 ergibt Konvergenz")
	var faden_vor: int = kf3.faden
	kf3.ausfuehren()
	pruefe(kf3.faden > faden_vor or faden_vor >= Konst.FADEN_MAX,
		"Konvergenz gibt Schicksalsfaeden")

	# Die Welt: Summe exakt 21.
	var kf4 := _kampf(kat, ["schwerter_04", "staebe_07", "kelche_10"])
	for p in [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]:
		if not kf4.stapel.hand.is_empty():
			kf4.legen(kf4.stapel.hand[0], p)
	var m4: Array[int] = kf4.muster_erkennen()
	pruefe(m4.has(Konst.Muster.DIE_WELT), "4 + 7 + 10 = 21 ruft Die Welt")

	# Gegenprobe: 4 + 7 + 9 = 20
	var kf5 := _kampf(kat, ["schwerter_04", "staebe_07", "kelche_09"])
	for p in [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]:
		if not kf5.stapel.hand.is_empty():
			kf5.legen(kf5.stapel.hand[0], p)
	pruefe(not kf5.muster_erkennen().has(Konst.Muster.DIE_WELT), "20 ruft Die Welt nicht")

	# Muster verstaerken die Wirkung messbar.
	var ohne := _kampf(kat, ["schwerter_05", "kelche_05"])
	var hp_a: int = ohne.gegner[0].hp
	ohne.legen(_hand_karte(ohne, "schwerter_05"), Konst.Pos.GEGENWART)
	ohne.ausfuehren()
	var schaden_ohne: int = hp_a - ohne.gegner[0].hp

	var mit := _kampf(kat, ["schwerter_05", "schwerter_05"])
	var hp_b: int = mit.gegner[0].hp
	mit.legen(mit.stapel.hand[0], Konst.Pos.GEGENWART)
	mit.legen(mit.stapel.hand[0], Konst.Pos.VERGANGENHEIT)
	mit.ausfuehren()
	var schaden_mit: int = hp_b - mit.gegner[0].hp
	pruefe(schaden_mit > schaden_ohne,
		"Resonanz erhoeht den Schaden (%d statt %d)" % [schaden_mit, schaden_ohne])

func _test_zukunft(kat: Katalog) -> void:
	t("Zukunft")
	var kf := _kampf(kat, ["muenzen_05", "muenzen_05", "muenzen_05"])
	var k := _hand_karte(kf, "muenzen_05")
	kf.legen(k, Konst.Pos.ZUKUNFT)
	# Vor dem Ausfuehren: noch kein Schild.
	gleich(kf.spieler.stapel(Konst.St.SCHILD), 0, "die Zukunft wirkt noch nicht")
	kf.ausfuehren()
	# 5 der Muenzen = 7 Schild, x2 = 14. Der Gegner schlaegt danach zu,
	# also pruefen wir ueber das Protokoll.
	var gefunden: bool = false
	for zeile in kf.log:
		if zeile.contains("+14 Schild"):
			gefunden = true
	pruefe(gefunden, "Zukunftskarte gibt doppeltes Schild (14)")

func _test_charm_stacking(kat: Katalog) -> void:
	t("Charms")
	var beutel := Charmbeutel.new(kat)
	gleich(beutel.geben("klingenanhaenger", 3), 3, "3 Stacks angenommen")
	gleich(beutel.anzahl("klingenanhaenger"), 3, "3 Stacks gespeichert")
	gleich(beutel.geben("klingenanhaenger", 9), 2, "Deckel bei 5 Stacks")
	gleich(beutel.anzahl("klingenanhaenger"), 5, "maximal 5 Stacks")
	gleich(beutel.geben("leere_karte", 5), 2, "Leere Karte hat ein eigenes Maximum (2)")
	gleich(beutel.regelwert("dornenring"), 0, "unbesessene Regel ist 0")
	beutel.geben("dornenring", 3)
	gleich(beutel.regelwert("dornenring"), 6, "Dornenring skaliert mit Stacks (2 je Stack)")

	# Wirkung im Kampf: Klingenanhaenger x4 gibt +4 Schaden pro Schwert.
	var ohne := _kampf(kat, ["schwerter_05"])
	var hp_a: int = ohne.gegner[0].hp
	ohne.legen(_hand_karte(ohne, "schwerter_05"), Konst.Pos.GEGENWART)
	ohne.ausfuehren()
	var s_ohne: int = hp_a - ohne.gegner[0].hp

	var mit := _kampf(kat, ["schwerter_05"], "lachender_henker",
		{"charms": ["klingenanhaenger"], "charm_stacks": 4})
	var hp_b: int = mit.gegner[0].hp
	mit.legen(_hand_karte(mit, "schwerter_05"), Konst.Pos.GEGENWART)
	mit.ausfuehren()
	var s_mit: int = hp_b - mit.gegner[0].hp
	gleich(s_mit - s_ohne, 4, "Klingenanhaenger x4 gibt genau +4 Schaden")

	# Flache Boni liegen VOR der Multiplikation: in der Zukunft verdoppeln sie sich.
	var zukunft := _kampf(kat, ["schwerter_05"], "lachender_henker",
		{"charms": ["klingenanhaenger"], "charm_stacks": 4})
	zukunft.legen(_hand_karte(zukunft, "schwerter_05"), Konst.Pos.ZUKUNFT)
	zukunft.ausfuehren()
	var treffer: bool = false
	for zeile in zukunft.log:
		if zeile.contains("18 Schaden"):
			treffer = true
	pruefe(treffer, "(5 + 4) x 2 = 18 Schaden aus der Zukunft")

func _test_faeden(kat: Katalog) -> void:
	t("Schicksalsfaeden")
	# Deck bewusst groesser als die Hand, damit Ziehen moeglich ist.
	var kf := _kampf(kat, ["schwerter_05", "schwerter_06", "kelche_03",
		"muenzen_03", "muenzen_04", "staebe_03", "staebe_05"])
	gleich(kf.faden, Konst.FADEN_START, "Startfaeden")
	var k := kf.stapel.hand[0]
	var ori_vorher: int = k.ori
	pruefe(kf.faden_nutzen(Konst.Faden.DREHEN, {"karte": k}), "Drehen gelingt")
	pruefe(k.ori != ori_vorher, "die Karte ist gedreht")
	gleich(kf.faden, Konst.FADEN_START - 1, "Drehen kostet 1 Faden")
	# Zu teuer: Schicksal biegen kostet 3.
	kf.faden = 2
	pruefe(not kf.faden_nutzen(Konst.Faden.SCHICKSAL_BIEGEN), "zu wenig Faeden -> abgelehnt")
	gleich(kf.faden, 2, "abgelehnte Aktion kostet nichts")
	kf.faden = 5
	var hand_vorher: int = kf.stapel.hand.size()
	pruefe(kf.faden_nutzen(Konst.Faden.ZIEHEN), "Ziehen gelingt")
	gleich(kf.stapel.hand.size(), hand_vorher + 1, "eine Karte mehr auf der Hand")
	gleich(kf.faden, 3, "Ziehen kostet 2")
	# Leerer Ziehstapel: die Aktion scheitert und kostet nichts.
	kf.stapel.ziehstapel.clear()
	kf.stapel.ablage.clear()
	var faden_vorher: int = kf.faden
	pruefe(not kf.faden_nutzen(Konst.Faden.ZIEHEN), "leerer Stapel -> Ziehen scheitert")
	gleich(kf.faden, faden_vorher, "gescheiterte Aktion kostet nichts")
	# Deckel bei 5.
	kf.faden_geben(99)
	gleich(kf.faden, Konst.FADEN_MAX, "Faeden sind bei 5 gedeckelt")

func _test_stab_combo(kat: Katalog) -> void:
	t("Stab-Combo")
	# Eine Stabkarte allein: Basiswert.
	var eins := _kampf(kat, ["staebe_04"])
	var hp_a: int = eins.gegner[0].hp
	eins.legen(_hand_karte(eins, "staebe_04"), Konst.Pos.GEGENWART)
	eins.ausfuehren()
	var s1: int = hp_a - eins.gegner[0].hp

	# Zwei Stabkarten: die zweite wirkt doppelt.
	var zwei := _kampf(kat, ["staebe_04", "staebe_04"])
	var hp_b: int = zwei.gegner[0].hp
	zwei.legen(zwei.stapel.hand[0], Konst.Pos.VERGANGENHEIT)
	zwei.legen(zwei.stapel.hand[0], Konst.Pos.GEGENWART)
	zwei.ausfuehren()
	var s2: int = hp_b - zwei.gegner[0].hp
	pruefe(s2 > s1 * 2, "die zweite Stabkarte eskaliert (%d gegen %d)" % [s2, s1])

func _test_kampf_laeuft_durch(kat: Katalog) -> void:
	t("Kampf laeuft durch")
	var pilot := Autopilot.new()
	var siege: int = 0
	var runden_summe: int = 0
	for seed in range(20):
		var rng := TRng.new(seed + 100)
		var spieler := Kaempfer.neu("Wahrsagerin", 70, true)
		var deck := _deck(kat, ["schwerter_02", "schwerter_02", "schwerter_03",
			"schwerter_04", "muenzen_02", "muenzen_03", "muenzen_03",
			"kelche_02", "kelche_04", "staebe_03"])
		var kf := Kampf.neu(kat, rng, spieler, deck, Charmbeutel.new(kat),
			["lachender_henker"], Wahl.new(), {})
		kf.starten()
		var runden: int = pilot.kampf_spielen(kf)
		runden_summe += runden
		pruefe(kf.vorbei(), "Kampf endet (Seed %d, %d Runden)" % [seed, runden])
		if kf.gewonnen():
			siege += 1
	pruefe(siege >= 15, "Startdeck schlaegt den ersten Gegner meistens (%d/20)" % siege)
	print("    Startdeck gegen Der lachende Henker: %d/20 Siege, im Schnitt %.1f Runden"
		% [siege, float(runden_summe) / 20.0])

func _test_run_speichern_laden(kat: Katalog) -> void:
	t("Speichern und Laden")
	var run := Run.neu(kat, "aderleser", 4242)
	run.gold = 123
	run.luck = 2
	run.verderbnis = 17
	run.charms.geben("silberspiegel", 3)
	run.deck[0].aufwerten(2)
	run.deck[1].drehen()
	var d: Dictionary = run.speichern()
	var txt: String = JSON.stringify(d)
	var wieder: Variant = JSON.parse_string(txt)
	pruefe(typeof(wieder) == TYPE_DICTIONARY, "Speicherstand ist gueltiges JSON")
	var run2 := Run.aus_speicher(kat, wieder)
	gleich(run2.gold, 123, "Gold erhalten")
	gleich(run2.luck, 2, "Luck erhalten")
	gleich(run2.verderbnis, 17, "Verderbnis erhalten")
	gleich(run2.deuter_id, "aderleser", "Deuter erhalten")
	gleich(run2.deck.size(), run.deck.size(), "Deckgroesse erhalten")
	gleich(run2.deck[0].stufe, 2, "Kartenstufe erhalten")
	pruefe(run2.deck[1].ist_umgekehrt(), "Orientierung erhalten")
	gleich(run2.charms.anzahl("silberspiegel"), 3, "Charm-Stacks erhalten")

func _test_determinismus_ganzer_kampf(kat: Katalog) -> void:
	t("Determinismus")
	var log_a: Array = _kampf_protokoll(kat, 777)
	var log_b: Array = _kampf_protokoll(kat, 777)
	var log_c: Array = _kampf_protokoll(kat, 778)
	gleich(log_a, log_b, "gleicher Seed erzeugt identischen Kampfverlauf")
	pruefe(log_a != log_c, "anderer Seed erzeugt anderen Verlauf")

func _test_endlosmodus(kat: Katalog) -> void:
	t("Endlosmodus")
	var run := Run.neu(kat, "wahrsagerin", 31337)
	run.endlos_beginnen()
	pruefe(run.endlos, "die Spirale ist offen")
	gleich(run.verderbte_arkana.size(), 0, "zu Beginn noch kein verderbtes Arkanum")

	# 15 Raeume durchlaufen: alle 5 Raeume muss ein Arkanum dazukommen.
	var verderbnis_vorher: int = run.verderbnis
	for _i in 15:
		run.wegkarten_ziehen()
		run.weg_waehlen(0)
	gleich(run.verderbte_arkana.size(), 3, "alle 5 Raeume kommt ein Arkanum dazu")
	pruefe(run.run_regeln.size() > 0, "die Regeln der Arkana sind uebernommen")
	pruefe(run.verderbnis > verderbnis_vorher, "die Spirale erhoeht die Verderbnis")

	# Keine Dubletten - jedes Arkanum hoechstens einmal.
	var gesehen := {}
	for id in run.verderbte_arkana:
		pruefe(not gesehen.has(id), "Arkanum %s kommt nur einmal" % id)
		gesehen[id] = true

	# Die Gegner wachsen superexponentiell mit der Tiefe.
	var f0: float = run._gegner_hp_faktor()
	run.endlos_tiefe = 5
	var f5: float = run._gegner_hp_faktor()
	run.endlos_tiefe = 15
	var f15: float = run._gegner_hp_faktor()
	pruefe(f5 > f0 * 2.0, "Tiefe 5 verdoppelt die Gegner mindestens (%.2f)" % f5)
	pruefe(f15 > f5 * 4.0, "Tiefe 15 waechst ueberproportional (%.2f)" % f15)
	print("    Gegner-HP-Faktor: Tiefe 0 = %.2f, Tiefe 5 = %.2f, Tiefe 15 = %.2f"
		% [f0, f5, f15])

func _test_verderbnis_verdunkelt(kat: Katalog) -> void:
	t("Verderbnis")
	# Aufwerten verdunkelt immer mit - Macht hat einen sichtbaren Preis.
	var k := kat.karte("schwerter_05")
	gleich(k.tinte, 0, "neue Karte ist blass")
	k.aufwerten(1)
	k.aufwerten(1)
	gleich(k.stufe, 2, "zweimal aufgewertet")
	gleich(k.tinte, 2, "Tinte steigt mit jeder Aufwertung")
	gleich(k.tintenname(), "Russ", "Tintenstufe hat einen Namen")

	# Umgekehrte Karten profitieren von hoher Verderbnis.
	var schwach := _kampf(kat, ["schwerter_05"], "lachender_henker", {"verderbnis": 0})
	var kk := _hand_karte(schwach, "schwerter_05")
	kk.drehen()
	var hp_a: int = schwach.gegner[0].hp
	schwach.legen(kk, Konst.Pos.GEGENWART)
	schwach.ausfuehren()
	var s_ohne: int = hp_a - schwach.gegner[0].hp

	var stark := _kampf(kat, ["schwerter_05"], "lachender_henker", {"verderbnis": 100})
	var kk2 := _hand_karte(stark, "schwerter_05")
	kk2.drehen()
	var hp_b: int = stark.gegner[0].hp
	stark.legen(kk2, Konst.Pos.GEGENWART)
	stark.ausfuehren()
	var s_mit: int = hp_b - stark.gegner[0].hp
	pruefe(s_mit > s_ohne,
		"volle Verderbnis verstaerkt umgekehrte Karten (%d statt %d)" % [s_mit, s_ohne])

	# Beute "traenken" wertet auf und verdunkelt.
	var run := Run.neu(kat, "wahrsagerin", 99)
	var stufen_vorher: int = 0
	for karte in run.deck:
		stufen_vorher += karte.stufe
	run.beute_waehlen("traenken")
	var stufen_nachher: int = 0
	for karte in run.deck:
		stufen_nachher += karte.stufe
	pruefe(stufen_nachher > stufen_vorher, "Traenken wertet Karten auf")
	pruefe(run.verderbnis > 0, "Traenken erhoeht die Verderbnis")

func _kampf_protokoll(kat: Katalog, seed: int) -> Array:
	var rng := TRng.new(seed)
	var spieler := Kaempfer.neu("Wahrsagerin", 70, true)
	var deck := _deck(kat, ["schwerter_02", "schwerter_03", "schwerter_04",
		"muenzen_03", "muenzen_04", "kelche_03", "kelche_05", "staebe_03",
		"staebe_05", "muenzen_02"])
	var kf := Kampf.neu(kat, rng, spieler, deck, Charmbeutel.new(kat),
		["kelchtrinker"], Wahl.new(), {})
	kf.starten()
	Autopilot.new().kampf_spielen(kf)
	return kf.log.duplicate()
