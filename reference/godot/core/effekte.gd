# Der Effekt-Interpreter.
#
# Karten, Charms, Items und Gegneraktionen beschreiben ihre Wirkung als Liste
# kleiner Operationen (data/*.json). Das hat drei Gruende:
#   * Balancing ohne Code-Aenderung und ohne neues Build,
#   * jede Wirkung ist automatisch simulierbar und testbar,
#   * Charms koennen Werte fremder Effekte anfassen, ohne sie zu kennen.
#
# Ops, die einen echten Spielerentscheid brauchen (welche Karte loeschen?),
# fragen die Wahlstrategie. Die UI liefert eine interaktive, die Simulation
# eine heuristische - der Kern bleibt identisch.
extends RefCounted
class_name Effekte

const Konst := preload("res://core/konst.gd")

## Ops, deren "wert" mit dem Wirkungsmodifikator skaliert.
const SKALIERT := {
	"schaden": true, "schild": true, "heilung": true, "status": true,
	"traum": true, "selbstschaden": false, "gold": false, "ziehen": false,
	"faden": false, "luck": false,
}

const ST_VON_NAME := {
	"SCHILD": Konst.St.SCHILD, "BLUTUNG": Konst.St.BLUTUNG,
	"GIFT": Konst.St.GIFT, "GLUT": Konst.St.GLUT,
	"VERWUNDBAR": Konst.St.VERWUNDBAR, "SCHWACH": Konst.St.SCHWACH,
	"STARK": Konst.St.STARK, "TRAUM": Konst.St.TRAUM,
	"VERANKERT": Konst.St.VERANKERT, "VERHUELLT": Konst.St.VERHUELLT,
	"MARKIERT": Konst.St.MARKIERT,
}

## Wendet eine Op-Liste an. kampf ist absichtlich untypisiert, damit es
## keinen Preload-Zyklus zwischen Kampf und Effekte gibt.
##
## kontext: {
##   "karte": Karte oder null,
##   "modifikator": int (Promille, 1000 = 100 %),
##   "quelle": String (fuer das Protokoll),
##   "position": int oder -1,
## }
static func anwenden(kampf, kontext: Dictionary, ops: Array) -> void:
	var modi: int = int(kontext.get("modifikator", 1000))
	var flach: Dictionary = kontext.get("flach", {})
	for op_v in ops:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_v
		var art: String = String(op.get("op", ""))
		var rohwert: int = int(op.get("wert", 0))
		var wert: int = rohwert
		if SKALIERT.get(art, false) and not bool(op.get("unskaliert", false)):
			# Flache Charm-Boni (z. B. "Schwerter +1 Schaden") liegen VOR der
			# Multiplikation - sonst waeren sie in spaeten Runs wertlos.
			var schluessel: String = art
			if art == "status":
				schluessel = "status_" + String(op.get("st", ""))
			wert = Konst.promille(rohwert + int(flach.get(schluessel, 0)), modi)
		_eine_op(kampf, kontext, art, op, wert)

