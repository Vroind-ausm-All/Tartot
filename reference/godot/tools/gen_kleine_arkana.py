#!/usr/bin/env python3
"""Erzeugt data/kleine_arkana.json.

Die 40 Zahlenkarten entstehen aus Formeln - so bleibt die Kurve glatt und
eine Balancing-Aenderung ist eine Zeile hier statt 40 Handgriffe im JSON.
Die 16 Hofkarten sind Figuren und stehen handgeschrieben darunter, weil jede
eine eigene Regel mitbringt.

Aufruf:  python3 tools/gen_kleine_arkana.py
"""
import json
import math
from collections import OrderedDict

CEIL = lambda x: int(math.ceil(x))


def schwerter(r):
    """Schaden, Blutung, Verwundbar. Aufrecht = Wert, umgekehrt = doppelt mit Preis."""
    auf = [{"op": "schaden", "wert": r}]
    if r == 1:
        auf.append({"op": "status", "st": "BLUTUNG", "wert": 3, "ziel": "gegner"})
    elif 4 <= r <= 6:
        auf.append({"op": "status", "st": "VERWUNDBAR", "wert": 1, "ziel": "gegner"})
    elif r >= 7:
        auf.append({"op": "status", "st": "BLUTUNG", "wert": r // 3, "ziel": "gegner"})
        # Ikonisch: die 8 schlaegt gezielt in offene Wunden.
        if r == 8:
            auf.append({"op": "schaden", "wert": 4,
                        "wenn": {"ziel_status": "VERWUNDBAR"}})
    um = [
        {"op": "schaden", "wert": 2 * r},
        {"op": "selbstschaden", "wert": CEIL(r / 2)},
    ]
    return auf, um


def staebe(r):
    """Combo und Glut. Jede weitere Stabkarte im Zug verstaerkt die naechste."""
    auf = [
        {"op": "schaden", "wert": r},
        {"op": "status", "st": "GLUT", "wert": CEIL(r / 3), "ziel": "gegner"},
    ]
    um = [
        {"op": "schaden", "wert": CEIL(r / 2)},
        {"op": "status", "st": "GLUT", "wert": r, "ziel": "gegner"},
    ]
    return auf, um


def kelche(r):
    """Heilung, die bei vollem Leben zu Traum wird. Umgekehrt direkt Traum."""
    auf = [{"op": "heilung", "wert": r + 1, "ueberschuss": "traum"}]
    if r >= 7:
        auf.append({"op": "debuff_weg", "wert": 1})
    um = [
        {"op": "traum", "wert": r},
        {"op": "debuff_weg", "wert": 1},
    ]
    return auf, um


def muenzen(r):
    """Schild und Gold. Umgekehrt weniger Schild, dafuer Rueckschlag und Zins."""
    auf = [{"op": "schild", "wert": r + 2}]
    if r >= 8:
        auf.append({"op": "gold", "wert": 1})
    um = [
        {"op": "schild", "wert": (r + 2) // 2},
        {"op": "status", "st": "VERANKERT", "wert": 1, "ziel": "selbst"},
        {"op": "gold", "wert": 1},
        {"op": "spezial", "id": "muenze_rueckschlag", "wert": (r + 2) + r},
    ]
    return auf, um


FARBEN = OrderedDict([
    ("SCHWERTER", ("schwerter", schwerter, "Schaden, Blutung, Verwundbar")),
    ("STAEBE", ("staebe", staebe, "Combo, Glut, Mehrfachtreffer")),
    ("KELCHE", ("kelche", kelche, "Heilung, Traum, Statuskontrolle")),
    ("MUENZEN", ("muenzen", muenzen, "Schild, Gold, Vorbereitung")),
])

RANGNAME = {1: "Ass", 11: "Bube", 12: "Ritter", 13: "Koenigin", 14: "Koenig"}

# Ab welchem Wert eine Zahlenkarte als selten gilt. Hohe Werte sind nicht
# automatisch besser, aber sie eroeffnen mehr Muster (Summe 21).
def seltenheit(r):
    if r <= 3:
        return "GEMEIN"
    if r <= 7:
        return "GEMEIN"
    if r <= 9:
        return "SELTEN"
    return "ARKAN"


# --------------------------------------------------------------------- Figuren
# Hofkarten sind keine Aktionen, sondern bleibende Figuren am Spielfeldrand.
# Es kann nur eine aktiv sein; eine neue ersetzt die alte.
# Die Haken sind dieselben wie bei Charms, damit es nur eine Engine gibt.
FIGUREN = {
    ("SCHWERTER", 11): {
        "name": "Bube der Schwerter",
        "text": "Jede erste Schwertkarte pro Zug verursacht +3 Schaden.",
        "mod": [{"wenn": {"farbe": "SCHWERTER", "erste_der_farbe_im_zug": True},
                 "flach": {"schaden": 3}}],
    },
    ("SCHWERTER", 12): {
        "name": "Ritter der Schwerter",
        "text": "Deine Schwerter ignorieren 3 Schild.",
        "mod": [{"wenn": {"farbe": "SCHWERTER"}, "schild_durchdringung": 3}],
    },
    ("SCHWERTER", 13): {
        "name": "Koenigin der Schwerter",
        "text": "Jeder dritte Schwertangriff trifft zweimal.",
        "haken": [{"bei": "karte_ausgeloest", "wenn": {"farbe": "SCHWERTER", "zaehler_modulo": 3},
                   "ops": [{"op": "wiederholen_letzte", "anteil": 1000}]}],
    },
    ("SCHWERTER", 14): {
        "name": "Koenig der Schwerter",
        "text": "Blutung, die du verursachst, sinkt nicht mehr von selbst.",
        "regel": "blutung_bleibt",
    },
    ("STAEBE", 11): {
        "name": "Bube der Staebe",
        "text": "Die erste Stabkarte jedes Zuges gibt 2 Glut zusaetzlich.",
        "haken": [{"bei": "karte_ausgeloest", "wenn": {"farbe": "STAEBE", "erste_der_farbe_im_zug": True},
                   "ops": [{"op": "status", "st": "GLUT", "wert": 2, "ziel": "gegner"}]}],
    },
    ("STAEBE", 12): {
        "name": "Ritter der Staebe",
        "text": "Drei Stabkarten in einem Zug: 8 Schaden an allen Gegnern.",
        "haken": [{"bei": "zug_ende", "wenn": {"farbe_im_zug_min": ["STAEBE", 3]},
                   "ops": [{"op": "schaden", "wert": 8, "alle": True}]}],
    },
    ("STAEBE", 13): {
        "name": "Koenigin der Staebe",
        "text": "Glut tickt zusaetzlich zu Zugbeginn.",
        "regel": "glut_doppelt",
    },
    ("STAEBE", 14): {
        "name": "Koenig der Staebe",
        "text": "Deine Combo-Stufe steigt auch durch Nicht-Stabkarten.",
        "regel": "combo_universell",
    },
    ("KELCHE", 11): {
        "name": "Bube der Kelche",
        "text": "Heilung gibt zusaetzlich 1 Schild.",
        "haken": [{"bei": "heilung", "ops": [{"op": "schild", "wert": 1, "unskaliert": True}]}],
    },
    ("KELCHE", 12): {
        "name": "Ritter der Kelche",
        "text": "Spielst du einen Kelch nach einem Angriff, heilt er +3.",
        "mod": [{"wenn": {"farbe": "KELCHE", "nach_angriff": True}, "flach": {"heilung": 3}}],
    },
    ("KELCHE", 13): {
        "name": "Koenigin der Kelche",
        "text": "Die Haelfte deiner Ueberheilung wird zu Schicksal.",
        "regel": "ueberheilung_zu_faden",
    },
    ("KELCHE", 14): {
        "name": "Koenig der Kelche",
        "text": "Zu Zugbeginn: 1 Traum. Traum kann Karten verdoppeln.",
        "haken": [{"bei": "zug_start", "ops": [{"op": "traum", "wert": 1, "unskaliert": True}]}],
    },
    ("MUENZEN", 11): {
        "name": "Bube der Muenzen",
        "text": "Beginne jeden Zug mit 3 Schild.",
        "haken": [{"bei": "zug_start", "ops": [{"op": "schild", "wert": 3, "unskaliert": True}]}],
    },
    ("MUENZEN", 12): {
        "name": "Ritter der Muenzen",
        "text": "Ueberschuessiges Schild am Zugende wird zu 1 Gold je 6 Schild.",
        "regel": "schild_zu_gold",
    },
    ("MUENZEN", 13): {
        "name": "Koenigin der Muenzen",
        "text": "Ein Viertel deines Schildes wird beim Verfallen zu Schaden.",
        "regel": "schild_zu_schaden",
    },
    ("MUENZEN", 14): {
        "name": "Koenig der Muenzen",
        "text": "Am Kampfende: +30 % Gold.",
        "regel": "gold_plus_30",
    },
}


def bauen():
    karten = []
    for farbe, (praefix, fn, thema) in FARBEN.items():
        for r in range(1, 11):
            auf, um = fn(r)
            rn = RANGNAME.get(r, str(r))
            karten.append(OrderedDict([
                ("id", "%s_%02d" % (praefix, r)),
                ("farbe", farbe),
                ("rang", r),
                ("name", "%s der %s" % (rn, farbe.capitalize())),
                ("selten", seltenheit(r)),
                ("figur", False),
                ("aufrecht", auf),
                ("umgekehrt", um),
            ]))
        for r in (11, 12, 13, 14):
            fig = FIGUREN[(farbe, r)]
            eintrag = OrderedDict([
                ("id", "%s_%02d" % (praefix, r)),
                ("farbe", farbe),
                ("rang", r),
                ("name", fig["name"]),
                ("selten", "SELTEN" if r <= 12 else "ARKAN"),
                ("figur", True),
                ("text", fig["text"]),
                ("aufrecht", []),
                ("umgekehrt", []),
            ])
            for k in ("mod", "haken", "regel"):
                if k in fig:
                    eintrag[k] = fig[k]
            karten.append(eintrag)
    return {
        "_hinweis": "Generiert von tools/gen_kleine_arkana.py - nicht per Hand aendern.",
        "karten": karten,
    }


if __name__ == "__main__":
    daten = bauen()
    with open("data/kleine_arkana.json", "w", encoding="utf-8") as f:
        json.dump(daten, f, ensure_ascii=False, indent=1)
    print("data/kleine_arkana.json: %d Karten" % len(daten["karten"]))
