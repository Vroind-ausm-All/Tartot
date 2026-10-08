# TARTOT — Produktvision

Status: verbindliche Produkt- und Präsentationsrichtung für den nächsten Entwicklungsschritt.

Diese Datei ergänzt ARCHITECTURE.md, SUCHT.md, SPASS.md, BALANCING.md und UNITY.md. Sie ersetzt keine Spielregel. Im Konfliktfall gilt weiterhin: Spielregeln liegen ausschließlich in Tartot.Core.

## 1. Produktversprechen

TARTOT ist kein Deckbuilder mit Tarot-Skin.

TARTOT ist ein taktisches Roguelike über eine Prophezeiung aus Vergangenheit, Gegenwart und Zukunft. Der Spieler sieht eine mögliche Zukunft, legt sie selbst auf den Tisch und versucht anschließend, sie gegen ein Schicksal zu verbiegen, das ebenfalls die Regeln verändert.

Der zentrale Satz lautet:

> Lege dein Schicksal. Lies, was geschehen wird. Entscheide, ob du es trotzdem wagst.

Das Spiel muss in den ersten 60 Sekunden verständlich machen:

- Ich habe Karten.
- Ich lege Vergangenheit, Gegenwart und Zukunft.
- Die Position verändert die Wirkung einer Karte.
- Ich sehe vor dem Ausführen, was meine Legung voraussichtlich bewirkt.
- Der Gegner verändert die Regeln.
- Ich kann darauf reagieren.

Für erfahrene Spieler muss derselbe Bildschirm zusätzliche Fragen öffnen:

- Welche Karte halte ich zurück?
- Halte ich meine Musterkette?
- Breche ich jetzt die Haltung oder bereite ich Burst vor?
- Lohnt sich die Zukunft trotz Gegneraktion?
- Kann ich DIE WELT erreichen?
- Muss ich meinen Build für das angekündigte Omen verändern?

## 2. Produktentscheidung

Unity ist die Produktionsplattform für PC, Android und iOS.

godot-karten bleibt als:

- Motion-Referenz,
- Shader- und Effektlabor,
- Art-Direction-Referenz,
- Quelle bereits getesteter Bewegungsparameter.

godot-karten wird nicht zu einem zweiten vollständigen Spiel ausgebaut.

Der vorhandene Tartot.Core bleibt die einzige Quelle für Regeln, Zustände, RNG, Savegames, Vorschau und Balancing.

## 3. Was bereits stark ist und erhalten bleibt

### 3.1 Regelkern

Der Kern ist die wertvollste technische Grundlage des Projekts:

- engine-unabhängig,
- deterministisch,
- mit benannten RNG-Teilströmen,
- Save/Load mitten im Kampf,
- Vorschau und tatsächliche Auflösung greifen auf dieselben Regeln zu,
- automatisierbare Simulation,
- umfangreiche Tests.

Diese Eigenschaften werden nicht für Präsentationskomfort aufgeweicht.

### 3.2 Die eigentliche Spielidentität

Folgende Mechaniken sind bereits stark genug, um die Identität des Spiels zu tragen:

- Vergangenheit / Gegenwart / Zukunft,
- Haltung als Burst-Fenster,
- Wiederholungs-Malus,
- Musterkette,
- Summe 21 = DIE WELT,
- angekündigte Regelbrecher-Bosse,
- Finale aus den tatsächlich besiegten Bossregeln,
- Verdunkelung,
- Omen-Beute,
- Grab des letzten Runs,
- Prophezeiungen,
- Deuter,
- Schleier,
- Tageskarte,
- Schwarze Spirale.

Die nächste Phase braucht deshalb nicht mehr Systeme, sondern eine deutlich bessere Verkörperung dieser Systeme.

### 3.3 Vorhandene Präsentationsdaten

Die Präsentation muss nicht aus Logs erraten, was passiert.

Bereits vorhanden sind unter anderem:

- CombatState.BlockedSlot für den Turm,
- CombatState.TowerCollapses,
- EnemyState.Phase,
- ScoreBreakdown mit Chips, Multiplier, FateDamage, ExpectedHit, BreaksStance, Lethal, Hints und Steps,
- ScoreBreakdown.Steps für die Wertungskaskade,
- TurnResult-basierte AnimationCues,
- ActiveRuleTexts für Bossregeln,
- Zustand für verdeckte, gezeichnete und verschobene Karten,
- Bossphasen und Siegelbruch.

Das ist die Grundlage der neuen Präsentationsschicht.

