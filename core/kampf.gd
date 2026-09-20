# Der Kampf: ein Zug ist eine Legung aus Vergangenheit, Gegenwart und Zukunft.
#
# Ablauf eines Zuges
#   1. zug_beginnen()  - Zukunftskarten erfuellen sich, Status ticken, nachziehen
#   2. legen(k, pos)   - bis zu 3 Karten platzieren (eine pro Position)
#   3. faden_nutzen()  - optional das Schicksal manipulieren
#   4. ausfuehren()    - Muster pruefen, Karten ausloesen, dann handelt der Gegner
#
# Der Kampf kennt keine Szene und keine UI. Er meldet sich ausschliesslich
# ueber protokoll() und ereignis(). So ist jeder Zug simulierbar.
extends RefCounted
class_name Kampf

const Konst := preload("res://core/konst.gd")

# ------------------------------------------------------------------- Aufbau
var katalog: Katalog
var rng: TRng
var wahl: Wahl
var charms: Charmbeutel
var stapel: Kampfstapel

var spieler: Kaempfer
var gegner: Array[Kaempfer] = []
var gegner_def: Array = []                  # Definition je Gegner
var gegner_absicht: Array[int] = []         # Index in der Absichtsliste
var gegner_regeln: Array = []               # aktive Bossregeln

# ------------------------------------------------------------------ Zustand
var runde: int = 0
var vorbei_flag: bool = false
var gewonnen_flag: bool = false

var legung: Dictionary = {}                 # Pos -> Karte
var gesperrte_positionen: Dictionary = {}   # Pos -> true (Der Turm)
var legungen_erlaubt: int = Konst.LEGUNGEN_PRO_ZUG
var legungen_naechster_zug: int = -1
var extra_legungen: int = 0
var hand_groesse: int = Konst.HAND_GROESSE

var faden: int = Konst.FADEN_START
var faden_gewinn_umgekehrt_genutzt: bool = false
var faden_gewinn_muster_genutzt: bool = false

var zukunft_wartend: Array = []             # [{karte, modi, flach}]
var letzte_gegenwart_ops: Array = []
var letzte_gegenwart_karte: Karte = null
var letzte_karte: Karte = null
var letzte_karte_war_angriff: bool = false

# Zaehler fuer Charm-Bedingungen
var karten_gelegt_gesamt: int = 0
var karten_im_zug: int = 0
var angriffe_im_kampf: int = 0
var farben_gespielt: Dictionary = {}
var farb_zaehler_zug: Dictionary = {}
var staebe_ausgeloest_im_zug: int = 0
var kills: int = 0

# Temporaere Boni (in Promille, sofern nicht anders benannt)
var bonus_zukunft: int = 0
var bonus_zukunft_runden: int = 0
var bonus_umgekehrt: int = 0
var bonus_umgekehrt_runden: int = 0
var bonus_naechste: int = 0
var bonus_naechste_anzahl: int = 0
var bonus_naechste_farben: Array = []
var bonus_naechste_nur_umgekehrt: bool = false
var naechste_angriffe_bonus: int = 0
var naechste_angriffe_anzahl: int = 0
var aschekranz_bonus: int = 0
var vierfach_bonus: int = 0
var fadenspule_bonus: int = 0
var basis_verdoppelt: Dictionary = {}       # karte.id -> true
var naechste_karte_erschoepft: bool = false
var zug_sofort_beenden: bool = false
var ueberheilung_umleiten: String = "traum"
var verdeckte_karten: Dictionary = {}       # karte.id -> true
var verbundene: Array[int] = []             # Die Liebenden
var verbund_anteil: int = 500
var verbund_ablegen: bool = false

# Aus dem Run hereingegeben
var verderbnis: int = 0
var luck: int = 0
var luck_gewinn: int = 0
var gold_gewinn: int = 0
var deuter_regel: String = ""
var run_regeln: Dictionary = {}             # verderbte Arkana des Runs
var sicht_absichten: int = 1
var letzte_debuffs_entfernt: int = 0

# Nachwirkungen fuer den Run
var permanent_loeschen: int = 0
var permanent_aufwerten: int = 0
var fluch_anzahl: int = 0
var markierte_karten: Dictionary = {}       # karte.id -> Restrunden

var log: Array[String] = []
var ereignisse: Array = []

# ------------------------------------------------------------------- Aufbau
static func neu(p_katalog: Katalog, p_rng: TRng, p_spieler: Kaempfer,
		run_deck: Array[Karte], p_charms: Charmbeutel,
		gegner_ids: Array, p_wahl: Wahl, opt: Dictionary = {}) -> Kampf:
	var kf := Kampf.new()
	kf.katalog = p_katalog
	kf.rng = p_rng
	kf.spieler = p_spieler
	kf.charms = p_charms
	kf.wahl = p_wahl
	kf.stapel = Kampfstapel.new(run_deck, p_rng)
	kf.verderbnis = int(opt.get("verderbnis", 0))
	kf.luck = int(opt.get("luck", 0))
	kf.deuter_regel = String(opt.get("deuter_regel", ""))
	kf.run_regeln = opt.get("run_regeln", {})
	kf.faden = int(opt.get("faden_start", Konst.FADEN_START))
	kf.hand_groesse = int(opt.get("hand_groesse", Konst.HAND_GROESSE))
	kf.legungen_erlaubt = int(opt.get("legungen", Konst.LEGUNGEN_PRO_ZUG))
	for gid in gegner_ids:
		kf._gegner_aufstellen(String(gid), opt)
	kf._run_regeln_anwenden()
	return kf

func _gegner_aufstellen(gid: String, opt: Dictionary) -> void:
	var d: Dictionary = katalog.gegner.get(gid, {})
	if d.is_empty():
		push_warning("Unbekannter Gegner: %s" % gid)
		return
	var hp_bereich: Array = d.get("hp", [10, 10])
	var hp: int = rng.int_zwischen(int(hp_bereich[0]), int(hp_bereich[1]))
	# Skalierung fuer Endlosmodus und Giermotte.
	var skal: float = float(opt.get("gegner_hp_faktor", 1.0))
	hp = maxi(1, int(round(float(hp) * skal)))
	var g := Kaempfer.neu(String(d.get("name", gid)), hp)
	gegner.append(g)
	gegner_def.append(d)
	gegner_absicht.append(0)
	for r in d.get("regeln", []):
		gegner_regeln.append(r)

