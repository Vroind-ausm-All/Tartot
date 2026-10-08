# Ein Kaempfer: Spieler oder Gegner. Beide nutzen dieselbe Statusmechanik,
# damit jeder Effekt symmetrisch funktioniert (Gift auf den Spieler, Schild
# beim Gegner, Verwundbar auf beiden Seiten).
extends RefCounted
class_name Kaempfer

const Konst := preload("res://core/konst.gd")

var name: String = ""
var hp: int = 1
var hp_max: int = 1
var ist_spieler: bool = false
var status: Dictionary = {}          # K.St -> Stacks
var tot: bool = false

## Protokoll der letzten Aktion, fuer UI-Text und Tests.
var letzte_notiz: String = ""

static func neu(p_name: String, p_hp: int, p_spieler: bool = false) -> Kaempfer:
	var k := Kaempfer.new()
	k.name = p_name
	k.hp = p_hp
	k.hp_max = p_hp
	k.ist_spieler = p_spieler
	return k

# ------------------------------------------------------------------- Status
func stapel(st: int) -> int:
	return int(status.get(st, 0))

func setze(st: int, wert: int) -> void:
	if wert <= 0:
		status.erase(st)
	else:
		status[st] = wert

func gib(st: int, wert: int) -> void:
	if wert == 0:
		return
	setze(st, stapel(st) + wert)

func hat(st: int) -> bool:
	return stapel(st) > 0

## Entfernt n negative Status (Gerechtigkeit, Blaues Band, Mondsalz).
func debuffs_entfernen(n: int) -> int:
	var negativ: Array[int] = [
		Konst.St.BLUTUNG, Konst.St.GIFT, Konst.St.GLUT,
		Konst.St.VERWUNDBAR, Konst.St.SCHWACH, Konst.St.VERHUELLT,
	]
	var entfernt: int = 0
	for st in negativ:
		if entfernt >= n:
			break
		if hat(st):
			status.erase(st)
			entfernt += 1
	return entfernt

func debuff_anzahl() -> int:
	var negativ: Array[int] = [
		Konst.St.BLUTUNG, Konst.St.GIFT, Konst.St.GLUT,
		Konst.St.VERWUNDBAR, Konst.St.SCHWACH, Konst.St.VERHUELLT,
	]
	var n: int = 0
	for st in negativ:
		if hat(st):
			n += 1
	return n

# ------------------------------------------------------------- Schadensrechnu
## Ausgehender Schaden nach Stark/Schwach des Angreifers.
func schaden_ausgehend(rohwert: int) -> int:
	var w: int = rohwert + stapel(Konst.St.STARK)
	if hat(Konst.St.SCHWACH):
		w = Konst.promille(w, Konst.SCHWACH_FAKTOR)
	return maxi(0, w)

## Eingehender Schaden nach Verwundbar, bevor Schild abzieht.
func schaden_eingehend(rohwert: int) -> int:
	var w: int = rohwert
	if hat(Konst.St.VERWUNDBAR):
		w = Konst.promille(w, Konst.VERWUNDBAR_FAKTOR)
	return maxi(0, w)

## Fuegt Schaden zu. Schild wird zuerst verbraucht.
## Gibt zurueck, wie viel HP tatsaechlich verloren ging.
func schaden_nehmen(rohwert: int, durch_schild: bool = true) -> int:
	if tot or rohwert <= 0:
		return 0
	var w: int = schaden_eingehend(rohwert)
	if durch_schild:
		var s: int = stapel(Konst.St.SCHILD)
		if s > 0:
			var absorbiert: int = mini(s, w)
			setze(Konst.St.SCHILD, s - absorbiert)
			w -= absorbiert
	if w <= 0:
		return 0
	hp = maxi(0, hp - w)
	if hp == 0:
		tot = true
	return w

## Schaden, der Schild ignoriert (Gift, Blutung, Selbstschaden).
func direktschaden(wert: int) -> int:
	return schaden_nehmen(wert, false)

func heilen(wert: int) -> int:
	if tot or wert <= 0:
		return 0
	var vorher: int = hp
	hp = mini(hp_max, hp + wert)
	return hp - vorher

## Ueberheilung: was ueber hp_max hinausgegangen waere (Kelchrand, Die Sonne).
func ueberheilung(wert: int) -> int:
	return maxi(0, wert - (hp_max - hp))

func hp_anteil() -> float:
	return 0.0 if hp_max <= 0 else float(hp) / float(hp_max)

# ------------------------------------------------------------ Rundenwechsel
## Zugbeginn: Gift tickt, Schild verfaellt (wenn nicht verankert).
## Gibt ein Protokoll der Ereignisse zurueck.
func zugbeginn() -> Array[String]:
	var log: Array[String] = []
	var g: int = stapel(Konst.St.GIFT)
	if g > 0:
		var v: int = direktschaden(g)
		setze(Konst.St.GIFT, g - 1)
		log.append("%s verliert %d HP durch Gift." % [name, v])
	if hat(Konst.St.SCHILD) and not hat(Konst.St.VERANKERT):
		setze(Konst.St.SCHILD, 0)
	elif hat(Konst.St.VERANKERT):
		# Verankert haelt genau einen Rundenwechsel durch.
		setze(Konst.St.VERANKERT, stapel(Konst.St.VERANKERT) - 1)
	return log

## Zugende: Blutung und Glut ticken, abklingende Status sinken.
func zugende() -> Array[String]:
	var log: Array[String] = []
	var b: int = stapel(Konst.St.BLUTUNG)
	if b > 0:
		var v: int = direktschaden(b)
		setze(Konst.St.BLUTUNG, b - 1)
		log.append("%s blutet fuer %d." % [name, v])
	var gl: int = stapel(Konst.St.GLUT)
	if gl > 0:
		var v2: int = direktschaden(gl)
		setze(Konst.St.GLUT, int(ceil(float(gl) / 2.0)))
		log.append("%s brennt fuer %d." % [name, v2])
	for st in Konst.ST_ABKLINGEND:
		if hat(st):
			setze(st, stapel(st) - 1)
	return log

func status_text() -> String:
	var teile: Array[String] = []
	for st in status.keys():
		teile.append("%s %d" % [Konst.ST_NAME[st], status[st]])
	return ", ".join(teile)

func kampf_status_loeschen() -> void:
	for st in Konst.ST_KAMPF_ONLY:
		status.erase(st)

func speichern() -> Dictionary:
	return {
		"name": name, "hp": hp, "hp_max": hp_max,
		"spieler": ist_spieler, "status": status.duplicate(), "tot": tot,
	}

static func aus_speicher(d: Dictionary) -> Kaempfer:
	var k := Kaempfer.new()
	k.name = String(d.get("name", ""))
	k.hp = int(d.get("hp", 1))
	k.hp_max = int(d.get("hp_max", 1))
	k.ist_spieler = bool(d.get("spieler", false))
	k.tot = bool(d.get("tot", false))
	var s: Dictionary = d.get("status", {})
	for key in s.keys():
		k.status[int(key)] = int(s[key])
	return k
