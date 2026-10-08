# Zentrale Konstanten und Regelzahlen.
#
# Alles, was ein Designer anfassen will, steht hier oder in data/*.json.
# Im Code stehen keine magischen Zahlen.
extends RefCounted
class_name K

# ---------------------------------------------------------------- Kartenfarben
enum Farbe { SCHWERTER, STAEBE, KELCHE, MUENZEN, ARKANA }

const FARBE_NAME := {
	Farbe.SCHWERTER: "Schwerter",
	Farbe.STAEBE: "Staebe",
	Farbe.KELCHE: "Kelche",
	Farbe.MUENZEN: "Muenzen",
	Farbe.ARKANA: "Arkana",
}

const FARBE_ZEICHEN := {
	Farbe.SCHWERTER: "⚔",   # Schwerter
	Farbe.STAEBE: "✸",     # Feuer (im UI durch Sprite ersetzt)
	Farbe.KELCHE: "♥",
	Farbe.MUENZEN: "◆",
	Farbe.ARKANA: "★",
}

# Die vier kleinen Arkana haben klar getrennte Aufgaben. Siehe docs/01_GDD.md.
const FARBE_AUFGABE := {
	Farbe.SCHWERTER: "Schaden, Blutung, Verwundbar",
	Farbe.STAEBE: "Combo, Glut, Mehrfachtreffer",
	Farbe.KELCHE: "Heilung, Traum, Statuskontrolle",
	Farbe.MUENZEN: "Schild, Gold, Vorbereitung",
}

# --------------------------------------------------------------- Kartenpositio
# Die Legung. Reihenfolge ist auch die Ausloese-Reihenfolge.
enum Pos { VERGANGENHEIT, GEGENWART, ZUKUNFT }

const POS_NAME := {
	Pos.VERGANGENHEIT: "Vergangenheit",
	Pos.GEGENWART: "Gegenwart",
	Pos.ZUKUNFT: "Zukunft",
}

## Wirkungsfaktor je Position, in Promille (1000 = 100 %).
## Vergangenheit ist schwaecher, wiederholt aber die letzte Gegenwart.
## Zukunft ist doppelt stark, wirkt aber erst naechste Runde.
const POS_FAKTOR := {
	Pos.VERGANGENHEIT: 700,
	Pos.GEGENWART: 1000,
	Pos.ZUKUNFT: 2000,
}

## Anteil der letzten Gegenwartskarte, den die Vergangenheit wiederholt.
const ECHO_FAKTOR: int = 500

# ------------------------------------------------------------------ Orientieru
enum Ori { AUFRECHT, UMGEKEHRT }

const ORI_NAME := { Ori.AUFRECHT: "aufrecht", Ori.UMGEKEHRT: "umgekehrt" }

# ------------------------------------------------------------------ Seltenheit
enum Selten { GEMEIN, SELTEN, ARKAN, VERKEHRT, MYTHOS }

const SELTEN_NAME := {
	Selten.GEMEIN: "Gemein",
	Selten.SELTEN: "Selten",
	Selten.ARKAN: "Arkan",
	Selten.VERKEHRT: "Verkehrt",
	Selten.MYTHOS: "Mythos",
}

## Grundgewichte fuer Belohnungen. Werden durch Luck und Verderbnis verschoben.
const SELTEN_GEWICHT := {
	Selten.GEMEIN: 62.0,
	Selten.SELTEN: 26.0,
	Selten.ARKAN: 9.0,
	Selten.VERKEHRT: 3.0,
	Selten.MYTHOS: 0.0,   # nur aus Bossen, Truhen, Elite-Beute
}

## Je Luck-Punkt verschiebt sich Gewicht von Gemein nach oben.
const LUCK_VERSCHIEBUNG: float = 4.0
## Je 10 Verderbnis steigt das Gewicht von Verkehrt.
const VERDERBNIS_VERKEHRT_BONUS: float = 1.4

# ------------------------------------------------------------- Statuseffekte
# Traeger-unabhaengig; Spieler und Gegner nutzen dieselbe Tabelle.
enum St {
	SCHILD,        # absorbiert Schaden, verfaellt zu Zugbeginn
	BLUTUNG,       # Rundenende: Schaden = Stacks, dann -1
	GIFT,          # Zugbeginn: Schaden = Stacks, dann -1
	GLUT,          # Rundenende: Schaden = Stacks, dann halbiert
	VERWUNDBAR,    # erlittener Schaden +50 %
	SCHWACH,       # verursachter Schaden -25 %
	STARK,         # verursachter Schaden +Stacks (flach)
	TRAUM,         # Ressource: Karten duplizieren
	VERANKERT,     # Schild verfaellt nicht
	VERHUELLT,     # Absichten verborgen
	MARKIERT,      # Der Tod: Karte wird bei Kampfende vernichtet
}

