# Ein Run: vom ersten Raum bis zum Tod oder tief in die Schwarze Spirale.
#
# Statt einer Landkarte zieht der Spieler nach jedem Raum drei Schicksalskarten
# und waehlt seinen Weg. Das passt zum Thema und spart auf dem Handy eine
# Menge Scrollerei.
extends RefCounted
class_name Run

const Konst := preload("res://core/konst.gd")

var katalog: Katalog
var rng: TRng
var rng_weg: TRng
var rng_belohnung: TRng
var seed_wert: int = 0

# --------------------------------------------------------------- Charakter
var deuter_id: String = "wahrsagerin"
var deuter_regel: String = ""
var spieler: Kaempfer
var deck: Array[Karte] = []
var charms: Charmbeutel
var items: Dictionary = {}           # item_id -> Ladungen

# ------------------------------------------------------------- Ressourcen
var gold: int = 0
var luck: int = 0
var verderbnis: int = 0

# -------------------------------------------------------------- Fortschritt
var abschnitt: int = 1
var raum_nr: int = 0
var raum_typ: int = Konst.Raum.KAMPF
var wegkarten: Array = []            # aktuelle Auswahl
var endlos: bool = false
var endlos_tiefe: int = 0
var verderbte_arkana: Array[String] = []
var run_regeln: Dictionary = {}
var fruehere_bossregeln: Array[String] = []
var besiegte_bosse: Array[String] = []

# ---------------------------------------------------------------- Zaehler
var geloescht_anzahl: int = 0
var reroll_genutzt: int = 0
var seit_haendler: int = 0
var seit_rast: int = 0
var vorbei: bool = false
var gewonnen: bool = false
var statistik: Dictionary = {
	"kaempfe": 0, "elite": 0, "bosse": 0, "schaden_gesamt": 0,
	"karten_gelegt": 0, "muster": 0, "hoechster_zug": 0, "runden": 0,
}

var letzter_kampf: Kampf = null
var log: Array[String] = []

# ------------------------------------------------------------------ Aufbau
static func neu(p_katalog: Katalog, p_deuter: String, p_seed: int = 0,
		p_endlos: bool = false) -> Run:
	var r := Run.new()
	r.katalog = p_katalog
	r.seed_wert = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	r.rng = TRng.new(r.seed_wert)
	# Getrennte Stroeme: ein Reroll im Laden darf die Kampf-Zuege nicht verschieben.
	r.rng_weg = r.rng.strom("weg")
	r.rng_belohnung = r.rng.strom("belohnung")
	r.deuter_id = p_deuter
	r.endlos = p_endlos
	r._deuter_aufbauen()
	r.wegkarten_ziehen()
	return r

func _deuter_aufbauen() -> void:
	var d: Dictionary = katalog.deuter.get(deuter_id, {})
	if d.is_empty():
		push_warning("Unbekannter Deuter: %s" % deuter_id)
		d = katalog.deuter.get("wahrsagerin", {})
	spieler = Kaempfer.neu(String(d.get("name", "Deuter")), int(d.get("hp", Konst.SPIELER_HP_START)), true)
	gold = int(d.get("gold", Konst.GOLD_START))
	deuter_regel = String(d.get("regel", ""))
	verderbnis = int(d.get("verderbnis_start", 0))
	charms = Charmbeutel.new(katalog)
	for cid in d.get("start_charms", []):
		charms.geben(String(cid), 1)
	for vid in d.get("deck", []):
		deck.append(katalog.karte(String(vid)))
	protokoll("Run beginnt: %s (Seed %d)" % [String(d.get("name", "")), seed_wert])

func faden_start() -> int:
	return int(katalog.deuter.get(deuter_id, {}).get("faden_start", Konst.FADEN_START))

