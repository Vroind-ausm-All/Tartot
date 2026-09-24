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

## 3b. Drei gezielte Eingriffe, gemessen

### Umgekehrte Karten sind jetzt eine Wahl

Vorher: `Rang / 5` HP — bei einer 9 also **1 HP** gegen ×1,18 Kraft und
+0,10 Multiplikator. Umgekehrt war strikt besser, es gab keine Entscheidung.
Große Arkana zahlten den Preis **gar nicht**, weil ihr Zweig vor der
Preisberechnung zurückkehrte.

Jetzt hängt der Preis an der tatsächlichen Wirkung der Karte
(`CombatSystem.ReversedCostFraction`). Messreihe, gleiches Startdeck einmal
komplett aufrecht und einmal komplett umgekehrt, je 150 Runs:

| Anteil | Kämpfe umgekehrt | gegen aufrecht 10,1 |
|---|---|---|
| 0,06 | 9,7 | knapp darunter |
| **0,08** | **9,7** | **gewählt** |
| 0,10 | 9,0 | spürbar schwächer |
| 0,14 | 8,3 | |
| 0,18 | 7,4 | |
| 0,22 | 6,4 | unspielbar |

Bei 250 Runs je Seite mit dem gewählten Wert:

| | Ø Kämpfe | Maximum |
|---|---|---|
| aufrecht | 10,2 | 15 |
| umgekehrt | 9,7 | **20** |

Das ist die Form, die ein Risiko-Build haben soll: **schlechterer Schnitt,
deutlich höhere Decke.** Mit den unterstützenden Charms (*Blutmondsplitter*
+15 % auf Karten mit Selbstschaden, *Mondbrosche*) kippt die Rechnung — ohne
sie bleibt Umkehren ein Verlustgeschäft.

**Grenze der Skalierung, ehrlich benannt:** Basiskarten haben Wirkung 4–13.
Bei 0,08 rundet der Preis dort auf 1 HP, egal ob Rang 2 oder Rang 10 — die
Staffelung greift erst bei gewachsenen Karten, in der Zukunftsposition und bei
Großen Arkana. Der Nebeneffekt ist brauchbar: eine schwache Karte umzudrehen
ist schlechtes Geschäft (1 HP auf Wirkung 4), eine starke gutes.

Der Schaden kann **nicht töten**. An der eigenen Karte zu sterben fühlt sich
nach Willkür an; der Druck entsteht aus der Zehrung über den Run, weil
zwischen den Kämpfen nicht geheilt wird.

### Gold ist keine tote Ressource mehr

Vergessen gibt es jetzt auch beim Händler, gegen Gold, mit steigendem Preis
(45, dann +25 je Löschung, Händlerrabatte greifen).

| | ungenutztes Gold am Rundenende |
|---|---|
| vorher | 80 |
| nachher | **48** |

**Der größere Teil dieses Gewinns kam allerdings nicht vom neuen Dienst,
sondern vom Messinstrument:** der Autopilot ging erst ab 120 Gold zum
Händler — einer Schwelle, die ein Run im Schnitt nie erreichte. Mit 60 wird
der Händler überhaupt besucht.

Den Löschdienst selbst nutzt der Autopilot fast nie (0,0–0,1 pro Run), weil
seine Belohnungspolitik das Deck ohnehin bei der Zielgröße deckelt und
Ritualräume kostenlos ausdünnen. Für einen Menschen, der früh gierig Karten
mitnimmt, ist er die Korrektur — belegt ist das aber nicht. Die Funktion
selbst ist durch neun Tests abgedeckt.

### Lesarten wirken

Freigeschaltete Lesarten werden beim Run-Start aus dem Meta-Fortschritt
**kopiert** — ein laufender Run ändert sich dadurch nicht mehr, sonst liefe
ein Speicherstand anders weiter und der Seed wäre wertlos. Jede Lesart gibt
ihrem Arkanum +15 % Wirkung; wer alle drei kennt, legt es ohne Umkehrpreis.

| | Ø Kämpfe (400 Runs) |
|---|---|
| ohne Lesarten | 9,9 |
| alle Lesarten | **10,1** |

Ein kleiner Effekt — und das ist richtig so. Das Startdeck enthält nur zwei
Große Arkana; wer gezielt auf sie baut, holt mehr heraus. Meta-Progression
soll hier Verständnis belohnen, nicht einen pauschalen Schadensbonus geben.

**Ein Hinweis zur Methode:** der erste Test dieser Aussage lief über 20 Runs
und schlug fehl (9,35 gegen 9,70) — bei einem Effekt von 2 % und einem
Rauschen von ±4 % war das Zufall. Solche Aussagen gehören in eine Messreihe,
nicht in die Testsuite. Der Test wurde entfernt und durch einen Verweis auf
den Simulationsaufruf ersetzt.

---

## 4. Offene Punkte

| Punkt | Beobachtung | Vorschlag |
|---|---|---|
| **Inhaltsmenge** | 8 gebaute Gegner, davon nur einer gefährlich | Akt-Struktur mit eigenen Gegnersätzen und Bossen |
| **Resonanz-Gewicht** | 0,06/Stufe ist kosmetisch | Deckgrößen-Anteil von den übrigen Faktoren trennen und getrennt gewichten |
| **Ausdünn-Gelegenheiten** | Nur Ritualräume entfernen Karten | Entfernen auch beim Händler anbieten |
| **Löschdienst ungenutzt** | Der Autopilot löscht 0,0–0,1 Karten pro Run beim Händler | Seine Politik deckelt das Deck ohnehin. Ob der Dienst für Menschen trägt, zeigt erst Spielerfahrung |
| **Umkehrpreis rundet grob** | Basiskarten kosten alle 1 HP, unabhängig vom Rang | Erst relevant, wenn Kartenwirkungen insgesamt größer werden |

---

## 5. Regressionsschutz

**130 Tests** (`dotnet test src/Tartot.Tests`), darunter für jeden behobenen
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
