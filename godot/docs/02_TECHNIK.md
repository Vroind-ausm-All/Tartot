# Technik: Sprache, Engine und Veröffentlichung für 2,49 €

## Kurze Antwort

**Godot 4 mit GDScript.** Ein einziges Projekt, aus dem Android- und
iOS-Builds fallen. Kein Lizenzmodell, keine Umsatzbeteiligung, kein
Installationszähler — bei 2,49 € Verkaufspreis ist das der entscheidende
Punkt.

Der Regelkern liegt bewusst **engine-unabhängig** in reinen
`RefCounted`-Klassen ohne Szenenbezug. Sollte die Engine je gewechselt
werden müssen, ist das die Portierung von ~3.500 Zeilen reiner Spiellogik
und nicht die des ganzen Spiels.

---

## Warum Godot und nicht die Alternativen

| | Godot 4 + GDScript | Unity + C# | Flutter + Flame | Nativ (Swift + Kotlin) |
|---|---|---|---|---|
| **Kosten** | 0 €, MIT-Lizenz, keine Beteiligung | Lizenzkosten ab Umsatzschwelle, Modell wurde mehrfach geändert | 0 € | 0 € |
| **App-Größe** | ~35–50 MB | ~60–90 MB | ~25–40 MB | am kleinsten |
| **2D-Karten-UI** | sehr gut, Control-Nodes sind für genau so etwas gebaut | gut, aber schwergewichtig | sehr gut (es *ist* eine UI-Engine) | viel Handarbeit |
| **iOS-Pipeline** | exportiert ein Xcode-Projekt, danach normaler Apple-Weg | am ausgereiftesten | gut | trivial |
| **Ein Codestand für beide Stores** | ja | ja | ja | **nein — doppelte Arbeit** |
| **Headless testbar** | ja, `--headless --script` | umständlich | ja | teilweise |
| **Risiko** | kleineres Ökosystem für Store-SDKs | Lizenzunsicherheit | Spiel-Tooling schwächer (Partikel, Shader, Tweens) | doppelte Wartung |

**Unity** wäre die Wahl, wenn Werbe-SDKs, Live-Ops und In-App-Käufe zentral
wären. Für ein reines Premium-Spiel ohne Werbung und ohne IAP fällt genau
dieser Vorteil weg — und die Lizenzunsicherheit bleibt.

**Flutter/Flame** ist stark bei UI, aber schwächer bei allem, was dieses
Spiel visuell ausmacht: kurze Cartoon-Animationen, Bildschirmzittern,
Filmkorn-Shader, Partikel.

**Nativ** bedeutet, jedes Balancing zweimal zu bauen. Bei einem Spiel, das
von häufigen Zahlenanpassungen lebt, ist das der teuerste Weg.

### Warum GDScript und nicht C#

C# ist in Godot möglich, aber der iOS-Export mit .NET ist deutlich
umständlicher (AOT-Kompilierung, größere Binaries, mehr Fallstricke bei
Store-Reviews). GDScript ist für ein rundenbasiertes Kartenspiel mehr als
schnell genug — die teuerste Operation pro Zug ist eine Handvoll
Wörterbuchzugriffe. Falls je ein Hotspot entstünde (eine Solver-Funktion,
ein Shader-Effekt), wäre GDExtension in C++ der gezielte Ausweg, nicht ein
Sprachwechsel für das ganze Projekt.

---

## Architektur

```
core/     Regelkern — reines GDScript, kein Node, keine Szene
          rng · karte · stapel · kaempfer · effekte · bedingung
          muster (in kampf) · charmbeutel · kampf · run · meta · katalog
data/     Inhalte als JSON — Karten, Arkana, Charms, Items, Gegner, Deuter
tools/    Generatoren (Python) + Simulation, Diagnose, Screenshots (GDScript)
tests/    Headless-Testlauf ohne Framework-Abhängigkeit
ui/       Szenen und Schirme — kennen den Kern, der Kern kennt sie nicht
```

Vier Entscheidungen, die sich im Betrieb auszahlen:

**1. Der Kern hat keine Szenen.** `Kampf`, `Run`, `Karte` sind
`RefCounted`. Ein kompletter Run läuft ohne Fenster, ohne Renderer, ohne
Hauptschleife. Deshalb kann `tools/sim.gd` 200 Runs in einer halben Minute
spielen und Balancing wird gemessen statt geraten.

**2. Effekte sind Daten, kein Code.**

```json
{"op": "schaden", "wert": 9}
{"op": "status", "st": "BLUTUNG", "wert": 3, "ziel": "gegner"}
{"op": "schaden", "wert": 4, "wenn": {"ziel_status": "VERWUNDBAR"}}
```

