# TARTOT — Game Design Document

> Einfach zu spielen. Einfach zu lesen. Aber je länger der Run dauert, desto
> mehr verwandeln Deck, Charms und Welt sich in eine völlig entgleiste
> Tarot-Maschine.

**Genre:** Roguelike-Deckbuilder · **Plattform:** Android + iOS, Hochformat
**Preis:** 2,49 € einmalig, keine Werbung, keine In-App-Käufe
**Sitzung:** 30–50 Minuten für einen vollen Run, 1–3 Minuten pro normalem Kampf

---

## 1. Der Kern in einem Absatz

Du spielst nicht einfach Tarotkarten aus — du **legst in jedem Zug eine
Legung** aus *Vergangenheit*, *Gegenwart* und *Zukunft* und versuchst, das
vorhergesagte Schicksal zu manipulieren. Der Gegner zeigt dir immer, was er
als Nächstes tut. Du siehst also beide Zukünfte und entscheidest: sicher
spielen oder investieren. Alles andere im Spiel — Charms, Große Arkana,
Bosse, der Endlosmodus — ist eine Variation dieser einen Frage.

**Warum das eigenständig ist:** Slay the Spire fragt „welche Karten spiele
ich für welche Energie?". Balatro fragt „welche Hand baue ich?". Tartot
fragt **„welche drei Karten lege ich wohin — und akzeptiere ich das
vorhergesagte Schicksal oder ändere ich es?"**. Die Position ist die
Entscheidung, nicht die Kosten.

---

## 2. Der Kampfschirm

Hochformat, vier Zonen, mehr nicht:

```
        ▲  (animierte Cartoon-Silhouette)
     DER LACHENDE HENKER
         48 / 80 HP
   Nächster Zug: 11 Schaden + Blutung

  70/70 HP   12 Schild   Runde 3   Traum 9
  Schicksal ● ● ● ○ ○
  🪞×3  ⚔×4  🍀×2  🔥×5

  ┌─────────────┬─────────────┬─────────────┐
  │VERGANGENHEIT│  GEGENWART  │   ZUKUNFT   │
  │   [Karte]   │   [Karte]   │   [Karte]   │
  └─────────────┴─────────────┴─────────────┘

     [Hand: 5 Karten]

  ▓▓▓ SCHICKSAL AUSFÜHREN ▓▓▓
```

Die Charmleiste zeigt nur Symbol und Anzahl. Erst auf Tipp öffnet sich
„Silberspiegel ×3 — Kopierte Karten +30 %". **Der Kampf bleibt sauber, die
Komplexität liegt darunter.**

---

## 3. Die drei Positionen

Kein Mana, keine Energiekosten. Du legst **bis zu 3 Karten pro Zug, eine pro
Position**. Die Position verändert die Karte:

| Position | Wirkung | Zusätzlich |
|---|---|---|
| **Vergangenheit** | 70 % | Wiederholt **50 %** der Karte, die letzte Runde in der Gegenwart lag |
| **Gegenwart** | 100 % | Sofort, zuverlässig, sichtbar |
| **Zukunft** | 200 % | Wirkt erst **zu Beginn deines nächsten Zuges** |

Das erzeugt die zentrale Spannung: Die Zukunft ist die stärkste Position —
aber der Gegner könnte dich vorher töten, und Bosse können dir die Zukunft
stehlen (*Der Uhrenwurm*) oder die Legung spiegeln (*Der Gehängte*).

Die Vergangenheit belohnt Rhythmus statt Einzelschläge: Wer letzte Runde
eine 9 der Schwerter in die Gegenwart legte, bekommt diese Runde ein Echo
davon gratis dazu — egal welche Karte in der Vergangenheit liegt.

> **Umgesetzt in:** `core/kampf.gd::_modifikator`, `_echo_ausloesen`
> **Zahlen in:** `core/konst.gd::POS_FAKTOR`, `ECHO_FAKTOR`

---

## 4. Muster

Innerhalb der Legung zählen nicht nur Farben, sondern auch **Werte**. Das
macht eine schwache 2 wertvoll, weil sie eine 8 und eine 11 auf 21 bringt.

