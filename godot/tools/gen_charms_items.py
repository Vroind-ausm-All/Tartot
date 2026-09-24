#!/usr/bin/env python3
"""Erzeugt data/charms.json und data/items.json.

Charms sind passiv, stapelbar (max. 5) und laufen ueber die Haken-Engine.
Gleiche Charms verschmelzen, damit die Leiste im Kampf nie voll wird.

Drei Wirkweisen:
  "mod"    - veraendert Werte einer Karte, WAEHREND sie ausgeloest wird
             (flach: vor der Multiplikation, promille: multiplikativ)
  "haken"  - fuehrt Ops aus, wenn ein Ereignis eintritt
  "regel"  - benannte Sonderregel, die der Kern kennt (nur wo Daten nicht reichen)

Alle Werte in "mod" und "haken" gelten PRO STACK.
"""
import json
from collections import OrderedDict

C = []


def ch(nr, cid, name, selten, text, maxi=5, mod=None, haken=None, regel=None, regelwert=None):
    e = OrderedDict([
        ("nr", nr), ("id", cid), ("name", name), ("selten", selten),
        ("max", maxi), ("text", text),
    ])
    if mod:
        e["mod"] = mod
    if haken:
        e["haken"] = haken
    if regel:
        e["regel"] = regel
        e["regelwert"] = regelwert if regelwert is not None else 1
    C.append(e)


# ---------------------------------------------------- 1-10  Angriff und Risiko
ch(1, "klingenanhaenger", "Klingenanhaenger", "GEMEIN",
   "Schwerter verursachen +1 Schaden.",
   mod=[{"wenn": {"farbe": "SCHWERTER"}, "flach": {"schaden": 1}}])
ch(2, "glutknoten", "Glutknoten", "GEMEIN",
   "Stabkarten erzeugen +2 Glut.",
   mod=[{"wenn": {"farbe": "STAEBE"}, "flach": {"status_GLUT": 2}}])
ch(3, "blutmondsplitter", "Blutmondsplitter", "SELTEN",
   "Karten mit Selbstschaden wirken mit +15 %.",
   mod=[{"wenn": {"hat_op": "selbstschaden"}, "promille": 150}])
ch(4, "raubzahn", "Raubzahn", "GEMEIN",
   "Angriffe auf Gegner mit Debuff heilen 1 HP.",
   haken=[{"bei": "schaden_verursacht", "wenn": {"ziel_hat_debuff": True},
           "ops": [{"op": "heilung", "wert": 1, "unskaliert": True}]}])
ch(5, "jagdglocke", "Jagdglocke", "GEMEIN",
   "Der erste Angriff eines Kampfes verursacht +4 Schaden.",
   mod=[{"wenn": {"erster_angriff_im_kampf": True}, "flach": {"schaden": 4}}])
ch(6, "schwarzer_nagel", "Schwarzer Nagel", "SELTEN",
   "Jede dritte gelegte Karte verursacht zusaetzlich 3 Schaden.",
   haken=[{"bei": "karte_ausgeloest", "wenn": {"zaehler_modulo": 3},
           "ops": [{"op": "schaden", "wert": 3, "unskaliert": True}]}])
ch(7, "falkenauge", "Falkenauge", "SELTEN",
   "Greift der Gegner diese Runde an, verursachen deine Angriffe +2 Schaden.",
   mod=[{"wenn": {"gegner_greift_an": True}, "flach": {"schaden": 2}}])
ch(8, "aschekranz", "Aschekranz", "SELTEN",
   "Nach einem Kill verursachen deine Angriffe +1 Schaden fuer den Rest des Kampfes.",
   regel="aschekranz", regelwert=1)
ch(9, "dornenring", "Dornenring", "GEMEIN",
   "Reflektiere 2 geblockten Schaden.",
   regel="dornenring", regelwert=2)
ch(10, "henkerkette", "Henkerkette", "ARKAN",
    "Zukunftskarten wirken mit +10 %.",
    mod=[{"wenn": {"position": "ZUKUNFT"}, "promille": 100}])