const ST_NAME := {
	St.SCHILD: "Schild",
	St.BLUTUNG: "Blutung",
	St.GIFT: "Gift",
	St.GLUT: "Glut",
	St.VERWUNDBAR: "Verwundbar",
	St.SCHWACH: "Schwach",
	St.STARK: "Stark",
	St.TRAUM: "Traum",
	St.VERANKERT: "Verankert",
	St.VERHUELLT: "Verhuellt",
	St.MARKIERT: "Markiert",
}

## Status, die beim Rundenwechsel um 1 sinken.
const ST_ABKLINGEND: Array[int] = [St.VERWUNDBAR, St.SCHWACH, St.VERHUELLT]
## Status, die nicht ueber Kampfgrenzen hinweg bestehen.
const ST_KAMPF_ONLY: Array[int] = [
	St.SCHILD, St.BLUTUNG, St.GIFT, St.GLUT, St.VERWUNDBAR,
	St.SCHWACH, St.STARK, St.TRAUM, St.VERANKERT, St.VERHUELLT,
]

const VERWUNDBAR_FAKTOR: int = 1500   # Promille
const SCHWACH_FAKTOR: int = 750       # Promille

# ---------------------------------------------------------------------- Muster
enum Muster { RESONANZ, SCHICKSALSKETTE, KONVERGENZ, DIE_WELT }

const MUSTER_NAME := {
	Muster.RESONANZ: "Resonanz",
	Muster.SCHICKSALSKETTE: "Schicksalskette",
	Muster.KONVERGENZ: "Konvergenz",
	Muster.DIE_WELT: "Die Welt",
}

const MUSTER_TEXT := {
	Muster.RESONANZ: "Alle gelegten Karten derselben Farbe: +30 % Wirkung.",
	Muster.SCHICKSALSKETTE: "Drei aufeinanderfolgende Werte: +25 % Wirkung.",
	Muster.KONVERGENZ: "Drei gleiche Werte: +1 Schicksalsfaden, alle Karten loesen erneut aus.",
	Muster.DIE_WELT: "Werte ergeben exakt 21: alle Karten loesen erneut aus.",
}

## Bonus auf den Wirkungsmodifikator in Promille (addiert sich).
const MUSTER_BONUS := {
	Muster.RESONANZ: 300,
	Muster.SCHICKSALSKETTE: 250,
	Muster.KONVERGENZ: 0,
	Muster.DIE_WELT: 0,
}

## Zusaetzliche Ausloesungen durch das Muster.
const MUSTER_WIEDERHOLUNG := {
	Muster.RESONANZ: 0,
	Muster.SCHICKSALSKETTE: 0,
	Muster.KONVERGENZ: 1,
	Muster.DIE_WELT: 1,
}

## Harte Obergrenze, damit Konvergenz + Die Welt + Charms nicht explodieren.
const MAX_AUSLOESUNGEN: int = 3

const WELT_SUMME: int = 21

# --------------------------------------------------------------- Schicksalsfae
const FADEN_MAX: int = 5
const FADEN_START: int = 2

enum Faden {
	DREHEN,          # 1: Karte aufrecht <-> umgekehrt
	TAUSCHEN,        # 1: zwei gelegte Karten tauschen Position
	VORZIEHEN,       # 2: Zukunftskarte sofort ausloesen
	ZIEHEN,          # 2: eine Karte ziehen
	SCHICKSAL_BIEGEN,# 3: gegnerische Absicht neu wuerfeln
}

const FADEN_KOSTEN := {
	Faden.DREHEN: 1,
	Faden.TAUSCHEN: 1,
	Faden.VORZIEHEN: 2,
	Faden.ZIEHEN: 2,
	Faden.SCHICKSAL_BIEGEN: 3,
}

const FADEN_NAME := {
	Faden.DREHEN: "Karte drehen",
	Faden.TAUSCHEN: "Positionen tauschen",
	Faden.VORZIEHEN: "Zukunft vorziehen",
	Faden.ZIEHEN: "Karte ziehen",
	Faden.SCHICKSAL_BIEGEN: "Schicksal biegen",
}

# Wofuer man Faeden zurueckbekommt (jeweils max. 1 pro Zug).
const FADEN_GEWINN_UMGEKEHRT: int = 1
const FADEN_GEWINN_MUSTER: int = 1
const FADEN_GEWINN_ZUKUNFT_ERFUELLT: int = 1
const FADEN_GEWINN_EXAKT_TOD: int = 1

