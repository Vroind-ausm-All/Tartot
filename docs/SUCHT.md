# Die Sucht-Architektur

> „Noch ein Run.“ — der Satz, um den es geht.

TARTOT soll süchtig machen im Sinn von *noch einmal*: jeder Tod hinterlässt
einen Grund weiterzuspielen, jeder Zug hat einen Moment, auf den man hinfiebert,
jeder Run erzählt etwas, das der letzte noch nicht erzählt hat. Erreicht wird
das über **Meisterschaft, Neugier und Beinahe-Momente** — nicht über Timer,
Streak-Strafen oder Lootboxen. Ein Kaufspiel für 2,49 € ohne In-App-Käufe hat
für solche Tricks keinen Geschäftsgrund, und Spieler nehmen sie übel.

Das System arbeitet auf drei Zeitskalen. Jede hat ihre eigenen Haken, und jede
füttert die nächste.

```
 SEKUNDEN  der Zug        Vorschau · Beinahe-Hinweis · Musterkette · Überschuss · Rekord
    │
 MINUTEN   der Run        Akte · angekündigte Omen · Regelbrecher · Wegwahl · Ereignisse
    │                     Verdunkelung · Omen-Beute · Finale aus deinen Bossen · Spirale
    │
 TAGE      die Laufbahn   Prophezeiungen · Deuter · Schleier · Lesarten · Geschichten
                          über Runs · das Grab · Tageskarte · der Run-Bericht
```

---

## 1. Der Zug — der Moment, auf den man hinfiebert

### Die Vorschau sagt, was *fast* geht

Die Vorschau rechnet nicht nur `Chips × Mult = Fate`, sie zeigt auch, was
beim Gegner ankommt („→ Haltung deckelt: 70“, „→ HALTUNG BRICHT“) — und was
knapp fehlt:

- *„Die 7 der Kelche vollendet DIE WELT (21).“* — die Karte liegt auf der Hand.
- *„Die 6 der Stäbe macht den Dreiklang.“*
- *„Summe 19: nur 2 neben DIE WELT.“*
- *„TÖDLICH – dieser Treffer beendet den Kampf.“*

Das ist der Cloverpit-Moment am Automaten: man sieht die zwei Kirschen und
wartet auf die dritte. Nebenbei lehrt es die Muster, ohne dass ein Tutorial
sie erklären muss. Die Hinweise nennen immer eine **konkrete Karte auf der
Hand**, nie eine abstrakte Regel.

> `CombatSystem.AddHints` · Tests in `MomentTests`

### Die Musterkette

Jede Legung mit einem Muster (Paar oder besser) in Folge verlängert die Kette,
jedes Glied gibt +0,10 Multiplikator, höchstens fünf. Eine Legung ohne Muster
bricht sie. *Drei Pfade* zählt bewusst nicht — es kommt fast von allein, und
eine Kette, die sich von selbst hält, ist keine Entscheidung.

Die Kette ist die Spannung *zwischen* den Zügen: man hält eine schwächere
Hand zurück, um nicht abzureißen. Sie spielt gegen den Wiederholungs-Malus —
dieselbe Legung zweimal hält die Kette, kostet aber Wirkung.

### Überschuss

Was ein tödlicher Treffer mehr nimmt, als da war, zahlt Gold aus (je 8
Überschuss ein Gold, gedeckelt je Akt). Der letzte Schlag soll groß sein
dürfen — und groß sein *lohnen*. Das ist Balatros „die Blinde weit
überbieten“.

### Rekorde zählen die Legung, nicht den Schaden

Der Haltungsdeckel begrenzt, was beim Gegner ankommt. Der Rekord misst
deshalb den **Wert der Legung** vor dem Deckel. Die erste Messung hatte den
gedeckelten Schaden gezählt — und der Rekord klebte bei 224 bis 228, also
genau am Deckel der Akt-III-Bosse. Er maß den Deckel, nicht den Build. Jetzt
streut er echt (Median 327, Spitze 764), und „Neuer Rekord“ bedeutet etwas.