# ------------------------------------------------- 11-20  Schutz und Ausdauer
ch(11, "eiserne_muenze", "Eiserne Muenze", "GEMEIN",
    "Muenzkarten geben +2 Schild.",
    mod=[{"wenn": {"farbe": "MUENZEN"}, "flach": {"schild": 2}}])
ch(12, "kelchrand", "Kelchrand", "SELTEN",
    "20 % deiner Ueberheilung wird zu Schild.",
    regel="kelchrand", regelwert=20)
ch(13, "weisser_faden", "Weisser Faden", "GEMEIN",
    "Beginne jeden Kampf mit 3 Schild.",
    haken=[{"bei": "kampf_start", "ops": [{"op": "schild", "wert": 3, "unskaliert": True}]}])
ch(14, "salzsiegel", "Salzsiegel", "SELTEN",
    "Negiere den ersten gegnerischen Debuff pro Kampf.",
    regel="salzsiegel", regelwert=1)
ch(15, "knochenperle", "Knochenperle", "SELTEN",
    "Unter 50 % HP geben Muenzkarten +2 Schild zusaetzlich.",
    mod=[{"wenn": {"farbe": "MUENZEN", "hp_unter_prozent": 50}, "flach": {"schild": 2}}])
ch(16, "mondbrosche", "Mondbrosche", "GEMEIN",
    "Umgekehrte Karten geben zusaetzlich 1 Schild.",
    haken=[{"bei": "karte_ausgeloest", "wenn": {"umgekehrt": True},
            "ops": [{"op": "schild", "wert": 1, "unskaliert": True}]}])
ch(17, "siegel_des_herrschers", "Siegel des Herrschers", "ARKAN",
    "10 % deines Schildes bleibt zwischen den Runden bestehen.",
    regel="schild_rest", regelwert=10)
ch(18, "heiligennadel", "Heiligennadel", "GEMEIN",
    "Jede fuenfte gelegte Karte heilt 1 HP.",
    haken=[{"bei": "karte_ausgeloest", "wenn": {"zaehler_modulo": 5},
            "ops": [{"op": "heilung", "wert": 1, "unskaliert": True}]}])
ch(19, "phoenixfeder", "Phoenixfeder", "MYTHOS",
    "Einmal pro Abschnitt verhindert toedlicher Schaden den Tod (1 HP). Weitere Stacks: +5 HP.",
    maxi=3, regel="phoenixfeder", regelwert=5)
ch(20, "glasherz", "Glasherz", "SELTEN",
    "-3 maximale HP, aber Heilung wirkt mit +25 %.",
    regel="glasherz", regelwert=25)

# ------------------------------------------- 21-30  Kopieren, Loeschen, Deck
ch(21, "silberspiegel", "Silberspiegel", "ARKAN",
    "Kopierte Karten wirken mit +10 %.",
    mod=[{"wenn": {"ist_kopie": True}, "promille": 100}])
ch(22, "rasieramulett", "Rasieramulett", "SELTEN",
    "Kartenloeschen kostet 15 % weniger.",
    regel="rabatt_loeschen", regelwert=15)
ch(23, "leere_karte", "Leere Karte", "ARKAN",
    "Ziehe zu Kampfbeginn 1 Karte zusaetzlich.",
    maxi=2,
    haken=[{"bei": "kampf_start", "ops": [{"op": "ziehen", "wert": 1}]}])
ch(24, "fadenspule", "Fadenspule", "GEMEIN",
    "Wirfst du eine Karte ab, erhaelt die naechste Karte +1 Effektwert.",
    regel="fadenspule", regelwert=1)
ch(25, "wachssiegel", "Wachssiegel", "SELTEN",
    "Verbesserte Karten wirken mit +8 %.",
    mod=[{"wenn": {"stufe_min": 1}, "promille": 80}])
ch(26, "kraehenfeder", "Kraehenfeder", "SELTEN",
    "Beim Mischen des Decks ziehst du 1 Karte zusaetzlich.",
    maxi=2,
    haken=[{"bei": "mischen", "ops": [{"op": "ziehen", "wert": 1}]}])
