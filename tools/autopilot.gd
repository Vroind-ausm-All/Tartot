# Ein einfacher Autopilot: spielt den Kampf ohne Spieler.
#
# Zweck: Balancing-Simulation und automatische Regressionstests. Er soll nicht
# optimal spielen, sondern *vernuenftig* - so wie jemand, der die Regeln kennt,
# aber nicht rechnet. Wenn der Autopilot 95 % der Kaempfe gewinnt, ist das
# Spiel zu leicht; wenn er unter 20 % liegt, zu schwer.
extends RefCounted
class_name Autopilot

const Konst := preload("res://core/konst.gd")

var aggressiv: float = 1.0

## Spielt einen kompletten Kampf. Gibt die Anzahl Runden zurueck.
func kampf_spielen(kf: Kampf, max_runden: int = 60) -> int:
	var runden: int = 0
	while not kf.vorbei() and runden < max_runden:
		runden += 1
		_zug_spielen(kf)
	return runden

func _zug_spielen(kf: Kampf) -> void:
	# Schicksalsfaeden: nur fuer klar gute Faelle ausgeben.
	_faeden_nutzen(kf)
	var beste: Array = _beste_legung(kf)
	for eintrag in beste:
		kf.legen(eintrag["karte"], int(eintrag["pos"]))
	kf.ausfuehren()

func _faeden_nutzen(kf: Kampf) -> void:
	# Eine wartende Zukunft vorziehen, wenn sie den Kampf jetzt beendet.
	if not kf.zukunft_wartend.is_empty() and kf.kann_faden(Konst.Faden.VORZIEHEN):
		var g: Kaempfer = kf.gegner[0]
		if not g.tot and g.hp <= 12:
			kf.faden_nutzen(Konst.Faden.VORZIEHEN)

## Probiert alle Platzierungen von bis zu 3 Handkarten und nimmt die beste.
func _beste_legung(kf: Kampf) -> Array:
	var hand: Array = kf.stapel.hand.duplicate()
	var frei: Array[int] = kf.positionen_frei()
	var max_karten: int = mini(kf.legungen_uebrig(), mini(hand.size(), frei.size()))
	if max_karten <= 0:
		return []
	var beste: Array = []
	var bester_wert: float = -1e9
	# Alle Kombinationen aus Karten und Positionen (klein genug fuer Brute Force).
	var kombis: Array = _kombinationen(hand, max_karten)
	for kombi in kombis:
		for anordnung in _permutationen(frei, kombi.size()):
			var vorschlag: Array = []
			for i in kombi.size():
				vorschlag.append({"karte": kombi[i], "pos": anordnung[i]})
			var w: float = _bewerten(kf, vorschlag)
			if w > bester_wert:
				bester_wert = w
				beste = vorschlag
	return beste

func _kombinationen(liste: Array, n: int) -> Array:
	var res: Array = []
	var m: int = liste.size()
	# Nur Kombinationen der Groesse n (und n-1, falls weniger besser ist).
	for groesse in range(maxi(1, n), 0, -1):
		_kombi_rekursiv(liste, groesse, 0, [], res)
		if res.size() > 60:
			break
	return res

func _kombi_rekursiv(liste: Array, n: int, start: int, aktuell: Array, res: Array) -> void:
	if aktuell.size() == n:
		res.append(aktuell.duplicate())
		return
	for i in range(start, liste.size()):
		aktuell.append(liste[i])
		_kombi_rekursiv(liste, n, i + 1, aktuell, res)
		aktuell.pop_back()

func _permutationen(positionen: Array[int], n: int) -> Array:
	var res: Array = []
	_perm_rekursiv(positionen, n, [], res)
	return res

func _perm_rekursiv(rest: Array, n: int, aktuell: Array, res: Array) -> void:
	if aktuell.size() == n:
		res.append(aktuell.duplicate())
		return
	for i in rest.size():
		var neu_rest: Array = rest.duplicate()
		var p: int = neu_rest[i]
		neu_rest.remove_at(i)
		aktuell.append(p)
		_perm_rekursiv(neu_rest, n, aktuell, res)
		aktuell.pop_back()