func _run_regeln_anwenden() -> void:
	# Verderbte Arkana wirken als dauerhafte Run-Regeln (Endlosmodus).
	if int(run_regeln.get("hand_bonus", 0)) > 0:
		hand_groesse += int(run_regeln["hand_bonus"])
	if int(run_regeln.get("schild_start", 0)) > 0:
		spieler.gib(Konst.St.SCHILD, int(run_regeln["schild_start"]))
	if int(run_regeln.get("legungen_deckel", 0)) > 0:
		legungen_erlaubt = mini(legungen_erlaubt, int(run_regeln["legungen_deckel"]))
	if int(run_regeln.get("sicht_absichten", 0)) > 0:
		sicht_absichten = maxi(sicht_absichten, int(run_regeln["sicht_absichten"]))
	if bool(run_regeln.get("absichten_verborgen", false)):
		for g in gegner:
			g.gib(Konst.St.VERHUELLT, 99)
	if int(run_regeln.get("luck", 0)) > 0:
		luck += int(run_regeln["luck"])
	if deuter_regel == "vier_legungen":
		legungen_erlaubt += 1

# ------------------------------------------------------------------ Start
func starten() -> void:
	protokoll("--- Kampf beginnt: %s ---" % gegner_namen())
	charms.haken(self, "kampf_start", _basis_kontext())
	for r in gegner_regeln:
		if int(r.get("intervall", 1)) == 0:
			_bossregel(String(r.get("id", "")), int(r.get("wert", 1)))
	stapel.ziehen(hand_groesse)
	if int(run_regeln.get("zufall_umgekehrt", 0)) > 0 and not stapel.hand.is_empty():
		for _i in int(run_regeln["zufall_umgekehrt"]):
			var k: Karte = rng.waehle(stapel.hand)
			k.drehen()
	runde = 1
	_zug_vorbereiten()

# ------------------------------------------------------------- Zug beginnen
func zug_beginnen() -> void:
	runde += 1
	_zug_vorbereiten()

func _zug_vorbereiten() -> void:
	legung.clear()
	karten_im_zug = 0
	staebe_ausgeloest_im_zug = 0
	farb_zaehler_zug.clear()
	faden_gewinn_umgekehrt_genutzt = false
	faden_gewinn_muster_genutzt = false
	zug_sofort_beenden = false
	fadenspule_bonus = 0
	if legungen_naechster_zug > 0:
		legungen_erlaubt = legungen_naechster_zug
		legungen_naechster_zug = -1
	extra_legungen = 0

	# Schild-Reste nach Charm "Siegel des Herrschers" / Deuter-Regel.
	var rest_prozent: int = charms.regelwert("schild_rest")
	if deuter_regel == "schild_rest_20":
		rest_prozent += 20
	var schild_vorher: int = spieler.stapel(Konst.St.SCHILD)
	for zeile in spieler.zugbeginn():
		protokoll(zeile)
	if rest_prozent > 0 and schild_vorher > 0 and not spieler.hat(Konst.St.SCHILD):
		var rest: int = Konst.promille(schild_vorher, rest_prozent * 10)
		if rest > 0:
			spieler.gib(Konst.St.SCHILD, rest)
			protokoll("Siegel: %d Schild bleibt bestehen." % rest)

	_zukunft_erfuellen()
	_bossregeln_pruefen()
	_markierungen_ticken()

	var fehlend: int = hand_groesse - stapel.hand.size()
	if fehlend > 0:
		var vorher_mischungen: int = stapel.mischungen
		stapel.ziehen(fehlend)
		if stapel.mischungen > vorher_mischungen:
			charms.haken(self, "mischen", _basis_kontext())
	charms.haken(self, "zug_start", _basis_kontext())
	ereignis("zug_start", {"runde": runde})

## Wartende Zukunftskarten loesen aus - das Versprechen erfuellt sich.
func _zukunft_erfuellen() -> void:
	if zukunft_wartend.is_empty():
		return
	var liste: Array = zukunft_wartend.duplicate()
	zukunft_wartend.clear()
	for eintrag in liste:
		var k: Karte = eintrag["karte"]
		protokoll("Die Zukunft erfuellt sich: %s" % k.anzeigename())
		_karte_ausloesen(k, Konst.Pos.ZUKUNFT, int(eintrag["modi"]),
			eintrag["flach"], 1)
		faden_geben(Konst.FADEN_GEWINN_ZUKUNFT_ERFUELLT, "Zukunft erfuellt")
		stapel.ablage.append(k)
	if bonus_zukunft_runden > 0:
		bonus_zukunft_runden -= 1
		if bonus_zukunft_runden == 0:
			bonus_zukunft = 0
	if bonus_umgekehrt_runden > 0:
		bonus_umgekehrt_runden -= 1
		if bonus_umgekehrt_runden == 0:
			bonus_umgekehrt = 0

# ---------------------------------------------------------------- Legen
func positionen_frei() -> Array[int]:
	var res: Array[int] = []
	for p in [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]:
		if not legung.has(p) and not gesperrte_positionen.has(p):
			res.append(p)
	return res

func legungen_uebrig() -> int:
	return legungen_erlaubt + extra_legungen - legung.size()

func kann_legen(k: Karte, pos: int) -> bool:
	if vorbei_flag or k == null:
		return false
	if k.ist_fluch:
		return false
	if gesperrte_positionen.has(pos) or legung.has(pos):
		return false
	if legungen_uebrig() <= 0:
		return false
	return stapel.hand.has(k)

func legen(k: Karte, pos: int) -> bool:
	if not kann_legen(k, pos):
		return false
	stapel.aus_hand_nehmen(k)
	legung[pos] = k
	# Verdeckte Karten (Der Mond): die Orientierung entscheidet sich erst jetzt.
	if verdeckte_karten.has(k.id):
		verdeckte_karten.erase(k.id)
		if rng.chance(0.5):
			k.drehen()
		protokoll("Die verdeckte Karte war %s." % Konst.ORI_NAME[k.ori])
	ereignis("karte_gelegt", {"karte": k, "position": pos})
	charms.haken(self, "karte_gelegt", {"karte": k, "position": pos})
	return true

func zurueckziehen(pos: int) -> bool:
	if not legung.has(pos):
		return false
	var k: Karte = legung[pos]
	legung.erase(pos)
	stapel.in_hand(k)
	return true

# -------------------------------------------------------- Schicksalsfaeden
func faden_geben(n: int, grund: String = "") -> void:
	if n <= 0:
		return
	var vorher: int = faden
	faden = mini(Konst.FADEN_MAX, faden + n)
	if faden > vorher:
		protokoll("+%d Schicksal%s" % [faden - vorher,
			(" (%s)" % grund) if grund != "" else ""])

func faden_kosten(art: int) -> int:
	return int(Konst.FADEN_KOSTEN.get(art, 99))

func kann_faden(art: int) -> bool:
	return faden >= faden_kosten(art)