| Muster | Bedingung | Effekt |
|---|---|---|
| **Resonanz** | Alle gelegten Karten gleiche Farbe | +30 % Wirkung |
| **Schicksalskette** | Drei aufeinanderfolgende Werte (4-5-6) | +25 % Wirkung |
| **Konvergenz** | Drei gleiche Werte (5-5-5) | +1 Schicksalsfaden, **alle Karten lösen erneut aus** |
| **Die Welt** | Werte ergeben **exakt 21** | **Alle Karten lösen erneut aus** |

Muster stapeln. Höchstens 3 Auslösungen pro Karte, damit Konvergenz + Die
Welt + Charms nicht ins Unendliche kippen.

Große Arkana zählen mit ihrer Arkana-Nummer, Hofkarten mit 11–14. *Der Tod*
ist die 13 — er passt in eine Summe-21-Legung mit einer 6 und einer 2.

> **Umgesetzt in:** `core/kampf.gd::muster_erkennen` · getestet in `tests/lauf.gd::_test_muster`

---

## 5. Schicksalsfäden

Die zweite Kampfressource. Maximum 5, Start 2 pro Kampf.

| Kosten | Aktion |
|---|---|
| 1 | **Karte drehen** — aufrecht ↔ umgekehrt |
| 1 | **Positionen tauschen** — zwei gelegte Karten |
| 2 | **Zukunft vorziehen** — wartende Zukunftskarte sofort auslösen |
| 2 | **Karte ziehen** |
| 3 | **Schicksal biegen** — gegnerische Absicht neu würfeln |

Fäden bekommt man nicht geschenkt, sondern **durch gutes Spiel**:

- eine umgekehrte Karte spielen: +1 (max. 1 pro Zug)
- ein Muster erfüllen: +1 (max. 1 pro Zug)
- eine Zukunftskarte überlebt und löst aus: +1
- einen Gegner exakt auf 0 bringen: +1

Das ist die Kernfantasie: **Das Spiel zeigt dir dein Schicksal — und du
kannst dagegen kämpfen.**

---

## 6. Die Kleinen Arkana — dein Deck

56 Karten, vier Farben mit klar getrennten Aufgaben. Die 40 Zahlenkarten
entstehen aus Formeln (`tools/gen_kleine_arkana.py`), damit die Kurve glatt
bleibt und Balancing eine Zeile ist, kein Handarbeitstag.

| Farbe | Aufgabe | Aufrecht (Wert r) | Umgekehrt |
|---|---|---|---|
| ⚔ **Schwerter** | Schaden, Blutung, Verwundbar | `r` Schaden, ab 7 zusätzlich Blutung | **`2r` Schaden, `⌈r/2⌉` Selbstschaden** |
| ✸ **Stäbe** | Combo, Glut, Mehrfachtreffer | `r` Schaden, `⌈r/3⌉` Glut | `⌈r/2⌉` Schaden, **`r` Glut** |
| ♥ **Kelche** | Heilung, Traum, Statuskontrolle | Heile `r+1`, Überheilung → **Traum** | **`r` Traum**, entferne 1 Debuff |
| ◆ **Münzen** | Schild, Gold, Vorbereitung | `r+2` Schild, ab 8 zusätzlich Gold | Halbes Schild, **verankert**, Gold, Rückschlag |

**Die Stab-Combo** ist die auffälligste Einzelregel: Jede weitere Stabkarte
im selben Zug verdoppelt ihren Basiswert. Drei Stäbe der 4 machen also
4 → 8 → 12 statt 4 → 4 → 4. Ein reiner Stab-Zug eskaliert sichtbar.

**Ikonische Ausnahmen**, handgesetzt:
- *8 der Schwerter* aufrecht: 8 Schaden, **+4 gegen verwundbare Ziele**
- *5 der Münzen* umgekehrt: nur 3 Schild — aber wird es vollständig
  zerstört, bekommst du nächste Runde 12

### Hofkarten sind Figuren

Bube, Ritter, Königin und König sind keine Aktionen. Sie stellen sich an den
Spielfeldrand und **bleiben**. Nur eine Figur kann gleichzeitig aktiv sein;
eine neue ersetzt die alte. Mechanisch laufen sie über dieselbe Haken-Engine
wie Charms — es gibt nur eine Engine.