---

## 2. Der Run — ein Bogen statt einer Liste

### Drei Akte, ein Finale, eine Spirale

| Akt | Kämpfe | Boss (einer von zwei, beim Start angekündigt) |
|---|---|---|
| I — Der Jahrmarkt der Omen | 4 + Boss | XVI Der Turm · XVIII Der Mond |
| II — Das Haus der Spiegel | 4 + Boss | XIII Der Tod · X Rad des Schicksals |
| III — Die Schwarze Messe | 4 + Boss | XV Der Teufel · XII Der Gehängte |
| Finale | 1 | **XXI Die Welt** — trägt die Regeln der Bosse, die *du* geschlagen hast |
| Die Schwarze Spirale | endlos | alle vier Kämpfe der Weltenwurm, mit Regeln, die sich stapeln |

Vorher gab es acht Gegner in fester Reihenfolge, und **96 % der Runs schlugen
alle acht** — die gebaute Strecke war ein Tutorial. Jetzt stirbt man verteilt
über den ganzen Bogen:

| | Akt I | Akt II | Akt III | Finale | **Sieg** |
|---|---|---|---|---|---|
| Runs, die hier enden | 12 % | 12 % | 20 % | 23 % | **34 %** |

*400 Runs, Wahrsagerin, Schleier 0. Der Autopilot spielt wie ein
aufmerksamer Spieler im dritten Run.*

Die Tode in Akt I fallen fast alle am ersten Boss, nicht an den normalen
Gegnern — die lehren. Jeder Gegner hat ein **eigenes Absichtsmuster**
(„Die Münze mit Zähnen“: Schild, Angriff, Angriff), damit man ihn lesen und
überlisten kann.

### Regelbrecher

Kein Boss hat einfach mehr HP. Jeder nimmt eine Selbstverständlichkeit weg —
und verschärft die Regel, sobald ein Siegel bricht. Der Boss verändert sich
**während** des Kampfes.

| Boss | Regel | Nach dem Siegel |
|---|---|---|
| **Der Turm** | Jede 3. Runde stürzt eine Position ein | jede 2. Runde |
| **Der Mond** | Jede 2. Runde: Absicht verborgen, eine Handkarte verdeckt | Absicht immer verborgen, zwei Karten verdeckt |
| **Der Tod** | Zeichnet deine stärkste Karte; nach 3 Runden gehört sie ihm. **Leg sie in die Zukunft, um sie zu retten.** | nach 2 Runden |
| **Das Rad** | Deine Positionen rücken jede Runde eins weiter | es dreht rückwärts |
| **Der Teufel** | Bietet einen Pakt: +50 % Fate-Schaden gegen Max-HP und Verdunkelung. Ablehnen macht ihn wütend. | bietet erneut, teurer |
| **Der Gehängte** | Vergangenheit und Zukunft tauschen die Rollen | zusätzlich eine Handkarte weniger |

Alles ist **angekündigt, bevor es greift**: das Banner unter dem Namen, der
eingestürzte Platz, das ☠ auf der gezeichneten Karte, der Hinweis „wirkt als
GEGENWART“ auf verschobenen Plätzen. Ein Boss soll eine neue Frage stellen,
keine Falle sein. Die Wegwahl nennt den nächsten Boss und seine Regel schon
Kämpfe vorher — wer weiß, dass der Turm wartet, baut anders.

Gleich schwere Omen sind gleich fair: gemessen liegen die Bosse eines Akts
eng beieinander (Todesrate im Kampf — Akt I: Turm 13 %, Mond 10 %; Akt II:
Tod 11 %, Rad 8 %; Akt III: Teufel 13 %, Gehängter 11 %; die Welt 40 % derer,
die sie erreichen). Der Teufel lag zuerst bei 32 % und der Mond bei 2 % —
beide wurden nachgezogen.