## args je Aktion:
##   DREHEN            {"karte": Karte}
##   TAUSCHEN          {"a": Pos, "b": Pos}
##   VORZIEHEN         {}
##   ZIEHEN            {}
##   SCHICKSAL_BIEGEN  {}
func faden_nutzen(art: int, args: Dictionary = {}) -> bool:
	if not kann_faden(art):
		return false
	match art:
		Konst.Faden.DREHEN:
			var k: Karte = args.get("karte", null)
			if k == null or not (stapel.hand.has(k) or legung.values().has(k)):
				return false
			k.drehen()
			protokoll("Schicksal: %s gedreht." % k.anzeigename())
		Konst.Faden.TAUSCHEN:
			var a: int = int(args.get("a", -1))
			var b: int = int(args.get("b", -1))
			if not (legung.has(a) and legung.has(b)):
				return false
			var t: Karte = legung[a]
			legung[a] = legung[b]
			legung[b] = t
			protokoll("Schicksal: %s und %s getauscht." % [Konst.POS_NAME[a], Konst.POS_NAME[b]])
		Konst.Faden.VORZIEHEN:
			if zukunft_wartend.is_empty():
				return false
			var e: Dictionary = zukunft_wartend.pop_front()
			protokoll("Schicksal: Zukunft vorgezogen.")
			_karte_ausloesen(e["karte"], Konst.Pos.GEGENWART, int(e["modi"]), e["flach"], 1)
			stapel.ablage.append(e["karte"])
		Konst.Faden.ZIEHEN:
			if stapel.ziehen(1).is_empty():
				return false
			protokoll("Schicksal: Karte gezogen.")
		Konst.Faden.SCHICKSAL_BIEGEN:
			absichten_neu_wuerfeln()
			protokoll("Schicksal: die Absicht des Gegners verschiebt sich.")
		_:
			return false
	faden -= faden_kosten(art)
	ereignis("faden_genutzt", {"art": art})
	return true

# ---------------------------------------------------------------- Muster
## Erkennt alle Muster in der aktuellen Legung.
func muster_erkennen() -> Array[int]:
	var karten: Array[Karte] = []
	for p in legung.keys():
		karten.append(legung[p])
	var res: Array[int] = []
	if karten.size() < 2:
		return res

	# Resonanz: alle gelegten Karten dieselbe Farbe.
	var farbe0: int = karten[0].farbe
	var gleiche_farbe: bool = true
	for k in karten:
		if k.farbe != farbe0:
			gleiche_farbe = false
			break
	if gleiche_farbe:
		res.append(Konst.Muster.RESONANZ)

	# Werte sammeln.
	var werte: Array[int] = []
	for k in karten:
		werte.append(k.musterwert())
	werte.sort()

	# Konvergenz: alle gleich (mindestens drei Karten).
	if karten.size() >= 3:
		var alle_gleich: bool = true
		for w in werte:
			if w != werte[0]:
				alle_gleich = false
				break
		if alle_gleich:
			res.append(Konst.Muster.KONVERGENZ)
		# Schicksalskette: aufeinanderfolgende Werte.
		var kette: bool = true
		for i in range(1, werte.size()):
			if werte[i] != werte[i - 1] + 1:
				kette = false
				break
		if kette:
			res.append(Konst.Muster.SCHICKSALSKETTE)

	# Die Welt: Summe exakt 21.
	var summe: int = 0
	for w in werte:
		summe += w
	if summe == Konst.WELT_SUMME:
		res.append(Konst.Muster.DIE_WELT)
	return res

func muster_bonus(muster: Array[int]) -> int:
	var b: int = 0
	for m in muster:
		b += int(Konst.MUSTER_BONUS.get(m, 0))
	return b

func muster_wiederholungen(muster: Array[int]) -> int:
	var w: int = 0
	for m in muster:
		w += int(Konst.MUSTER_WIEDERHOLUNG.get(m, 0))
	return w

# -------------------------------------------------------------- Ausfuehren
## Loest die Legung auf und laesst danach den Gegner handeln.
func ausfuehren() -> void:
	if vorbei_flag:
		return
	var muster: Array[int] = muster_erkennen()
	for m in muster:
		protokoll("MUSTER: %s" % Konst.MUSTER_NAME[m])
		ereignis("muster", {"muster": m})
	if not muster.is_empty() and not faden_gewinn_muster_genutzt:
		faden_gewinn_muster_genutzt = true
		faden_geben(Konst.FADEN_GEWINN_MUSTER, "Muster")
	if muster.has(Konst.Muster.KONVERGENZ):
		faden_geben(1, "Konvergenz")

	var bonus: int = muster_bonus(muster)
	var wiederholungen: int = 1 + muster_wiederholungen(muster)
	wiederholungen = mini(wiederholungen, Konst.MAX_AUSLOESUNGEN)

	_positionen_verschieben()
	var reihenfolge: Array[int] = _ausloese_reihenfolge()

	for pos in reihenfolge:
		if not legung.has(pos):
			continue
		var k: Karte = legung[pos]
		var modi_flach := _modifikator(k, pos, bonus)
		if pos == Konst.Pos.ZUKUNFT:
			# Das Versprechen: wirkt erst naechste Runde, dann doppelt.
			zukunft_wartend.append({
				"karte": k, "modi": int(modi_flach["modi"]), "flach": modi_flach["flach"],
			})
			protokoll("%s wandert in die Zukunft (x%.1f)."
				% [k.anzeigename(), float(modi_flach["modi"]) / 1000.0])
			_nach_legen_zaehlen(k)
			continue
		_karte_ausloesen(k, pos, int(modi_flach["modi"]), modi_flach["flach"], wiederholungen)
		if pos == Konst.Pos.VERGANGENHEIT:
			_echo_ausloesen(k, int(modi_flach["modi"]))
		if pos == Konst.Pos.GEGENWART:
			letzte_gegenwart_ops = _karten_ops(k)
			letzte_gegenwart_karte = k
		if zug_sofort_beenden:
			break

	# Gelegte Karten aufraeumen.
	for pos in legung.keys():
		var k2: Karte = legung[pos]
		if pos == Konst.Pos.ZUKUNFT:
			continue
		if naechste_karte_erschoepft:
			naechste_karte_erschoepft = false
			stapel.vernichten(k2)
		elif katalog.ist_figur(k2):
			charms.figur_vorlage = k2.vorlage
			protokoll("Figur tritt ein: %s" % k2.anzeigename())
			stapel.ablage.append(k2)
		else:
			stapel.ablage.append(k2)
	legung.clear()

	charms.haken(self, "zug_ende", _basis_kontext())
	for zeile in spieler.zugende():
		protokoll(zeile)
	_pruefe_ende()
	if vorbei_flag:
		return
	_gegner_handeln()
	_pruefe_ende()
	if not vorbei_flag:
		zug_beginnen()

