# Balancing: Formeln, Messungen, Befunde

Balancing wird hier **gemessen, nicht geschätzt**.

```bash
dotnet run --project src/Tartot.Sim -c Release -- --runs=200 --fights=40
dotnet run --project src/Tartot.Sim -c Release -- --runs=150 --deck=8
```

Der Autopilot spielt vernünftig, nicht optimal — etwa auf dem Niveau eines
aufmerksamen Spielers im dritten Run.

---

## 1. Formeln

### Fate-Schaden

```
Fate = Chips × Multiplikator × Wiederholungs-Malus
```

**Chips** je gelegter Karte: `EffectiveRank` (Kartenwert + Level/2 + Schimmer),
plus Charm-Boni. Bei voller Rage (3/3): × 1,5, danach verbraucht.

**Multiplikator** beginnt bei 1,0 und sammelt additiv:

| Quelle | Beitrag |
|---|---|
| Karte in der Gegenwart | +0,15 |
| Karte in der Zukunft | +0,10 (+0,10 je *Henkerkette*) |
| Umgekehrte Karte | +0,10 je Karte |
| **Summe 21 — Die Welt** | **+2,10** und +21 Chips |
| Dreiklang | +1,00 und +12 Chips |
| Folge | +0,75 und +8 Chips |
| Resonanz (gleiche Farbe) | +0,65 und +10 Chips |
| Großes Omen (≥2 Arkana) | +0,60, je weiteres +0,25 |
| Paar | +0,50 und +5 Chips |
| Drei Pfade (3 Farben) | +0,35 |
| Deck-Resonanz | +0,06 je Stufe über 1 |

**Wiederholungs-Malus** bei identischer Legung: 1,00 → 0,90 → 0,75 → 0,50.
Eine andere Legung setzt ihn zurück.

### Positionen

| Position | Faktor | Zeitpunkt |
|---|---|---|
| Vergangenheit | 0,90 | sofort |
| Gegenwart | 1,00 | sofort |
| Zukunft | 1,50 | **nach der Gegneraktion** |

Stirbst du im selben Zug, verfällt die Zukunftskarte ersatzlos. Das ist der
Sinn der Position und als Test festgehalten.

### Haltung

Solange Haltung steht, ist ein einzelner Fate-Schlag auf **35 % der maximalen
HP** gedeckelt. Haltungsschaden = `Chips/9 + 2 je Schwertkarte`. Bricht sie,
wirkt Fate-Schaden mit **× 1,5** für ein Fenster von einer Runde; danach
gewinnt der Gegner 60 % seiner Haltung zurück.

**Schicksalssiegel**: bei tödlichem Schaden kehrt der Gegner mit 45 % HP,
voller Haltung und +3 Angriff zurück.

### Endlos-Skalierung

Nach den acht gebauten Gegnern:
`HP × (1 + Stufe × 0,18)`, `Haltung × (1 + Stufe × 0,12)`,
`Angriff + Stufe × 2`, Siegel bis 4.

---

## 2. Gemessener Stand

200 Runs, Deck-Ziel 12, Kampflimit 40:

| Kennzahl | Wert |
|---|---|
| Ohne Absturz durchgelaufen | **200 / 200** |
| Kämpfe im Schnitt | 10,1 (max 16) |
| Züge pro Kampf | 5,3 |
| Deckgröße am Ende | 11,6 |
| Charm-Stacks am Ende | 10,3 |
| Deck-Resonanz am Ende | 7,5 von 10 |
| Ungenutztes Gold | 81 |

---

## 3. Befunde

### Die gebaute Strecke ist ein Tutorial, kein Spannungsbogen

**96 % der Runs schlagen alle acht gebauten Gegner** und sterben erst im
Endlosmodus. Nur 4 % scheitern vorher, praktisch alle an *Die rote Sonne*
(Gegner 7).

Das heißt: die Schwierigkeit liegt vollständig in der Endlos-Skalierung, nicht
im entworfenen Inhalt. Das ist eine **Struktur- und Inhaltsfrage**, keine
Zahlenfrage — sie sollte zusammen mit einer Akt-Struktur entschieden werden
und nicht durch Hochdrehen der vorhandenen acht Gegner.

### DeckResonance war ein toter Wert

`UpdateDeckResonance` wurde an **fünf Stellen gepflegt und nirgends gelesen**.
Der Wert belohnt genau das, was beide Konzeptpapiere als zentralen Hebel
beschreiben — kleines Deck, entwickelte Karten, stimmiger Build.