- *Königin der Schwerter*: Jeder dritte Schwertangriff trifft zweimal.
- *König der Stäbe*: Deine Combo-Stufe steigt auch durch Nicht-Stabkarten.
- *Königin der Kelche*: Die Hälfte deiner Überheilung wird zu Schicksal.
- *Ritter der Münzen*: Überschüssiges Schild wird am Zugende zu Gold.

---

## 7. Die Großen Arkana — drei Gesichter

22 Arkana, jedes mit **drei** Gesichtern:

1. **aufrecht** — die Kampfkarte, wie gelegt
2. **umgekehrt** — dieselbe Karte, riskanter und spezialisierter, *nicht
   schlechter*
3. **verderbt** — eine dauerhafte Run-Regel; so erscheinen sie im
   Endlosmodus und als Bossregel

Maximal 3 Große Arkana gleichzeitig im Deck. Sie sind keine
„30-Schaden-Bomben", sie **brechen Regeln**:

| Arkanum | Aufrecht | Umgekehrt |
|---|---|---|
| **0 Der Narr** | Ziehe 2, lege diesen Zug eine vierte Karte | Ziehe 3, wirf 1 ab, +1 Luck |
| **I Der Magier** | Echo der letzten Karte mit 100 % | Kopiere eine Handkarte temporär |
| **VIII Kraft** | Nächster Angriff doppelt, +4 Schild | Nächste zwei Angriffe +75 %, danach 5 Schaden |
| **XII Der Gehängte** | Verzichte auf den Zug, nächste Runde 5 Karten | Opfere eine Handkarte, alle übrigen +30 % |
| **XIII Der Tod** | Vernichte eine Karte, ziehe 2, lösche sie nach dem Sieg | Lösche permanent, verbessere zwei zufällige andere |
| **XV Der Teufel** | Nächste Karte +100 %, danach ein Fluch | Alle umgekehrten Karten 3 Runden +50 % |
| **XVI Der Turm** | 18 Schaden an allen, dein Schild fällt auf 0 | Zerstöre gegnerischen Schild, verursache seinen Wert |
| **XXI Die Welt** | Alle vier Farben gespielt: 20 Schaden, 10 Schild, ziehe 2 | Deck neu zusammensetzen, perfekte Hand aus vier Farben |

Vollständige Liste: `data/grosse_arkana.json`.

**Beim Ausspielen fühlen sie sich nicht wie normale Karten an.** *Der Tod*:
Bildschirm wird schwarz, ein weißes Gesicht, ein roter Schnitt, dann „Wähle
eine Karte zum Vernichten". *Der Turm*: Screen zittert, ein Turm wächst
hinter dem Gegner hoch, Blitz, alle Schilde weg. Zwei Sekunden, nicht mehr.
Große Arkana sind **kleine dramatische Unterbrechungen der Regeln**.

---

## 8. Aufrecht und umgekehrt

Die durchgehendste Mechanik des Spiels. **Umgekehrt heißt nie „schlechter",
sondern riskanter, ungewöhnlicher, schwerer auszunutzen.**

- Jede Karte kann in beiden Orientierungen im Deck liegen
- Das Ritual **UMDREHEN** ändert sie permanent
- Ein Schicksalsfaden dreht sie für einen Zug
- Steigende Verderbnis verstärkt umgekehrte Karten (+6 % je 20 Verderbnis)
- Charms wie *Mondbrosche* und *Blutmondsplitter*, Arkana wie *Der Teufel
  (umgekehrt)* und *Der Mond* bauen ganze Builds darauf

So entsteht ein echter Reverse-Build: ein Deck, das absichtlich auf den
gefährlichen Seiten steht und dafür Selbstschaden in Kauf nimmt — und dann
Kelche einbaut, die Selbstschaden in Traum verwandeln.

---

## 9. Charms — der eigentliche Build

50 Stück. Passiv, stapelbar bis 5, **gleiche Charms verschmelzen
automatisch**. Deshalb können 20+ Drops im Run vorkommen, ohne dass der
Bildschirm mit 20 Symbolen vollsteht.

Drei Wirkweisen, alle datengetrieben:

