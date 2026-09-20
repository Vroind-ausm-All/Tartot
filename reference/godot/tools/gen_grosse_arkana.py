#!/usr/bin/env python3
"""Erzeugt data/grosse_arkana.json.

Jedes Grosse Arkanum hat drei Gesichter:
  1. "aufrecht"  - die Kampfkarte, wie gelegt
  2. "umgekehrt" - dieselbe Karte, riskanter und spezialisierter (nicht schlechter)
  3. "verderbt"  - eine dauerhafte Run-Regel; so erscheinen sie im Endlosmodus
                   und als Bossregel

Handgeschrieben, weil jedes Arkanum eine eigene Regel bricht.
"""
import json
from collections import OrderedDict

A = []


def ark(nr, name, schlagwort, selten, auf_text, auf_ops, um_text, um_ops,
        verderbt_text=None, verderbt=None):
    A.append(OrderedDict([
        ("id", "arkana_%02d" % nr),
        ("nr", nr),
        ("name", name),
        ("schlagwort", schlagwort),
        ("selten", selten),
        ("aufrecht_text", auf_text),
        ("aufrecht", auf_ops),
        ("umgekehrt_text", um_text),
        ("umgekehrt", um_ops),
        ("verderbt_text", verderbt_text or ""),
        ("verderbt", verderbt or {}),
    ]))


ark(0, "Der Narr", "Chaos, Neubeginn, Risiko", "ARKAN",
    "Ziehe 2 Karten. Du darfst diesen Zug eine vierte Karte legen.",
    [{"op": "ziehen", "wert": 2}, {"op": "extra_legung", "wert": 1}],
    "Ziehe 3 Karten, wirf danach zufaellig 1 Karte ab. +1 Luck fuer den Kampf.",
    [{"op": "ziehen", "wert": 3}, {"op": "ablegen_zufaellig", "wert": 1},
     {"op": "luck", "wert": 1}],
    "Deine Starthand ist jeden Kampf um 1 Karte groesser, aber eine zufaellige Karte ist umgekehrt.",
    {"hand_bonus": 1, "zufall_umgekehrt": 1})

ark(1, "Der Magier", "Macht, Kombination, Manipulation", "ARKAN",
    "Erzeuge ein Echo der zuletzt gelegten Karte und loese es mit 100 % erneut aus.",
    [{"op": "wiederholen_letzte", "anteil": 1000}],
    "Kopiere eine Handkarte. Die Kopie verschwindet nach dem Kampf.",
    [{"op": "kopie_hand", "wert": 1}],
    "Die erste Karte jedes Kampfes loest zweimal aus - auch beim Gegner.",
    {"erste_karte_doppelt": True, "gilt_auch_fuer_gegner": True})

ark(2, "Die Hohepriesterin", "Wissen, Geheimnisse, Vorahnung", "ARKAN",
    "Sieh die naechsten 3 Karten deines Decks und ordne sie neu. Zeigt 2 Gegneraktionen.",
    [{"op": "spaehen", "wert": 3}, {"op": "absicht_zeigen", "wert": 2}],
    "Ziehe die beste von 3 zufaelligen Karten. Die naechste Gegnerabsicht wird verborgen.",
    [{"op": "spezial", "id": "priesterin_beste_von_drei", "wert": 3},
     {"op": "absicht_verbergen", "wert": 1}],
    "Du siehst zwei Gegnerabsichten - dafuer kennst du deine oberste Deckkarte nie.",
    {"sicht_absichten": 2, "deck_blind": True})

ark(3, "Die Herrscherin", "Wachstum, Heilung, Erschaffung", "ARKAN",
    "Heile 6. Deine naechsten zwei Kelch- oder Muenzkarten erhalten +50 %.",
    [{"op": "heilung", "wert": 6, "ueberschuss": "traum"},
     {"op": "naechste_karten_bonus", "wert": 2, "prozent": 50,
      "farben": ["KELCHE", "MUENZEN"]}],
    "Opfere 4 HP. Deine naechsten drei Karten erhalten +40 %.",
    [{"op": "selbstschaden", "wert": 4},
     {"op": "naechste_karten_bonus", "wert": 3, "prozent": 40}],
    "Nach jedem Kampf +4 HP, aber Gegner haben +8 % maximale HP.",
    {"hp_nach_kampf": 4, "gegner_hp_prozent": 8})