# ------------------------------------------------------------------ Kampfregel
const HAND_GROESSE: int = 5
const LEGUNGEN_PRO_ZUG: int = 3
const SPIELER_HP_START: int = 70
const DECK_MIN_GROESSE: int = 5     # darunter kann nicht mehr geloescht werden

# ------------------------------------------------------------------- Verderbni
# Die Verdunkelungsachse. Steigt durch Pakte, Fluechte, Tinte, Bosse.
# Faerbt Karten, UI und Ereignisse ein und oeffnet die Verkehrt-Seiten.
const VERDERBNIS_MAX: int = 100
const VERDERBNIS_SCHWELLEN: Array[int] = [20, 40, 60, 80, 100]
const VERDERBNIS_STUFEN_NAME: Array[String] = [
	"Blass", "Grau", "Russ", "Pech", "Obsidian", "Leer",
]

## Wirkungsbonus je Verderbnisstufe fuer umgekehrte Karten, in Promille.
const VERDERBNIS_UMGEKEHRT_BONUS: int = 60

# ------------------------------------------------------------- Kartenstufen
# Aufwerten verdunkelt die Karte. Stufe = "+" im Namen.
const STUFE_MAX: int = 3
const STUFE_BONUS: Array[int] = [0, 2, 5, 9]
const STUFE_NAME: Array[String] = ["", "+", "++", "+++"]

# ------------------------------------------------------------------- Oekonomie
const GOLD_START: int = 55
const GOLD_KAMPF: Array[int] = [11, 18]      # min/max normaler Kampf
const GOLD_ELITE: Array[int] = [26, 34]
const GOLD_BOSS: Array[int] = [45, 60]

## Loeschen wird teurer, je oefter man es tut (Index = Anzahl bisher).
const KOSTEN_VERGESSEN: Array[int] = [30, 50, 70, 90, 115, 140, 170, 200]
const KOSTEN_SPIEGELN: int = 80
const KOSTEN_UMDREHEN: int = 45
const KOSTEN_AUFWERTEN: int = 60
const KOSTEN_REROLL_BASIS: int = 12

# ------------------------------------------------------------------- Raumtypen
enum Raum { KAMPF, ELITE, BOSS, HAENDLER, RITUAL, UNBEKANNT, TRUHE, RUHE }

const RAUM_NAME := {
	Raum.KAMPF: "Kampf",
	Raum.ELITE: "Elite",
	Raum.BOSS: "Boss",
	Raum.HAENDLER: "Haendler",
	Raum.RITUAL: "Ritual",
	Raum.UNBEKANNT: "Unbekannt",
	Raum.TRUHE: "Truhe",
	Raum.RUHE: "Rast",
}

# --------------------------------------------------------------------- Struktu
## Raeume je Abschnitt (Akt). Der letzte Raum ist immer der Boss.
const RAEUME_PRO_ABSCHNITT: int = 14
const ABSCHNITTE_STORY: int = 3
## Im Endlosmodus: alle N Raeume kommt ein Verderbtes Arkanum dauerhaft dazu.
const ENDLOS_ARKANUM_INTERVALL: int = 5

# ------------------------------------------------------------------ Charmregel
const CHARM_STACK_MAX: int = 5
const ITEM_SLOTS: int = 3
const ARKANA_AKTIV_MAX: int = 3
const HOFKARTE_AKTIV_MAX: int = 1

# --------------------------------------------------------------- Kartenwerte
## Hofkarten belegen die Werte 11-14 und zaehlen so in Summe-21-Mustern mit.
const RANG_BUBE: int = 11
const RANG_RITTER: int = 12
const RANG_KOENIGIN: int = 13
const RANG_KOENIG: int = 14

const RANG_NAME := {
	1: "Ass", 11: "Bube", 12: "Ritter", 13: "Koenigin", 14: "Koenig",
}

## Roemische Zahlen fuer die Kartenkoepfe.
const ROEMISCH: Array[String] = [
	"0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII",
]

static func roemisch(n: int) -> String:
	if n >= 0 and n < ROEMISCH.size():
		return ROEMISCH[n]
	return str(n)

# --------------------------------------------------------------------- Palette
# "Occult Clean" - siehe docs/04_ART.md
const FARBE_SCHWARZ := Color("#161616")
const FARBE_ELFENBEIN := Color("#F2ECDD")
const FARBE_INDIGO := Color("#2E3A67")
const FARBE_OCKER := Color("#C89B3C")
const FARBE_BLUT := Color("#8E2B2B")

## Promille-Multiplikation mit Rundung auf die naechste Ganzzahl.
static func promille(wert: int, faktor: int) -> int:
	return int(floor(float(wert) * float(faktor) / 1000.0 + 0.5))