# =============================================================== Wegwahl
## Zieht drei Schicksalskarten: der Spieler waehlt, wohin der Weg fuehrt.
func wegkarten_ziehen() -> Array:
	wegkarten.clear()
	if _ist_bossraum():
		wegkarten.append({"typ": Konst.Raum.BOSS, "name": "Das Omen",
			"text": "Es wartet schon."})
		return wegkarten
	var pool: Array[int] = [Konst.Raum.KAMPF, Konst.Raum.KAMPF, Konst.Raum.KAMPF,
		Konst.Raum.ELITE, Konst.Raum.HAENDLER, Konst.Raum.RITUAL,
		Konst.Raum.UNBEKANNT, Konst.Raum.TRUHE, Konst.Raum.RUHE]
	# Fruehe Raeume sind milder, spaete haerter.
	if raum_nr < 2:
		pool.erase(Konst.Raum.ELITE)
	# Zwei Elites hintereinander sind kein Schicksal, sondern schlechtes Design.
	if raum_typ == Konst.Raum.ELITE:
		pool.erase(Konst.Raum.ELITE)
	var gezogen: Array = rng_weg.waehle_mehrere(pool, 3)
	# Grundversorgung: ohne Haendler kann niemand ein Deck bauen, ohne Rast
	# niemand einen Bossfehler ueberleben. Beides wird erzwungen, wenn es
	# zu lange her ist - der Spieler darf es trotzdem ignorieren.
	if seit_haendler >= 4 and not gezogen.has(Konst.Raum.HAENDLER):
		gezogen[0] = Konst.Raum.HAENDLER
	if seit_rast >= 6 and not gezogen.has(Konst.Raum.RUHE):
		gezogen[gezogen.size() - 1] = Konst.Raum.RUHE
	for t in gezogen:
		wegkarten.append({"typ": int(t), "name": Konst.RAUM_NAME[int(t)],
			"text": _weg_text(int(t))})
	return wegkarten

func _weg_text(typ: int) -> String:
	match typ:
		Konst.Raum.KAMPF: return "Etwas wartet. Es hat schon gewartet."
		Konst.Raum.ELITE: return "Groesser. Geduldiger. Es weiss deinen Namen."
		Konst.Raum.HAENDLER: return "Ein Mantel oeffnet sich. Darin haengt zu viel."
		Konst.Raum.RITUAL: return "Vergessen, Spiegeln, Umdrehen."
		Konst.Raum.UNBEKANNT: return "Die Karte liegt verdeckt."
		Konst.Raum.TRUHE: return "Ein Kasten ohne Schloss - und ohne Deckel."
		Konst.Raum.RUHE: return "Kurz nichts. Das ist selten."
		Konst.Raum.BOSS: return "Es wartet schon."
	return ""

func _ist_bossraum() -> bool:
	if endlos:
		return raum_nr > 0 and raum_nr % Konst.RAEUME_PRO_ABSCHNITT == 0
	return raum_nr >= Konst.RAEUME_PRO_ABSCHNITT - 1

## Betritt den gewaehlten Weg. Gibt den Raumtyp zurueck.
func weg_waehlen(index: int) -> int:
	if index < 0 or index >= wegkarten.size():
		index = 0
	raum_typ = int(wegkarten[index]["typ"])
	raum_nr += 1
	seit_haendler = 0 if raum_typ == Konst.Raum.HAENDLER else seit_haendler + 1
	seit_rast = 0 if raum_typ == Konst.Raum.RUHE else seit_rast + 1
	protokoll("Raum %d: %s" % [raum_nr, Konst.RAUM_NAME[raum_typ]])
	if endlos and raum_nr % Konst.ENDLOS_ARKANUM_INTERVALL == 0:
		_verderbtes_arkanum_ziehen()
	return raum_typ

# =============================================================== Kampf
func gegner_fuer_raum() -> Array:
	var stufe: int = mini(3, abschnitt)
	match raum_typ:
		Konst.Raum.ELITE:
			var e: Array[String] = katalog.gegner_nach("ELITE", stufe)
			if e.is_empty():
				e = katalog.gegner_nach("ELITE", 1)
			return [rng.waehle(e)]
		Konst.Raum.BOSS:
			return [_boss_waehlen()]
		_:
			var n: Array[String] = katalog.gegner_nach("NORMAL", stufe)
			if n.is_empty():
				n = katalog.gegner_nach("NORMAL", 1)
			# Ab Abschnitt 2 treten schwache Gegner zu zweit auf.
			if abschnitt >= 2 and rng.chance(0.3):
				return [rng.waehle(n), rng.waehle(n)]
			return [rng.waehle(n)]