- **`mod`** — verändert Werte einer Karte, *während* sie auslöst. Flache
  Boni liegen **vor** der Multiplikation: „Klingenanhänger ×4" gibt +4
  Schaden, und in der Zukunft wird daraus +8. Das ist der Grund, warum
  Charms im späten Run nicht wertlos werden.
- **`haken`** — führt Ops aus, wenn ein Ereignis eintritt (`kampf_start`,
  `karte_ausgeloest`, `kill`, `mischen`, `abschnitt_start` …)
- **`regel`** — benannte Sonderregel, die der Kern kennt. Nur dort, wo Daten
  nicht reichen.

Beispiel einer eskalierenden Maschine nach 30 Minuten:

```
Silberspiegel ×5      Kopien +50 % Wirkung
Klingenanhänger ×5    Schwerter +5 Schaden
Zwillingsmünze ×3     Kopien +3 Basiswert
Blutmondsplitter ×4   Karten mit Selbstschaden +60 %
+ drei Kopien einer 9 der Schwerter+ (umgekehrt)
+ Der Teufel (umgekehrt)
```

Aus einer 9-Schaden-Karte wird der Kern-Build. Jetzt lohnt es sich, schwache
Karten zu löschen, die Schwerter mehrfach zu spiegeln und gezielt weitere
Spiegel-Charms zu suchen. **Das ist der Roguelike-Payoff.**

Die letzten Charms der Liste sorgen bewusst dafür, dass ein langer Run
eskaliert — *Weltenfaden*: „Für je 5 unterschiedliche Charms erhalten alle
Karten +2 % Wirkung pro Stack."

---

## 10. Items

22 Stück, 3 Slots, gleichartige stapeln als Ladungen. Items **retten oder
verändern den Run**, sie bauen ihn nicht.

*Spiegelscherbe* (Karte permanent kopieren), *Schere des Schicksals*
(löschen), *Schwarzes Wachs* (permanent drehen), *Goldene Nadel*
(verbessern), *Aschephiole* (bei Tod automatisch: Wiederbelebung mit 25 %),
*Weltenkompass* (alle kommenden Räume zeigen), *Glocke des Gerichts* (eine
gelöschte Karte verbessert zurückholen).

Vollständig in `data/items.json`.

---

## 11. Deck formen: Löschen, Spiegeln, Umdrehen

Das eigentliche Deckbuilding, ausdrücklich erwünscht. Ein starkes
Endgame-Deck hat 8 Karten, kein 30-Karten-Stapel.

| Aktion | Wo | Kosten |
|---|---|---|
| **VERGESSEN** — Karte permanent löschen | Händler, Ritual | 30 / 50 / 70 / 90 / 115 … Gold (steigend) |
| **SPIEGELN** — Karte permanent kopieren | Händler, Ritual | 80 Gold |
| **UMDREHEN** — Karte permanent drehen | Ritual | 45 Gold |
| **GOLDENE NADEL** — Karte verbessern | Händler | 60 Gold |

Die steigenden Löschkosten verhindern, dass man kostenlos auf drei Karten
herunterfährt. Der Konflikt bleibt lebendig:

> **Löschen macht dein Deck konsistenter. Kopieren macht eine starke
> Strategie häufiger verfügbar, bläht das Deck aber wieder auf.**

Der Händler ist die groteske Umsetzung davon: Du gibst ihm eine Karte, er
**frisst** sie → gelöscht. Oder er steckt sie zwischen zwei Spiegel, zwei
identische Versionen kommen heraus → kopiert.

---

## 12. Der Run: Schicksalskarten statt Landkarte

Keine Standard-Roguelike-Map. Nach jedem Raum zieht das Spiel **drei
Schicksalskarten**, dargestellt wie alte Cartoon-Wegweiser:

```
        WOHIN FÜHRT DEIN WEG?

   ⚔             ☠             🛒
 KAMPF         ELITE        HÄNDLER
```

Räume: **Kampf · Elite · Boss · Händler · Ritual · Truhe · Rast ·
Unbekannt**. 14 Räume pro Abschnitt, 3 Abschnitte in der Story.

