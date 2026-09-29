# Spaß — was TARTOT von Balatro und Inscryption lernt

> [`SUCHT.md`](SUCHT.md) beschreibt, warum man *noch einen Run* spielt.
> Dieses Dokument beschreibt, warum sich **ein einzelner Zug** gut anfühlt,
> warum die Entscheidungen darin interessant sind und wie die Herausforderung
> gebaut ist.

Die beiden Vorbilder machen zwei verschiedene Dinge richtig:

- **Balatro** macht Zahlen körperlich. Jeder Wert springt, zählt und
  explodiert. Die Entscheidung liegt in einem kleinen, harten Puzzle: welche
  fünf Joker, in welcher Reihenfolge.
- **Inscryption** macht Karten zu Dingen auf einem Tisch. Man opfert sie,
  näht sie zusammen und verliert sie an einen Spielleiter, der einem
  gegenübersitzt und schummelt.

TARTOT sitzt zwischen beiden. Die Legung aus Vergangenheit, Gegenwart und
Zukunft ist ein Balatro-Rechenpuzzle. Die Wahrsagerin am Tisch ist eine
Inscryption-Bühne.

---

## 1. Die Lehren

### Balatro

| # | Lehre | Wie Balatro es macht |
|---|---|---|
| B1 | **Die Zahl muss explodieren können** | Chips × Mult, erst addieren, dann multiplizieren. Builds wachsen exponentiell. |
| B2 | **Man sieht und spürt die Rechnung** | Karte für Karte zählt hoch, der Ton steigt mit, am Ende brennt die Zahl. |
| B3 | **Wenige Plätze, Reihenfolge zählt** | 5 Joker, links nach rechts. Jeder neue Joker heißt: welcher fliegt raus? |
| B4 | **Macht über den Zufall** | 4 Hände, 3 Abwürfe je Runde. Man jagt die Straße, statt auf sie zu hoffen. |
| B5 | **Sparen ist eine Entscheidung** | Zinsen: 1 $ je 5 $ Guthaben, höchstens 5 $. Jetzt kaufen oder wachsen lassen? |
| B6 | **Schichten auf einer Karte** | Verzauberung, Edition und Siegel. Eine einzelne Karte wird ein Projekt. |
| B7 | **Die Regel wird vorher angesagt** | Boss-Blinds zeigen ihre Regel, bevor man spielt. Man plant dagegen. |
| B8 | **Seltenheit lesbar machen** | Gewöhnlich, ungewöhnlich, selten, legendär mit festen Farben auf jeder Karte. |
| B9 | **Juice überall** | Karten wackeln, kippen, federn nach. Nichts passiert ohne Rückmeldung. |

### Inscryption

| # | Lehre | Wie Inscryption es macht |
|---|---|---|
| I1 | **Opfer als Preis** | Starke Karten kosten Blut: man opfert eigene Karten. Schwache Karten werden wertvoll. |
| I2 | **Eigene kaputte Karten bauen** | Am Opferstein wandert ein Siegel von einer Karte auf eine andere. |
| I3 | **Spannung als Waage** | Statt Lebenspunkten kippt eine Waage. Wer 5 vorn liegt, gewinnt. Jeder Punkt zählt sichtbar. |
| I4 | **Der Gegner ist eine Person** | Leshy sitzt am Tisch, erzählt, setzt Masken auf, schummelt, kommentiert. |
| I5 | **Bosse bringen Requisiten** | Der Goldsucher macht Karten zu Nuggets, der Angler hakt sie weg. Jeder Boss ist ein kleines Rätsel. |
| I6 | **Risiko beim Verbessern** | Am Lagerfeuer wird eine Karte stärker. Jedes weitere Mal kann sie gefressen werden. |
| I7 | **Der Tod hinterlässt etwas** | Nach dem Scheitern baut man aus dem Run eine Todeskarte, die später wiederkommt. |

---

## 2. Wo TARTOT steht

