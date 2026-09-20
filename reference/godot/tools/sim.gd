# Balancing-Simulation: spielt komplette Runs ohne Spieler.
#
#   godot --headless --path . --script tools/sim.gd -- --runs=200 --deuter=wahrsagerin
#
# Ausgegeben wird, was man zum Tunen braucht: Wie weit kommt ein solider,
# aber nicht genialer Spieler? Wo bricht der Run ab? Wie gross wird das Deck?
extends SceneTree

const Konst := preload("res://core/konst.gd")

var katalog: Katalog
var pilot: Autopilot

func _initialize() -> void:
	var args := _argumente()
	var anzahl: int = int(args.get("runs", 100))
	var deuter: String = String(args.get("deuter", "wahrsagerin"))
	var endlos_testen: bool = bool(args.get("endlos", false))
	var seed_basis: int = int(args.get("seed", 1000))

	katalog = Katalog.new()
	if not katalog.laden():
		for f in katalog.fehler:
			print("KATALOGFEHLER: ", f)
		quit(1)
		return
	pilot = Autopilot.new()

	print("\n=== TARTOT Simulation: %d Runs als %s ===\n" % [anzahl, deuter])
	var erg: Array = []
	for i in anzahl:
		erg.append(_run_spielen(deuter, seed_basis + i, endlos_testen))
	_auswerten(erg, anzahl)
	quit(0)

func _argumente() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var t: String = String(a).lstrip("-")
		if t.contains("="):
			var teile: PackedStringArray = t.split("=", true, 1)
			d[teile[0]] = teile[1]
		else:
			d[t] = true
	return d

# ------------------------------------------------------------- Ein Run
func _run_spielen(deuter: String, seed_wert: int, endlos_testen: bool) -> Dictionary:
	var run := Run.neu(katalog, deuter, seed_wert)
	var wahl := Wahl.new()
	var raeume: int = 0
	var grenze: int = 200 if endlos_testen else 60
	var hp_verlauf: Array = []
	var tod_bei: String = "-"

	while not run.vorbei and raeume < grenze:
		raeume += 1
		run.wegkarten_ziehen()
		var typ: int = run.weg_waehlen(_weg_bewerten(run))
		match typ:
			Konst.Raum.KAMPF, Konst.Raum.ELITE, Konst.Raum.BOSS:
				var kf := run.kampf_starten(wahl)
				pilot.kampf_spielen(kf)
				var erg: Dictionary = run.kampf_beenden(kf)
				hp_verlauf.append(run.spieler.hp)
				if not bool(erg.get("gewonnen", false)):
					tod_bei = "%s/%s" % [Konst.RAUM_NAME[typ], kf.gegner_namen()]
					break
				_belohnung_nehmen(run, typ)
				if erg.has("beute"):
					run.beute_waehlen(_beute_waehlen(run))
					if run.gewonnen and not run.endlos:
						if endlos_testen:
							run.endlos_beginnen()
						else:
							break
			Konst.Raum.HAENDLER:
				_einkaufen(run)
			Konst.Raum.RITUAL:
				_ritual(run)
			Konst.Raum.RUHE:
				run.spieler.heilen(int(float(run.spieler.hp_max) * 0.3))
			Konst.Raum.TRUHE:
				var truhe_charm: String = run.belohnung_charm()
				if truhe_charm != "":
					run.charms.geben(truhe_charm, 1)
			Konst.Raum.UNBEKANNT:
				# Unbekannt ist im Schnitt leicht positiv, manchmal teuer.
				if run.rng.chance(0.55):
					run.gold += 25
				else:
					run.spieler.direktschaden(int(float(run.spieler.hp_max) * 0.12))
					run.verderbnis = mini(Konst.VERDERBNIS_MAX, run.verderbnis + 3)
		if run.spieler.hp <= 0:
			run.vorbei = true

	return {
		"raeume": raeume, "abschnitt": run.abschnitt, "gewonnen": run.gewonnen,
		"hp": run.spieler.hp, "hp_max": run.spieler.hp_max,
		"deck": run.deck.size(), "gold": run.gold, "luck": run.luck,
		"verderbnis": run.verderbnis, "charms": run.charms.gesamt_stacks(),
		"charm_arten": run.charms.verschiedene(),
		"endlos_tiefe": run.endlos_tiefe, "statistik": run.statistik,
		"charm_liste": run.charms.stacks.duplicate(),
		"deck_stufen": _stufen(run.deck), "hp_verlauf": hp_verlauf,
		"tod_bei": tod_bei,
	}

