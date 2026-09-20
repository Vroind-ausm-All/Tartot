#!/usr/bin/env python3
"""Erzeugt data/gegner.json.

Gegner sind Tarotfiguren im Cartoon-Horror-Look. Jeder zeigt immer seine
naechste Aktion - das ist die Grundlage der ganzen Vorhersage-Fantasie.

Absichtsmuster:
  "zyklus"  - feste Reihenfolge, die der Spieler lernen kann (gut fuer normale Gegner)
  "gewicht" - gewichteter Zufall (gut fuer Elites, weniger vorhersagbar)

Bosse brechen zusaetzlich eine Grundregel ("regeln").
"""
import json
from collections import OrderedDict

G = []


def ang(wert, mal=1):
    return {"art": "angriff", "wert": wert, "mal": mal}


def blk(wert):
    return {"art": "block", "wert": wert}


def deb(st, wert):
    return {"art": "debuff", "st": st, "wert": wert}


def hei(wert):
    return {"art": "heilen", "wert": wert}


def reg(rid, wert=1):
    return {"art": "regel", "id": rid, "wert": wert}


def g(gid, name, typ, abschnitt, hp, silhouette, beschreibung, absichten,
      muster="zyklus", regeln=None, gold=None):
    e = OrderedDict([
        ("id", gid), ("name", name), ("typ", typ), ("abschnitt", abschnitt),
        ("hp", hp), ("silhouette", silhouette), ("beschreibung", beschreibung),
        ("muster", muster), ("absichten", absichten),
    ])
    if regeln:
        e["regeln"] = regeln
    if gold:
        e["gold"] = gold
    G.append(e)


# ======================================================== ABSCHNITT I
# "Der Jahrmarkt der Blicke"
g("lachender_henker", "Der lachende Henker", "NORMAL", 1, [26, 32],
  "henker",
  "Ein viel zu langer Hals, ein viel zu breites Grinsen. Der Strick haengt lose.",
  [[ang(8)], [ang(6), deb("BLUTUNG", 2)], [ang(14)]])

g("zahnmuenze", "Die Muenze mit Zaehnen", "NORMAL", 1, [20, 25],
  "muenze_zaehne",
  "Sie rollt. Sie klappert. Wenn sie sich oeffnet, sieht man das Gebiss.",
  [[blk(8)], [ang(5), ang(5)], [blk(6), ang(4)]])

g("kelchtrinker", "Der Kelchtrinker", "NORMAL", 1, [30, 36],
  "kelchtrinker",
  "Er trinkt aus einem Kelch, in dem ein Auge schwimmt. Das Auge sieht dich.",
  [[ang(7)], [hei(6)], [ang(11)]])

g("schreiende_klinge", "Die schreiende Klinge", "NORMAL", 1, [15, 19],
  "klinge_mund",
  "Ein Schwert mit einem Mund in der Schneide. Es schreit den eigenen Namen.",
  [[ang(12)], [ang(4), deb("VERWUNDBAR", 2)]])

g("zwillingsschatten", "Die Zwillingsschatten", "NORMAL", 1, [17, 21],
  "schatten_paar",
  "Zwei Schatten einer Figur, die es nicht gibt. Sie tun nicht dasselbe.",
  [[ang(5)], [blk(5), ang(5)], [deb("SCHWACH", 2), ang(6)]])

g("kleiner_mond", "Der kleine grinsende Mond", "NORMAL", 1, [23, 28],
  "mond_klein",
  "Er haengt zu niedrig und grinst zu breit. Manchmal blinzelt er nicht.",
  [[deb("VERHUELLT", 1), ang(6)], [ang(9)], [ang(7), deb("SCHWACH", 1)]])

g("papierpriester", "Der Papierpriester", "ELITE", 1, [52, 60],
  "priester_papier",
  "Sein Gewand ist aus Vertraegen. Er liest laut, aber niemand hoert Worte.",
  [[ang(11)], [reg("verdeckte_karte", 1), ang(8)], [blk(10), ang(9)],
   [ang(7), ang(7)]],
  muster="gewicht",
  regeln=[{"id": "verdeckte_karte", "intervall": 2, "wert": 1}],
  gold=[26, 34])

g("fette_ratte", "Die fette Ratte des Haendlers", "ELITE", 1, [44, 50],
  "ratte",
  "Sie hat Muenzen gefressen. Man hoert sie klimpern, wenn sie atmet.",
  [[ang(9), reg("gold_stehlen", 6)], [blk(12)], [ang(13)]],
  muster="gewicht",
  gold=[30, 40])