| Lehre | TARTOT heute | Lücke |
|---|---|---|
| B1 Zahl explodiert | Chips × Mult, Muster, Kette, Positionen, Editionen | — |
| B2 Rechnung spüren | Kaskade im Godot-Addon (`WertungsKaskade`), Kern liefert `ScoreBreakdown.Steps` | **Klang fehlt**, Unity zeigt nur die Summe |
| B3 Plätze und Reihenfolge | Charms ohne Grenze, ohne Reihenfolge | **größte Lücke** |
| B4 Macht über Zufall | Glück: 2 je Kampf, tauscht je eine Karte | **zu wenig**, keine Abwürfe mehrerer Karten |
| B5 Sparen | Gold, Überschuss-Gold, Händler | **keine Zinsen** |
| B6 Schichten | Stufe, Schimmer-Leiter, Umkehrung, **Editionen (neu)** | Siegel fehlen |
| B7 Regel angesagt | Regelbrecher-Bosse, beim Aktstart angekündigt | Regel liegt nicht als Karte sichtbar auf dem Tisch |
| B8 Seltenheit | **neu**: Raute, Pille, legendärer Glanz | — |
| B9 Juice | **neu**: Feder, Neigung, Stoß, Schatten, Austeilen | — |
| I1 Opfer | Teufelspakt, der Tod nimmt Karten | Opfern kann man nie selbst |
| I2 Eigene Karten | Händler: vergessen, spiegeln, umdrehen | **kein Übertragen** von Edition oder Schimmer |
| I3 Waage | Haltung und Siegel als Spannungsbogen | passt, keine Änderung nötig |
| I4 Gegner als Person | Deuter, Ereignisse als Zwischensequenzen | **niemand sitzt am Tisch** |
| I5 Bosse mit Requisiten | Turm stürzt Plätze ein, Mond verschleiert, Teufel verhandelt | passt |
| I6 Risiko beim Verbessern | Rast heilt oder verbessert, ohne Risiko | fehlt |
| I7 Tod hinterlässt etwas | Das Grab mit der besten Karte | passt |

---

## 3. Vorschläge, nach Wirkung geordnet

Jeder Vorschlag nennt die Regel mit Zahlen, warum sie Spaß macht, wo sie im
Kern landet und woran man sieht, ob sie funktioniert. Zielwerte bleiben die
aus [`BALANCING.md`](BALANCING.md): 30–35 % Siege auf Schleier 0.

### 1 · Die Auslage — fünf Charm-Plätze, Reihenfolge zählt (B3)

**Regel.**

- Charms liegen in einer Reihe aus **5 Plätzen** über dem Tisch.
- Beim Werten wirken sie **von links nach rechts**, nach den Karten und vor
  den ×-Faktoren der Editionen.
- Ein sechster Charm verlangt, einen der fünf zu **verkaufen**. Der Verkauf
  bringt die Hälfte des Preises.
- Charms lassen sich zwischen den Kämpfen per Ziehen umsortieren.
- Neue Charm-Art **Wertungscharm** (etwa 12 Stück), zum Beispiel:
  - *Stundenglas:* +4 Mult.
  - *Spiegelscherbe:* wiederholt den Charm links von ihr.
  - *Rabenfeder:* ×1,5 Mult, wenn die Zukunft eine Schwerterkarte hält.
  - *Kerzenstummel:* ×2 Mult, wird jeden Kampf um 0,1 schwächer.
- Die bestehenden 50 Charms bleiben. Wirtschafts- und Schildcharms zählen
  als **Talismane** und haben eine eigene Leiste mit 3 Plätzen.

**Warum es Spaß macht.** Jeder Fund ist eine Entscheidung statt ein
Geschenk. Die Reihenfolge ist ein Puzzle, das man in Ruhe lösen kann.
Die Kaskade bekommt einen zweiten Akt: erst springen die Karten an, dann
leuchten die Charms der Reihe nach auf.

**Kern.**

- `RunState.Charms` wird eine geordnete Liste mit Grenze.
- `CombatSystem.CalculateScore` bekommt einen Charm-Schritt je Platz.
  `ScoreStep` trägt dafür schon `Label`; eine `CharmId` kommt dazu.
- Verkaufen kommt in `ProgressionSystem`.
- Das Speicherformat braucht die Reihenfolge.

**Messen.**

- Siegquote.
- Wie oft der Autopilot verkauft.
- Median und Spitze des Rekords: die Spitze soll deutlich steigen, der
  Median kaum.

