# Balancing: Zahlen und Messungen

Balancing wird hier **gemessen, nicht geschätzt**. `tools/sim.gd` spielt
komplette Runs mit einem Autopiloten, der die Regeln kennt, aber nicht
rechnet — ungefähr das Niveau eines aufmerksamen Spielers im dritten Run.

```bash
godot --headless --path . --script tools/sim.gd -- --runs=200
godot --headless --path . --script tools/diagnose.gd -- --seed=1003
```

---

## 1. Grundformeln

### Wirkung einer Karte

```
Wirkung = (Basiswert + flache Boni) × Modifikator
```

Flache Boni (Charms, Kartenstufe, Tinte) liegen **vor** der Multiplikation.
Das ist der wichtigste Einzelentscheid des Balancings: „Klingenanhänger ×4"
gibt +4 Schaden, und in der Zukunft werden daraus +8. Sonst wären flache
Charms im späten Run wertlos.

Modifikator in Promille, additiv gesammelt:

| Quelle | Beitrag |
|---|---|
| Position Vergangenheit / Gegenwart / Zukunft | 700 / 1000 / 2000 |
| Resonanz | +300 |
| Schicksalskette | +250 |
| Stab-Combo | +1000 je vorher gelegter Stabkarte im Zug |
| Verderbnis (nur umgekehrte Karten) | +60 je 20 Verderbnis |
| Charm-`promille` | je Stack |
| Kartenstufe (flach) | +2 / +5 / +9 |
| Tinte (flach) | +0,5 je Stufe |

Auslösungen: 1, +1 bei Konvergenz, +1 bei Die Welt, **hart gedeckelt bei 3**.

### Status

| Status | Wirkung |
|---|---|
| Schild | absorbiert zuerst, verfällt zu Zugbeginn (außer *verankert*) |
| Verwundbar | erlittener Schaden ×1,5 |
| Schwach | verursachter Schaden ×0,75 |
| Stark | +Stacks flach |
| Blutung | Zugende: Schaden = Stacks, dann −1 |
| Gift | Zugbeginn: Schaden = Stacks, dann −1 |
| Glut | Zugende: Schaden = Stacks, dann **halbiert** |

Glut ist die einzige Quelle mit exponentiellem Abfall — deshalb lohnt sich
Nachladen (Stäbe) statt eines einzelnen großen Stapels.

### Ökonomie

| | |
|---|---|
| Gold: normaler Kampf | 11–18 |
| Gold: Elite | 26–34 |
| Gold: Boss | 45–60 |
| Löschen | 30 / 50 / 70 / 90 / 115 / 140 / 170 / 200 |
| Spiegeln | 80 · Aufwerten 60 · Umdrehen 45 |
| Charm beim Händler | 60 |

### Charm-Drops

| Raum | Charms |
|---|---|
| Normaler Kampf | 45 % Chance auf 1 (+3 % je Luck) |
| Elite | 1 sicher, 35 % auf einen zweiten (+ *Gebrochene Krone*) |
| Boss | 2 sicher |
| Truhe | 1 |

Zielwert: **rund 20 Drops pro vollem Run.** Gemessen: 25,6 Stacks im Schnitt.

### Endlos-Skalierung

```
Gegner-HP-Faktor(t) = 1,19^t × (1 + 0,012·t²)
```

Gemessen: Tiefe 0 = 1,08 · Tiefe 5 = **3,35** · Tiefe 15 = **54,30**.
Superexponentiell, damit auch absurde Builds irgendwann scheitern. Alle 5
Räume kommt ein Verderbtes Arkanum dauerhaft dazu — geprüft: keine
Dubletten, die Regeln sammeln sich im Run, die Verderbnis steigt mit.

---

## 2. Gemessener Stand

200 Runs als *Die Wahrsagerin*, Autopilot, keine Schleier:

| Kennzahl | Wert | Bewertung |
|---|---|---|
| Siegquote | **21,5 %** | gesund — ein guter Spieler liegt darüber |
| Räume pro Run | 28,2 | passt zu 3 × 14 Räumen mit Abbrüchen |
| Deckgröße am Ende | 13,4 Karten | Start 10; der Autopilot dünnt zu wenig aus |
| Charm-Stacks am Ende | 25,6 | trifft das Ziel |
| Verderbnis am Ende | 11,7 | **zu niedrig**, siehe offene Punkte |
| Tinte im Deck | 11,5 | sichtbare Verdunkelung setzt ein |

Verteilung der Abbrüche:

| | Anteil |
|---|---|
| Abschnitt 1 | 35 % |
| Abschnitt 2 | 17 % |
| Abschnitt 3 | 26 % |
| Abschnitt 4 / gewonnen | 22 % |

Häufigste Todesursachen:

| | Anteil aller Runs |
|---|---|
| Boss XVI — Der Turm | 35 % |
| Boss XIII — Der Tod | 10 % |
| Boss XVIII — Der Mond | 8 % |
| Elite Der Henker (umgekehrt) | 3 % |

---

## 3. Was die Messung bereits verändert hat

### Der Turm war ein Designfehler, kein Zahlenfehler

Erste Messung: **56 % aller Runs starben am ersten Boss.** Nichts anderes
kam in die Nähe.