func _boss_waehlen() -> String:
	var kandidaten: Array[String] = []
	for id in katalog.gegner.keys():
		var g: Dictionary = katalog.gegner[id]
		if String(g.get("typ", "")) != "BOSS":
			continue
		if besiegte_bosse.has(id) and not endlos:
			continue
		kandidaten.append(String(id))
	if kandidaten.is_empty():
		kandidaten = ["boss_turm"]
	kandidaten.sort()
	# Im Endlosmodus steigt die Stufe, also der spaetere Boss.
	if endlos:
		return String(kandidaten[endlos_tiefe % kandidaten.size()])
	var passend: Array[String] = []
	for id in kandidaten:
		if int(katalog.gegner[id].get("abschnitt", 1)) == abschnitt:
			passend.append(id)
	return String(rng.waehle(passend)) if not passend.is_empty() else String(kandidaten[0])

func kampf_starten(wahl_strategie: Wahl = null) -> Kampf:
	var gegner_ids: Array = gegner_fuer_raum()
	var opt := {
		"verderbnis": verderbnis, "luck": luck, "deuter_regel": deuter_regel,
		"run_regeln": _run_regeln_gesamt(), "faden_start": faden_start(),
		"gegner_hp_faktor": _gegner_hp_faktor(),
	}
	var kf := Kampf.neu(katalog, rng, spieler, deck, charms, gegner_ids,
		wahl_strategie if wahl_strategie != null else Wahl.new(), opt)
	kf.starten()
	letzter_kampf = kf
	return kf

func _gegner_hp_faktor() -> float:
	var f: float = 1.0
	# Giermotte: mehr Gold, dickere Gegner.
	f += float(charms.regelwert("giermotte")) * 0.003
	f += float(run_regeln.get("gegner_hp_prozent", 0)) / 100.0
	if endlos:
		# Superexponentiell, damit auch absurde Builds irgendwann scheitern.
		f *= pow(1.19, float(endlos_tiefe)) * (1.0 + 0.012 * float(endlos_tiefe * endlos_tiefe))
	else:
		f *= 1.0 + 0.06 * float(abschnitt - 1)
	return f

func _run_regeln_gesamt() -> Dictionary:
	var d: Dictionary = run_regeln.duplicate(true)
	d["fruehere_bossregeln"] = fruehere_bossregeln
	return d

## Nach dem Kampf: Ressourcen verbuchen, Nachwirkungen aufloesen.
func kampf_beenden(kf: Kampf) -> Dictionary:
	statistik["runden"] = int(statistik["runden"]) + kf.runde
	statistik["karten_gelegt"] = int(statistik["karten_gelegt"]) + kf.karten_gelegt_gesamt
	spieler.kampf_status_loeschen()
	if not kf.gewonnen():
		vorbei = true
		gewonnen = false
		protokoll("Der Run endet in Raum %d." % raum_nr)
		return {"gewonnen": false}

	match raum_typ:
		Konst.Raum.ELITE: statistik["elite"] = int(statistik["elite"]) + 1
		Konst.Raum.BOSS: statistik["bosse"] = int(statistik["bosse"]) + 1
		_: statistik["kaempfe"] = int(statistik["kaempfe"]) + 1

	var gold_bereich: Array = _gold_bereich()
	var verdient: int = rng_belohnung.int_zwischen(int(gold_bereich[0]), int(gold_bereich[1]))
	verdient += kf.gold_gewinn
	gold = maxi(0, gold + verdient)
	luck += kf.luck_gewinn
	# Der Kampf startet mit der Verderbnis des Runs und kann sie nur erhoehen
	# (Pakte, Fluechte, Heilung unter dem Teufel).
	verderbnis = clampi(kf.verderbnis, 0, Konst.VERDERBNIS_MAX)

	# Nachwirkungen: Fluchkarten, Markierungen, Der Tod.
	for _i in kf.fluch_anzahl:
		_fluchkarte_hinzufuegen()
	for _i in kf.permanent_loeschen:
		var weg: Karte = Wahl._extrem(deck, false)
		if weg != null and deck.size() > Konst.DECK_MIN_GROESSE:
			karte_loeschen(weg)
	for _i in kf.permanent_aufwerten:
		var k: Karte = rng_belohnung.waehle(deck)
		if k != null:
			k.aufwerten(1)

	# Verdunkelung: jeder Sieg faerbt das Deck ein Stueck weiter ein.
	_verduesterung(1 if raum_typ == Konst.Raum.KAMPF else 2)

	var ergebnis_charms: Array[String] = []
	# Charms sind der Build. Sie muessen haeufig genug fallen, damit ein Run
	# ueberhaupt eine Identitaet bekommt - Ziel sind rund 20 Drops pro Run.
	ergebnis_charms = charm_drops()

	var ergebnis := {"gewonnen": true, "gold": verdient, "charms": ergebnis_charms}
	if raum_typ == Konst.Raum.BOSS:
		var bid: String = String(kf.gegner_def[0].get("id", ""))
		if bid == "":
			for id in katalog.gegner.keys():
				if String(katalog.gegner[id].get("name", "")) == kf.gegner[0].name:
					bid = String(id)
		besiegte_bosse.append(bid)
		for r in kf.gegner_regeln:
			var rid: String = String(r.get("id", ""))
			if not fruehere_bossregeln.has(rid):
				fruehere_bossregeln.append(rid)
		verderbnis = mini(Konst.VERDERBNIS_MAX, verderbnis + 6)
		ergebnis["beute"] = beute_optionen(bid)
		_abschnitt_weiter()
	protokoll("Sieg. +%d Gold (gesamt %d)." % [verdient, gold])
	return ergebnis