Zwei Garantien, weil reiner Zufall hier schlechtes Design wäre:
- Nach 4 Räumen ohne Händler wird einer in die Auswahl gezwungen — ohne
  Händler kann niemand ein Deck bauen
- Nach 6 Räumen ohne Rast wird eine gezwungen
- Nie zwei Elites hintereinander

Der Spieler darf sie trotzdem ignorieren.

### Dauer

| | Ziel |
|---|---|
| Normaler Gegner | 1–3 Minuten |
| Elite | 3–5 Minuten |
| Boss | 5–8 Minuten |
| Ganzer Run | 30–50 Minuten |

---

## 13. Bosse brechen Grundregeln

Kein Boss hat 2.000 HP. Jeder nimmt dir stattdessen eine Regel weg.

| Boss | HP | Regel |
|---|---|---|
| **XVI Der Turm** | 84 | Ab Runde 4 zerstört er alle 4 Runden **eine Position deiner Legung**. 3 Karten → 2 → 1. Du musst ihn vorher töten. |
| **XVIII Der Mond** | 190 | Jede 2. Runde ist eine Handkarte **verdeckt** — du erfährst erst beim Legen, ob sie aufrecht oder umgekehrt war. Seine HP werden nur ungefähr angezeigt. |
| **XIII Der Tod** | 260 | Alle 3 Runden **markiert** er eine Karte. Endet der Kampf nicht rechtzeitig, ist sie für den Run vernichtet. |
| **XV Der Teufel** | 320 | Er kämpft nicht gern, er **verhandelt**: +100 % Schaden, aber eine Karte wird verflucht. Annehmen oder ablehnen. |
| **X Das Rad** | 380 | Jede Runde werden deine gelegten Positionen **zufällig vertauscht**. |
| **XII Der Gehängte** | 420 | Die Legung ist dauerhaft **gespiegelt**: Zukunft ← Gegenwart ← Vergangenheit. Alle Combos laufen rückwärts. |
| **XXI Die Welt** | 520 | **Alle Bossregeln dieses Runs gleichzeitig**, jeweils abgeschwächt. |

Nach jedem Boss steigt die Verderbnis um 6 — die Welt wird sichtbar dunkler.

---

## 14. Verderbnis — je weiter, desto düsterer

Die Verdunkelungsachse, 0–100. Sie steigt durch Pakte, Flüche, Getränkte
Karten, besiegte Bosse und verderbte Arkana.

**Sichtbar:** Jede Karte trägt eine eigene Tinte-Stufe 0–5 (*Blass · Grau ·
Ruß · Pech · Obsidian · Leer*). Je höher, desto dunkler das Kartenpapier,
bis die Schrift von Schwarz auf Elfenbein kippt. Der Streifen am unteren
Kartenrand färbt sich von Schwarz nach Blutrot. Nach 20 Räumen sieht dein
Deck anders aus als am Anfang — ohne dass ein Zahlenwert es dir sagt.

**Spürbar:**
- Umgekehrte Karten wirken +6 % je 20 Verderbnis
- Kartenbelohnungen erscheinen häufiger umgekehrt (0,5 % je Verderbnispunkt)
- Verkehrt-Seltenheiten werden im Angebot wahrscheinlicher
- *Der Teufel (verderbt)*: jede Heilung erzeugt zusätzlich Verderbnis

**Der Kern der Sache:** Du schlägst Gegner, und deine eigenen Karten werden
davon besser — **und dunkler**. Aufwerten erhöht immer auch die Tinte. Macht
hat einen sichtbaren Preis.

### Beute nach einem Boss

Drei Wege, mit dem gefallenen Omen umzugehen:

| | |
|---|---|
| **TRÄNKEN** | Salbe drei Karten mit der Tinte des Omens: +1 Stufe, dafür dunkler. +4 Verderbnis. |
| **BINDEN** | Nimm das Omen als Großes Arkanum ins Deck. Es bringt seinen Fluch mit. |
| **BANNEN** | Verbanne es: +40 Gold und lösche zwei Karten deines Decks. |

---

## 15. Endlosmodus: Die Schwarze Spirale

Nach dem Storyboss:

> **„DIE WELT IST NICHT DAS ENDE."**