func _ausloese_reihenfolge() -> Array[int]:
	var r: Array[int] = [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]
	if _regel_aktiv("legung_spiegeln") or bool(run_regeln.get("legung_gespiegelt", false)):
		r.reverse()
	return r

## Der Gehaengte und das Rad greifen in die Legung ein, nachdem sie liegt.
func _positionen_verschieben() -> void:
	if not _regel_aktiv("positionen_tauschen"):
		return
	var karten: Array = legung.values()
	var pos: Array = legung.keys()
	rng.mische(karten)
	legung.clear()
	for i in pos.size():
		legung[pos[i]] = karten[i]
	protokoll("Das Rad dreht: die Positionen sind vertauscht.")

# --------------------------------------------------------- Modifikatoren
## Berechnet Wirkungsmodifikator (Promille) und flache Boni fuer eine Karte.
func _modifikator(k: Karte, pos: int, muster_b: int) -> Dictionary:
	var modi: int = int(Konst.POS_FAKTOR.get(pos, 1000))
	modi += muster_b

	# Stabkarten-Combo: jede weitere Stabkarte im Zug verdoppelt die Basis.
	if k.farbe == Konst.Farbe.STAEBE or charms.hat_regel("combo_universell"):
		modi += staebe_ausgeloest_im_zug * 1000

	if pos == Konst.Pos.ZUKUNFT:
		modi += bonus_zukunft
		modi += int(run_regeln.get("zukunft_prozent", 0)) * 10
		modi += charms.regelwert("henkerkette_dummy")  # Platzhalter, Charm laeuft ueber mod
	if k.ist_umgekehrt():
		modi += bonus_umgekehrt
		# Verderbnis macht umgekehrte Karten staerker - die Verdunkelung zahlt sich aus.
		modi += (verderbnis / 20) * Konst.VERDERBNIS_UMGEKEHRT_BONUS
	if bonus_naechste_anzahl > 0 and _naechste_bonus_passt(k):
		modi += bonus_naechste
		bonus_naechste_anzahl -= 1
		if bonus_naechste_anzahl == 0:
			bonus_naechste = 0
			bonus_naechste_farben = []
			bonus_naechste_nur_umgekehrt = false
	if naechste_angriffe_anzahl > 0 and _ist_angriff(k):
		modi += naechste_angriffe_bonus
		naechste_angriffe_anzahl -= 1
		if naechste_angriffe_anzahl == 0:
			naechste_angriffe_bonus = 0
	modi += int(run_regeln.get("schaden_prozent", 0)) * 10 if _ist_angriff(k) else 0
	modi += charms.regelwert("weltenfaden") * 10 * int(charms.verschiedene() / 5)
	if charms.hat_regel("glasherz"):
		pass  # Heilungsbonus wird in heilen() angewandt

	var kontext := {
		"karte": k, "position": pos, "ops": _karten_ops(k),
	}
	var cm: Dictionary = charms.modifikator(self, kontext)
	modi += int(cm["promille"])

	var flach: Dictionary = (cm["flach"] as Dictionary).duplicate()
	# Stufe und Tinte der Karte wirken flach auf alle Zahlenwerte.
	var fb: int = k.flachbonus() + vierfach_bonus + fadenspule_bonus
	if _ist_angriff(k):
		fb += aschekranz_bonus
	for schluessel in ["schaden", "schild", "heilung", "traum"]:
		flach[schluessel] = int(flach.get(schluessel, 0)) + fb
	if basis_verdoppelt.has(k.id):
		modi += 1000
		basis_verdoppelt.erase(k.id)
	flach["_durchdringung"] = int(cm["durchdringung"])
	return {"modi": maxi(0, modi), "flach": flach}

func _naechste_bonus_passt(k: Karte) -> bool:
	if bonus_naechste_nur_umgekehrt and not k.ist_umgekehrt():
		return false
	if not bonus_naechste_farben.is_empty():
		var name: String = Konst.FARBE_NAME[k.farbe].to_upper()
		if not bonus_naechste_farben.has(name):
			return false
	return true

func _karten_ops(k: Karte) -> Array:
	return katalog.ops(k)

func _ist_angriff(k: Karte) -> bool:
	for op_v in _karten_ops(k):
		if typeof(op_v) == TYPE_DICTIONARY and String((op_v as Dictionary).get("op", "")) == "schaden":
			return true
	return false

# ------------------------------------------------------------ Ausloesen
func _karte_ausloesen(k: Karte, pos: int, modi: int, flach: Dictionary, mal: int) -> void:
	var ops: Array = _karten_ops(k)
	var kontext := {
		"karte": k, "position": pos, "modifikator": modi, "flach": flach,
		"quelle": k.anzeigename(), "ops": ops,
		"durchdringung": int(flach.get("_durchdringung", 0)),
	}
	for i in mal:
		if i > 0:
			protokoll("  ... loest erneut aus (%d/%d)" % [i + 1, mal])
		_ops_mit_bedingung(kontext, ops)
		charms.haken(self, "karte_ausgeloest", kontext)
	_nach_legen_zaehlen(k)
	_verbund_ausloesen(k, pos, modi, flach)

func _ops_mit_bedingung(kontext: Dictionary, ops: Array) -> void:
	# Ops duerfen eigene Bedingungen tragen (z. B. "nur gegen Verwundbar").
	var erlaubt: Array = []
	for op_v in ops:
		if typeof(op_v) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = op_v
		if op.has("wenn") and not Bedingung.erfuellt(self, kontext, op["wenn"]):
			continue
		erlaubt.append(op)
	Effekte.anwenden(self, kontext, erlaubt)

func _nach_legen_zaehlen(k: Karte) -> void:
	karten_gelegt_gesamt += 1
	karten_im_zug += 1
	letzte_karte = k
	letzte_karte_war_angriff = _ist_angriff(k)
	if letzte_karte_war_angriff:
		angriffe_im_kampf += 1
	farben_gespielt[k.farbe] = true
	farb_zaehler_zug[k.farbe] = int(farb_zaehler_zug.get(k.farbe, 0)) + 1
	if k.farbe == Konst.Farbe.STAEBE or charms.hat_regel("combo_universell"):
		staebe_ausgeloest_im_zug += 1
	fadenspule_bonus = 0
	# Vierfachknoten: alle vier Farben gelegt.
	if vierfach_bonus == 0 and farben_gespielt.size() >= 4:
		var vf: int = charms.regelwert("vierfachknoten")
		if vf > 0:
			vierfach_bonus = vf
			protokoll("Vierfachknoten: alle Karten +%d Effekt." % vf)