ark(4, "Der Herrscher", "Kontrolle, Schutz, Ordnung", "ARKAN",
    "Erhalte 12 Schild. Dein Schild verfaellt naechste Runde nicht.",
    [{"op": "schild", "wert": 12},
     {"op": "status", "st": "VERANKERT", "wert": 1, "ziel": "selbst"}],
    "Erhalte 18 Schild, aber naechste Runde darfst du nur 2 Karten legen.",
    [{"op": "schild", "wert": 18}, {"op": "legungen_naechster_zug", "wert": 2}],
    "Beginne jeden Kampf mit 10 Schild, aber du kannst nie mehr als 3 Karten legen.",
    {"schild_start": 10, "legungen_deckel": 3})

ark(5, "Der Hierophant", "Regeln, Tradition, Opfer", "ARKAN",
    "Verbessere eine Handkarte fuer diesen Kampf um eine Stufe.",
    [{"op": "aufwerten_kampf", "wert": 1}],
    "Verdopple den Basiswert einer Handkarte; danach ist sie fuer diesen Kampf erschoepft.",
    [{"op": "basiswert_verdoppeln", "wert": 1},
     {"op": "spezial", "id": "hierophant_erschoepfen"}],
    "Aufwerten kostet die Haelfte, aber du darfst pro Abschnitt nur eine Karte loeschen.",
    {"aufwerten_rabatt": 50, "loeschen_pro_abschnitt": 1})

ark(6, "Die Liebenden", "Verbindung, Entscheidung, Synergie", "ARKAN",
    "Verbinde zwei Handkarten. Wird eine gelegt, loest die andere mit 50 % mit aus.",
    [{"op": "binden", "anteil": 500}],
    "Verbinde zwei Handkarten zu 100 %. Danach werden beide abgeworfen.",
    [{"op": "binden", "anteil": 1000, "danach_ablegen": True}],
    "Zu Kampfbeginn werden zwei Karten verbunden - aber der Gegner waehlt welche.",
    {"binden_start": True, "gegner_waehlt": True})

ark(7, "Der Wagen", "Geschwindigkeit, Angriff, Momentum", "ARKAN",
    "8 Schaden. Ist dies deine dritte Karte im Zug, loest sie erneut aus.",
    [{"op": "schaden", "wert": 8},
     {"op": "wiederholen_letzte", "anteil": 1000, "wenn": {"karte_nr_im_zug": 3}}],
    "12 Schaden. Danach endet dein Zug sofort.",
    [{"op": "schaden", "wert": 12}, {"op": "zug_beenden"}],
    "Du legst zuerst - aber Gegner handeln zweimal pro Runde, wenn du weniger als 3 Karten legst.",
    {"initiative": True, "strafe_unter_drei": True})

ark(8, "Kraft", "Staerke, Selbstbeherrschung", "ARKAN",
    "Die naechste Angriffskarte verursacht doppelten Basisschaden. +4 Schild.",
    [{"op": "spezial", "id": "kraft_naechster_angriff", "prozent": 100, "wert": 1},
     {"op": "schild", "wert": 4}],
    "Die naechsten zwei Angriffe +75 %. Danach erhaeltst du 5 Schaden.",
    [{"op": "spezial", "id": "kraft_naechster_angriff", "prozent": 75, "wert": 2},
     {"op": "selbstschaden", "wert": 5}],
    "Deine Angriffe +20 %, aber Heilung wirkt nur zur Haelfte.",
    {"schaden_prozent": 20, "heilung_prozent": -50})

ark(9, "Der Eremit", "Isolation, Suche, Wissen", "ARKAN",
    "Entferne eine Handkarte fuer diesen Kampf und ziehe 2 neue Karten.",
    [{"op": "spezial", "id": "eremit_tausch", "entfernen": 1, "ziehen": 2}],
    "Entferne zwei Handkarten fuer diesen Kampf und ziehe 3.",
    [{"op": "spezial", "id": "eremit_tausch", "entfernen": 2, "ziehen": 3}],
    "Legst du nur eine Karte pro Zug, wirkt sie doppelt.",
    {"einzelkarte_doppelt": True})

ark(10, "Rad des Schicksals", "Zufall, Veraenderung", "ARKAN",
    "Ziehe 3 Karten und behalte eine. Die anderen kommen zurueck ins Deck.",
    [{"op": "spezial", "id": "rad_waehlen", "wert": 3}],
    "Ersetze deine gesamte Hand. Jede neue Karte hat +25 % Wirkung.",
    [{"op": "hand_ersetzen", "prozent": 25}],
    "Belohnungen werden zufaellig ersetzt - manchmal besser, manchmal schlechter.",
    {"belohnung_chaos": True})

