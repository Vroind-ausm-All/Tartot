# Bedingungspruefung fuer Ops, Charm-Modifikatoren und Haken.
#
# Eine Bedingung ist ein Dictionary; ALLE Schluessel muessen zutreffen (UND).
# Fuer ODER schreibt man zwei Eintraege - das hat sich als lesbarer erwiesen
# als eine verschachtelte Logik-Sprache im JSON.
extends RefCounted
class_name Bedingung

const Konst := preload("res://core/konst.gd")

const FARBE_VON_NAME := {
	"SCHWERTER": Konst.Farbe.SCHWERTER, "STAEBE": Konst.Farbe.STAEBE,
	"KELCHE": Konst.Farbe.KELCHE, "MUENZEN": Konst.Farbe.MUENZEN,
	"ARKANA": Konst.Farbe.ARKANA,
}
const POS_VON_NAME := {
	"VERGANGENHEIT": Konst.Pos.VERGANGENHEIT,
	"GEGENWART": Konst.Pos.GEGENWART,
	"ZUKUNFT": Konst.Pos.ZUKUNFT,
}
const ST_VON_NAME := {
	"SCHILD": Konst.St.SCHILD, "BLUTUNG": Konst.St.BLUTUNG, "GIFT": Konst.St.GIFT,
	"GLUT": Konst.St.GLUT, "VERWUNDBAR": Konst.St.VERWUNDBAR,
	"SCHWACH": Konst.St.SCHWACH, "STARK": Konst.St.STARK, "TRAUM": Konst.St.TRAUM,
	"VERANKERT": Konst.St.VERANKERT, "VERHUELLT": Konst.St.VERHUELLT,
}

## kampf untypisiert, um Preload-Zyklen zu vermeiden.
static func erfuellt(kampf, kontext: Dictionary, wenn: Variant) -> bool:
	if typeof(wenn) != TYPE_DICTIONARY:
		return true
	var w: Dictionary = wenn
	if w.is_empty():
		return true
	var k: Karte = kontext.get("karte", null)

	for schluessel in w.keys():
		var v: Variant = w[schluessel]
		match String(schluessel):
			"farbe":
				if k == null or k.farbe != int(FARBE_VON_NAME.get(String(v), -1)):
					return false
			"nicht_farbe":
				if k != null and k.farbe == int(FARBE_VON_NAME.get(String(v), -1)):
					return false
			"position":
				if int(kontext.get("position", -1)) != int(POS_VON_NAME.get(String(v), -1)):
					return false
			"umgekehrt":
				if k == null or k.ist_umgekehrt() != bool(v):
					return false
			"ist_kopie":
				if k == null or k.ist_kopie != bool(v):
					return false
			"stufe_min":
				if k == null or k.stufe < int(v):
					return false
			"tinte_min":
				if k == null or k.tinte < int(v):
					return false
			"arkana":
				if k == null or k.ist_grosse_arkana() != bool(v):
					return false
			"hat_op":
				if not _hat_op(kontext, String(v)):
					return false
			"hp_unter_prozent":
				if kampf.spieler.hp_anteil() * 100.0 >= float(v):
					return false
			"hp_ueber_prozent":
				if kampf.spieler.hp_anteil() * 100.0 <= float(v):
					return false
			"erster_angriff_im_kampf":
				if kampf.angriffe_im_kampf > 0:
					return false
			"gegner_greift_an":
				if not kampf.gegner_greift_diese_runde_an():
					return false
			"nach_angriff":
				if not kampf.letzte_karte_war_angriff:
					return false
			"zaehler_modulo":
				var n: int = int(v)
				if n <= 0 or kampf.karten_gelegt_gesamt % n != 0:
					return false
			"karte_nr_im_zug":
				if kampf.karten_im_zug != int(v):
					return false
			"erste_der_farbe_im_zug":
				if k == null or kampf.farbe_zaehler_im_zug(k.farbe) != 1:
					return false
			"farbe_im_zug_min":
				if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
					return false
				var farbe_id: int = int(FARBE_VON_NAME.get(String((v as Array)[0]), -1))
				if kampf.farbe_zaehler_im_zug(farbe_id) < int((v as Array)[1]):
					return false
			"ziel_hat_debuff":
				if not kampf.irgendein_gegner_hat_debuff():
					return false
			"ziel_status":
				var st: int = int(ST_VON_NAME.get(String(v), -1))
				if not kampf.irgendein_gegner_hat(st):
					return false
			"spieler_status":
				var st2: int = int(ST_VON_NAME.get(String(v), -1))
				if not kampf.spieler.hat(st2):
					return false
			"schild_min":
				if kampf.spieler.stapel(Konst.St.SCHILD) < int(v):
					return false
			"traum_min":
				if kampf.spieler.stapel(Konst.St.TRAUM) < int(v):
					return false
			"verderbnis_min":
				if kampf.verderbnis < int(v):
					return false
			"verderbnis_max":
				if kampf.verderbnis > int(v):
					return false
			"farben_gespielt_min":
				if kampf.farben_gespielt.size() < int(v):
					return false
			"runde_min":
				if kampf.runde < int(v):
					return false
			_:
				push_warning("Unbekannte Bedingung: %s" % schluessel)
	return true

static func _hat_op(kontext: Dictionary, art: String) -> bool:
	var ops: Variant = kontext.get("ops", [])
	if typeof(ops) != TYPE_ARRAY:
		return false
	for op_v in ops:
		if typeof(op_v) == TYPE_DICTIONARY and String((op_v as Dictionary).get("op", "")) == art:
			return true
	return false