## Die Vergangenheit wiederholt die Gegenwart des letzten Zuges.
func _echo_ausloesen(k: Karte, modi: int) -> void:
	if letzte_gegenwart_ops.is_empty():
		return
	var echo_modi: int = Konst.promille(modi, Konst.ECHO_FAKTOR)
	protokoll("  Echo von %s (x%.2f)" % [
		letzte_gegenwart_karte.anzeigename() if letzte_gegenwart_karte else "?",
		float(echo_modi) / 1000.0])
	var kontext := {
		"karte": letzte_gegenwart_karte, "position": Konst.Pos.VERGANGENHEIT,
		"modifikator": echo_modi, "flach": {}, "quelle": "Echo",
		"ops": letzte_gegenwart_ops,
	}
	_ops_mit_bedingung(kontext, letzte_gegenwart_ops)

## Die Liebenden: verbundene Karten loesen mit Anteil mit aus.
func _verbund_ausloesen(k: Karte, pos: int, modi: int, flach: Dictionary) -> void:
	if verbundene.size() < 2 or not verbundene.has(k.id):
		return
	var partner_id: int = verbundene[0] if verbundene[1] == k.id else verbundene[1]
	var partner: Karte = _karte_nach_id(partner_id)
	if partner == null:
		return
	var anteil_modi: int = Konst.promille(modi, verbund_anteil)
	protokoll("  Verbindung: %s loest mit %d %% aus."
		% [partner.anzeigename(), int(verbund_anteil / 10)])
	var kontext := {
		"karte": partner, "position": pos, "modifikator": anteil_modi,
		"flach": flach, "quelle": "Verbindung", "ops": _karten_ops(partner),
	}
	_ops_mit_bedingung(kontext, _karten_ops(partner))
	if verbund_ablegen:
		stapel.ablegen(partner)
		verbundene.clear()

func _karte_nach_id(kid: int) -> Karte:
	for liste in [stapel.hand, stapel.ziehstapel, stapel.ablage]:
		for k in liste:
			if k.id == kid:
				return k
	return null

# ======================================================== Schaden und Heilung
func ziele_fuer(ziel: Variant, alle: bool) -> Array[Kaempfer]:
	var res: Array[Kaempfer] = []
	if String(ziel) == "selbst":
		res.append(spieler)
		return res
	var lebende: Array[Kaempfer] = []
	for g in gegner:
		if not g.tot:
			lebende.append(g)
	if lebende.is_empty():
		return res
	if alle:
		return lebende
	res.append(lebende[0])
	return res

func schaden_zufuegen(von: Kaempfer, ziel: Kaempfer, wert: int, quelle: String,
		durchdringung: int = 0) -> int:
	if ziel == null or ziel.tot or wert <= 0:
		return 0
	var roh: int = von.schaden_ausgehend(wert)
	if durchdringung > 0 and ziel.hat(Konst.St.SCHILD):
		var abzug: int = mini(durchdringung, ziel.stapel(Konst.St.SCHILD))
		ziel.setze(Konst.St.SCHILD, ziel.stapel(Konst.St.SCHILD) - abzug)
	var verursacht: int = ziel.schaden_nehmen(roh)
	protokoll("%s: %d Schaden an %s (HP %d)." % [quelle, verursacht, ziel.name, ziel.hp])
	ereignis("schaden", {"ziel": ziel, "wert": verursacht, "quelle": quelle})
	charms.haken(self, "schaden_verursacht", {"ziel": ziel, "wert": verursacht})
	if ziel.tot:
		_kill(ziel)
	return verursacht

func _kill(ziel: Kaempfer) -> void:
	kills += 1
	protokoll("%s faellt." % ziel.name)
	ereignis("kill", {"ziel": ziel})
	var ak: int = charms.regelwert("aschekranz")
	if ak > 0:
		aschekranz_bonus += ak
	charms.haken(self, "kill", {"ziel": ziel})

func heilen(wert: int, quelle: String) -> int:
	if wert <= 0:
		return 0
	var w: int = wert
	if charms.hat_regel("glasherz"):
		w = Konst.promille(w, 1000 + charms.regelwert("glasherz") * 10)
	if int(run_regeln.get("heilung_prozent", 0)) != 0:
		w = Konst.promille(w, 1000 + int(run_regeln["heilung_prozent"]) * 10)
	if deuter_regel == "glut_ueberall":
		protokoll("%s: Der Verbrannte kann nicht heilen." % quelle)
		return 0
	var ueber: int = spieler.ueberheilung(w)
	var geheilt: int = spieler.heilen(w)
	if geheilt > 0:
		protokoll("%s: %d HP geheilt (HP %d/%d)." % [quelle, geheilt, spieler.hp, spieler.hp_max])
	if ueber > 0:
		_ueberheilung_verwerten(ueber, quelle)
	# Schwarzer Kelch: Heilung schaedigt den Gegner.
	var sk: int = charms.regelwert("schwarzer_kelch")
	if sk > 0 and w > 0:
		var dmg: int = Konst.promille(w, sk * 10)
		for z in ziele_fuer("gegner", false):
			schaden_zufuegen(spieler, z, dmg, "Schwarzer Kelch")
	# Der Teufel (verderbt): jede Heilung erzeugt Verderbnis.
	if int(run_regeln.get("heilung_verderbnis", 0)) > 0 and geheilt > 0:
		verderbnis += int(run_regeln["heilung_verderbnis"])
	charms.haken(self, "heilung", {"wert": geheilt})
	return geheilt

func _ueberheilung_verwerten(ueber: int, quelle: String) -> void:
	var kr: int = charms.regelwert("kelchrand")
	if kr > 0:
		var s: int = Konst.promille(ueber, kr * 10)
		if s > 0:
			spieler.gib(Konst.St.SCHILD, s)
			protokoll("Kelchrand: %d Ueberheilung wird zu Schild." % s)
	match ueberheilung_umleiten:
		"schild":
			spieler.gib(Konst.St.SCHILD, ueber)
			protokoll("%s: %d Ueberheilung wird zu Schild." % [quelle, ueber])
		"maxhp":
			spieler.hp_max += ueber
			spieler.hp += ueber
			protokoll("%s: %d Ueberheilung wird maximales Leben." % [quelle, ueber])
		_:
			var faktor: int = 1500 if deuter_regel == "ueberheilung_traum_verstaerkt" else 1000
			var t: int = Konst.promille(ueber, faktor)
			spieler.gib(Konst.St.TRAUM, t)
			protokoll("%s: %d Ueberheilung wird Traum." % [quelle, t])
	if charms.hat_regel("ueberheilung_zu_faden"):
		faden_geben(int(ueber / 4), "Koenigin der Kelche")
	charms.haken(self, "ueberheilung", {"wert": ueber})