func _gold_bereich() -> Array:
	match raum_typ:
		Konst.Raum.ELITE: return Konst.GOLD_ELITE
		Konst.Raum.BOSS: return Konst.GOLD_BOSS
		_: return Konst.GOLD_KAMPF

func _abschnitt_weiter() -> void:
	if endlos:
		endlos_tiefe += 1
		protokoll("Die Schwarze Spirale: Tiefe %d." % endlos_tiefe)
		return
	abschnitt += 1
	raum_nr = 0
	charms.haken(letzter_kampf, "abschnitt_start", {}) if letzter_kampf != null else null
	if abschnitt > Konst.ABSCHNITTE_STORY:
		gewonnen = true
		protokoll("DIE WELT IST NICHT DAS ENDE.")

## Nach dem Storyboss: in den Endlosmodus wechseln.
func endlos_beginnen() -> void:
	endlos = true
	endlos_tiefe = 0
	raum_nr = 0
	gewonnen = false
	vorbei = false
	protokoll("XXII - Das Schicksal. Die Schwarze Spirale oeffnet sich.")

func _verderbtes_arkanum_ziehen() -> void:
	var pool: Array[String] = []
	for id in katalog.grosse.keys():
		if not verderbte_arkana.has(id) and int(katalog.grosse[id].get("nr", 0)) != 22:
			pool.append(String(id))
	if pool.is_empty():
		return
	pool.sort()
	var id: String = String(rng.waehle(pool))
	verderbte_arkana.append(id)
	var d: Dictionary = katalog.grosse[id]
	for schluessel in (d.get("verderbt", {}) as Dictionary).keys():
		run_regeln[schluessel] = (d["verderbt"] as Dictionary)[schluessel]
	verderbnis = mini(Konst.VERDERBNIS_MAX, verderbnis + 8)
	protokoll("VERDERBTES ARKANUM: %s - %s"
		% [String(d.get("name", id)), String(d.get("verderbt_text", ""))])

# =========================================================== Verdunkelung
## Je weiter der Run, desto dunkler das eigene Deck. Tinte ist sichtbar
## (Kartenfarbe) und spuerbar (flacher Bonus, staerkere umgekehrte Seite).
func _verduesterung(n: int) -> void:
	var kandidaten: Array[Karte] = []
	for k in deck:
		if k.tinte < 5:
			kandidaten.append(k)
	if kandidaten.is_empty():
		return
	for _i in n:
		var k: Karte = rng_belohnung.waehle(kandidaten)
		if k == null:
			break
		k.tinte += 1
		kandidaten.erase(k)

## Beute nach einem Boss: drei Wege, mit dem Omen umzugehen.
func beute_optionen(boss_id: String) -> Array:
	var arkanum: String = _arkanum_zu_boss(boss_id)
	return [
		{"id": "traenken", "name": "TRAENKEN",
		 "text": "Salbe drei Karten mit der Tinte des Omens: +1 Stufe, dafuer dunkler."},
		{"id": "binden", "name": "BINDEN",
		 "text": "Nimm das Omen als Grosses Arkanum ins Deck. Es bringt seinen Fluch mit.",
		 "arkanum": arkanum},
		{"id": "bannen", "name": "BANNEN",
		 "text": "Verbanne es: +40 Gold und loesche zwei Karten deines Decks."},
	]