## 4. Audit der aktuellen Unity-Oberfläche

Die aktuelle Oberfläche ist funktional, aber noch keine überzeugende Verkörperung des Spiels.

### 4.1 Problem: Dashboard statt Tisch

Tartot.uxml organisiert den Kampf als vertikale Folge aus:

Gegner -> Werte -> Legung -> Vorschau -> Protokoll -> Hand -> Aktionsknopf.

Das ist logisch und testbar, aber visuell gleichgewichtet. Viele Informationen erscheinen als Label, Balken, Rahmen oder Textzeile. Dadurch liest der Spieler eine Oberfläche, statt an einem Tisch zu handeln.

Konsequenz:

Die Primärinteraktion wandert aus der statischen UI-Toolkit-Struktur in eine echte Unity-2D-Szene.

### 4.2 Problem: Karten sind UI-Elemente

CardElement ist ein VisualElement. Es kann Zustände gut darstellen, bleibt aber semantisch und haptisch ein UI-Objekt.

Es fehlen im Produktionspfad:

- physische Position im Tischraum,
- Federbewegung,
- Drag-Trägheit,
- Neigung,
- Schatten,
- Überschwingen,
- Nachbarverdrängung,
- räumliche Kollision mit Plätzen,
- starke Auflösungsanimationen.

Die Godot-Referenz besitzt diese Eigenschaften bereits als Prototyp.

### 4.3 Problem: Bossregel ist Text

Die Regel des Gegners steht aktuell als Banner unter dem Namen. Das ist korrekt, aber leicht zu überlesen und nicht Teil der Spielwelt.

Ziel:

Die Bossregel liegt als physische Regelkarte auf dem Tisch. Beim Siegelbruch transformiert oder wendet sie sich sichtbar.

Text bleibt verfügbar, ist aber Beschriftung des Gegenstands und nicht dessen einzige Existenz.

### 4.4 Problem: Animation ist zu eng an die Gegnerfigur gebunden

EnemyStage spielt Sprite-Streifen aus einer Queue. AnimationCues liefert bereits sinnvolle Zustände wie hit, phase2, attack1 und death.

Das ist wiederverwendbar, reicht aber nicht als Choreografie eines Zuges.

Ein Zug benötigt eine Sequenz über mehrere Darsteller:

- Karten,
- Schicksalsplätze,
- Wertung,
- Boss,
- Haltung,
- Gegnerangriff,
- Zukunft,
- Bossregel,
- Kamera,
- Audio,
- Haptik.

EnemyStage wird deshalb nicht verworfen, sondern später als Teil eines größeren Cue-Systems eingebettet oder ersetzt.

### 4.5 Problem: Portrait ist derzeit Struktur, nicht Profil

UNITY.md beschreibt eine feste Referenzauflösung 1080 x 1920. Das ist für Mobile sinnvoll, aber kein PC-Layout.

PC darf nicht aus einer hochskalierten Portrait-Fläche in der Bildschirmmitte bestehen.

Es braucht zwei Layoutprofile auf derselben Komponentenbasis:

- Mobile Portrait,
- Desktop Landscape.

## 5. Art Direction: Okkultes Tischtheater

Der Spieler soll sich fühlen, als säße er an einem physischen, unheimlichen Wahrsagetisch.

Schlüsselbegriffe:

- okkult,
- taktil,
- analog,
- düster,
- elegant,
- grotesk,
- Zelluloid,
- Tarotdruck,
- Papier,
- Tinte,
- Wachs,
- Staub,
- Kratzer,
- mechanische Bewegung,
- wenige starke Farben.

Nicht gewünscht:

- generisches Mobile-Game,
- Neon,
- Fantasy-RPG-HUD,
- Material-Design,
- viele schwebende Panels,
- permanente Tooltips,
- Textwände,
- sterile Oberflächen.

### 5.1 Materialhierarchie

Jedes wichtige System bekommt eine physische Entsprechung:

| System | Verkörperung |
|---|---|
| Hand | echte Karten im Fächer |
| Vergangenheit / Gegenwart / Zukunft | drei Plätze im Tisch / Tuch / Bühnenbild |
| Bossregel | große Regelkarte mit Wachssiegel |
| Haltung | sichtbare Versiegelung / Spannung am Bossrahmen, ergänzt um kompakte Zahl |
| Siegelbruch | Wachs reißt, Regelkarte wendet sich, Bühne reagiert |
| Verdunkelung | Tinte, Licht und Material des Tisches verändern sich |
| Muster | Verbindungslinie / Kaskade zwischen den gelegten Karten |
| DIE WELT | kurze Unterbrechung mit eigenem visuellen Takt |
| Omen-Beute | physische Entscheidung mit drei klaren Objekten |