# ======================================================== ABSCHNITT II
# "Die Gasse der falschen Namen"
g("hutmann", "Der Hutmann", "NORMAL", 2, [34, 40],
  "hutmann",
  "Unter dem Hut ist noch ein Hut. Und darunter wieder einer.",
  [[ang(13)], [ang(8), blk(8)], [deb("VERWUNDBAR", 2), ang(10)]])

g("augensammlerin", "Die Augensammlerin", "NORMAL", 2, [30, 36],
  "augensammlerin",
  "Sie traegt die Augen anderer an einer Schnur. Keines davon ist ihres.",
  [[deb("VERHUELLT", 2), ang(9)], [ang(15)], [hei(8), ang(6)]])

g("blutorgel", "Die Blutorgel", "NORMAL", 2, [40, 46],
  "orgel",
  "Jede Pfeife ein Finger. Sie spielt sich selbst und trifft nie denselben Ton.",
  [[ang(6), ang(6), ang(6)], [blk(14)], [ang(18)]])

g("wachsbote", "Der Wachsbote", "NORMAL", 2, [28, 33],
  "wachsbote",
  "Er bringt eine Nachricht, die schmilzt, bevor man sie lesen kann.",
  [[deb("SCHWACH", 2), deb("VERWUNDBAR", 2)], [ang(14)], [ang(9), hei(5)]])

g("spiegelschwester", "Die Spiegelschwester", "ELITE", 2, [78, 88],
  "spiegel_schwester",
  "Sie ahmt dich nach, aber immer eine Sekunde zu spaet - und etwas zu genau.",
  [[reg("letzte_karte_kopieren", 1)], [ang(16)], [blk(14), ang(10)],
   [ang(8), deb("BLUTUNG", 4)]],
  muster="gewicht",
  regeln=[{"id": "letzte_karte_kopieren", "intervall": 2, "wert": 1}],
  gold=[32, 42])

# ======================================================== ABSCHNITT III
# "Das Haus ohne Innen"
g("uhrenwurm", "Der Uhrenwurm", "NORMAL", 3, [52, 60],
  "uhrenwurm",
  "Er frisst Minuten. In seinem Bauch schlaegt es immer eins.",
  [[ang(17)], [reg("zukunft_stehlen", 1), ang(10)], [blk(16), ang(12)]],
  regeln=[{"id": "zukunft_stehlen", "intervall": 3, "wert": 1}])

g("sieben_finger", "Die Sieben Finger", "NORMAL", 3, [46, 54],
  "finger",
  "Sieben Finger ohne Hand. Sie zaehlen mit, wie oft du getroffen hast.",
  [[ang(7), ang(7), ang(7)], [deb("BLUTUNG", 5)], [ang(21)]])

g("laecheln_ohne_gesicht", "Das Laecheln ohne Gesicht", "NORMAL", 3, [58, 66],
  "laecheln",
  "Nur ein Mund, frei schwebend. Er wird breiter, je laenger der Kampf dauert.",
  [[ang(12), deb("SCHWACH", 2)], [hei(12)], [ang(20)],
   [deb("VERWUNDBAR", 3), ang(14)]],
  muster="gewicht")

g("henker_verkehrt", "Der Henker (umgekehrt)", "ELITE", 3, [104, 116],
  "henker_verkehrt",
  "Derselbe Hals, dasselbe Grinsen - aber der Strick haelt jetzt ihn.",
  [[ang(20)], [ang(11), deb("BLUTUNG", 6)], [blk(18), ang(14)],
   [reg("schild_klauen", 1), ang(12)]],
  muster="gewicht",
  gold=[38, 48])

# =============================================================== BOSSE
# Bosse haben nicht viel mehr HP, sie brechen eine Grundregel.
g("boss_turm", "XVI - Der Turm", "BOSS", 1, [84, 84],
  "turm",
  "Er waechst hinter dir hoch. Jeder Blitz nimmt dir eine Moeglichkeit.",
  [[ang(14)], [ang(9), ang(9)], [reg("position_zerstoeren", 1), ang(10)],
   [ang(22)]],
  muster="zyklus",
  # Der Slot-Verlust soll ein Rennen sein, kein Todesurteil: ab Runde 4, nicht 3.
  # Bei 84 HP schafft ein solides Abschnitt-1-Deck ihn in 4-6 Runden und
  # verliert hoechstens einen Slot - ein schwaches Deck spuert die Spirale.
  regeln=[{"id": "position_zerstoeren", "intervall": 4, "wert": 1,
           "text": "Ab Runde 4 zerstoert der Turm alle 4 Runden eine Position deiner Legung."}],
  gold=[45, 60])