ch(27, "erinnerungssplitter", "Erinnerungssplitter", "ARKAN",
    "Die erste Karte jedes Kampfes kehrt naechste Runde auf die Hand zurueck. Weitere Stacks: die zweite, dritte ...",
    regel="erinnerungssplitter", regelwert=1)
ch(28, "zwillingsmuenze", "Zwillingsmuenze", "ARKAN",
    "Permanente Kartenkopien erhalten +1 auf ihren Basiswert.",
    mod=[{"wenn": {"ist_kopie": True},
          "flach": {"schaden": 1, "schild": 1, "heilung": 1}}])
ch(29, "leerer_rahmen", "Leerer Rahmen", "SELTEN",
    "Jede permanent geloeschte Karte gibt +1 maximales Leben.",
    regel="leerer_rahmen", regelwert=1)
ch(30, "auge_des_orakels", "Auge des Orakels", "GEMEIN",
    "Du siehst 1 Karte mehr oben auf deinem Deck.",
    maxi=3, regel="sicht_deck", regelwert=1)

# ------------------------------------------------- 31-40  Farb-Synergien
ch(31, "klingenrose", "Klingenrose", "SELTEN",
    "Nach zwei Schwertern erhaelt die naechste Nicht-Schwert-Karte +2 Effekt.",
    regel="klingenrose", regelwert=2)
ch(32, "stabgeflecht", "Stabgeflecht", "SELTEN",
    "Aufeinanderfolgende Stabkarten erhalten jeweils +1 Combo-Schaden.",
    regel="stabgeflecht", regelwert=1)
ch(33, "kelchperle", "Kelchperle", "GEMEIN",
    "Spielst du einen Kelch nach einem Angriff, heilt er +2.",
    mod=[{"wenn": {"farbe": "KELCHE", "nach_angriff": True}, "flach": {"heilung": 2}}])
ch(34, "pentakelkette", "Pentakelkette", "GEMEIN",
    "Endest du einen Kampf mit mindestens 10 Schild, erhaeltst du +2 Gold.",
    haken=[{"bei": "kampf_ende", "wenn": {"schild_min": 10},
            "ops": [{"op": "gold", "wert": 2}]}])
ch(35, "vierfachknoten", "Vierfachknoten", "ARKAN",
    "Sind alle vier Farben gelegt, erhalten alle Karten +2 Effekt fuer den Rest des Kampfes.",
    regel="vierfachknoten", regelwert=2)
ch(36, "schwarzer_kelch", "Schwarzer Kelch", "ARKAN",
    "Heilung schaedigt den Gegner fuer 20 % ihres Wertes.",
    regel="schwarzer_kelch", regelwert=20)
ch(37, "messingstab", "Messingstab", "SELTEN",
    "Glut verursacht pro Tick +1 Schaden.",
    regel="glut_bonus", regelwert=1)
ch(38, "silberklinge", "Silberklinge", "SELTEN",
    "Schwerter ignorieren 1 gegnerisches Schild.",
    mod=[{"wenn": {"farbe": "SCHWERTER"}, "schild_durchdringung": 1}])
ch(39, "goldenes_pentakel", "Goldenes Pentakel", "SELTEN",
    "Jede dritte Muenzkarte erzeugt +1 temporaeres Luck.",
    haken=[{"bei": "karte_ausgeloest", "wenn": {"farbe": "MUENZEN", "zaehler_modulo": 3},
            "ops": [{"op": "luck", "wert": 1}]}])
ch(40, "blaues_band", "Blaues Band", "SELTEN",
    "Jede dritte Kelchkarte entfernt 1 Debuff. Jeder Stack senkt die benoetigte Anzahl um 1 (min. 1).",
    regel="blaues_band", regelwert=3)

# ------------------------------------------------- 41-50  Luck und Oekonomie
ch(41, "narrenklee", "Narrenklee", "SELTEN",
    "Beginne jeden Abschnitt mit +1 Luck.",
    maxi=3,
    haken=[{"bei": "abschnitt_start", "ops": [{"op": "luck", "wert": 1}]}])
ch(42, "auge_des_haendlers", "Auge des Haendlers", "GEMEIN",
    "Haendlerpreise -5 %.",
    regel="rabatt_laden", regelwert=5)