### 5.2 Farbdisziplin

Die vorhandene Occult-Clean-Palette bleibt Ausgangspunkt:

- Schwarz / tiefe Brauntöne tragen den Raum.
- Elfenbein trägt Papier und Lesbarkeit.
- Ocker / Gold markiert Schicksal, Wertung und seltene Höhepunkte.
- Indigo markiert Geheimnis, Haltung und okkulte Gegenkraft.
- Blutrot markiert Gefahr, Verdunkelung und irreversible Eingriffe.

Farben sind semantisch, nicht dekorativ.

## 6. Informationshierarchie

Reihenfolge der Wahrnehmung:

1. Gegner und unmittelbare Bedrohung.
2. Eigene Hand.
3. Vergangenheit / Gegenwart / Zukunft.
4. Erwartetes Ergebnis der Legung.
5. Besonderheiten des Builds.
6. Sekundäre Werte.

Immer sichtbar:

- Gegner,
- Gegner-HP,
- Haltung bei relevanten Gegnern,
- nächste Absicht, sofern die Regel sie nicht verbirgt,
- eigene HP,
- eigener Schild,
- drei Schicksalsplätze,
- Hand,
- Ausführen,
- Live-Vorschau in einer kompakten Form.

Zurückhaltend oder kontextuell:

- Gold,
- Deckgröße,
- Ablage,
- ausführliche Charmtexte,
- Run-Statistiken,
- lange Regeltexte,
- Erläuterungen von Seltenheit / Edition / Schimmer.

## 7. Interaktionsprinzipien

### 7.1 Eine Karte ist ein Gegenstand

Die Bewegungswerte aus godot-karten sind die Referenz, nicht zwingend die endgültigen Zahlen:

- Hover-Lift ungefähr 60 px in der Godot-Referenz,
- Selected-Lift ungefähr 40 px,
- Hover-Skalierung ungefähr 1,14,
- maximale Neigung ungefähr 22 Grad,
- Drag-Feder ungefähr 900 / 34,
- Snap-Feder ungefähr 170 / 14,
- kleiner Stoß beim Einrasten.

In Unity werden diese Werte in Welt- oder Canvas-Einheiten übersetzt und auf unterschiedlichen Auflösungen normalisiert.

### 7.2 Jede Primäraktion funktioniert ohne Hover

Mobile ist Touch-first.

Deshalb:

- Tap wählt eine Karte.
- Tap auf einen Platz legt die gewählte Karte.
- Drag-and-drop ist eine gleichwertige, schnellere Alternative.
- Tap auf eine gelegte Karte nimmt sie zurück.
- Long Press öffnet Detailinformationen.
- Hover auf PC ist Verstärkung, nie einzige Informationsquelle.

### 7.3 Ungültige Ziele antworten sichtbar

Ein ungültiger Platz darf nicht nur Eingabe ignorieren.

Beispiele:

- eingestürzter Platz stößt die Karte zurück,
- Platz vibriert kurz oder zeigt einen Tintenriss,
- leiser Fehlklang,
- auf Mobile kurzer Haptikimpuls.

## 8. Die Wertung als Kaskade

ScoreBreakdown.Steps ist der Schlüssel zur Inszenierung.

Die Vorschau bleibt vor dem Ausführen schnell und lesbar. Beim tatsächlichen Ausführen wird dieselbe Logik als kurze Kaskade sichtbar:

Karte
-> Karteneffekt
-> Muster
-> Charm / Edition
-> Multiplikator
-> Fate
-> Haltung / Treffer

Die Kaskade darf einen normalen Zug nicht ausbremsen.

Zielwerte:

- gewöhnlicher Zug: ungefähr 2,5 bis 4 Sekunden bis wieder Eingabe möglich ist,
- große Arkana / Siegelbruch: kurze bewusste Verlängerung,
- wiederholte oder triviale Teilschritte dürfen beschleunigen.

Ein tödlicher Zug ist bereits in der Vorschau sichtbar und bekommt eine besondere Erwartung, bevor der Spieler ausführt.

## 9. Zielarchitektur der Unity-Präsentation

### 9.1 Schichten