### Das Finale ist dein eigenes

Die Welt trägt die Regeln der drei Bosse, die du in diesem Run geschlagen
hast, jeweils abgeschwächt. Wer Turm, Tod und Teufel hatte, spielt ein anderes
Finale als jemand mit Mond, Rad und Gehängtem. Acht mögliche Finale, ohne
eine Zeile Sondercode.

### Wegwahl mit Garantien

Nach jedem Kampf drei Wege: der direkte Kampf (+12 Gold für keinen Umweg) und
zwei aus Händler, Ritual, Orakel, Elite, Ereignis, Rast. Reiner Zufall wäre
hier schlechtes Design, deshalb:

- **vor jedem Boss** wird eine Rast angeboten,
- nach vier Schritten ohne Händler wird einer erzwungen,
- nie zwei Elites hintereinander und nie direkt vor einem Boss.

Elites geben verlässlich Charms — das Risiko hat einen sichtbaren Preis.

### Ereignisse: Zwischensequenzen, die sich erinnern

18 Szenen, jede eine kurze Zwischensequenz aus zwei bis drei Sätzen, die
**nacheinander** eingeblendet werden, dann eine Entscheidung, dann ein
Schlusssatz. Jede Wahl nennt ihren Preis — auch die Chancen beim Glücksspiel
(„Hälfte-Hälfte: +50 Gold oder −30 Gold“). Ein Glücksspiel mit bekannten
Chancen fühlt sich nach eigener Entscheidung an, eines mit versteckten nach
Betrug.

Drei Dinge machen sie zum Wiederspiel-Hebel:

- **Geschichten über mehrere Runs.** *Der Kartenspieler* begegnet dir am
  Kreuzweg, erinnert sich im nächsten Run an dich und zeigt im dritten sein
  Blatt — es sind deine Karten. *Die Tinte* führt nur durch dunkle Runs zum
  Schwarzen Blatt. Jede abgeschlossene Geschichte schaltet etwas frei.
- **Das Grab.** Die stärkste Karte deines letzten gescheiterten Runs liegt in
  einem Grab mit deinem Namen. Du kannst sie ausgraben.
- **Dunkle Varianten.** Ab Verdunkelung 40 sehen dich manche Szenen anders an
  („Du schon wieder.“).

### Je weiter, desto düsterer

Die **Verdunkelung** (0–100) steigt mit jedem Boss, jedem Pakt, jeder
Veredelung und dunklen Entscheidungen. Sie macht umgekehrte Karten stärker
(+1 Chip und +6 % Wirkung je 20), lässt Belohnungen häufiger verkehrt
erscheinen — und Gegner härter zuschlagen. Der Hintergrund des Spiels färbt
sich in fünf Stufen ins Blutrote.

Nach jedem Boss die **Omen-Beute**:

| | |
|---|---|
| **TRÄNKEN** | Die drei Karten, die den Boss besiegt haben, steigen eine Stufe und dunkeln nach — über Gold hinaus bis **Blut** und **Schwarz**. |
| **BINDEN** | Das Omen selbst kommt ins Deck: verkehrt herum und blutig. |
| **BANNEN** | Gold, Heilung, und ein wenig Licht kehrt zurück. |

Das ist der Satz aus dem ursprünglichen Auftrag, als Mechanik: *man schlägt
Gegner, und die eigenen Karten werden davon besser — und dunkler.* Gemessen
endet ein Run im Schnitt bei Verdunkelung 35, und fast jeder hat am Ende eine
Karte mit Blutschimmer.

---

## 3. Die Laufbahn — warum ein Tod kein Verlust ist

### Prophezeiungen

19 Ziele über Runs hinweg. Sie schalten **neue Möglichkeiten** frei — 18
Charms und drei Deuter —, nie pauschale Kraft. Ein Veteran hat mehr
Werkzeuge, nicht mehr Schaden.