Rund 35 Operationen decken fast alle Karten, Charms und Gegneraktionen ab.
Nur wirklich eigenwillige Effekte (Mäßigkeit mischt zwei Karten, Die Welt
prüft alle vier Farben) bekommen einen benannten Spezialeffekt. Vorteile:
Balancing ohne Build, jede Wirkung ist automatisch simulierbar, und Charms
können fremde Werte anfassen, ohne die Karte zu kennen.

**3. Determinismus von Anfang an.** Eigener 64-Bit-LCG statt
`RandomNumberGenerator`, mit **benannten Teilströmen**:

```gdscript
rng_weg = rng.strom("weg")
rng_belohnung = rng.strom("belohnung")
```

Ein Reroll im Laden verschiebt damit nicht die Kartenzüge im nächsten Kampf.
Das ist Voraussetzung für Tageskarte, Bestenlisten, Seed-Teilen und
reproduzierbare Fehlerberichte — und lässt sich später nicht nachrüsten.

**4. Entscheidungen laufen über eine Wahlstrategie.** Wenn ein Effekt fragt
„welche Karte vernichten?", blockiert der Kern nicht und ruft keine UI. Er
fragt ein `Wahl`-Objekt. Die UI setzt eine interaktive Variante ein, die
Simulation eine heuristische. Deshalb ist **jeder** Effekt mit Spielerwahl
automatisch simulierbar.

---

## Entwickeln und Prüfen

```bash
# Klassencache und Import aufbauen (einmalig und nach neuen class_name-Dateien)
godot --headless --path . --import

# Testlauf (193 Prüfungen, kein Framework nötig)
godot --headless --path . --script tests/lauf.gd

# Balancing: 200 komplette Runs
godot --headless --path . --script tools/sim.gd -- --runs=200

# Einzelnen Run Raum für Raum protokollieren
godot --headless --path . --script tools/diagnose.gd -- --seed=1003

# UI-Layout ohne Gerät prüfen
xvfb-run -a godot --path . --script tools/screenshot.gd --resolution 540x960

# Inhalte neu erzeugen
python3 tools/gen_kleine_arkana.py && python3 tools/gen_grosse_arkana.py
python3 tools/gen_charms_items.py && python3 tools/gen_gegner.py
```

Alles davon läuft in CI ohne Bildschirm.

---

## Veröffentlichung für 2,49 €

### Google Play

- Einmalige Entwicklergebühr **25 $**
- Pflichtformat **AAB** (Android App Bundle), `arm64-v8a` + `armeabi-v7a`
- Ziel-API-Level: das von Play jeweils geforderte (steigt jährlich)
- Beteiligung: 15 % bis 1 Mio. $ Jahresumsatz, danach 30 %
- Bei 2,49 € brutto bleiben nach deutscher MwSt. (19 %) und 15 % Store
  etwa **1,78 €** pro Verkauf

### Apple App Store

- **99 $ pro Jahr**, wiederkehrend
- Build **nur über macOS mit Xcode** — Godot exportiert ein Xcode-Projekt,
  signiert und hochgeladen wird auf einem Mac. Das ist die einzige harte
  Hardware-Abhängigkeit des Projekts; ein Mac-Mini oder ein gemieteter
  CI-Runner genügt
- Beteiligung: 15 % im Small Business Program (bis 1 Mio. $), sonst 30 %
- Preisniveau: Apple-Preisstufen, 2,49 € liegt auf einer regulären Stufe

### Was für ein Premium-Spiel zusätzlich zu tun ist

- **Kein Tracking, keine Werbe-SDKs.** Das vereinfacht Datenschutzerklärung,
  Play-Data-Safety-Formular und Apples App-Privacy-Label erheblich — und ist
  bei 2,49 € auch ein Verkaufsargument.
- **Altersfreigabe:** Der Cartoon-Horror-Look („grinsende Monde, Münzen mit
  Zähnen, Blutung als Statuseffekt") landet realistisch bei USK 12 / PEGI 12,
  IARC-Fragebogen entsprechend ausfüllen.
- **Lokalisierung:** Deutsch und Englisch zum Start. Alle Texte liegen in
  `data/*.json`, nicht im Code — Übersetzung ist ein Datei-Export, kein
  Refactoring.
- **Cloud-Speicher optional.** Der Speicherstand ist JSON
  (`Run.speichern()`), Play Games Services und iCloud sind nachrüstbar, ohne
  das Format zu ändern.
- **Demo statt Werbung.** Für Premium-Mobile ist die wirksamste Konversion
  eine kostenlose Version mit Abschnitt I und einem Deuter, aus der heraus
  man den Vollpreis einmalig freischaltet.

### Realistische Erwartung

Premium-Mobile ohne Werbung ist ein schwieriger Markt. Die beiden
Verkaufsargumente, die tragen, sind: **kein Free-to-Play-Gefühl** und **ein
Look, den man auf einem Screenshot sofort wiedererkennt**. Beides ist eine
Design- und Kunstfrage, keine Technikfrage — die Technik muss hier nur
billig, klein und wartbar sein. Genau das leistet Godot mit GDScript.