### 2 · Abwürfe — drei je Kampf (B4)

**Regel.**

- Jeder Kampf beginnt mit **3 Abwürfen**. Ein Abwurf legt bis zu 3
  Handkarten ab und zieht gleich viele nach.
- Ein Abwurf kostet keinen Zug.
- Glück geht darin auf: heute tauscht es 2-mal je Kampf eine einzelne
  Karte. Charms mit Glück geben künftig +1 Abwurf.
- Die *Fadenspule* (`DiscardBoost`) wird damit endlich ein Baustein.

**Warum es Spaß macht.** Muster jagt man dann, statt auf sie zu hoffen.
Der Beinahe-Hinweis („Die 7 der Kelche vollendet DIE WELT“) wird zur
Aufforderung: abwerfen und die 7 suchen.

**Kern.**

- `CombatState.Discards`.
- `CombatSystem.Discard(run, combat, ids)`, gebaut wie `LuckReroll`.
- Der Autopilot wirft ab, wenn ihm ein Muster fehlt.

**Messen.**

- Anteil der Züge mit Muster.
- Wie oft DIE WELT fällt. Der Autopilot, der alle Legungen durchprobiert,
  legt sie schon 22-mal je Run; Menschen seltener. Steigt der Wert mit
  Abwürfen deutlich, wird sie Routine: dann sinkt ihr Mult, und das Große
  Omen wird die neue Spitze.
- Siegquote. Sie wird steigen; ausgleichen über die Lebenspunkte der
  Gegner, nicht über weniger Abwürfe.

### 3 · Klangleiter in der Kaskade (B2)

**Regel.**

- Jeder Zählschritt spielt denselben Ton, **einen Halbton höher** als der
  vorige, höchstens eine Oktave.
- Jeder ×-Faktor spielt einen tiefen Schlag.
- Die tödliche Summe spielt einen Akkord und das Knistern eines
  Filmprojektors.

**Warum.** Balatro trägt die Hälfte seines Gefühls über den Ton. Die
steigende Leiter lässt den Spieler mitzählen, ohne hinzusehen.

**Umsetzung.**

- Im Godot-Addon: ein `AudioStreamPlayer` in `WertungsKaskade`,
  `pitch_scale = pow(2, schritt / 12.0)`.
- Drei Klänge genügen.

### 4 · Zinsen (B5)

**Regel.**

- Nach jedem gewonnenen Kampf gibt es **+1 Gold je 10 Gold** im Beutel,
  höchstens +4.
- Die Obergrenze hebt der Charm *Gier* (`Greed`).

**Warum.** Das Gold-Einkommen ist heute fest, deshalb gibt es beim Händler
nur eine Frage: „leiste ich mir das?“. Mit Zinsen kommt eine zweite dazu:
„wachse ich lieber?“.

**Vorsicht.** Der Autopilot beendet einen Run heute mit 177 ungenutztem
Gold: Gold ist schon zu reichlich. Zinsen nur zusammen mit knapperem
Grundeinkommen (heute 12 + 3 je Kampf, künftig etwa 10 + 2) oder mit der
Auslage, deren Charms Gold kosten. Sonst verstärken sie den Überfluss.

**Kern.** `ProgressionSystem` nach dem Kampf, zusammen mit dem
Überschuss-Gold.

**Messen.**

- Ungenutztes Gold am Ende. Heute 177; Ziel unter 60.
- Wie oft beim Händler gar nichts gekauft wird.

### 5 · Siegel auf Karten — die dritte Schicht (B6)

Wachssiegel in der Ecke der Karte, neben Stufe/Schimmer und Edition:

| Siegel | Wirkung |
|---|---|
| **Blutsiegel** | Die Karte zählt zweimal (in der Kaskade springt sie zweimal an). |
| **Goldsiegel** | +3 Gold, wenn sie gespielt wird. |
| **Indigosiegel** | Bleibt sie am Zugende auf der Hand: +1 Glück (höchstens 3 je Kampf). |
| **Aschesiegel** | Abgeworfen: +0,5 Mult für den Rest des Kampfs. |

Siegel gibt es bei Ereignissen und beim Händler. Pro Karte ist ein Siegel
erlaubt. Die Aufgabe dahinter heißt, *eine* Karte zum Star zu machen.