func schild_brechen(als_schaden: bool, quelle: String) -> void:
	for g in gegner:
		if g.tot:
			continue
		var s: int = g.stapel(Konst.St.SCHILD)
		if s <= 0:
			continue
		g.setze(Konst.St.SCHILD, 0)
		protokoll("%s: %d Schild von %s zerstoert." % [quelle, s, g.name])
		if als_schaden:
			schaden_zufuegen(spieler, g, s, quelle)

func debuff_uebertragen() -> void:
	var negativ: Array[int] = [Konst.St.BLUTUNG, Konst.St.GIFT, Konst.St.GLUT,
		Konst.St.VERWUNDBAR, Konst.St.SCHWACH]
	for st in negativ:
		if spieler.hat(st):
			var n: int = spieler.stapel(st)
			spieler.setze(st, 0)
			for z in ziele_fuer("gegner", false):
				z.gib(st, n)
			protokoll("Gerechtigkeit: %s %d uebertragen." % [Konst.ST_NAME[st], n])
			return

# ================================================================== Abfragen
func gegner_greift_diese_runde_an() -> bool:
	for i in gegner.size():
		if gegner[i].tot:
			continue
		for a in absicht(i):
			if String(a.get("art", "")) == "angriff":
				return true
	return false

func farbe_zaehler_im_zug(farbe: int) -> int:
	return int(farb_zaehler_zug.get(farbe, 0))

func irgendein_gegner_hat_debuff() -> bool:
	for g in gegner:
		if not g.tot and g.debuff_anzahl() > 0:
			return true
	return false

func irgendein_gegner_hat(st: int) -> bool:
	for g in gegner:
		if not g.tot and g.hat(st):
			return true
	return false

func gegner_namen() -> String:
	var n: Array[String] = []
	for g in gegner:
		n.append(g.name)
	return ", ".join(n)

func lebende_gegner() -> int:
	var n: int = 0
	for g in gegner:
		if not g.tot:
			n += 1
	return n

func vorbei() -> bool:
	return vorbei_flag

func gewonnen() -> bool:
	return gewonnen_flag

func _basis_kontext() -> Dictionary:
	return {"karte": null, "position": -1, "modifikator": 1000, "flach": {},
		"quelle": "Charm", "ops": []}

# ========================================================== Gegner-Absichten
func absicht(i: int) -> Array:
	if i < 0 or i >= gegner_def.size():
		return []
	var d: Dictionary = gegner_def[i]
	var liste: Array = d.get("absichten", [])
	if liste.is_empty():
		return []
	return liste[gegner_absicht[i] % liste.size()]

## Fuer die UI: "14 Schaden", "Block 8 + Blutung 2", "???" bei Verhuellt.
func absicht_text(i: int) -> String:
	if i < 0 or i >= gegner.size():
		return ""
	if gegner[i].hat(Konst.St.VERHUELLT) or bool(run_regeln.get("absichten_verborgen", false)):
		return "???"
	var teile: Array[String] = []
	for a in absicht(i):
		var w: int = int(a.get("wert", 0))
		match String(a.get("art", "")):
			"angriff":
				var mal: int = int(a.get("mal", 1))
				teile.append("%d Schaden" % w if mal <= 1 else "%dx%d Schaden" % [mal, w])
			"block": teile.append("%d Schild" % w)
			"heilen": teile.append("Heilt %d" % w)
			"debuff": teile.append("%s %d" % [String(a.get("st", "")).capitalize(), w])
			"regel": teile.append(_regel_kurztext(String(a.get("id", ""))))
	return " + ".join(teile)

func _regel_kurztext(id: String) -> String:
	match id:
		"position_zerstoeren": return "Zerstoert eine Position"
		"karte_verdecken", "verdeckte_karte": return "Verdeckt eine Karte"
		"karte_markieren": return "Markiert eine Karte"
		"positionen_tauschen": return "Vertauscht die Legung"
		"legung_spiegeln": return "Spiegelt die Legung"
		"pakt_anbieten": return "Bietet einen Pakt"
		"gold_stehlen": return "Stiehlt Gold"
		"letzte_karte_kopieren": return "Kopiert deine Karte"
		"zukunft_stehlen": return "Stiehlt deine Zukunft"
		"schild_klauen": return "Nimmt dein Schild"
		"alle_bossregeln": return "Alles zugleich"
		_: return "Unbekannt"

func absichten_neu_wuerfeln() -> void:
	for i in gegner.size():
		var d: Dictionary = gegner_def[i]
		var liste: Array = d.get("absichten", [])
		if liste.size() > 1:
			gegner_absicht[i] = rng.int_bis(liste.size())

func _absicht_weiter(i: int) -> void:
	var d: Dictionary = gegner_def[i]
	var liste: Array = d.get("absichten", [])
	if liste.is_empty():
		return
	if String(d.get("muster", "zyklus")) == "gewicht":
		gegner_absicht[i] = rng.int_bis(liste.size())
	else:
		gegner_absicht[i] = (gegner_absicht[i] + 1) % liste.size()

# ============================================================= Gegnerzug
func _gegner_handeln() -> void:
	for i in gegner.size():
		var g: Kaempfer = gegner[i]
		if g.tot:
			continue
		for zeile in g.zugbeginn():
			protokoll(zeile)
		if g.tot:
			continue
		for a in absicht(i):
			_gegner_aktion(i, g, a)
			if spieler.tot:
				return
		for zeile in g.zugende():
			protokoll(zeile)
		_absicht_weiter(i)

func _gegner_aktion(i: int, g: Kaempfer, a: Dictionary) -> void:
	var w: int = int(a.get("wert", 0))
	match String(a.get("art", "")):
		"angriff":
			for _n in maxi(1, int(a.get("mal", 1))):
				_gegner_schaden(g, w)
				if spieler.tot:
					return
		"block":
			g.gib(Konst.St.SCHILD, w)
			protokoll("%s erhaelt %d Schild." % [g.name, w])
		"heilen":
			var geheilt: int = g.heilen(w)
			protokoll("%s heilt %d." % [g.name, geheilt])
		"debuff":
			var st_name: String = String(a.get("st", "VERWUNDBAR"))
			var st: int = int(Effekte.ST_VON_NAME.get(st_name, Konst.St.VERWUNDBAR))
			if charms.hat_regel("salzsiegel") and not _salzsiegel_verbraucht:
				_salzsiegel_verbraucht = true
				protokoll("Salzsiegel negiert %s." % st_name)
			else:
				spieler.gib(st, w)
				protokoll("%s: du erhaeltst %s %d." % [g.name, st_name, w])
		"regel":
			_bossregel(String(a.get("id", "")), maxi(1, w))