Die Ziele sind an gemessenen Verteilungen geeicht, nicht geraten: *„Lege eine
Legung im Wert von 500“* schafft der Autopilot in rund jedem zehnten Run,
*„Halte eine Musterkette über 7 Züge“* ebenso. Die erste Prophezeiung ist
garantiert — schon der erste Tod öffnet etwas.

Erfüllt sich eine Prophezeiung **mitten im Run**, wird sie sofort
eingeblendet, nicht erst im Bericht.

### Der Run-Bericht endet mit „Beinahe“

Die Reihenfolge ist Absicht: erst was du erreicht hast, dann was neu ist,
zuletzt was knapp verfehlt wurde. Der letzte Blick vor dem Knopf fällt auf
das Beinahe:

- *„Überschuss — 237 / 250 → Charm: Raubzahn“*
- *„XIII · Der Tod hatte noch 230 HP — Dahinter wartete Akt III“*
- *„Der Magier: noch 1 Begegnung bis zur Lesart ‚Transformation‘“*
- *„2 Kämpfe unter deinem Rekord“*

Der Boss-Hinweis erscheint nur, wenn wirklich wenig fehlte — ein Boss mit
vollem Leben ist kein Beinahe. **„NOCH EINMAL“** startet sofort mit derselben
Figur und demselben Schleier: zwischen Tod und nächstem Run liegt ein Tipp.

### Deuter

Vier spielbare Figuren, jede mit eigenem Startdeck und einer eigenen
Grundregel. Freigeschaltet werden sie dort, wo man ihr Spiel schon spielt:
der Aderleser kommt zu dem, der viel umgekehrt legt; der Eremit zu dem, der
einen Boss mit höchstens acht Karten schlägt.

### Schleier 0–8

Wer auf Schleier *n* gewinnt, öffnet *n + 1*. Jede Stufe nimmt eine
Sicherheit weg und stapelt sich mit den vorigen. Mehr Gegner-HP allein ändert
kaum etwas (die Kampflänge bestimmt der Haltungsdeckel); die Stufen greifen
deshalb dort an, wo es gemessen wirkt — Angriff, Bosshaltung, eigene
Lebenskraft — und die harten erst ab Akt II, damit nicht der erste Boss zur
Mauer wird.

### Lesarten

Jedes Große Arkanum, das man oft genug spielt, zeigt neue Lesarten: +10 %
Wirkung je Lesart, und wer alle drei kennt, legt es ohne Umkehrpreis. Zuerst
waren es +15 % — gemessen gewann ein voll gelesener Veteran damit 43 % statt
33 %. Das war mehr, als „Verständnis statt Kraft“ verspricht. Mit 10 % sind es
knapp 39 %.

### Tageskarte

Ein Seed für alle an einem Tag, dieselbe Figur, derselbe Schleier, **ohne**
Meta-Fortschritt — der Veteran spielt dieselbe Karte wie der Neuling. Auch
gesperrte Deuter kommen an die Reihe: wer ihn einmal gespielt hat, will ihn
freischalten. Bewusst **ohne Streak-Verlust**: wer einen Tag auslässt, verliert
nichts.

---

## 4. Wie das gemessen wird

```bash
dotnet run --project src/Tartot.Sim -c Release -- --runs=400 --detail=1 --stats=1
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --veilsweep=1
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --deuter=aderleser
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --fights=60 --spiral=1
dotnet run --project src/Tartot.Sim -c Release -- --runs=300 --career=1
```

`--detail` zeigt die Kurve je Kampf (Züge, HP davor und danach, Todesrate),
`--stats` die Verteilung jeder Run-Statistik, an der die Prophezeiungen
geeicht sind, `--career` eine ganze Spielerlaufbahn mit einem
Meta-Fortschritt: wann was freigeschaltet wird und ob Veteranen stärker
werden.

Die Zahlen und Befunde stehen in [`BALANCING.md`](BALANCING.md).