ark(11, "Gerechtigkeit", "Ausgleich, Konsequenz", "ARKAN",
    "Entferne 2 eigene Debuffs. Verursache 4 Schaden pro entferntem Debuff.",
    [{"op": "debuff_weg", "wert": 2},
     {"op": "spezial", "id": "gerechtigkeit_schaden", "wert": 4}],
    "Uebertrage einen deiner Debuffs auf den Gegner.",
    [{"op": "debuff_uebertragen", "wert": 1}],
    "Jeder Status, den du erhaeltst, trifft auch den Gegner - und umgekehrt.",
    {"status_spiegel": True})

ark(12, "Der Gehaengte", "Opfer, Perspektivwechsel", "ARKAN",
    "Verzichte auf diesen Zug. Naechste Runde darfst du 5 Karten legen.",
    [{"op": "legungen_naechster_zug", "wert": 5}, {"op": "zug_beenden"}],
    "Opfere eine Handkarte fuer diesen Kampf. Alle verbleibenden erhalten +30 %.",
    [{"op": "vernichten_hand", "wert": 1},
     {"op": "naechste_karten_bonus", "wert": 5, "prozent": 30}],
    "Die Legung ist gespiegelt: Zukunft liegt links, Vergangenheit rechts.",
    {"legung_gespiegelt": True})

ark(13, "Der Tod", "Ende, Transformation", "MYTHOS",
    "Vernichte eine Handkarte fuer diesen Kampf. Ziehe 2. Nach dem Sieg darfst du sie loeschen.",
    [{"op": "vernichten_hand", "wert": 1}, {"op": "ziehen", "wert": 2},
     {"op": "karte_loeschen_permanent", "wert": 1}],
    "Loesche eine Karte permanent und verbessere dafuer zwei zufaellige andere.",
    [{"op": "karte_loeschen_permanent", "wert": 1},
     {"op": "karte_aufwerten_permanent", "wert": 2, "zufall": True}],
    "Jeder Boss vernichtet dauerhaft eine deiner Karten - aber jede geloeschte Karte staerkt eine andere.",
    {"boss_zerstoert_karte": 1, "loeschen_staerkt": True})

ark(14, "Maessigkeit", "Balance, Mischung", "ARKAN",
    "Mische die Effekte zweier Handkarten zu einer gemeinsamen Aktion.",
    [{"op": "spezial", "id": "maessigkeit_mischen", "anteil": 1000, "ausloesungen": 1}],
    "Beide Effekte werden um 25 % reduziert, loesen dafuer zweimal aus.",
    [{"op": "spezial", "id": "maessigkeit_mischen", "anteil": 750, "ausloesungen": 2}],
    "Alle Werte werden gemittelt: keine Spitzen, keine Ausfaelle.",
    {"werte_mitteln": True})

ark(15, "Der Teufel", "Versuchung, Macht gegen Preis", "MYTHOS",
    "Die naechste Karte wirkt mit +100 %. Danach erhaeltst du einen Fluch.",
    [{"op": "naechste_karten_bonus", "wert": 1, "prozent": 100},
     {"op": "spezial", "id": "teufel_fluch", "wert": 1}],
    "Alle umgekehrten Karten wirken 3 Runden lang mit +50 %.",
    [{"op": "umgekehrt_bonus", "wert": 3, "prozent": 50}],
    "Du verursachst +50 % Schaden. Jede Heilung erzeugt 1 Verderbnis.",
    {"schaden_prozent": 50, "heilung_verderbnis": 1})

ark(16, "Der Turm", "Zerstoerung, ploetzlicher Wandel", "MYTHOS",
    "18 Schaden an allen Gegnern. Dein Schild faellt auf 0.",
    [{"op": "schaden", "wert": 18, "alle": True},
     {"op": "spezial", "id": "turm_schild_null"}],
    "Zerstoere allen gegnerischen Schild und verursache dessen Wert als Schaden.",
    [{"op": "schild_brechen", "als_schaden": True}],
    "Alle Gegner verursachen +30 % Schaden. Alle drei Kaempfe verlieren alle 20 % ihrer HP.",
    {"gegner_schaden_prozent": 30, "aderlass_intervall": 3, "aderlass_prozent": 20})