var _salzsiegel_verbraucht: bool = false

func _gegner_schaden(g: Kaempfer, wert: int) -> void:
	var w: int = g.schaden_ausgehend(wert)
	var prozent: int = int(run_regeln.get("gegner_schaden_prozent", 0))
	if prozent != 0:
		w = Konst.promille(w, 1000 + prozent * 10)
	var schild_vorher: int = spieler.stapel(Konst.St.SCHILD)
	var verloren: int = spieler.schaden_nehmen(w)
	var geblockt: int = schild_vorher - spieler.stapel(Konst.St.SCHILD)
	protokoll("%s greift an: %d Schaden (%d geblockt), HP %d/%d."
		% [g.name, verloren, geblockt, spieler.hp, spieler.hp_max])
	ereignis("spieler_getroffen", {"wert": verloren, "geblockt": geblockt})
	var dr: int = charms.regelwert("dornenring")
	if dr > 0 and geblockt > 0:
		schaden_zufuegen(spieler, g, dr, "Dornenring")
	# Koenigin der Muenzen: verfallendes Schild wird Schaden - hier nicht,
	# sondern beim Zugbeginn; siehe _zug_vorbereiten.
	charms.haken(self, "schaden_erlitten", {"wert": verloren, "geblockt": geblockt})
	if spieler.tot:
		_todespruefung()

func _todespruefung() -> void:
	# Phoenixfeder und Aschephiole fangen den Tod ab.
	var pf: int = charms.regelwert("phoenixfeder")
	if pf > 0 and not _phoenix_verbraucht:
		_phoenix_verbraucht = true
		spieler.tot = false
		spieler.hp = maxi(1, pf - 4)
		protokoll("Die Phoenixfeder verbrennt. Du stehst mit %d HP." % spieler.hp)
		ereignis("phoenix", {})

var _phoenix_verbraucht: bool = false

# ============================================================== Bossregeln
func _regel_aktiv(id: String) -> bool:
	for r in gegner_regeln:
		if String(r.get("id", "")) == id and int(r.get("intervall", 1)) == 0:
			return true
	return false

func _bossregeln_pruefen() -> void:
	for r in gegner_regeln:
		var iv: int = int(r.get("intervall", 0))
		if iv > 0 and runde % iv == 0:
			_bossregel(String(r.get("id", "")), int(r.get("wert", 1)))

func _bossregel(id: String, wert: int) -> void:
	match id:
		"position_zerstoeren":
			var frei: Array[int] = positionen_frei()
			if frei.is_empty():
				frei = [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]
			var p: int = int(rng.waehle(frei))
			gesperrte_positionen[p] = true
			protokoll("DER TURM: Die Position %s ist zerstoert." % Konst.POS_NAME[p])
			ereignis("position_zerstoert", {"position": p})
		"karte_verdecken", "verdeckte_karte":
			if not stapel.hand.is_empty():
				var k: Karte = rng.waehle(stapel.hand)
				verdeckte_karten[k.id] = true
				protokoll("Eine deiner Karten ist verdeckt.")
		"karte_markieren":
			if not stapel.hand.is_empty():
				var k2: Karte = rng.waehle(stapel.hand)
				k2.markiert = true
				markierte_karten[k2.id] = 3
				protokoll("DER TOD markiert %s. Noch 3 Runden." % k2.anzeigename())
				ereignis("markiert", {"karte": k2})
		"positionen_tauschen", "legung_spiegeln":
			pass  # wirkt in ausfuehren()
		"pakt_anbieten":
			_pakt_anbieten()
		"gold_stehlen":
			gold_gewinn -= wert
			protokoll("Die Ratte stiehlt %d Gold." % wert)
		"letzte_karte_kopieren":
			if letzte_karte != null:
				protokoll("Die Spiegelschwester kopiert %s." % letzte_karte.anzeigename())
				var dmg: int = 0
				for op_v in _karten_ops(letzte_karte):
					if typeof(op_v) == TYPE_DICTIONARY and String(op_v["op"]) == "schaden":
						dmg += int(op_v.get("wert", 0))
				if dmg > 0:
					spieler.schaden_nehmen(dmg)
					protokoll("Die Kopie trifft dich fuer %d." % dmg)
		"zukunft_stehlen":
			if not zukunft_wartend.is_empty():
				var e: Dictionary = zukunft_wartend.pop_front()
				stapel.ablage.append(e["karte"])
				protokoll("Der Uhrenwurm frisst deine Zukunft: %s."
					% (e["karte"] as Karte).anzeigename())
		"schild_klauen":
			var s: int = spieler.stapel(Konst.St.SCHILD)
			if s > 0:
				spieler.setze(Konst.St.SCHILD, 0)
				protokoll("Dein Schild (%d) wird dir genommen." % s)
		"hp_verborgen":
			pass  # reine Anzeige
		"alle_bossregeln":
			for id2 in run_regeln.get("fruehere_bossregeln", []):
				_bossregel(String(id2), 1)
		_:
			protokoll("[WARNUNG] Unbekannte Bossregel: %s" % id)

func _pakt_anbieten() -> void:
	var pakt := {
		"text": "+100 % Schaden fuer 2 Runden - eine zufaellige Karte wird verflucht.",
		"bonus": 1000, "runden": 2, "fluch": 1,
	}
	protokoll("DER TEUFEL bietet an: %s" % pakt["text"])
	if wahl.pakt_annehmen(self, pakt):
		bonus_naechste += int(pakt["bonus"])
		bonus_naechste_anzahl += 4
		fluch_vormerken(int(pakt["fluch"]))
		protokoll("Du nimmst den Pakt an.")
	else:
		protokoll("Du lehnst ab. Er laechelt trotzdem.")
	ereignis("pakt", pakt)

func _markierungen_ticken() -> void:
	for kid in markierte_karten.keys():
		markierte_karten[kid] = int(markierte_karten[kid]) - 1
		if int(markierte_karten[kid]) <= 0:
			protokoll("Die Markierung greift: eine Karte ist fuer den Run verloren.")
			permanent_loeschen += 1
			markierte_karten.erase(kid)

# ===================================================== Spezial-Unterstuetzung
func letzte_karte_wiederholen(anteil: int, quelle: String) -> void:
	if letzte_karte == null:
		protokoll("%s: nichts zu wiederholen." % quelle)
		return
	var ops: Array = _karten_ops(letzte_karte)
	var kontext := {
		"karte": letzte_karte, "position": Konst.Pos.GEGENWART,
		"modifikator": anteil, "flach": {}, "quelle": quelle + " (Echo)", "ops": ops,
	}
	_ops_mit_bedingung(kontext, ops)