func _stufen(deck: Array[Karte]) -> Dictionary:
	var d := {"stufe0": 0, "stufe_plus": 0, "umgekehrt": 0, "tinte": 0, "arkana": 0}
	for k in deck:
		if k.stufe > 0:
			d["stufe_plus"] = int(d["stufe_plus"]) + 1
		else:
			d["stufe0"] = int(d["stufe0"]) + 1
		if k.ist_umgekehrt():
			d["umgekehrt"] = int(d["umgekehrt"]) + 1
		if k.ist_grosse_arkana():
			d["arkana"] = int(d["arkana"]) + 1
		d["tinte"] = int(d["tinte"]) + k.tinte
	return d

# --------------------------------------------------------- Entscheidungen
func _weg_bewerten(run: Run) -> int:
	var beste: int = 0
	var bester_wert: float = -1e9
	for i in run.wegkarten.size():
		var typ: int = int(run.wegkarten[i]["typ"])
		var w: float = 0.0
		var hp_anteil: float = run.spieler.hp_anteil()
		match typ:
			Konst.Raum.KAMPF: w = 10.0
			Konst.Raum.ELITE: w = 16.0 if hp_anteil > 0.65 else -5.0
			Konst.Raum.BOSS: w = 100.0
			Konst.Raum.HAENDLER: w = 12.0 if run.gold > 90 else 4.0
			Konst.Raum.RITUAL: w = 14.0 if run.deck.size() > 11 else 8.0
			Konst.Raum.RUHE: w = 20.0 if hp_anteil < 0.5 else 3.0
			Konst.Raum.TRUHE: w = 13.0
			Konst.Raum.UNBEKANNT: w = 9.0
		if w > bester_wert:
			bester_wert = w
			beste = i
	return beste

func _belohnung_nehmen(run: Run, typ: int) -> void:
	var karten: Array[Karte] = run.belohnung_karten(3)
	# Ein gutes Deck ist ein kleines Deck: nur nehmen, was klar besser ist.
	var beste: Karte = null
	var bester: int = 0
	for k in karten:
		var s: int = Wahl.staerke(k)
		if beste == null or s > bester:
			beste = k
			bester = s
	# Frueh fast alles nehmen, spaet nur noch echte Verbesserungen: das ist
	# die Kurve, die ein normaler Spieler auch faehrt.
	var schwaechste: Karte = Wahl._extrem(run.deck, false)
	var untergrenze: int = 0 if schwaechste == null else Wahl.staerke(schwaechste)
	var deckel: int = 16
	if beste != null and run.deck.size() < deckel and bester > untergrenze:
		run.deck.append(beste)
	if typ == Konst.Raum.ELITE or typ == Konst.Raum.BOSS:
		var bonus_charm: String = run.belohnung_charm()
		if bonus_charm != "":
			run.charms.geben(bonus_charm, 1)

func _beute_waehlen(run: Run) -> String:
	# Traenken ist fast immer stark, Bannen hilft bei aufgeblaehten Decks.
	if run.deck.size() > 14:
		return "bannen"
	if run.verderbnis < 55:
		return "traenken"
	return "bannen"

func _einkaufen(run: Run) -> void:
	# Charm kaufen, wenn bezahlbar; sonst eine schwache Karte vergessen.
	var versuche: int = 0
	var charmpreis: int = run.preis(60)
	while run.gold >= charmpreis and versuche < 4:
		versuche += 1
		var cid: String = run.belohnung_charm()
		if cid == "":
			break
		if run.charms.geben(cid, 1) > 0:
			run.gold -= charmpreis
	# Aufwerten ist der wichtigste Goldsink - eine verbesserte Karte schlaegt
	# fast immer eine weitere Karte im Deck.
	var preis_aufwerten: int = run.preis(Konst.KOSTEN_AUFWERTEN)
	while run.gold >= preis_aufwerten:
		var ziel: Karte = null
		var bester_wert: int = -1
		for k in run.deck:
			if k.stufe >= Konst.STUFE_MAX:
				continue
			var w: int = Wahl.staerke(k)
			if w > bester_wert:
				bester_wert = w
				ziel = k
		if ziel == null or not run.karte_aufwerten(ziel):
			break
		run.gold -= preis_aufwerten
	var kosten: int = run.kosten_loeschen()
	if run.gold >= kosten and run.deck.size() > 9:
		var weg: Karte = Wahl._extrem(run.deck, false)
		if weg != null and run.karte_loeschen(weg):
			run.gold -= kosten

