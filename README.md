# TARTOT

Ein groteskes Tarot-Roguelike für Android und iOS, Hochformat.
**Unity 2022.3 LTS · C# · netstandard2.1**

> Du spielst nicht einfach Tarotkarten aus — du legst in jedem Zug eine Legung
> aus **Vergangenheit**, **Gegenwart** und **Zukunft** und versuchst, das
> vorhergesagte Schicksal zu manipulieren.

---

## Der Kern in dreißig Sekunden

Kein Mana. Du legst bis zu **3 Karten pro Zug**, eine pro Position:

| Position | Wirkung |
|---|---|
| **Vergangenheit** | 90 % — Vorbereitung, Erinnerung, Reaktion |
| **Gegenwart** | 100 % + Multiplikator-Bonus — die sichere Position |
| **Zukunft** | 150 % — löst aber erst **nach der Gegneraktion** aus |

Die gesamte Legung verursacht zusätzlich **Fate-Schaden**: `Chips × Multiplikator`.
Chips kommen aus Kartenwert, Level, Schimmer und Charms; Muster heben den
Multiplikator. **Summe 21** ruft *Die Welt*.

Zwei Mechaniken halten das Spiel ehrlich:

- **Haltung** — solange sie steht, ist ein einzelner Fate-Schlag gedeckelt.
  Bricht sie, öffnet sich ein Burst-Fenster. Bosse haben zusätzlich
  **Schicksalssiegel** und kehren mit einer neuen Phase zurück.
- **Wiederholungs-Malus** — dieselbe Legung immer wieder zu spielen verliert
  Wirkung: 100 % → 90 % → 75 % → 50 %.

Karten wachsen mit: EP aus ihrem tatsächlichen Beitrag, **Rage** (bleibt
zwischen Kämpfen), **Siegesmale** und der Schimmer-Leiter
`Matt → Weiß → Indigo → Gold → Blut → Schwarz`. Nach jedem Sieg wird aus den
wichtigsten Karten ein **Schicksalsträger** gewählt und garantiert verbessert.

---

## Aufbau

```
unity/Assets/Tartot/
  Core/            Regelkern — keine Unity-Abhängigkeit (asmdef: noEngineReferences)
  UI/              UI Toolkit: UXML, USS, View
  Scripts/         Bootstrap
src/
  Tartot.Core/     csproj, das dieselben Core-Quellen verlinkt (eine Kopie!)
  Tartot.Tests/    xunit — 130 Tests
  Tartot.Sim/      Balancing-Simulation
tools/
  unity-syntax-check/   kompiliert den Unity-Code gegen Stubs
reference/godot/   frühere Godot-Umsetzung, dient als Regelreferenz
docs/
```

Der Regelkern liegt **unter `unity/Assets`**, weil Unity nur dort kompiliert.
`src/Tartot.Core/Tartot.Core.csproj` verlinkt genau dieselben Dateien — es gibt
also eine einzige Kopie, und Spiel, Tests und Simulation können nicht
auseinanderlaufen.

---

## Loslegen

```bash
# Alles bauen
dotnet build

# Tests (130)
dotnet test src/Tartot.Tests

# Balancing: 200 komplette Runs spielen und auswerten
dotnet run --project src/Tartot.Sim -c Release -- --runs=200 --fights=40

# Deckgröße gegen Reichweite messen
dotnet run --project src/Tartot.Sim -c Release -- --runs=150 --deck=8

# Unity-Code auf Syntax prüfen, ohne Unity
dotnet build tools/unity-syntax-check
```

**In Unity:** Repository klonen, in Unity Hub den Unterordner **`unity/`**
öffnen (2022.3 LTS oder neuer), ein TSS-Theme anlegen, dann
`Tartot → Projekt einrichten` im Menü und **Play**. Der Regelkern liegt
bereits unter `unity/Assets` — es ist nichts zu kopieren. Schritt für Schritt,
inklusive Weg von Hand und was ungeprüft ist, in
[`docs/UNITY.md`](docs/UNITY.md).

---

## Dokumentation

| | |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Entscheidungen und warum |
| [`docs/BALANCING.md`](docs/BALANCING.md) | Formeln, gemessene Zahlen, Befunde |
| [`docs/UNITY.md`](docs/UNITY.md) | Unity-Einrichtung und was ungeprüft ist |
| [`reference/godot/README.md`](reference/godot/ README.md) | frühere Godot-Umsetzung |

## Stand

Der Regelkern ist geprüft: **130 Tests**, 200 Runs ohne Absturz, Speichern
und Laden mitten im Kampf, reproduzierbare Seeds. Was fehlt, ist überwiegend
Inhalt und Politur — siehe *Offene Punkte* in
[`docs/BALANCING.md`](docs/BALANCING.md) und [`docs/UNITY.md`](docs/UNITY.md).