func karten_binden(anteil: int) -> void:
	if stapel.hand.size() < 2:
		return
	var a: Karte = wahl.handkarte(self, "kopieren")
	var rest: Array = stapel.hand.duplicate()
	rest.erase(a)
	if rest.is_empty():
		return
	var b: Karte = rest[0]
	verbundene = [a.id, b.id]
	verbund_anteil = anteil
	a.verbunden_mit = b.id
	b.verbunden_mit = a.id
	protokoll("Die Liebenden: %s und %s sind verbunden." % [a.anzeigename(), b.anzeigename()])

func karten_zurueckholen(n: int, aus_vernichtet: bool) -> void:
	var quelle: Array = stapel.verbannt if aus_vernichtet else stapel.ablage
	for _i in n:
		if quelle.is_empty():
			break
		var k: Karte = quelle.pop_back()
		stapel.in_hand(k)
		protokoll("Das Gericht ruft %s zurueck." % k.anzeigename())

func perfekte_hand_ziehen() -> void:
	# Je eine Karte pro Farbe, dann auffuellen.
	var gewuenscht: Array[int] = [Konst.Farbe.SCHWERTER, Konst.Farbe.STAEBE,
		Konst.Farbe.KELCHE, Konst.Farbe.MUENZEN]
	for farbe in gewuenscht:
		for i in range(stapel.ziehstapel.size() - 1, -1, -1):
			if stapel.ziehstapel[i].farbe == farbe:
				stapel.in_hand(stapel.ziehstapel[i])
				stapel.ziehstapel.remove_at(i)
				break
	stapel.ziehen(maxi(0, hand_groesse - stapel.hand.size()))
	protokoll("DIE WELT: eine perfekte Hand liegt vor dir.")

func rad_waehlen(n: int) -> void:
	var gezogen: Array = stapel.ziehen(n)
	if gezogen.size() <= 1:
		return
	var behalten: Karte = Wahl._extrem(gezogen, true)
	for k in gezogen:
		if k != behalten:
			stapel.aus_hand_nehmen(k)
			stapel.obenauf(k)
	protokoll("Das Rad: du behaeltst %s." % behalten.anzeigename())

func effekte_mischen(anteil: int, ausloesungen: int) -> void:
	if stapel.hand.size() < 2:
		return
	var a: Karte = stapel.hand[0]
	var b: Karte = stapel.hand[1]
	var ops: Array = _karten_ops(a).duplicate()
	ops.append_array(_karten_ops(b))
	stapel.ablegen(a)
	stapel.ablegen(b)
	protokoll("Maessigkeit mischt %s und %s." % [a.anzeigename(), b.anzeigename()])
	var kontext := {"karte": a, "position": Konst.Pos.GEGENWART,
		"modifikator": anteil, "flach": {}, "quelle": "Maessigkeit", "ops": ops}
	for _i in maxi(1, ausloesungen):
		_ops_mit_bedingung(kontext, ops)

func fluch_vormerken(n: int) -> void:
	fluch_anzahl += n
	verderbnis += n * 2
	protokoll("Ein Fluch haftet an deinem Deck. (+%d Verderbnis)" % (n * 2))

func permanent_loeschen_vormerken(n: int) -> void:
	permanent_loeschen += n
	protokoll("Nach dem Kampf darfst du %d Karte(n) permanent loeschen." % n)

func permanent_aufwerten_vormerken(n: int, _zufall: bool) -> void:
	permanent_aufwerten += n
	protokoll("Nach dem Kampf werden %d Karte(n) permanent verbessert." % n)

# ================================================================== Ende
func _pruefe_ende() -> void:
	if vorbei_flag:
		return
	if spieler.tot:
		vorbei_flag = true
		gewonnen_flag = false
		protokoll("--- Du faellst. ---")
		ereignis("niederlage", {})
		return
	if lebende_gegner() == 0:
		vorbei_flag = true
		gewonnen_flag = true
		charms.haken(self, "kampf_ende", _basis_kontext())
		# Markierte Karten, die der Kampf ueberlebt hat, sind gerettet.
		markierte_karten.clear()
		# Koenig der Muenzen und Giermotte veraendern die Beute.
		if charms.hat_regel("gold_plus_30"):
			gold_gewinn = Konst.promille(gold_gewinn, 1300)
		var gm: int = charms.regelwert("giermotte")
		if gm > 0:
			gold_gewinn = Konst.promille(gold_gewinn, 1000 + gm * 10)
		protokoll("--- Gewonnen (Runde %d). ---" % runde)
		ereignis("sieg", {"runde": runde})

# =============================================================== Protokoll
func protokoll(text: String) -> void:
	log.append(text)
	if log.size() > 400:
		log.remove_at(0)

func ereignis(name: String, daten: Dictionary) -> void:
	ereignisse.append({"name": name, "daten": daten, "runde": runde})
	if ereignisse.size() > 400:
		ereignisse.remove_at(0)

## Kompakte Zustandsanzeige fuer UI und Tests.
func zustand() -> Dictionary:
	var g_liste: Array = []
	for i in gegner.size():
		g_liste.append({
			"name": gegner[i].name, "hp": gegner[i].hp, "hp_max": gegner[i].hp_max,
			"tot": gegner[i].tot, "absicht": absicht_text(i),
			"status": gegner[i].status_text(),
		})
	return {
		"runde": runde, "hp": spieler.hp, "hp_max": spieler.hp_max,
		"schild": spieler.stapel(Konst.St.SCHILD),
		"faden": faden, "hand": stapel.hand.size(),
		"ziehstapel": stapel.ziehstapel.size(), "ablage": stapel.ablage.size(),
		"gegner": g_liste, "vorbei": vorbei_flag, "gewonnen": gewonnen_flag,
		"legungen_uebrig": legungen_uebrig(),
	}

# ------------------------------------------------- Nachtraege fuer Spezialops
## Die umgekehrte Muenze zahlt zurueck, wenn dein Schild vollstaendig faellt.
var muenze_rueckschlag: int = 0
var gegner_zug_ueberspringen: bool = false

## II Die Hohepriesterin (umgekehrt): drei Karten ansehen, die beste behalten.
func priesterin_beste_von_drei(n: int) -> void:
	var gezogen: Array = stapel.ziehen(n)
	if gezogen.size() <= 1:
		return
	var beste: Karte = Wahl._extrem(gezogen, true)
	for k in gezogen:
		if k != beste:
			stapel.ablegen(k)
	protokoll("Die Hohepriesterin waehlt: %s." % beste.anzeigename())