func beute_waehlen(id: String, ziele: Array[Karte] = []) -> void:
	match id:
		"traenken":
			var liste: Array[Karte] = ziele
			if liste.is_empty():
				liste = rng_belohnung.waehle_mehrere(deck, 3)
			for k in liste:
				k.aufwerten(1)
			verderbnis = mini(Konst.VERDERBNIS_MAX, verderbnis + 4)
			protokoll("Getraenkt: %d Karten sind staerker und dunkler." % liste.size())
		"binden":
			var arkanum: String = _arkanum_zu_boss(besiegte_bosse[-1] if not besiegte_bosse.is_empty() else "")
			if arkanum != "":
				deck.append(katalog.karte(arkanum))
				_fluchkarte_hinzufuegen()
				protokoll("Gebunden: %s liegt jetzt in deinem Deck."
					% String(katalog.grosse[arkanum].get("name", arkanum)))
		"bannen":
			gold += 40
			for _i in 2:
				var weg: Karte = Wahl._extrem(deck, false)
				if weg != null and deck.size() > Konst.DECK_MIN_GROESSE:
					karte_loeschen(weg)
			protokoll("Gebannt: +40 Gold, zwei Karten weniger.")

func _arkanum_zu_boss(boss_id: String) -> String:
	match boss_id:
		"boss_turm": return "arkana_16"
		"boss_mond": return "arkana_18"
		"boss_tod": return "arkana_13"
		"boss_teufel": return "arkana_15"
		"boss_rad": return "arkana_10"
		"boss_gehaengter": return "arkana_12"
		"boss_welt": return "arkana_21"
	return ""

func _fluchkarte_hinzufuegen() -> void:
	var k := katalog.karte("schwerter_01")
	k.ist_fluch = true
	k.tinte = 5
	k.vorlage = "schwerter_01"
	deck.append(k)
	protokoll("Eine Fluchkarte verstopft dein Deck.")

# ============================================================ Deckbauen
func karte_loeschen(k: Karte) -> bool:
	if deck.size() <= Konst.DECK_MIN_GROESSE:
		return false
	var i: int = deck.find(k)
	if i < 0:
		return false
	deck.remove_at(i)
	geloescht_anzahl += 1
	var lr: int = charms.regelwert("leerer_rahmen")
	if lr > 0:
		spieler.hp_max += lr
		spieler.hp += lr
	protokoll("Vergessen: %s ist fort." % k.anzeigename())
	return true

func kosten_loeschen() -> int:
	var i: int = mini(geloescht_anzahl, Konst.KOSTEN_VERGESSEN.size() - 1)
	var basis: int = Konst.KOSTEN_VERGESSEN[i]
	if deuter_regel == "schild_rest_20":
		basis *= 2   # Der Buchhalter trennt sich ungern.
	var rabatt: int = charms.regelwert("rabatt_loeschen") + charms.regelwert("rabatt_laden")
	return maxi(1, Konst.promille(basis, 1000 - rabatt * 10))

func karte_spiegeln(k: Karte) -> Karte:
	var kop: Karte = k.kopie()
	deck.append(kop)
	protokoll("Gespiegelt: %s liegt jetzt zweimal im Deck." % k.anzeigename())
	return kop

func karte_umdrehen(k: Karte) -> void:
	k.drehen()
	protokoll("Umgedreht: %s." % k.anzeigename())

func karte_aufwerten(k: Karte) -> bool:
	return k.aufwerten(1)

func preis(basis: int) -> int:
	var rabatt: int = charms.regelwert("rabatt_laden")
	return maxi(1, Konst.promille(basis, 1000 - rabatt * 10))

