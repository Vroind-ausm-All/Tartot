class_name DemoWertung
extends RefCounted
## Rechnet eine Legung fuer die Vorfuehrung - in Schritten, wie sie die
## Kaskade abspielt.
##
## ACHTUNG: Das ist ein Spiegel der wichtigsten Regeln aus
## CombatSystem.CalculateScore (Tartot.Core), nicht das Spiel selbst. Im Spiel
## kommen die Schritte fertig aus ScoreBreakdown.Steps - dieselbe Form:
## {id, label, chips, mult, xmult, edition}. Ohne Level, Charms, Kette,
## Schimmer und Pakt.

const POSITION_MULT := [0.0, 0.15, 0.10]   # Vergangenheit, Gegenwart, Zukunft


static func rechnen(legung: Dictionary) -> Dictionary:
	var schritte: Array = []
	var chips := 0
	var mult := 1.0
	var faktor := 1.0
	var karten: Array = []
	for platz in legung.keys():
		var karte: TarotKarte = legung[platz]
		karten.append(karte)
		var rang := int(karte.daten.get("rank", 1))
		var ed := KartenDaten.edition(karte.edition) if karte.edition != "" else {}
		var c := rang + int(ed.get("chips", 0))
		var m := float(ed.get("mult", 0.0))
		var x := float(ed.get("xmult", 1.0))
		chips += c
		mult += m
		faktor *= x
		schritte.append({"id": karte.get_instance_id(), "label": karte.daten.get("name", ""),
			"chips": c, "mult": m, "xmult": x, "edition": karte.edition})

	var muster_chips := 0
	var muster_mult := 0.0
	var teile: Array[String] = []
	for platz in legung.keys():
		muster_mult += POSITION_MULT[platz]
	var werte: Array = karten.map(func(k): return int(k.daten.get("rank", 1)))
	werte.sort()
	var farben: Array = karten.map(func(k): return str(k.daten.get("suit", "")))
	var summe := 0
	for w in werte:
		summe += w
	var grosse := farben.count("Major")
	if summe == 21:
		muster_mult += 2.1
		muster_chips += 21
		teile.append("DIE WELT 21")
	if werte.size() == 3 and werte[1] == werte[0] + 1 and werte[2] == werte[1] + 1:
		muster_mult += 0.75
		muster_chips += 8
		teile.append("Folge")
	if karten.size() == 3 and farben.count(farben[0]) == 3:
		muster_mult += 0.65
		muster_chips += 10
		teile.append("Resonanz")
	var gleich := 1
	for w in werte:
		gleich = max(gleich, werte.count(w))
	if gleich == 3:
		muster_mult += 1.0
		muster_chips += 12
		teile.append("Dreiklang")
	elif gleich == 2:
		muster_mult += 0.5
		muster_chips += 5
		teile.append("Paar")
	if karten.size() == 3 and _verschieden(farben) == 3:
		muster_mult += 0.35
		teile.append("Drei Pfade")
	if grosse >= 2:
		muster_mult += 0.6 + (grosse - 2) * 0.25
		teile.append("Großes Omen")

	var name := " + ".join(teile) if teile.size() > 0 else ("Dreier-Legung" if karten.size() == 3 else "Offene Legung")
	if muster_chips > 0 or muster_mult > 0.0:
		schritte.append({"id": 0, "label": name, "chips": muster_chips, "mult": muster_mult, "xmult": 1.0, "edition": ""})
	chips += muster_chips
	mult += muster_mult
	mult *= faktor
	return {"schritte": schritte, "chips": chips, "mult": mult, "schicksal": maxi(1, roundi(chips * mult)), "muster": name}


static func _verschieden(liste: Array) -> int:
	var gesehen := {}
	for x in liste:
		gesehen[x] = true
	return gesehen.size()