## Schaetzt den Wert einer Legung. Bewusst grob - siehe Kopfkommentar.
func _bewerten(kf: Kampf, vorschlag: Array) -> float:
	var gegner_hp: int = 0
	var eingehend: int = _eingehender_schaden(kf)
	for g in kf.gegner:
		if not g.tot:
			gegner_hp += g.hp + g.stapel(Konst.St.SCHILD)
	var schaden: float = 0.0
	var schild: float = 0.0
	var heilung: float = 0.0
	var sonst: float = 0.0
	var werte: Array[int] = []
	var farben: Dictionary = {}

	for e in vorschlag:
		var k: Karte = e["karte"]
		var pos: int = int(e["pos"])
		var faktor: float = float(Konst.POS_FAKTOR[pos]) / 1000.0
		# Die Zukunft zahlt doppelt, aber erst spaeter - und nur, wenn man lebt.
		if pos == Konst.Pos.ZUKUNFT:
			faktor *= 0.55 if kf.spieler.hp <= eingehend else 0.95
		werte.append(k.musterwert())
		farben[k.farbe] = true
		for op_v in kf.katalog.ops(k):
			if typeof(op_v) != TYPE_DICTIONARY:
				continue
			var op: Dictionary = op_v
			var w: float = float(op.get("wert", 0)) * faktor
			match String(op.get("op", "")):
				"schaden": schaden += w
				"selbstschaden": sonst -= w * 1.4
				"schild": schild += w
				"heilung": heilung += w
				"traum": sonst += w * 0.2
				"gold": sonst += w * 0.3
				"ziehen": sonst += w * 2.0
				"faden": sonst += w * 2.5
				"status":
					match String(op.get("st", "")):
						"BLUTUNG", "GIFT", "GLUT": schaden += w * 1.6
						"VERWUNDBAR": schaden += w * 2.0
						"SCHWACH": sonst += w * 1.5
						_: sonst += w * 0.5
				_: sonst += 1.0

	# Muster erkennen (dieselbe Logik wie im Kampf, nur auf dem Vorschlag).
	var bonus: float = 0.0
	if vorschlag.size() >= 2:
		if farben.size() == 1:
			bonus += 0.30
		var s: Array[int] = werte.duplicate()
		s.sort()
		var summe: int = 0
		for w2 in s:
			summe += w2
		if summe == Konst.WELT_SUMME:
			bonus += 1.0
		if s.size() >= 3:
			var gleich: bool = true
			var kette: bool = true
			for i in range(1, s.size()):
				if s[i] != s[0]:
					gleich = false
				if s[i] != s[i - 1] + 1:
					kette = false
			if gleich:
				bonus += 1.0
			elif kette:
				bonus += 0.25

	schaden *= (1.0 + bonus)
	schild *= (1.0 + bonus)
	heilung *= (1.0 + bonus)

	# Nutzen gewichten: Schild nur so viel, wie wirklich einschlaegt.
	var schild_nutzen: float = minf(schild, float(eingehend)) * 1.1
	var heil_nutzen: float = minf(heilung, float(kf.spieler.hp_max - kf.spieler.hp)) * 1.0
	var toedlich: float = 0.0
	if schaden >= float(gegner_hp) and gegner_hp > 0:
		toedlich = 50.0   # Kampf jetzt beenden ist fast immer richtig
	# Ueberschuessiger Schaden zaehlt wenig.
	var schaden_nutzen: float = minf(schaden, float(gegner_hp)) * aggressiv

	# Lebensgefahr: dann zaehlt Verteidigung mehr.
	var not_faktor: float = 1.0
	if kf.spieler.hp - eingehend + kf.spieler.stapel(Konst.St.SCHILD) <= 0:
		not_faktor = 3.0
	return toedlich + schaden_nutzen + (schild_nutzen + heil_nutzen) * not_faktor + sonst

func _eingehender_schaden(kf: Kampf) -> int:
	var summe: int = 0
	for i in kf.gegner.size():
		if kf.gegner[i].tot:
			continue
		for a in kf.absicht(i):
			if String(a.get("art", "")) == "angriff":
				summe += int(a.get("wert", 0)) * maxi(1, int(a.get("mal", 1)))
	return summe