static func _eine_op(kampf, kontext: Dictionary, art: String, op: Dictionary, wert: int) -> void:
	var quelle: String = String(kontext.get("quelle", "Effekt"))
	match art:
		"schaden":
			var ziele: Array = kampf.ziele_fuer(op.get("ziel", "gegner"), bool(op.get("alle", false)))
			var durchdringung: int = int(kontext.get("durchdringung", 0))
			for z in ziele:
				kampf.schaden_zufuegen(kampf.spieler, z, wert, quelle, durchdringung)
		"selbstschaden":
			kampf.protokoll("%s: %d Selbstschaden." % [quelle, wert])
			kampf.spieler.direktschaden(wert)
			kampf.ereignis("selbstschaden", {"wert": wert})
		"schild":
			kampf.spieler.gib(Konst.St.SCHILD, wert)
			kampf.protokoll("%s: +%d Schild." % [quelle, wert])
			kampf.ereignis("schild", {"wert": wert})
		"heilung":
			var alt_umleitung: String = kampf.ueberheilung_umleiten
			if op.has("ueberschuss"):
				kampf.ueberheilung_umleiten = String(op["ueberschuss"])
			kampf.heilen(wert, quelle)
			kampf.ueberheilung_umleiten = alt_umleitung
		"status":
			var st: int = int(ST_VON_NAME.get(String(op.get("st", "BLUTUNG")), Konst.St.BLUTUNG))
			var ziel_s: String = String(op.get("ziel", "gegner"))
			if ziel_s == "selbst":
				kampf.spieler.gib(st, wert)
				kampf.protokoll("%s: Spieler erhaelt %s %d." % [quelle, Konst.ST_NAME[st], wert])
			else:
				for z in kampf.ziele_fuer(ziel_s, bool(op.get("alle", false))):
					z.gib(st, wert)
					kampf.protokoll("%s: %s erhaelt %s %d." % [quelle, z.name, Konst.ST_NAME[st], wert])
			kampf.ereignis("status_gegeben", {"st": st, "wert": wert})
		"traum":
			kampf.spieler.gib(Konst.St.TRAUM, wert)
			kampf.protokoll("%s: +%d Traum." % [quelle, wert])
		"gold":
			kampf.gold_gewinn += wert
			kampf.protokoll("%s: +%d Gold." % [quelle, wert])
		"ziehen":
			var gez: Array = kampf.stapel.ziehen(wert)
			kampf.protokoll("%s: %d Karte(n) gezogen." % [quelle, gez.size()])
		"ablegen_zufaellig":
			for _i in wert:
				if kampf.stapel.hand.is_empty():
					break
				var k = kampf.rng.waehle(kampf.stapel.hand)
				kampf.stapel.ablegen(k)
				kampf.ereignis("abgelegt", {"karte": k})
		"faden":
			kampf.faden_geben(wert, quelle)
		"luck":
			kampf.luck_gewinn += wert
			kampf.protokoll("%s: +%d Luck." % [quelle, wert])
		"debuff_weg":
			var n: int = kampf.spieler.debuffs_entfernen(wert)
			kampf.protokoll("%s: %d Debuff(s) entfernt." % [quelle, n])
			kampf.letzte_debuffs_entfernt = n
		"debuff_uebertragen":
			kampf.debuff_uebertragen()
		"schild_brechen":
			kampf.schild_brechen(bool(op.get("als_schaden", false)), quelle)
		"vernichten_hand":
			for _i in maxi(1, wert):
				var k = kampf.wahl.handkarte(kampf, "vernichten")
				if k == null:
					break
				kampf.stapel.vernichten(k)
				kampf.protokoll("%s: %s vernichtet." % [quelle, k.anzeigename()])
		"karte_loeschen_permanent":
			kampf.permanent_loeschen_vormerken(maxi(1, wert))
		"karte_aufwerten_permanent":
			kampf.permanent_aufwerten_vormerken(maxi(1, wert), bool(op.get("zufall", false)))
		"aufwerten_kampf":
			var k2 = kampf.wahl.handkarte(kampf, "aufwerten")
			if k2 != null:
				k2.aufwerten(maxi(1, wert))
				kampf.protokoll("%s: %s aufgewertet." % [quelle, k2.anzeigename()])
		"basiswert_verdoppeln":
			var k3 = kampf.wahl.handkarte(kampf, "verdoppeln")
			if k3 != null:
				kampf.basis_verdoppelt[k3.id] = true
				kampf.protokoll("%s: Basiswert von %s verdoppelt." % [quelle, k3.anzeigename()])
		"kopie_hand":
			var k4 = kampf.wahl.handkarte(kampf, "kopieren")
			if k4 != null:
				var kop: Karte = k4.kopie()
				kop.fluechtig = true
				kampf.stapel.in_hand(kop)
				kampf.ereignis("kopie_erzeugt", {"karte": kop})
				kampf.protokoll("%s: %s kopiert." % [quelle, kop.anzeigename()])
		"wiederholen_letzte":
			kampf.letzte_karte_wiederholen(int(op.get("anteil", 1000)), quelle)
		"spaehen":
			var oben: Array = kampf.stapel.spaehen(wert)
			kampf.wahl.stapel_ordnen(kampf, oben)
			kampf.protokoll("%s: %d Karten des Ziehstapels geordnet." % [quelle, oben.size()])
		"absicht_zeigen":
			kampf.sicht_absichten = maxi(kampf.sicht_absichten, maxi(1, wert))
			kampf.protokoll("%s: %d Absichten offengelegt." % [quelle, kampf.sicht_absichten])
		"absicht_verbergen":
			for z in kampf.gegner:
				z.gib(Konst.St.VERHUELLT, maxi(1, wert))
		"zukunft_bonus":
			kampf.bonus_zukunft += int(op.get("prozent", 50)) * 10
			kampf.bonus_zukunft_runden = maxi(kampf.bonus_zukunft_runden, maxi(1, wert))
		"umgekehrt_bonus":
			kampf.bonus_umgekehrt += int(op.get("prozent", 50)) * 10
			kampf.bonus_umgekehrt_runden = maxi(kampf.bonus_umgekehrt_runden, maxi(1, wert))
		"naechste_karten_bonus":
			kampf.bonus_naechste += int(op.get("prozent", 50)) * 10
			kampf.bonus_naechste_anzahl += maxi(1, wert)
			if op.has("farben"):
				kampf.bonus_naechste_farben = op["farben"]
			if bool(op.get("nur_umgekehrt", false)):
				kampf.bonus_naechste_nur_umgekehrt = true
		"extra_legung":
			kampf.extra_legungen += maxi(1, wert)
			kampf.protokoll("%s: +%d Kartenaktion." % [quelle, wert])
		"legungen_naechster_zug":
			kampf.legungen_naechster_zug = wert
		"zug_beenden":
			kampf.zug_sofort_beenden = true
		"hand_ersetzen":
			var n2: int = kampf.stapel.hand_ablegen()
			kampf.stapel.ziehen(n2)
			kampf.bonus_naechste += int(op.get("prozent", 25)) * 10
			kampf.bonus_naechste_anzahl += n2
		"binden":
			kampf.karten_binden(int(op.get("anteil", 500)))
		"zurueckholen":
			kampf.karten_zurueckholen(maxi(1, wert), bool(op.get("aus_vernichtet", false)))
		"gegner_absicht_neu":
			kampf.absichten_neu_wuerfeln()
		"markieren":
			var k5 = kampf.wahl.handkarte(kampf, "markieren")
			if k5 != null:
				k5.markiert = true
		"spezial":
			Spezial.ausfuehren(kampf, kontext, String(op.get("id", "")), op)
		_:
			kampf.protokoll("[WARNUNG] Unbekannte Op: %s" % art)

