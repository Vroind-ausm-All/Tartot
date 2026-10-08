# TARTOT

Ein groteskes Tarot-Roguelike für Android und iOS, Hochformat.

> Du spielst nicht einfach Tarotkarten aus — du legst in jedem Zug eine
> Legung aus **Vergangenheit**, **Gegenwart** und **Zukunft** und versuchst,
> das vorhergesagte Schicksal zu manipulieren.

**Einfach zu spielen. Einfach zu lesen. Aber je länger der Run dauert, desto
mehr verwandeln Deck, Charms und Welt sich in eine völlig entgleiste
Tarot-Maschine.**

---

## Der Kern in dreißig Sekunden

Kein Mana. Du legst bis zu **3 Karten pro Zug**, eine pro Position:

| Position | Wirkung |
|---|---|
| **Vergangenheit** | 70 % — wiederholt zusätzlich 50 % deiner letzten Gegenwart |
| **Gegenwart** | 100 % — sofort und zuverlässig |
| **Zukunft** | 200 % — aber erst nächste Runde, wenn du so lange lebst |

Der Gegner zeigt immer seine nächste Aktion. Du siehst also beide Zukünfte.
**Schicksalsfäden** (max. 5) erlauben, was sonst unmöglich wäre: Karten
drehen, Positionen tauschen, die Zukunft vorziehen, die gegnerische Absicht
neu würfeln.

Innerhalb der Legung zählen auch die **Werte**: drei gleiche ergeben
*Konvergenz*, drei aufeinanderfolgende eine *Schicksalskette* — und wenn die
drei Werte **exakt 21** ergeben, ruft das **Die Welt** und alle Karten lösen
erneut aus. Eine schwache 2 kann dadurch die wertvollste Karte im Deck sein.

---

## Dokumentation

| | |
|---|---|
| [`docs/01_GDD.md`](docs/01_GDD.md) | Vollständige Spielmechanik |
| [`docs/02_TECHNIK.md`](docs/02_TECHNIK.md) | Sprach- und Engine-Entscheidung, Architektur, Store-Veröffentlichung für 2,49 € |
| [`docs/03_ART.md`](docs/03_ART.md) | Artdirection „Occult Clean", Cartoon-Horror |
| [`docs/04_BALANCING.md`](docs/04_BALANCING.md) | Formeln, gemessene Zahlen, offene Punkte |
| [`docs/05_ROADMAP.md`](docs/05_ROADMAP.md) | Meilensteine und Risiken |

---

## Projektaufbau

```
core/    Regelkern — reines GDScript, kein Node, keine Szene, headless lauffähig
data/    Inhalte als JSON: Karten, Arkana, Charms, Items, Gegner, Deuter
tools/   Generatoren (Python), Simulation, Diagnose, Screenshots
tests/   Testlauf ohne Framework-Abhängigkeit
ui/      Szenen und Schirme — kennen den Kern, der Kern kennt sie nicht
```

## Loslegen

Benötigt **Godot 4.4** (kein Editor nötig für Tests und Simulation).

```bash
# Einmalig und nach jeder neuen class_name-Datei: Klassencache aufbauen
godot --headless --path . --import

# Testlauf — 193 Prüfungen
godot --headless --path . --script tests/lauf.gd

# Balancing: 200 komplette Runs spielen und auswerten
godot --headless --path . --script tools/sim.gd -- --runs=200

# Einen einzelnen Run Raum für Raum protokollieren
godot --headless --path . --script tools/diagnose.gd -- --seed=1003

# Layout ohne Gerät prüfen (legt PNGs in /tmp/tartot_shots ab)
xvfb-run -a godot --path . --script tools/screenshot.gd --resolution 540x960

# Spielen
godot --path .
```

Inhalte werden aus Generatoren erzeugt, nicht von Hand editiert:

```bash
python3 tools/gen_kleine_arkana.py    # 56 Kleine Arkana aus Formeln
python3 tools/gen_grosse_arkana.py    # 22 Große Arkana, drei Gesichter
python3 tools/gen_charms_items.py     # 50 Charms, 22 Items
python3 tools/gen_gegner.py           # 24 Gegner inklusive 7 Bossen
```

## Stand

Der Regelkern ist vollständig und gemessen: 193 Tests, 21,5 % Siegquote für
einen Autopiloten, der die Regeln kennt, aber nicht rechnet. Die UI ist
spielbar, aber ohne Animation und ohne Kunst. Details in
[`docs/05_ROADMAP.md`](docs/05_ROADMAP.md).