Tartot.Core
- Regeln,
- Zustand,
- RNG,
- Savegames,
- Vorschau,
- TurnResult,
- ScoreBreakdown,
- Simulation.

Unity Application / Presenter
- liest Core-State,
- sendet Spieleraktionen an GameController / CombatSystem,
- erzeugt präsentationsneutrale Snapshots,
- leitet aus Vorher/Nachher und TurnResult eine Cue-Sequenz ab.

Unity 2D Presentation
- Tisch,
- Karten,
- Plätze,
- Gegnerbühne,
- Regelkarte,
- Kamera,
- Partikel,
- Audio,
- Haptik,
- Animation.

UI Toolkit
- Menüs,
- Einstellungen,
- klassische HUD-Werte,
- Run-Bericht,
- Händler / Ereignisse zunächst,
- Accessibility- und Detail-Overlays.

### 9.2 Presentation Snapshot

Die Unity-Schicht bekommt einen kleinen, unveränderlichen Snapshot dessen, was sie zum Darstellen braucht.

Beispiele:

- Turn,
- Handkarten-Ids,
- Karten auf den drei Plätzen,
- BlockedSlot,
- EnemyHp,
- EnemyStance,
- EnemyPhase,
- Intent,
- PlayerHp,
- PlayerShield,
- Preview.

Dieser Snapshot enthält keine neue Spielregel.

### 9.3 Presentation Cues

Cues entstehen in Unity aus existierenden Core-Fakten.

Beispiele:

- CardMovedToSlot,
- ScoreCardStep,
- ScorePatternStep,
- FateResolved,
- StanceBroken,
- EnemyHit,
- EnemyAttack,
- PlayerHit,
- PhaseChanged,
- SlotCollapsed,
- Victory,
- Defeat.

Ein Cue sagt WAS sichtbar gemacht werden muss, nicht WIE.

Beispiel:

SlotCollapsed(Future)

Die Präsentation entscheidet:

- Riss,
- Staub,
- Kamerastoß,
- Platzbild bricht,
- kurzer Klang,
- Haptik.

Der Core kennt weder Riss noch Kamerastoß noch Animationsdauer.

### 9.4 Bestehende AnimationCues

AnimationCues bleibt zunächst bestehen und wird als Boss-Animationshinweis verwendet.

Die neue Präsentationsschicht darf AnimationCues.ForTurn in ihre größere Sequenz einbetten.

Langfristig darf die Zuordnung aus dem Core entfernt oder neutraler benannt werden, aber nicht während des Vertical Slice, solange dadurch kein konkretes Problem gelöst wird.

### 9.5 Wann der Core überhaupt geändert werden darf

Nur wenn eine semantische Information für eine korrekte Darstellung fehlt und nicht zuverlässig aus vorhandenem Zustand / Ergebnis abgeleitet werden kann.

Dann gilt:

- Datenfeld ist engine-neutral,
- Name beschreibt Spielereignis statt Animation,
- Test im Core,
- Save-Kompatibilität prüfen, falls persistiert,
- keine Unity-Typen,
- keine Dauer,
- keine Farbe,
- keine Partikel- oder Kameradaten.

## 10. Wiederverwendung statt Neubau

| Bestand | Entscheidung |
|---|---|
| Tartot.Core | vollständig erhalten |
| Tartot.Sim | erhalten, nach jeder Regeländerung weiter nutzen |
| Tartot.Tests | erhalten und erweitern |
| CardElement | für Overlays / Deckansichten weiter nutzbar; nicht Hauptkarte im Kampf |
| TartotView.Overlays | zunächst behalten |
| Tartot.uxml / Tartot.uss | HUD / Overlay-Basis, Kampftisch schrittweise herauslösen |
| EnemyStage | Übergangslösung / Animationsdaten wiederverwenden |
| Resources/Tartot/Anim | wiederverwenden |
| godot-karten/karte.gd | Motion-Referenz |
| godot-karten/tisch.gd | Input- und Handlayout-Referenz |
| godot-karten/choreografie.gd | Boss-Choreografie-Referenz |
| godot-karten/effekte.gd | Effektbibliothek als visuelle Referenz |
| godot-karten/buehnen | Quellen für Bossbühne / Assets |
| tools/buehne | Asset-Pipeline erhalten |
| tools/klang | Audio-Prototypen erhalten |

## 11. Responsive Design

### Mobile Portrait

Prioritäten:

- Hand im unteren Daumenbereich,
- drei Plätze mittig,
- Gegner oberhalb,
- Vorschau direkt am Entscheidungsraum,
- Safe Areas,
- Touch-Ziele mindestens etwa 44 logische Pixel,
- keine Pflicht-Hoverzustände,
- Detailinformationen über Tap / Long Press,
- Sekundärwerte einklappbar oder klein.

### Desktop 16:9

Prioritäten:

- Tisch nutzt horizontale Fläche,
- Gegner / Regelkarte bilden obere oder gegenüberliegende Tischhälfte,
- Hand darf breiter auffächern,
- Charms, Deck und Ablage können seitlich persistent sichtbar sein,
- Mausinteraktion mit Hover-Lift und Tilt,
- Controller später über dieselben Selektionszustände.

Beide Profile nutzen dieselben Komponenten, dieselben Core-Aktionen und dieselben Cue-Typen.

## 12. Wiederspielwert: Reihenfolge nach dem Vertical Slice

Keine neue Meta-Schicht vor einem überzeugenden Kampfgefühl.

Danach in dieser Reihenfolge prüfen:

1. Auslage und Wertungscharms: Builds bekommen erkennbare Motoren.
2. Siegel: einzelne Karten bekommen Identität und langfristige Bedeutung.
3. Opferaltar: Deckausdünnung plus Transfer erzeugt Entscheidungen.
4. Riskantes Lagerfeuer: Gier gegen Verlust.
5. Challenge-Decks: vorhandene Infrastruktur günstig für neue Run-Identitäten nutzen.

Messfrage nach jedem System:

> Erzeugt dies eine neue spielerische Identität oder nur eine weitere Zahl?

Wenn nur eine Zahl entsteht, wird es nicht priorisiert.

## 13. Nicht-Ziele

Für den Vertical Slice ausdrücklich nicht:

- kompletter visueller Umbau aller Menüs,
- neue Akte,
- neue Bosse,
- neue Meta-Währung,
- Online-Features,
- Accountsystem,
- Multiplayer,
- Monetarisierungssysteme,
- komplette Lokalisierungsarchitektur,
- vollständiger Controller-Support,
- Neuimplementierung des Kerns,
- Portierung der Godot-Skripte Zeile für Zeile.

## 14. Risiken

### Unity-Projekt ist noch nicht real auf Zielgeräten validiert

UNITY.md weist selbst darauf hin, dass der Unity-Pfad bisher vor allem per Stub kompiliert wurde.

Maßnahme:

Der Vertical Slice muss früh in einem echten Unity-Editor und auf mindestens einem Android- oder iOS-Gerät laufen.

### Zwei Präsentationswelten können auseinanderlaufen

Godot und Unity besitzen ähnliche Ideen.

Maßnahme:

Godot ab jetzt als Referenz einfrieren. Neue Produktionsarbeit ausschließlich in Unity.

### Zu viel Text trotz neuer Grafik

Viele vorhandene Zustände werden heute durch Labels erklärt.

Maßnahme:

Für jede sichtbare Information fragen:

> Kann der Spieler das sehen oder fühlen, statt es lesen zu müssen?

### Animation kann das Spiel verlangsamen

Die Mechanik lebt von häufigen Zügen.

Maßnahme:

CueRunner unterstützt unterschiedliche Geschwindigkeiten und Skip/Accelerate für wiederholte Sequenzen. Game Feel darf keine Wartezeit erzeugen.

### Responsive Layout kann zu zwei Produkten werden

Maßnahme:

Nur Layout-Profile unterscheiden sich. Komponenten, Inputzustände, Cue-Sequenzen und Spiellogik bleiben gemeinsam.

## 15. Produkt-Gates

Vor Content-Produktion müssen vier Gates bestanden sein.

### Gate A — Verständlichkeit

Ein neuer Spieler versteht innerhalb von 60 Sekunden Hand, drei Positionen, Vorschau und Bossregel.

### Gate B — Haptik

Karte auswählen, ziehen, platzieren und zurücknehmen fühlt sich auch ohne fertige Kunst befriedigend an.

### Gate C — Inszenierung

Der Turm-Kampf besitzt mindestens drei erinnerbare Momente:

- Bossregel wird physisch eingeführt,
- Siegelbruch verändert den Kampf sichtbar,
- ein Platz stürzt sichtbar ein.

### Gate D — Cross-Platform

Der gleiche Kampf ist auf Mobile Portrait und Desktop 16:9 ohne alternative Gameplay-Implementierung spielbar.

Erst danach wird die restliche Kampagne visuell migriert.