# ------------------------------------------------------------------------
# Spezialeffekte, die sich nicht sinnvoll als Daten ausdruecken lassen.
# Bewusst wenige - alles andere gehoert in die Op-Liste.
class Spezial:
	static func ausfuehren(kampf, kontext: Dictionary, id: String, op: Dictionary) -> void:
		match id:
			"welt_vier_farben":
				# XXI Die Welt (aufrecht): nur wenn alle vier Farben in diesem
				# Kampf gespielt wurden.
				if kampf.farben_gespielt.size() >= 4:
					Effekte.anwenden(kampf, kontext, op.get("dann", []))
				else:
					kampf.protokoll("Die Welt bleibt stumm - noch nicht alle Farben gespielt.")
			"welt_perfekte_hand":
				# XXI umgekehrt: Deck neu zusammensetzen, Hand aus vier Farben.
				kampf.stapel.hand_ablegen()
				kampf.perfekte_hand_ziehen()
			"kraft_naechster_angriff":
				kampf.naechste_angriffe_bonus += int(op.get("prozent", 100)) * 10
				kampf.naechste_angriffe_anzahl += maxi(1, int(op.get("wert", 1)))
			"teufel_fluch":
				kampf.fluch_vormerken(maxi(1, int(op.get("wert", 1))))
			"maessigkeit_mischen":
				kampf.effekte_mischen(int(op.get("anteil", 1000)), int(op.get("ausloesungen", 1)))
			"eremit_tausch":
				var n: int = maxi(1, int(op.get("entfernen", 1)))
				for _i in n:
					var k = kampf.wahl.handkarte(kampf, "verbannen")
					if k != null:
						kampf.stapel.vernichten(k)
				kampf.stapel.ziehen(maxi(1, int(op.get("ziehen", 2))))
			"rad_waehlen":
				kampf.rad_waehlen(maxi(1, int(op.get("wert", 3))))
			"gerechtigkeit_schaden":
				var n: int = kampf.letzte_debuffs_entfernt
				if n > 0:
					for z in kampf.ziele_fuer("gegner", false):
						kampf.schaden_zufuegen(kampf.spieler, z,
							n * int(op.get("wert", 4)), "Gerechtigkeit")
			"turm_schild_null":
				kampf.spieler.setze(Effekte.Konst.St.SCHILD, 0)
				kampf.protokoll("Der Turm reisst dein Schild nieder.")
			"muenze_rueckschlag":
				kampf.muenze_rueckschlag = int(op.get("wert", 0))
			"priesterin_beste_von_drei":
				kampf.priesterin_beste_von_drei(int(op.get("wert", 3)))
			"schicksal_alles_nochmal":
				kampf.protokoll("DAS SCHICKSAL: alles geschieht noch einmal.")
				kampf.letzte_karte_wiederholen(1000, "Das Schicksal")
			"schicksal_preis":
				kampf.spieler.hp = maxi(1, int(kampf.spieler.hp / 2))
				kampf.perfekte_hand_ziehen()
			"gegner_zug_ueberspringen":
				kampf.gegner_zug_ueberspringen = true
			"gericht_wiederholen":
				kampf.karten_zurueckholen(maxi(1, int(op.get("wert", 2))), false)
			"ueberheilung_zu_schild":
				kampf.ueberheilung_umleiten = "schild"
			"ueberheilung_zu_maxhp":
				kampf.ueberheilung_umleiten = "maxhp"
			"hierophant_erschoepfen":
				kampf.naechste_karte_erschoepft = true
			_:
				kampf.protokoll("[WARNUNG] Unbekannter Spezialeffekt: %s" % id)