**Kern.**

- `CardInstance.Seal`, gebaut wie `Edition`.
- Ein Schritt in `CalculateScore`.
- Speicherfeld `seal`.

**Godot.** Ein Siegelbild (16 × 16) in `kunst/siegel/`. `TarotKarte`
zeichnet es rechts unten neben die Seltenheit.

### 6 · Der Opferaltar (I1, I2)

**Regel.**

- Neues Ereignis und neue Option an der Rast.
- Man **opfert eine Karte** und überträgt dabei ihre Edition, ihr Siegel
  oder ihre Schimmerstufe auf eine andere Karte.
- Die geopferte Karte verlässt das Deck.
- Mindestdeckgröße bleibt `MinimumDeckSize`.

**Warum.** Schwache Karten mit guter Edition werden wertvoll, und man baut
sich die eine kaputte Karte selbst. Es ist zugleich eine Deckverkleinerung,
die man sich verdienen muss, statt sie zu kaufen.

**Kern.**

- `ProgressionSystem.Sacrifice(run, from, to, what)`.
- Neues Ereignis in `Content/Events.cs`.

### 7 · Die Wahrsagerin am Tisch (I4)

**Regel.** Der Gegenüber ist eine Figur, die **Kartenlegerin**: nur Hände,
Ärmel und ein Gesicht im Schatten, im Stil der Rubberhose-Figuren. Sie
kommentiert:

- Beinahe-Treffer, zum Beispiel „Fast. Die Welt hat dich gesehen.“
- Rekorde.
- Wie lange man zögert.
- Zerspringende Glaskarten.

In Bosskämpfen **schummelt** sie sichtbar: sie zieht dem Teufel eine Karte
aus dem Ärmel, legt dem Turm einen Stein nach.

Regeländerungen kommen aus ihrem Mund, nicht aus einem Textfeld.

**Warum.** Inscryption ist spannend, weil einem jemand gegenübersitzt. Die
bestehenden Hinweise (`CombatSystem.AddHints`) und Animations-Cues
(`AnimationCues`) liefern schon alle Anlässe. Es fehlen nur Zeilen und eine
Figur.

**Kern.** Keine Regeländerung. Eine Tabelle Anlass → Sätze in
`Content/`, die UI zieht zufällig ohne Wiederholung.

### 8 · Die Regel als Karte (B7, I5)

**Regel.** Der Boss legt seine Regel **als große Karte** quer über den
Tisch, bevor der Kampf beginnt. Beim Bruch des Siegels dreht sie sich um
und zeigt die Verschärfung.

**Warum.** Die Regeln existieren schon. Auf dem Tisch werden sie zu einem
Gegenstand, den man ansieht und gegen den man plant, statt zu einer Zeile,
die man überliest.

**Godot.** `TarotKarte` mit `GROESSE × 1,5`, Motiv aus dem Boss-Blatt;
`umdrehen()` ist schon da.

### 9 · Lagerfeuer mit Risiko (I6)

**Regel.**

- An der Rast gibt es **+2 Stufen für eine Karte**.
- Man darf nochmals verbessern. Beim zweiten Mal verbrennt die Karte zu
  25 %, beim dritten zu 50 %.
- Verbrennt sie, wird sie zu **Asche**: eine Karte mit Rang 1, die
  zweimal zählt.

**Warum.** Gier gegen Vernunft, mit einem schönen Scheitern. Die
Brennen-Auflösung aus dem Addon passt genau.

### 10 · Herausforderungs-Decks

Feste Startdecks und Regeln, freigeschaltet über Prophezeiungen:

- **Glashaus:** alle Karten gläsern.
- **Nur Schwerter.**
- **Der Turm steht immer:** jede Runde ein eingestürzter Platz.
- **Blinde Wahrsagerin:** Zukunft immer verdeckt.

Das ist billig, denn Schleier, Deuter und Tageskarte haben die Infrastruktur
schon. Es ist Balatros Challenge-Liste und Inscryptions Kaycee's Mod.

### Später oder bewusst nicht

- **Karten verschmelzen:** zwei gleiche werden eine mit beiden Editionen.
  Das ist reizvoll, aber erst sinnvoll, wenn Siegel und Altar gemessen sind.