ch(43, "gebogene_muenze", "Gebogene Muenze", "GEMEIN",
    "+1 kostenloser Belohnungs-Reroll pro Abschnitt.",
    maxi=3, regel="reroll_frei", regelwert=1)
ch(44, "katzenzahn", "Katzenzahn", "SELTEN",
    "Chance auf seltene Karten +4 Prozentpunkte.",
    regel="selten_bonus", regelwert=4)
ch(45, "gluecksglocke", "Gluecksglocke", "SELTEN",
    "Positive Ereignisvarianten werden um 6 Prozentpunkte wahrscheinlicher.",
    regel="ereignis_glueck", regelwert=6)
ch(46, "giermotte", "Giermotte", "VERKEHRT",
    "+10 % Gold, aber Gegner erhalten +3 % maximale HP.",
    regel="giermotte", regelwert=10)
ch(47, "goldener_wuerfel", "Goldener Wuerfel", "ARKAN",
    "Jeder zweite Stack gibt eine zusaetzliche Auswahl bei Kartenbelohnungen.",
    maxi=4, regel="wuerfel", regelwert=1)
ch(48, "sternenstaub", "Sternenstaub", "SELTEN",
    "Kartenbelohnungen sind mit +8 Prozentpunkten Chance bereits verbessert.",
    regel="sternenstaub", regelwert=8)
ch(49, "gebrochene_krone", "Gebrochene Krone", "ARKAN",
    "Elitegegner geben +20 % Chance auf einen zusaetzlichen Charm.",
    regel="krone", regelwert=20)
ch(50, "weltenfaden", "Weltenfaden", "MYTHOS",
    "Fuer je 5 unterschiedliche Charms erhalten alle Karten +2 % Wirkung pro Stack.",
    regel="weltenfaden", regelwert=2)

# ==========================================================================
I = []


def it(nr, iid, name, selten, text, ops=None, wo="kampf", regel=None):
    e = OrderedDict([
        ("nr", nr), ("id", iid), ("name", name), ("selten", selten),
        ("text", text), ("wo", wo),
    ])
    if ops:
        e["ops"] = ops
    if regel:
        e["regel"] = regel
    I.append(e)


it(1, "spiegelscherbe", "Spiegelscherbe", "SELTEN",
   "Erstelle permanent eine Kopie einer normalen Karte.",
   wo="karte", regel="kopie_permanent")
it(2, "schere_des_schicksals", "Schere des Schicksals", "SELTEN",
   "Loesche permanent eine Karte aus deinem Deck.",
   wo="karte", regel="loeschen_permanent")
it(3, "schwarzes_wachs", "Schwarzes Wachs", "GEMEIN",
   "Drehe eine Karte permanent aufrecht oder umgekehrt.",
   wo="karte", regel="drehen_permanent")
it(4, "goldene_nadel", "Goldene Nadel", "SELTEN",
   "Verbessere eine Karte permanent.",
   wo="karte", regel="aufwerten_permanent")
it(5, "orakellinse", "Orakellinse", "GEMEIN",
   "Sieh die naechsten 5 Karten und ordne sie neu.",
   ops=[{"op": "spaehen", "wert": 5}])
it(6, "sonnenphiole", "Sonnenphiole", "GEMEIN",
   "Heile sofort 15 HP.",
   ops=[{"op": "heilung", "wert": 15, "unskaliert": True}], wo="immer")
it(7, "mondsalz", "Mondsalz", "SELTEN",
   "Entferne alle Debuffs und enthuelle 3 Gegneraktionen.",
   ops=[{"op": "debuff_weg", "wert": 9}, {"op": "absicht_zeigen", "wert": 3}])
it(8, "turmpulver", "Turmpulver", "SELTEN",
   "20 Schaden an allen Gegnern; dein Schild wird zerstoert.",
   ops=[{"op": "schaden", "wert": 20, "alle": True, "unskaliert": True},
        {"op": "spezial", "id": "turm_schild_null"}])