g("boss_mond", "XVIII - Der Mond", "BOSS", 2, [190, 190],
  "mond_gross",
  "Du siehst sein Grinsen. Sonst siehst du nichts - nicht einmal deine eigenen Karten.",
  [[ang(17)], [reg("karte_verdecken", 1), ang(12)], [hei(15), ang(10)],
   [ang(11), deb("VERHUELLT", 3)], [ang(26)]],
  muster="zyklus",
  regeln=[{"id": "karte_verdecken", "intervall": 2, "wert": 1,
           "text": "Jede 2. Runde ist eine deiner Handkarten verdeckt - Orientierung unbekannt."},
          {"id": "hp_verborgen", "intervall": 0, "wert": 1,
           "text": "Seine HP werden nur ungefaehr angezeigt."}],
  gold=[45, 60])

g("boss_tod", "XIII - Der Tod", "BOSS", 3, [260, 260],
  "tod",
  "Ein weisses Gesicht, ein roter Schnitt. Er nimmt nicht dich - er nimmt deine Karten.",
  [[ang(22)], [reg("karte_markieren", 1), ang(14)], [blk(20), ang(16)],
   [ang(13), deb("BLUTUNG", 8)], [ang(34)]],
  muster="zyklus",
  regeln=[{"id": "karte_markieren", "intervall": 3, "wert": 1,
           "text": "Alle 3 Runden markiert er eine Karte. Endet der Kampf nicht rechtzeitig, ist sie fuer den Run verloren."}],
  gold=[55, 70])

g("boss_teufel", "XV - Der Teufel", "BOSS", 4, [320, 320],
  "teufel",
  "Er kaempft nicht gern. Er verhandelt. Und er gewinnt fast immer.",
  [[ang(20)], [reg("pakt_anbieten", 1)], [ang(15), deb("VERWUNDBAR", 3)],
   [ang(28)], [hei(25), ang(12)]],
  muster="zyklus",
  regeln=[{"id": "pakt_anbieten", "intervall": 3, "wert": 1,
           "text": "Er bietet dir Pakte an: +100 % Schaden, aber eine Karte wird verflucht."}],
  gold=[60, 80])

g("boss_rad", "X - Rad des Schicksals", "BOSS", 5, [380, 380],
  "rad",
  "Es dreht. Deine Positionen bleiben nicht, wo du sie gelegt hast.",
  [[ang(24)], [reg("positionen_tauschen", 1), ang(16)], [blk(24), ang(18)],
   [ang(36)]],
  muster="zyklus",
  regeln=[{"id": "positionen_tauschen", "intervall": 1, "wert": 1,
           "text": "Jede Runde werden deine gelegten Positionen zufaellig vertauscht."}],
  gold=[65, 85])

g("boss_gehaengter", "XII - Der Gehaengte", "BOSS", 6, [420, 420],
  "gehaengter",
  "Er haengt verkehrt. Von seiner Seite aus liegt deine Zukunft links.",
  [[ang(26)], [reg("legung_spiegeln", 1), ang(18)], [ang(14), ang(14)],
   [ang(40)]],
  muster="zyklus",
  regeln=[{"id": "legung_spiegeln", "intervall": 0, "wert": 1,
           "text": "Die Legung ist dauerhaft gespiegelt: Zukunft <- Gegenwart <- Vergangenheit."}],
  gold=[70, 90])

g("boss_welt", "XXI - Die Welt", "BOSS", 7, [520, 520],
  "welt",
  "Alles, was du besiegt hast, ist noch da. Es sieht nur jetzt zusammen aus.",
  [[ang(28)], [reg("alle_bossregeln", 1), ang(20)], [blk(30), ang(22)],
   [ang(18), ang(18)], [ang(48)]],
  muster="zyklus",
  regeln=[{"id": "alle_bossregeln", "intervall": 0, "wert": 1,
           "text": "Alle Bossregeln dieses Runs sind gleichzeitig aktiv, jeweils abgeschwaecht."}],
  gold=[90, 120])


if __name__ == "__main__":
    ids = [x["id"] for x in G]
    assert len(ids) == len(set(ids)), "doppelte Gegner-ID"
    for x in G:
        assert x["absichten"], "%s ohne Absichten" % x["id"]
        for runde in x["absichten"]:
            assert isinstance(runde, list), "%s: Absicht muss Liste sein" % x["id"]
    with open("data/gegner.json", "w", encoding="utf-8") as f:
        json.dump({"_hinweis": "Generiert von tools/gen_gegner.py.", "gegner": G},
                  f, ensure_ascii=False, indent=1)
    n = {"NORMAL": 0, "ELITE": 0, "BOSS": 0}
    for x in G:
        n[x["typ"]] += 1
    print("data/gegner.json: %d Gegner (%d normal, %d Elite, %d Boss)"
          % (len(G), n["NORMAL"], n["ELITE"], n["BOSS"]))