# ============================================================ Belohnungen
## Drei Kartenoptionen nach einem Kampf. Luck macht sie sichtbar besser.
func belohnung_karten(n: int = 3) -> Array[Karte]:
	var extra: int = int(charms.regelwert("wuerfel") / 2)
	var anzahl: int = n + extra
	var pool: Array[String] = katalog.belohnungs_pool()
	var res: Array[Karte] = []
	for _i in anzahl:
		var selten: int = _seltenheit_ziehen()
		var passend: Array[String] = []
		for vid in pool:
			var d: Dictionary = katalog.kleine[vid]
			if int(Katalog.SELTEN_VON_NAME.get(String(d.get("selten", "GEMEIN")), 0)) == selten:
				passend.append(vid)
		if passend.is_empty():
			passend = pool
		var k: Karte = katalog.karte(String(rng_belohnung.waehle(passend)))
		# Sternenstaub und Luck: Chance auf bereits verbesserte Karten.
		var chance_plus: float = float(charms.regelwert("sternenstaub")) + float(luck) * 2.0
		if rng_belohnung.chance_prozent(chance_plus):
			k.aufwerten(1)
		# Bei hoher Verderbnis tauchen umgekehrte Karten von selbst auf.
		if rng_belohnung.chance_prozent(float(verderbnis) * 0.5):
			k.drehen()
		res.append(k)
	return res

func _seltenheit_ziehen() -> int:
	var stufen: Array = [Konst.Selten.GEMEIN, Konst.Selten.SELTEN,
		Konst.Selten.ARKAN, Konst.Selten.VERKEHRT]
	var gewichte: Array = []
	for s in stufen:
		var g: float = float(Konst.SELTEN_GEWICHT[s])
		if s == Konst.Selten.GEMEIN:
			g -= float(luck) * Konst.LUCK_VERSCHIEBUNG
			g -= float(charms.regelwert("selten_bonus"))
		elif s == Konst.Selten.SELTEN or s == Konst.Selten.ARKAN:
			g += float(luck) * Konst.LUCK_VERSCHIEBUNG * 0.5
			g += float(charms.regelwert("selten_bonus")) * 0.5
		elif s == Konst.Selten.VERKEHRT:
			g += float(verderbnis) / 10.0 * Konst.VERDERBNIS_VERKEHRT_BONUS
		gewichte.append(maxf(0.0, g))
	return int(rng_belohnung.waehle_gewichtet(stufen, gewichte))

## Wie viele Charms ein Raum abwirft. Normale Kaempfe tropfen, Elites und
## Bosse schuetten aus. Gebrochene Krone erhoeht die Elite-Chance.
func charm_drops() -> Array[String]:
	var n: int = 0
	match raum_typ:
		Konst.Raum.ELITE:
			n = 1
			if rng_belohnung.chance_prozent(35.0 + float(charms.regelwert("krone"))):
				n += 1
		Konst.Raum.BOSS:
			n = 2
		_:
			if rng_belohnung.chance_prozent(45.0 + float(luck) * 3.0):
				n = 1
	var res: Array[String] = []
	for _i in n:
		var cid: String = belohnung_charm()
		if cid != "" and charms.geben(cid, 1) > 0:
			res.append(cid)
	return res

## Charm-Belohnung. Elite und Boss geben bessere.
func belohnung_charm() -> String:
	var stufen: Array = [Konst.Selten.GEMEIN, Konst.Selten.SELTEN,
		Konst.Selten.ARKAN, Konst.Selten.VERKEHRT, Konst.Selten.MYTHOS]
	var gewichte: Array = [60.0, 26.0, 9.0, 4.0, 1.0]
	if raum_typ == Konst.Raum.ELITE:
		gewichte = [30.0, 36.0, 22.0, 8.0, 4.0]
	elif raum_typ == Konst.Raum.BOSS:
		gewichte = [12.0, 30.0, 34.0, 12.0, 12.0]
	for i in stufen.size():
		if int(stufen[i]) == Konst.Selten.GEMEIN:
			gewichte[i] = maxf(0.0, float(gewichte[i]) - float(luck) * 3.0)
	var ziel: int = int(rng_belohnung.waehle_gewichtet(stufen, gewichte))
	var passend: Array[String] = []
	for cid in katalog.charms.keys():
		var c: Dictionary = katalog.charms[cid]
		if int(Katalog.SELTEN_VON_NAME.get(String(c.get("selten", "GEMEIN")), 0)) != ziel:
			continue
		if charms.anzahl(String(cid)) >= int(c.get("max", 5)):
			continue
		passend.append(String(cid))
	if passend.is_empty():
		# Alle Charms dieser Seltenheit sind ausgereizt - dann irgendeinen,
		# der noch Platz hat, sonst bleibt die Belohnung leer.
		for cid in katalog.charms.keys():
			if charms.anzahl(String(cid)) < int(katalog.charms[cid].get("max", 5)):
				passend.append(String(cid))
	if passend.is_empty():
		return ""
	passend.sort()
	return String(rng_belohnung.waehle(passend))