Zusätzlich zählte die Deckgröße nur an zwei Sprungmarken (≤ 12 und ≤ 9). Da
ein Run praktisch nie unter 12 Karten kam, war der Hebel doppelt tot. Jetzt
ist die Deckgröße ein Gradient (`(16 − Deckgröße) / 2`), und der Wert geht in
den Multiplikator ein.

### Die erste Messung war ungültig — das Instrument war kaputt

Der Autopilot kaufte im Laden auch Karten und arbeitete damit gegen sein
eigenes Ausdünnen. Das Deck endete **unabhängig vom Ziel** bei rund 12 Karten,
und die Deckgröße schien wirkungslos.

Mit korrigiertem Instrument:

| Deck-Ziel | Kämpfe | Deck am Ende | Resonanz |
|---|---|---|---|
| 8 | **10,6** | 8,0 | 9,5 |
| 10 | 10,1 | 9,7 | 8,3 |
| 12 | 10,1 | 11,6 | 7,5 |
| 16 | 9,9 | 13,4 | 6,7 |
| 22 | 9,9 | 13,6 | 6,7 |

Ein kleines Deck kommt also messbar weiter — der Designanspruch stimmt.

### Der Resonanz-Multiplikator trägt derzeit fast nichts bei

Kontrollmessung mit `DeckResonancePerStep = 0`:

| | Deck-Ziel 8 | Deck-Ziel 22 | Spreizung |
|---|---|---|---|
| Ohne Resonanz | 10,4 | 9,6 | 0,8 |
| Mit Resonanz (0,06) | 10,6 | 9,9 | 0,7 |

Der Vorteil eines kleinen Decks kommt aus der **Ziehkonsistenz**, die es
ohnehin gab, nicht aus der Resonanz. Die Verdrahtung ist trotzdem richtig —
ein gepflegter Wert, den niemand liest, ist ein Fehler —, aber bei 0,06 pro
Stufe ist sie kosmetisch.

`CombatSystem.DeckResonancePerStep` steht als benannte Konstante bereit. Sie
anzuheben ist eine Designentscheidung mit Schneeballrisiko, weil die Resonanz
auch Charms und Fortschritt belohnt: ein Run, der ohnehin gut läuft, würde
zusätzlich beschleunigt.

---

## 4. Offene Punkte

| Punkt | Beobachtung | Vorschlag |
|---|---|---|
| **Inhaltsmenge** | 8 gebaute Gegner, davon nur einer gefährlich | Akt-Struktur mit eigenen Gegnersätzen und Bossen |
| **Resonanz-Gewicht** | 0,06/Stufe ist kosmetisch | Deckgrößen-Anteil von den übrigen Faktoren trennen und getrennt gewichten |
| **Ausdünn-Gelegenheiten** | Nur Ritualräume entfernen Karten | Entfernen auch beim Händler anbieten |
| **Ungenutztes Gold** | 81 im Schnitt am Ende | Goldsenken fehlen, sobald das Deck voll ist |
| **Umgekehrte Karten** | +18 % Kraft, +10 % Multiplikator, Selbstschaden kann nie töten | Derzeit strikt besser statt riskanter. Der Preis muss spürbar werden, bevor Reverse-Builds ein echter Pfad sind |
| **Lesarten** | werden gesammelt, wirken aber noch nicht | in die Kartenwirkung einspeisen |

---

## 5. Regressionsschutz

**101 Tests** (`dotnet test src/Tartot.Tests`), darunter für jeden behobenen
Defekt ein eigener Test:

- **Determinismus**: gleicher Seed → identischer Run; goldene RNG-Folge
  festgeschrieben; Läden-Reroll verschiebt die Kartenzüge nicht
- **Scoring**: alle Kombinationen einzeln, Summe 20 als Gegenprobe,
  Wiederholungs-Malus über vier Züge
- **Vorschau ohne Nebenwirkung** — vorher farmte jede angefasste Karte Rage
- **Positionen**: Vergangenheit < Gegenwart < Zukunft; Zukunft verfällt bei Tod
- **Haltung**: Schadenskappe, Burst-Fenster, Rückkehr
- **Schicksalssiegel**: zweite Phase — und der dokumentierte Gegenfall, dass
  ein starker Zug ohne Haltung durch beide Phasen bricht
- **Speichern/Laden**: mitten im Kampf, Kartenidentität, RNG-Fortsetzung,
  kaputte und veraltete Stände
- **Katalog**: 78 Karten, 50 Charms mit eindeutigen Wirkungen, 22 Items
