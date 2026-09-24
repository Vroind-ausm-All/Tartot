# Balancing: Formeln, Messungen, Befunde

Balancing wird hier **gemessen, nicht geschätzt**.

```bash
dotnet run --project src/Tartot.Sim -c Release -- --runs=400 --detail=1 --stats=1
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --veilsweep=1
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --deuter=aderleser
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --fights=60 --spiral=1
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --career=1
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
| Deck-Resonanz | +0,06 je Stufe über 1 (Eremit: doppelt) |
| **Musterkette** | +0,10 je Glied, höchstens 5 — nur Paar oder besser zählt |
| Umgekehrte Karte beim Aderleser | +0,15 statt +0,10 |

Danach: **Pakt des Teufels** × 1,5 auf den ganzen Fate-Schaden.
**Verdunkelung**: umgekehrte Karten +1 Chip und +6 % Wirkung je 20.

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

Das Rad und der Gehängte verschieben, **wo** eine Karte wirkt, nicht wo sie
liegt: `CombatSystem.EffectiveSlot`. Vorschau, Muster, Faktor und Zeitpunkt
lesen alle diese eine Funktion.

### Haltung

Solange Haltung steht, ist ein einzelner Fate-Schlag auf **35 % der maximalen
HP** gedeckelt. Haltungsschaden = `Chips/9 + 2 je Schwertkarte`. Bricht sie,
wirkt Fate-Schaden mit **× 1,5** für ein Fenster von einer Runde; danach
gewinnt der Gegner 60 % seiner Haltung zurück.

**Schicksalssiegel**: bei tödlichem Schaden kehrt der Gegner mit 45 % HP,
voller Haltung und +3 Angriff zurück.

### Akte, Schleier, Spirale

Drei Akte à vier Kämpfe und ein Boss, dann das Finale. Werte je Akt stehen im
Katalog (`Content/Acts.cs`), gemessen und eingebrannt — nicht per Formel.

| | Normale | Elites | Bosse |
|---|---|---|---|
| Akt I | 110–160 HP, Angriff 17–25 | 230–260 | 320–360, 1 Siegel |
| Akt II | 240–320 HP, Angriff 17–23 | 450–480 | 495–510, 1 Siegel |
| Akt III | 380–450 HP, Angriff 19–22 | 600–620 | 640–650, 1 Siegel |
| Finale | Die Welt: 504 HP, 2 Siegel, Regeln der geschlagenen Bosse abgeschwächt | | |

Beim Kampfstart wird der Gegner geklont und skaliert: Verdunkelung +1 Angriff
je 25, dann die Schleier (siehe unten).

**Spirale** je Tiefe *t*: `HP × 1,08^t × (1 + 0,008·t²)`, Haltung +6 % je
Tiefe, Angriff +*t*, Siegel +1 je 8 Tiefen. Jeder vierte Kampf ist der
Weltenwurm mit zwei oder mehr ungeschwächten Regeln. Wer die Welt schlägt,
heilt beim Eintritt 40 %.

**Wirtschaft**: Gold je Sieg `(12 + 3·Kampfindex) × Stufe` (Elite ×1,3,
Boss ×1,5), Überschuss je 8 ein Gold (gedeckelt 4 + 4·Akt), direkter Weg
+12. Senken: Händlerangebote, Vergessen (45, +25 je Mal), Veredeln (70, +30
je Mal).

## 2. Gemessener Stand

400 Runs, Wahrsagerin, Schleier 0, Deck-Ziel 14:

| Kennzahl | Wert |
|---|---|
| Ohne Absturz durchgelaufen | **400 / 400** |
| **Siege** (Finale geschlagen) | **34 %** |
| Kämpfe im Schnitt | 12,5 (von 16) |
| Züge pro Kampf | 4,1 — Normale 3–3,5, Bosse 5–6,5 |
| Deckgröße am Ende | 12,9 |
| Verdunkelung am Ende | 35 |
| DIE WELT gelegt | 21 pro Run |
| Längste Musterkette | 5,7 |
| Stärkste Legung | Median 327, Spitze 764 |
| Ereignisse / Rasten / Elites | 4,1 / 1,9 / 1,1 pro Run |
| Ungenutztes Gold | 179 |

### Wo die Runs enden

| Akt I | Akt II | Akt III | Finale | **Sieg** |
|---|---|---|---|---|
| 12 % | 12 % | 20 % | 23 % | **34 %** |

Todesrate im Bosskampf: Turm 13 %, Mond 10 %, Tod 11 %, Rad 8 %,
Teufel 13 %, Gehängter 11 %, **die Welt 40 %** derer, die sie erreichen.

### Deuter

| Deuter | Sieg |
|---|---|
| Die Wahrsagerin | 34 % |
| Der Aderleser | 32 % |
| Der Buchhalter | 35 % |
| Der Eremit (Deck-Ziel 9) | 24 % |

### Schleier

| Schleier | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Sieg | 34 % | 31 % | 27 % | 31 % | 23 % | 15 % | 10 % | 8 % | 5 % |

300 Runs je Stufe, Streuung etwa ±3 Punkte.

### Spirale

Wer die Welt schlägt und weitergeht, erreicht im Schnitt **Tiefe 4**
(Maximum 12). Jeder Weltenwurm ist ein Kontrollpunkt.

### Laufbahn

300 Runs mit *einem* Meta-Fortschritt, wie ein echter Spieler:

- Freischaltungen in Run 1, 3–6, 8, 9, 11, 17, 18, 22, 25 — danach bleiben
  nur die Schleier- und Spiralziele als lange Strecke.
- Siegquote auf Schleier 0: **rund 42 %** statt 34 %. Davon kommen gut 5
  Punkte aus den Lesarten (voll gelesen: 38,8 %), der Rest aus den
  freigeschalteten Charms. Genau dafür gibt es die Schleier: wer gewinnt,
  öffnet Schleier 1 und spielt dort.

---

## 3. Befunde dieser Runde

### Der Bogen war ein Tutorial — jetzt stirbt man überall

Vorher schlugen 96 % der Runs alle acht gebauten Gegner. Nach dem Umbau auf
drei Akte waren es zunächst **0 % Tote in Akt I und II** und 55 % am Finale:
normale Gegner dauerten 2–2,7 Züge und kosteten kaum Leben. Fünf Tuning-Runden
später liegt die Verteilung bei 12 / 12 / 20 / 23 / 34 %.

### Gegner-HP ist der falsche Hebel

Mehr Gegner-HP ändert fast nichts. Der Haltungsdeckel (35 % der Max-HP je
Treffer) bestimmt die Kampflänge — wer HP verdoppelt, verdoppelt nicht die
Züge. Was wirkt, ist **Haltung** (hält den Deckel länger) und **Angriff**
(Schaden über 16 Kämpfe summiert sich). Ein einziger Angriffspunkt mehr für
alle Gegner kostete 13 Punkte Siegquote.

Die erste Schleier-Kurve war deshalb flach und brach dann ein
(29, 29, 26, 27, **13, 2** %). Umgebaut: milde Stufen zuerst, harte Angriffe
erst ab Akt II — sonst wird der erste Boss zur Mauer (40–55 % Tote in Akt I).

### Der Rekord maß den Deckel

Der härteste Treffer klebte bei 224–228: genau 35 % der HP der
Akt-III-Bosse. Er maß den Haltungsdeckel, nicht den Build. Jetzt zählt der
Wert der Legung vor dem Deckel.

### Drei echte Fehler, gefunden durch Messung und Tests

1. **Ein Ereignis konnte den Boss ersetzen.** Der Kartenspieler-Kampf wurde
   für den *nächsten* Kampf vorgemerkt — war das ein Boss oder das Finale,
   trat der Kartenspieler an seine Stelle. Sichtbar wurde es, weil zwei Runs
   „in der Spirale“ weiterliefen, ohne das Finale gesehen zu haben.
2. **Der Überschuss wurde auf 0 zurückgesetzt.** Die Todesprüfung lief nach
   den Zukunftskarten ein zweites Mal von vorn. Überschuss-Gold kam dadurch
   fast nie an. Gefunden vom Test `Overkill_IsMeasured`.
3. **Lesarten wuchsen im Spiel nie pro Sieg.** Die Oberfläche zählte eine
   Begegnung, wenn der Kampfindex gestiegen war — der steigt aber erst beim
   nächsten Kampfstart. Gezählt wurde nur am Run-Ende.

### Zwei Deuter lagen daneben

Der **Aderleser** gewann **0,7 %**: er startete mit dem umgekehrten Teufel
(4 HP Selbstschaden je Einsatz plus erhöhter Umkehrpreis) und fast ohne
Heilung. Jetzt mit Kraft statt Teufel, einem Kelch mehr und der Mondbrosche:
32 %. Der **Buchhalter** gewann zuerst 56 %; mit weniger Startgold, ohne
Startcharm und 15 statt 20 % Schildrest: 35 %.

### Die Spirale war eine Mauer

Sieger erreichten Tiefe 2,9, weil der erste Weltenwurm mit drei Siegeln kam
und man ohne Heilung aus dem Finale stolperte (88 % Tote an ihm). Jetzt ein
Siegel weniger, Heilung beim Eintritt: Tiefe 4,2.

### Gold

Ungenutztes Gold stieg mit der längeren Strecke auf **465**. Weniger
Einkommen und **Veredeln** als zweite Senke: 179. Der Rest ist zum Teil
Instrument — der Autopilot kauft vorsichtig.

### Grenzen des Instruments, ehrlich benannt

- Schleier 1 (weniger Gold) und 3 (eine Belohnungswahl weniger) misst der
  Autopilot kaum, weil er Gold übrig hat und sein Deck ohnehin deckelt. Ein
  Mensch spürt beide.
- Der Autopilot findet DIE WELT per Durchprobieren aller Legungen (21 pro
  Run). Menschen legen sie seltener — Prophezeiungen um DIE WELT werden für
  Menschen später fallen als hier gemessen.
- Items benutzt er nur zum Heilen.

---

## 3b. Frühere Eingriffe (vor der Akt-Struktur)

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

*Stand vor der Akt-Struktur. Heute gibt es +10 % je Lesart statt +15 % —
mit dem längeren Bogen machte der alte Wert Veteranen zu stark (siehe
Laufbahn in Abschnitt 2).*

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
| **Die Welt ist steil** | 40 % Todesrate am Finale | Gewollt als Höhepunkt — mit echten Spielern prüfen, ob es sich fair anfühlt |
| **Resonanz-Gewicht** | 0,06/Stufe ist kosmetisch (außer beim Eremiten) | Deckgrößen-Anteil getrennt gewichten |
| **Items** | Der Autopilot nutzt nur Heiltränke | Zielmodi für Items, dann messen |
| **Menschen vs. Autopilot** | Muster-Prophezeiungen sind am Autopiloten geeicht | Nach einem Spieltest nachjustieren |
| **Umkehrpreis rundet grob** | Basiskarten kosten alle 1 HP | Erst relevant, wenn Kartenwirkungen insgesamt größer werden |

## 5. Regressionsschutz

**246 Tests** (`dotnet test src/Tartot.Tests`), darunter für jeden behobenen
Defekt ein eigener Test:

- **Determinismus**: gleicher Seed → identischer Run, auch über Ereignisse
  und Spirale; goldene RNG-Folge festgeschrieben; Laden-Reroll verschiebt die
  Kartenzüge nicht
- **Bossregeln**: jede Regel, ihre Verschärfung nach dem Siegel und ihre
  abgeschwächte Form im Finale; die Vorschau rechnet dort, wo die Karte wirkt
- **Momente**: Kette wächst, bricht und ist gedeckelt; Vorschau ändert sie
  nicht; Überschuss und sein Gold; Beinahe-Hinweise nennen die konkrete Karte
- **Bogen**: Bosse angekündigt und geplant, keine Wiederholung im Akt, Rast
  vor jedem Boss, Ereignis ersetzt nie einen Boss, Omen-Beute, Finale,
  Spirale, jeder Schleier, jeder Deuter
- **Ereignisse**: jede Wahl jedes Ereignisses mit sechs Seeds, danach ist der
  Run gültig; Geschichten in der richtigen Reihenfolge; das Grab
- **Meta**: Prophezeiungen einmalig, gesperrte Charms nie im Angebot,
  Bericht mit höchstens drei Beinahe, Tageskarte ohne Meta-Fortschritt
- **Speichern/Laden**: mitten im Bosskampf mit allen Regelzuständen, mitten
  in einer Szene, in der Omen-Beute; Version-1-Stände laden weiter
- **Scoring, Positionen, Haltung, Siegel, Umkehrpreis, Händler** (wie zuvor)