it(9, "teufelspakt", "Teufelspakt", "VERKEHRT",
   "Der naechste Haendlerkauf kostet 0 Gold; du erhaeltst dafuer einen Fluch.",
   wo="run", regel="teufelspakt")
it(10, "band_der_liebenden", "Band der Liebenden", "ARKAN",
    "Verbinde zwei Karten fuer die naechsten 3 Kaempfe.",
    wo="run", regel="band")
it(11, "strick_des_gehaengten", "Strick des Gehaengten", "SELTEN",
    "Ueberspringe eine gegnerische Aktion; dein naechster Zug hat nur 2 Kartenaktionen.",
    ops=[{"op": "spezial", "id": "gegner_zug_ueberspringen"},
         {"op": "legungen_naechster_zug", "wert": 2}])
it(12, "pentakelbeutel", "Pentakelbeutel", "GEMEIN",
    "Sofort +40 Gold.",
    ops=[{"op": "gold", "wert": 40}], wo="immer")
it(13, "knochenschluessel", "Knochenschluessel", "SELTEN",
    "Oeffnet eine verschlossene Truhe oder einen geheimen Weg.",
    wo="run", regel="schluessel")
it(14, "haendlermarke", "Haendlermarke", "GEMEIN",
    "Erneuere das komplette Haendlerangebot kostenlos.",
    wo="laden", regel="laden_reroll")
it(15, "aschephiole", "Aschephiole", "ARKAN",
    "Bei Tod automatisch verbraucht: Wiederbelebung mit 25 % HP.",
    wo="passiv", regel="wiederbelebung")
it(16, "sternenwasser", "Sternenwasser", "SELTEN",
    "+1 Luck fuer den Rest des Abschnitts.",
    ops=[{"op": "luck", "wert": 1, "dauerhaft": True}], wo="immer")
it(17, "siegel_des_kaisers", "Siegel des Kaisers", "SELTEN",
    "Beginne die naechsten 3 Kaempfe mit 12 Schild.",
    wo="run", regel="kaisersiegel")
it(18, "tinte_der_priesterin", "Tinte der Priesterin", "SELTEN",
    "Verwandle eine Karte in eine zufaellige Karte derselben Farbe und Seltenheit.",
    wo="karte", regel="verwandeln")
it(19, "radmarke", "Radmarke", "GEMEIN",
    "Wuerfle eine Kartenbelohnung oder ein Ereignis komplett neu.",
    wo="belohnung", regel="belohnung_reroll")
it(20, "weltenkompass", "Weltenkompass", "ARKAN",
    "Zeige alle kommenden Raeume des Abschnitts und waehle frei den naechsten.",
    wo="run", regel="kompass")
it(21, "laterne_des_eremiten", "Laterne des Eremiten", "SELTEN",
    "Entferne eine Fluchkarte permanent.",
    wo="karte", regel="fluch_entfernen")
it(22, "glocke_des_gerichts", "Glocke des Gerichts", "MYTHOS",
    "Hole eine zuvor geloeschte Karte als verbesserte Version zurueck ins Deck.",
    wo="run", regel="gericht_glocke")


if __name__ == "__main__":
    with open("data/charms.json", "w", encoding="utf-8") as f:
        json.dump({"_hinweis": "Generiert von tools/gen_charms_items.py.",
                   "charms": C}, f, ensure_ascii=False, indent=1)
    with open("data/items.json", "w", encoding="utf-8") as f:
        json.dump({"_hinweis": "Generiert von tools/gen_charms_items.py.",
                   "items": I}, f, ensure_ascii=False, indent=1)
    print("data/charms.json: %d Charms" % len(C))
    print("data/items.json: %d Items" % len(I))
    # Konsistenzpruefung: keine doppelten IDs, jede Wirkweise gesetzt.
    ids = [c["id"] for c in C]
    assert len(ids) == len(set(ids)), "doppelte Charm-ID"
    ohne = [c["id"] for c in C if not any(k in c for k in ("mod", "haken", "regel"))]
    assert not ohne, "Charm ohne Wirkung: %s" % ohne
    iids = [x["id"] for x in I]
    assert len(iids) == len(set(iids)), "doppelte Item-ID"
    print("Pruefung: ok")