Dann erscheint **XXII — Das Schicksal**, eine Karte, die es im normalen
Tarot nicht gibt. Damit beginnt der Endlosmodus.

**Alle 5 Räume** nimmt die Spirale ein **Verderbtes Arkanum** dauerhaft auf.
Sie bleiben und **stapeln sich**:

- *Der Mond*: Gegnerabsichten bleiben verborgen — dafür Zukunftskarten +40 %
- *Der Turm*: Alle Gegner +30 % Schaden; alle 3 Kämpfe verlieren alle 20 % HP
- *Der Teufel*: +50 % Schaden, jede Heilung erzeugt 1 Verderbnis
- *Der Tod*: Jeder Boss vernichtet dauerhaft eine Karte — aber jede
  gelöschte Karte stärkt eine andere
- *Gerechtigkeit*: Jeder Status, den du erhältst, trifft auch den Gegner
- *Der Gehängte*: Die Legung bleibt gespiegelt

Gleichzeitig eskaliert dein Build weiter. Nach Ebene 20 hast du vielleicht
25 Charm-Stacks gegen 7 globale Flüche. Gegner-HP wächst superexponentiell
(`1,19^t · (1 + 0,012·t²)`), damit auch absurde Builds irgendwann scheitern.

Genau dort soll der Endlosmodus völlig wahnsinnig werden.

---

## 16. Luck

Luck ist sichtbar, aber **nicht ständig würfelnd**. Es wirkt dort, wo der
Spieler es sehen kann: bei Belohnungen.

Mit Luck 4:
- eine der drei Karten ist bereits verbessert
- eine seltenere Karte erscheint
- eine vierte Option erscheint (über *Goldener Würfel*)

So spürt man Luck, ohne dass im Kampf permanent Zufall passiert.

---

## 17. Wiederspielwert

| Hebel | Wirkung |
|---|---|
| **6 Deuter** | Eigene Startdecks *und* eine geänderte Grundregel. *Der Verbrannte* kann gar nicht heilen; *Das leere Blatt* legt 4 Karten pro Zug, startet aber mit 6 Karten und Verderbnis. |
| **Interpretationen** | Meta-Progression ist kein „+5 % Schaden", sondern: du verstehst das Tarot besser. Erste Begegnung mit *Der Tod*: „Tod bedeutet nicht immer Ende." Nach 5 Begegnungen: neue Lesart *Transformation* — ab dann kann das Arkanum in künftigen Runs andere Effekte haben. |
| **Totenkarten** | Jeder Tod formt eine Karte aus deinem Run (Deuter, Raum, Deckgröße, Verderbnis, Charms). Sie kann späteren Runs begegnen. |
| **Tageskarte** | Ein Seed für alle Spieler pro Tag, Bestenliste. Der RNG ist dafür vollständig deterministisch und über Plattformen hinweg gleich. |
| **Schleier** | Schwierigkeitsstufen 0–8 nach dem ersten Sieg. |
| **Sammlung** | 78 Tarotkarten als Sammelobjekt, Kunst wird freigeschaltet. |

---

## 18. Was bereits läuft

| System | Zustand |
|---|---|
| Legung, Positionen, Echo, Muster, Schicksalsfäden | vollständig, getestet |
| 56 Kleine Arkana inkl. Hofkarten-Figuren | vollständig |
| 22 Große Arkana, drei Gesichter je Arkanum | Daten vollständig, ~80 % der Effekte verdrahtet |
| 50 Charms, 22 Items | Daten vollständig, Charms wirken |
| Status, Schaden, Schild, Blutung/Gift/Glut/Traum | vollständig, getestet |
| 24 Gegner, 7 Bosse mit Regelbrüchen | vollständig |
| Run, Wegwahl, Händler, Ritual, Beute, Verderbnis | vollständig |
| Endlosmodus mit stapelnden Arkana | vollständig |
| Speichern/Laden mitten im Run | vollständig, getestet |
| UI (Hochformat, spielbar) | Prototyp ohne Animation und Kunst |
| Animation, Ton, Kunst | offen — siehe `docs/05_ROADMAP.md` |

**193 automatisierte Tests**, `tools/sim.gd` spielt komplette Runs für
Balancing. Details in `docs/04_BALANCING.md`.