Ursache war nicht die HP-Zahl, sondern die Regel. Der Turm zerstörte alle 3
Runden eine Position. Bei 120 HP brauchte ein Abschnitt-1-Deck acht Runden —
und kämpfte die letzten beiden mit **einer** Karte pro Zug. Das ist keine
Herausforderung, sondern eine Todesspirale: Wer zurückliegt, verliert
Handlungsfähigkeit und liegt dadurch weiter zurück.

Änderung: 84 HP, Intervall 4. Damit fällt die erste Zerstörung in Runde 4,
und ein solides Deck ist vorher fertig. Ein schwaches Deck spürt die Spirale
weiterhin — das Rennen bleibt, das Urteil fällt weg.

Ergebnis: 56 % → 35 %, und die Abbrüche verteilen sich über alle Abschnitte.

### Charms fielen viel zu selten

Vor der Korrektur gab es Charms nur nach Elites und Bossen: **2 Stacks nach
14 Räumen**. Ohne Charms gibt es keinen Build, ohne Build keinen Payoff.
Jetzt tropfen auch normale Kämpfe (45 %).

### Kein Händler, kein Deckbau

Die Wegwahl war reiner Zufall; ein Run konnte 20 Räume ohne Händler laufen
und mit 373 ungenutztem Gold enden. Jetzt wird nach 4 Räumen ohne Händler
einer in die Auswahl gezwungen, nach 6 ohne Rast eine Rast, und nie kommen
zwei Elites hintereinander. Der Spieler darf sie weiter ignorieren.

### Zwei echte Programmfehler, die die Messung sichtbar machte

- Die Verderbnis nach dem Kampf wurde in einem Ausdruck verrechnet, der sich
  zu einer Identität auflöste — sie stieg praktisch nie.
- `belohnung_charm()` konnte ein untypisiertes Array zuweisen und lief in
  einen Laufzeitfehler, sobald alle Charms einer Seltenheit ausgereizt
  waren; das passiert in langen Runs zuverlässig.

---

## 4. Offene Punkte

| Punkt | Beobachtung | Idee |
|---|---|---|
| **Der Turm bleibt Spitzenreiter** | 35 % aller Tode | Erster Boss sein heißt, jeder Run begegnet ihm — ein Anteil ist normal. Zielwert: unter 25 %. Nächster Versuch: Abschnitt 1 auf 12 Räume kürzen, damit der Spieler ihn ausgeruhter trifft. |
| **Verderbnis bleibt bei ~12** | Die Verdunkelung setzt zu spät ein | Tränken und Pakte sind die einzigen großen Quellen. Vorschlag: +1 Verderbnis je Elite, +2 je Aufwertung beim Händler. |
| **Deck wird nicht klein genug** | 13,4 statt der angepeilten 8–10 | Zum Teil Schwäche des Autopiloten. Gegenprobe nötig: Läufe mit erzwungener Löschstrategie. |
| **Umgekehrte Karten unterrepräsentiert** | Der Autopilot dreht fast nie | Braucht eine bessere Heuristik, bevor man daraus Balancing-Schlüsse zieht. |
| **Nur ein Deuter gemessen** | Die anderen 5 sind ungetestet | `--deuter=verbrannte` usw. durchlaufen lassen; besonders *Das leere Blatt* (4 Legungen, 6 Karten) ist verdächtig. |
| **Endlosmodus** | Mechanik geprüft, Spielgefühl nicht | Die Arkana-Stapelung und die HP-Kurve sind getestet. Was fehlt, ist eine lange Messreihe — ein Endlos-Run kann 200 Räume dauern und der Autopilot braucht dafür Minuten. Nächster Schritt: Raumgrenze im Simulator konfigurierbar machen und über Nacht laufen lassen. |

---

## 5. Regressionsschutz

`tests/lauf.gd` prüft 193 Zusicherungen ohne Framework, darunter:

- **Determinismus:** gleicher Seed ⇒ identisches Kampfprotokoll; benannte
  Ströme sind unabhängig und reproduzierbar
- **Positionsfaktoren:** Vergangenheit exakt 6 Schaden + 1 Blutung aus einer
  8 der Schwerter (8 × 0,7 und 2 × 0,7), Gegenwart 8, Zukunft ≥ 16 und erst
  in der Folgerunde
- **Alle vier Muster** inklusive Gegenprobe (Summe 20 ruft *Die Welt* nicht)
- **Charm-Stacking:** *Klingenanhänger* ×4 gibt exakt +4 Schaden; dieselbe
  Karte in der Zukunft macht (5+4)×2 = 18
- **Stab-Combo** eskaliert messbar über den doppelten Einzelwert hinaus
- **Status:** Verwundbar 10→15, Schwach 10→8, Blutung/Gift/Glut-Ticks,
  Schild verfällt, *verankert* hält
- **Speichern/Laden:** Gold, Luck, Verderbnis, Kartenstufen, Orientierungen
  und Charm-Stacks überstehen eine JSON-Rundreise
- **Katalogintegrität:** 56 + 22 + 50 + 22 Einträge, jede Zahlenkarte hat
  beide Orientierungen, jedes Arkanum alle drei Gesichter
- **Endlosmodus:** alle 5 Räume genau ein neues verderbtes Arkanum, keine
  Dubletten, Regeln sammeln sich, HP-Faktor wächst überproportional
- **Verderbnis:** Aufwerten erhöht immer auch die Tinte; volle Verderbnis
  verstärkt umgekehrte Karten messbar; *Tränken* wertet auf und verdunkelt