# ================================================================ Items
func item_geben(item_id: String, n: int = 1) -> bool:
	if items.size() >= Konst.ITEM_SLOTS and not items.has(item_id):
		return false
	items[item_id] = int(items.get(item_id, 0)) + n
	return true

func item_nutzen(item_id: String) -> bool:
	if int(items.get(item_id, 0)) <= 0:
		return false
	items[item_id] = int(items[item_id]) - 1
	if int(items[item_id]) <= 0:
		items.erase(item_id)
	return true

# ============================================================= Speichern
func protokoll(text: String) -> void:
	log.append(text)
	if log.size() > 600:
		log.remove_at(0)

func speichern() -> Dictionary:
	var deck_d: Array = []
	for k in deck:
		deck_d.append(k.speichern())
	return {
		"version": 1, "seed": seed_wert, "rng": rng.speichern(),
		"rng_weg": rng_weg.speichern(), "rng_belohnung": rng_belohnung.speichern(),
		"deuter": deuter_id, "spieler": spieler.speichern(), "deck": deck_d,
		"charms": charms.speichern(), "items": items.duplicate(),
		"gold": gold, "luck": luck, "verderbnis": verderbnis,
		"abschnitt": abschnitt, "raum_nr": raum_nr, "raum_typ": raum_typ,
		"endlos": endlos, "endlos_tiefe": endlos_tiefe,
		"verderbte_arkana": verderbte_arkana, "run_regeln": run_regeln,
		"fruehere_bossregeln": fruehere_bossregeln, "besiegte_bosse": besiegte_bosse,
		"geloescht": geloescht_anzahl, "statistik": statistik,
		"karten_id_zaehler": Karte.id_zaehler(),
	}

static func aus_speicher(p_katalog: Katalog, d: Dictionary) -> Run:
	var r := Run.new()
	r.katalog = p_katalog
	r.seed_wert = int(d.get("seed", 0))
	r.rng = TRng.new(0)
	r.rng.laden(d.get("rng", {}))
	r.rng_weg = TRng.new(0)
	r.rng_weg.laden(d.get("rng_weg", {}))
	r.rng_belohnung = TRng.new(0)
	r.rng_belohnung.laden(d.get("rng_belohnung", {}))
	r.deuter_id = String(d.get("deuter", "wahrsagerin"))
	r.deuter_regel = String(p_katalog.deuter.get(r.deuter_id, {}).get("regel", ""))
	r.spieler = Kaempfer.aus_speicher(d.get("spieler", {}))
	Karte.setze_id_zaehler(int(d.get("karten_id_zaehler", 1)))
	for kd in d.get("deck", []):
		r.deck.append(Karte.aus_speicher(kd))
	r.charms = Charmbeutel.new(p_katalog)
	r.charms.laden(d.get("charms", {}))
	r.items = (d.get("items", {}) as Dictionary).duplicate()
	r.gold = int(d.get("gold", 0))
	r.luck = int(d.get("luck", 0))
	r.verderbnis = int(d.get("verderbnis", 0))
	r.abschnitt = int(d.get("abschnitt", 1))
	r.raum_nr = int(d.get("raum_nr", 0))
	r.raum_typ = int(d.get("raum_typ", 0))
	r.endlos = bool(d.get("endlos", false))
	r.endlos_tiefe = int(d.get("endlos_tiefe", 0))
	for a in d.get("verderbte_arkana", []):
		r.verderbte_arkana.append(String(a))
	r.run_regeln = (d.get("run_regeln", {}) as Dictionary).duplicate()
	for b in d.get("fruehere_bossregeln", []):
		r.fruehere_bossregeln.append(String(b))
	for b in d.get("besiegte_bosse", []):
		r.besiegte_bosse.append(String(b))
	r.geloescht_anzahl = int(d.get("geloescht", 0))
	r.statistik = (d.get("statistik", {}) as Dictionary).duplicate()
	r.wegkarten_ziehen()
	return r