func _ritual(run: Run) -> void:
	# Vergessen, Spiegeln, Umdrehen - hier: kleines Deck schlaegt grosses.
	if run.deck.size() > 10:
		var weg: Karte = Wahl._extrem(run.deck, false)
		if weg != null:
			run.karte_loeschen(weg)
	else:
		var beste: Karte = Wahl._extrem(run.deck, true)
		if beste != null:
			run.karte_spiegeln(beste)

# ------------------------------------------------------------- Auswertung
func _auswerten(erg: Array, anzahl: int) -> void:
	var siege: int = 0
	var raeume_summe: int = 0
	var deck_summe: int = 0
	var charm_summe: int = 0
	var verderbnis_summe: int = 0
	var tinte_summe: int = 0
	var abbruch_je_abschnitt := {1: 0, 2: 0, 3: 0, 4: 0}
	var charm_haeufigkeit := {}
	var tiefste: int = 0

	for e in erg:
		if bool(e["gewonnen"]):
			siege += 1
		raeume_summe += int(e["raeume"])
		deck_summe += int(e["deck"])
		charm_summe += int(e["charms"])
		verderbnis_summe += int(e["verderbnis"])
		tinte_summe += int((e["deck_stufen"] as Dictionary)["tinte"])
		var a: int = clampi(int(e["abschnitt"]), 1, 4)
		abbruch_je_abschnitt[a] = int(abbruch_je_abschnitt[a]) + 1
		tiefste = maxi(tiefste, int(e["endlos_tiefe"]))
		for cid in (e["charm_liste"] as Dictionary).keys():
			charm_haeufigkeit[cid] = int(charm_haeufigkeit.get(cid, 0)) + 1

	var f: float = float(anzahl)
	print("Siegquote            : %.1f %% (%d von %d)" % [100.0 * float(siege) / f, siege, anzahl])
	print("Raeume im Schnitt    : %.1f" % (float(raeume_summe) / f))
	print("Deckgroesse am Ende  : %.1f Karten" % (float(deck_summe) / f))
	print("Charm-Stacks am Ende : %.1f" % (float(charm_summe) / f))
	print("Verderbnis am Ende   : %.1f" % (float(verderbnis_summe) / f))
	print("Tinte im Deck        : %.1f (Summe der Kartenstufen)" % (float(tinte_summe) / f))
	if tiefste > 0:
		print("Tiefste Spirale      : %d" % tiefste)
	print("\nRun endet in Abschnitt:")
	for a in [1, 2, 3, 4]:
		var n: int = int(abbruch_je_abschnitt[a])
		print("  Abschnitt %d: %s %d (%.0f %%)"
			% [a, "#".repeat(int(30.0 * float(n) / f)), n, 100.0 * float(n) / f])

	var tode := {}
	for e in erg:
		var t: String = String(e["tod_bei"])
		if t != "-":
			tode[t] = int(tode.get(t, 0)) + 1
	var tod_sortiert: Array = tode.keys()
	tod_sortiert.sort_custom(func(x, y): return int(tode[x]) > int(tode[y]))
	print("\nWoran die Runs sterben:")
	for i in mini(10, tod_sortiert.size()):
		var t2: String = String(tod_sortiert[i])
		print("  %-46s %3d (%.0f %%)" % [t2, int(tode[t2]), 100.0 * float(tode[t2]) / f])

	var sortiert: Array = charm_haeufigkeit.keys()
	sortiert.sort_custom(func(x, y): return int(charm_haeufigkeit[x]) > int(charm_haeufigkeit[y]))
	print("\nHaeufigste Charms:")
	for i in mini(8, sortiert.size()):
		var cid: String = String(sortiert[i])
		print("  %-24s %d Runs" % [String(katalog.charms[cid].get("name", cid)),
			int(charm_haeufigkeit[cid])])
