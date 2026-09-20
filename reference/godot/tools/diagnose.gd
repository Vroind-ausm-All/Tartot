# Diagnose: wo genau bricht ein Run ab? Druckt Raum fuer Raum.
#   godot --headless --path . --script tools/diagnose.gd -- --seed=1000
extends SceneTree

const Konst := preload("res://core/konst.gd")

func _initialize() -> void:
	var seed_wert: int = 1000
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--seed="):
			seed_wert = int(String(a).split("=")[1])
	var kat := Katalog.new()
	kat.laden()
	var pilot := Autopilot.new()
	var run := Run.neu(kat, "wahrsagerin", seed_wert)
	var wahl := Wahl.new()
	print("Start: %d HP, %d Karten, %d Gold" % [run.spieler.hp, run.deck.size(), run.gold])
	var raum: int = 0
	while not run.vorbei and raum < 60:
		raum += 1
		run.wegkarten_ziehen()
		var typ: int = run.weg_waehlen(_weg(run))
		var zeile: String = "R%02d A%d %-9s" % [raum, run.abschnitt, Konst.RAUM_NAME[typ]]
		match typ:
			Konst.Raum.KAMPF, Konst.Raum.ELITE, Konst.Raum.BOSS:
				var kf := run.kampf_starten(wahl)
				var gegner_hp: int = 0
				for g in kf.gegner:
					gegner_hp += g.hp_max
				var runden: int = pilot.kampf_spielen(kf)
				var erg: Dictionary = run.kampf_beenden(kf)
				zeile += " %-28s %3d HP | %2d Runden | %s" % [
					kf.gegner_namen().substr(0, 28), gegner_hp, runden,
					"Sieg" if bool(erg.get("gewonnen", false)) else "TOD"]
				zeile += " | Spieler %d/%d" % [run.spieler.hp, run.spieler.hp_max]
				print(zeile)
				if not bool(erg.get("gewonnen", false)):
					break
				_belohnung(run, typ)
				if erg.has("beute"):
					run.beute_waehlen("traenken")
					if run.gewonnen:
						print("  >>> Abschnitt geschafft.")
						break
				continue
			Konst.Raum.RUHE:
				var g2: int = run.spieler.heilen(int(float(run.spieler.hp_max) * 0.3))
				zeile += " +%d HP -> %d/%d" % [g2, run.spieler.hp, run.spieler.hp_max]
			Konst.Raum.HAENDLER:
				zeile += " Gold %d" % run.gold
			_:
				pass
		zeile += " | Deck %d, Charms %d, HP %d/%d" % [
			run.deck.size(), run.charms.gesamt_stacks(), run.spieler.hp, run.spieler.hp_max]
		print(zeile)
	print("\nEnde: Abschnitt %d, Raum %d, Deck %d, Charms %d, Gold %d, Verderbnis %d"
		% [run.abschnitt, run.raum_nr, run.deck.size(), run.charms.gesamt_stacks(),
		   run.gold, run.verderbnis])
	quit(0)

func _weg(run: Run) -> int:
	var beste: int = 0
	var bw: float = -1e9
	for i in run.wegkarten.size():
		var typ: int = int(run.wegkarten[i]["typ"])
		var hp: float = run.spieler.hp_anteil()
		var w: float = 0.0
		match typ:
			Konst.Raum.KAMPF: w = 10.0
			Konst.Raum.ELITE: w = 16.0 if hp > 0.65 else -5.0
			Konst.Raum.BOSS: w = 100.0
			Konst.Raum.HAENDLER: w = 12.0 if run.gold > 90 else 4.0
			Konst.Raum.RITUAL: w = 14.0 if run.deck.size() > 11 else 8.0
			Konst.Raum.RUHE: w = 20.0 if hp < 0.5 else 3.0
			Konst.Raum.TRUHE: w = 13.0
			Konst.Raum.UNBEKANNT: w = 9.0
		if w > bw:
			bw = w
			beste = i
	return beste

func _belohnung(run: Run, typ: int) -> void:
	var karten: Array[Karte] = run.belohnung_karten(3)
	var beste: Karte = null
	var bester: int = -1
	for k in karten:
		var s: int = Wahl.staerke(k)
		if s > bester:
			bester = s
			beste = k
	var schwaechste: Karte = Wahl._extrem(run.deck, false)
	if beste != null and run.deck.size() < 16 and bester > Wahl.staerke(schwaechste):
		run.deck.append(beste)
	if typ == Konst.Raum.ELITE or typ == Konst.Raum.BOSS:
		var bonus_charm: String = run.belohnung_charm()
		if bonus_charm != "":
			run.charms.geben(bonus_charm, 1)