ark(17, "Der Stern", "Hoffnung, Regeneration", "ARKAN",
    "Heile 8, ziehe 1 Karte, +1 Luck fuer diesen Kampf.",
    [{"op": "heilung", "wert": 8, "ueberschuss": "traum"},
     {"op": "ziehen", "wert": 1}, {"op": "luck", "wert": 1}],
    "Heile nur 4, dafuer bleibt +1 Luck bis zum Ende des Abschnitts.",
    [{"op": "heilung", "wert": 4, "ueberschuss": "traum"},
     {"op": "luck", "wert": 1, "dauerhaft": True}],
    "+2 Luck dauerhaft, aber du kannst nie mehr als 60 % deiner HP heilen.",
    {"luck": 2, "heilung_deckel_prozent": 60})

ark(18, "Der Mond", "Illusion, Unsicherheit", "MYTHOS",
    "Deine naechsten zwei umgekehrten Karten wirken mit +50 %.",
    [{"op": "naechste_karten_bonus", "wert": 2, "prozent": 50, "nur_umgekehrt": True}],
    "Gegnerabsichten sind 2 Runden verborgen. Deine Karten wirken mit +35 %.",
    [{"op": "absicht_verbergen", "wert": 2},
     {"op": "naechste_karten_bonus", "wert": 6, "prozent": 35}],
    "Gegnerabsichten bleiben verborgen. Deine Zukunftskarten wirken mit +40 %.",
    {"absichten_verborgen": True, "zukunft_prozent": 40})

ark(19, "Die Sonne", "Staerke, Erfolg, Energie", "ARKAN",
    "10 Schaden, 6 Heilung, ziehe 1 Karte.",
    [{"op": "schaden", "wert": 10},
     {"op": "heilung", "wert": 6, "ueberschuss": "traum"},
     {"op": "ziehen", "wert": 1}],
    "16 Schaden. Ueberheilung wird zu Schild.",
    [{"op": "schaden", "wert": 16},
     {"op": "spezial", "id": "ueberheilung_zu_schild"}],
    "Nach jedem Kampf +3 HP. Du kannst nicht mehr normal heilen; Ueberheilung wird maximales Leben.",
    {"hp_nach_kampf": 3, "ueberheilung_zu_maxhp": True})

ark(20, "Das Gericht", "Wiedergeburt, Konsequenz", "ARKAN",
    "Hole zwei bereits gelegte Karten zurueck auf die Hand.",
    [{"op": "zurueckholen", "wert": 2}],
    "Hole eine vernichtete Karte zurueck und loese sie sofort aus.",
    [{"op": "zurueckholen", "wert": 1, "aus_vernichtet": True},
     {"op": "spezial", "id": "gericht_wiederholen", "wert": 1}],
    "Stirbst du, kehrst du einmal pro Abschnitt mit 30 % HP zurueck - dafuer +1 Verderbnis pro Kampf.",
    {"wiederbelebung_prozent": 30, "verderbnis_pro_kampf": 1})

ark(21, "Die Welt", "Vollendung, Ganzheit", "MYTHOS",
    "Hast du in diesem Kampf alle vier Farben gelegt: 20 Schaden, 10 Schild, ziehe 2.",
    [{"op": "spezial", "id": "welt_vier_farben", "dann": [
        {"op": "schaden", "wert": 20},
        {"op": "schild", "wert": 10},
        {"op": "ziehen", "wert": 2}]}],
    "Setze dein Deck neu zusammen und ziehe eine perfekte Hand aus vier Farben.",
    [{"op": "spezial", "id": "welt_perfekte_hand"}],
    "Jede Farbe gibt einen Bonus. Hast du alle vier im Deck, verdoppeln sie sich.",
    {"farbboni": True, "verdoppelt_bei_vier": True})

ark(22, "Das Schicksal", "Die verbotene Karte", "MYTHOS",
    "Existiert im Tarot nicht. Loese jede Karte dieses Zuges ein weiteres Mal aus.",
    [{"op": "spezial", "id": "schicksal_alles_nochmal"}],
    "Der Preis: setze deine HP auf die Haelfte. Dein Deck wird fuer diesen Kampf perfekt.",
    [{"op": "spezial", "id": "schicksal_preis"}],
    "Der Endlosmodus beginnt. Alle 5 Raeume kommt ein Verderbtes Arkanum dauerhaft dazu.",
    {"endlos": True, "arkanum_intervall": 5})

if __name__ == "__main__":
    daten = {
        "_hinweis": "Generiert von tools/gen_grosse_arkana.py.",
        "arkana": A,
    }
    with open("data/grosse_arkana.json", "w", encoding="utf-8") as f:
        json.dump(daten, f, ensure_ascii=False, indent=1)
    print("data/grosse_arkana.json: %d Arkana" % len(A))