- **Die Waage statt Lebenspunkten:** die Haltung erfüllt diese Rolle
  schon. Beides zusammen wäre doppelt.
- **Negativ-Edition** (Balatro: +1 Jokerplatz): erst mit der Auslage.
  Dann wäre sie die fünfte Edition, eine *Schwarze* Karte mit +1 Platz.
- **Glücksspiel mit echtem Geld, Energie-Timer, Lootboxen:** nein.
  Siehe [`SUCHT.md`](SUCHT.md).

---

## 4. Das Kartengefühl

Umgesetzt in `godot-karten/addons/tartot_karten/` (siehe dortige README).
Die Werte hier sind der Ausgangspunkt fürs Feintuning.

| Moment | Verhalten | Werte |
|---|---|---|
| Ruhe | Karte wiegt sich, kreist leicht in der Neigung | ±1°, Neigung 0,22 |
| Drüberfahren | hebt sich, wird größer, kippt zum Zeiger, Nachbarn weichen | +60 px, ×1,14, bis 22°, Nachbarn 42 px |
| Antippen | bleibt angehoben (gewählt), kurzer Stoß | +40 px, Stoß 0,08 |
| Ziehen | hängt straff am Finger, legt sich in die Bewegung, Schatten fällt weiter | Feder 900/34, Schwung 0,0011 |
| Loslassen | federt weich ins Ziel und schwingt nach | Feder 170/14 |
| Einrasten auf Platz | Stoß, Größe 0,96 | Stoß 0,16 |
| Zählen | Stoß je Schritt, Tempo steigt | 0,42 s → ×0,86 → min. 0,2 s |
| Faktor | großer Stoß, Bildschirm wackelt | Stoß 0,32, Wackeln 8 |
| Tödlich | goldene Zahl, Funken, starkes Wackeln | bis 22 × 1,6 |
| Austeilen | fliegt verdeckt heran, dreht sich um | 0,22 s, Wendung 0,09 + 0,12 s |
| Zerspringen | löst sich von den Rändern her auf | 0,8 s |

## 5. Seltenheit und Editionen

**Seltenheit** hängt an der Karte selbst:

- Zahlen sind gewöhnlich, Hofkarten ungewöhnlich, Arkana selten.
- Narr, Rad und Welt sind legendär.

Sie steht auf drei Ebenen:

- als Raute auf der Karte,
- als farbige Pille im Info-Fenster,
- bei legendären Karten zusätzlich als goldener Glanz über die ganze Karte.

**Editionen** veredeln eine einzelne Karte:

| Edition | Wirkung | in Belohnungen | Shader |
|---|---|---|---|
| Schimmernd | +6 Chips | 2,5 % | Folienstreifen |
| Leuchtend | +0,4 Mult | 1,5 % | schillernder Schein |
| Brennend | ×1,4 Mult, +3 Brand, kostet 2 LP | 0,8 % | Glut und Flammen |
| Gläsern | ×1,8 Mult, zerspringt zu 25 % | 0,7 % | Glasmorphism |

Gläsern und Brennend sind **Wetten**: die stärksten Faktoren, mit einem
Preis, der in der Kaskade sichtbar wird. Die Glaskarte zerspringt vor den
Augen, die brennende Karte kostet Leben. Die Werte und die Messung stehen in
`Editions.cs` und `EditionTests.cs`.

## 6. Fahrplan

| Schritt | Inhalt | Aufwand | Wirkung |
|---|---|---|---|
| 1 | Abwürfe, Zinsen, Klangleiter, Kaskade im Hauptspiel | klein | hoch |
| 2 | Auslage mit Reihenfolge, 12 Wertungscharms, Verkaufen | groß | sehr hoch |
| 3 | Siegel, Opferaltar, Lagerfeuer | mittel | hoch |
| 4 | Wahrsagerin am Tisch, Regel als Karte | mittel (vor allem Kunst) | hoch |
| 5 | Herausforderungs-Decks | klein | mittel |

Nach jedem Schritt folgen dieselbe Messung wie in
[`BALANCING.md`](BALANCING.md) (400 Runs, Siegquote, Tode je Akt) und ein
Test je neuer Regel.
