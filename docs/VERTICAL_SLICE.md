# TARTOT — Vertical Slice: XVI Der Turm

Status: Implementierungsplan. Noch kein Auftrag zum großflächigen Umbau.

Ziel dieses Slices ist nicht, möglichst viel TARTOT zu zeigen. Ziel ist, einen einzigen vollständigen Kampf so gut zu machen, dass er die Produktionsrichtung für alle weiteren Kämpfe beweist.

## 1. Scope

Der Slice umfasst ausschließlich den Kampf gegen XVI — Der Turm und die unmittelbar anschließende Omen-Beute.

Enthalten:

- Kampfstart,
- Bossauftritt,
- physische Boss-Regelkarte,
- Hand ziehen,
- Karte auswählen,
- Tap-to-place,
- Drag-and-drop,
- Vergangenheit,
- Gegenwart,
- Zukunft,
- Live-Vorschau,
- Muster- und Wertungskaskade,
- Schicksal ausführen,
- Gegnerreaktion,
- Spielerschaden,
- Haltung,
- Siegelbruch,
- zweite Bossphase,
- Turm-Regel,
- sichtbar einstürzende Position,
- Boss-Niederlage,
- Omen-Beute,
- TRÄNKEN,
- BINDEN,
- BANNEN.

Nicht enthalten:

- visueller Final-Pass für andere Bosse,
- vollständiger Händler-Umbau,
- vollständiger Titelbildschirm-Umbau,
- neue Regeln,
- neue Meta-Systeme,
- neue Balancewerte.

## 2. Grundsatz

Der Slice spielt gegen den echten Tartot.Core.

Keine Turm-Regel wird in Unity nachgebaut.

Unity darf:

- vorhandenen Zustand darstellen,
- gültige Spieleraktionen auslösen,
- Vorschau abfragen,
- TurnResult darstellen,
- Vorher/Nachher-Zustände vergleichen,
- daraus Presentation Cues bilden.

Unity darf nicht:

- Schaden selbst berechnen,
- einen Platz nach eigener Rundenzählung blockieren,
- Haltung selbst brechen,
- Bossphase selbst wechseln,
- Omen-Beute simulieren.

## 3. Bestehende Core-Fakten für den Slice

Bereits vorhanden und direkt nutzbar:

- CombatState.Slots,
- CombatState.BlockedSlot,
- CombatState.TowerCollapses,
- CombatState.Enemy,
- EnemyState.Phase,
- CombatSystem.ActiveRuleTexts,
- CombatSystem.PreviewScore,
- ScoreBreakdown.Chips,
- ScoreBreakdown.Multiplier,
- ScoreBreakdown.FateDamage,
- ScoreBreakdown.ExpectedHit,
- ScoreBreakdown.BreaksStance,
- ScoreBreakdown.Lethal,
- ScoreBreakdown.Hints,
- ScoreBreakdown.Steps,
- TurnResult und seine bestehenden Kampfresultate,
- AnimationCues.ForTurn,
- GameController.ChooseBossLoot beziehungsweise vorhandener Boss-Loot-Pfad.

Wichtig:

Der Turm setzt den blockierten Platz im Core über PrepareRules. Unity stellt nur CombatState.BlockedSlot dar.

## 4. Spielablauf

### 4.1 Kampfstart

Zielgefühl:

Der Spieler betritt keine UI-Seite. Ein Tisch wird sichtbar.

Ablauf:

1. Tisch und Handbereich sind schon da.
2. Der Turm tritt / springt in seine Bühne.
3. Name und XVI erscheinen kurz.
4. Eine große Regelkarte wird vom Boss auf den Tisch gelegt.
5. Ein Wachssiegel sitzt auf dieser Karte.
6. Regeltext wird knapp lesbar.
7. Hand wird ausgeteilt.
8. Eingabe wird freigegeben.

Zielzeit:

ungefähr 2 bis 3 Sekunden bis zur ersten eigenen Aktion; Intro darf nach dem ersten Sehen beschleunigbar sein.

### 4.2 Karte wählen und legen

Tap-Pfad:

1. Karte antippen.
2. Karte hebt sich und bleibt gewählt.
3. gültige Plätze reagieren subtil.
4. Platz antippen.
5. Karte rastet ein.
6. Vorschau aktualisiert sich sofort.

Drag-Pfad:

1. Karte drücken und ziehen.
2. Karte hängt mit leichter Feder am Pointer.
3. gültiger Platz zieht die Karte visuell an.
4. loslassen.
5. Snap und kleines Überschwingen.

Rücknahme:

- gelegte Karte antippen oder zurück in die Hand ziehen.

Eingestürzter Platz:

- kann nicht Ziel sein,
- weist Drag sichtbar ab,
- Tap erzeugt kurzes negatives Feedback.

### 4.3 Live-Vorschau

Die Vorschau besteht aus zwei Ebenen.

Ebene 1 — sofort lesbar:

- Name des Musters,
- Chips x Multiplikator,
- Fate,
- tatsächlicher erwarteter Treffer,
- Haltung bricht,
- tödlich.

Ebene 2 — Beinahe-Hinweis:

- vorhandene ScoreBreakdown.Hints,
- konkret an eine Handkarte gebunden, sofern der Core dies bereits liefert.

Die Vorschau darf beim Kartenlegen keine lange Animation abspielen.

### 4.4 Schicksal ausführen

Nach Betätigung wird Eingabe gesperrt und eine Cue-Sequenz gestartet.

Beispiel eines normalen Zuges:

1. Karten setzen sich kurz.
2. Vergangenheit löst aus.
3. Gegenwart löst aus.
4. ScoreBreakdown.Steps laufen als beschleunigte Kaskade.
5. Fate-Zahl entsteht.
6. Haltung / Boss nimmt Treffer.
7. Gegner führt seine Absicht aus.
8. Zukunft löst aus.
9. neue Hand / neuer Zustand wird gezeigt.
10. Eingabe wird freigegeben.

Die genaue Reihenfolge muss dem Core entsprechen. Die Präsentation darf nicht der Regel vorgreifen.

## 5. Präsentationsarchitektur

Vorgeschlagene Ordnerstruktur:

~~~text
unity/Assets/Tartot/
  Presentation/
    Combat/
      CombatTableController.cs
      CombatPresentationAdapter.cs
      CombatPresentationSnapshot.cs
      CombatLayoutProfile.cs
    Cues/
      PresentationCue.cs
      PresentationCueBuilder.cs
      PresentationCueRunner.cs
    Cards/
      CardView.cs
      CardMotion.cs
      CardHandLayout.cs
      CardInputController.cs
    Slots/
      FateSlotView.cs
      FateSlotLayout.cs
    Boss/
      BossStageView.cs
      BossRuleCardView.cs
    Effects/
      CameraImpulse.cs
      TableParticles.cs
      ScreenFeedback.cs
    Audio/
      CombatAudio.cs
    Haptics/
      CombatHaptics.cs
~~~

Die Namen sind Vorschläge, keine Verpflichtung. Wichtiger ist die Trennung der Verantwortlichkeiten.

### 5.1 CombatTableController

Verantwortlich für:

- Lebenszyklus der Kampfpräsentation,
- aktuelle Views,
- Freigabe / Sperre von Input,
- Übergabe von Spieleraktionen an den bestehenden Controller,
- Starten der Cue-Sequenz.

Nicht verantwortlich für:

- Schadensberechnung,
- Bossregeln,
- Pattern-Erkennung,
- RNG.

### 5.2 CombatPresentationAdapter

Erzeugt aus dem Core einen Snapshot für die Darstellung.

Aufgabe:

- Core-Objekte nicht quer durch alle Views reichen,
- Presentation code gegen kleine Datenstrukturen stabilisieren,
- alte und neue UI während der Migration parallel ermöglichen.

Keine gecachten Regeln.

### 5.3 PresentationCueBuilder

Eingaben:

- Snapshot vor der Aktion,
- Preview unmittelbar vor der Auflösung,
- TurnResult,
- Snapshot nach der Aktion,
- vorhandene AnimationCues.

Ausgabe:

eine lineare oder gruppierte Cue-Sequenz.

Beispiel:

~~~text
LockInput
SettleCards
ScoreCard(Past)
ScoreCard(Present)
ScorePattern(Pair)
ScoreMultiplier
ResolveFate(86)
BreakStance
BossHit
BossPhaseChange
EnemyAttack
ResolveFuture
SlotCollapsed(Future)
DealHand
UnlockInput
~~~

### 5.4 CueRunner

Der CueRunner kennt Timing und Darstellung, aber keine Regeln.

Er kann:

- Cues seriell spielen,
- kleine Cues parallel gruppieren,
- Geschwindigkeit erhöhen,
- bei Reduced Motion vereinfachen,
- nach Unterbrechung in einen konsistenten Endzustand springen.

Wichtig für Mobile:

Wenn die App während einer Animation pausiert, muss beim Fortsetzen der Core-Zustand maßgeblich sein. Die Animation ist niemals die Wahrheit.

## 6. Turm-spezifische Cues

### 6.1 Bossregel erscheint

Core-Fakt:

Boss besitzt BossRule.Tower und ActiveRuleTexts liefert die Regel.

Presentation:

- Regelkarte gleitet aus Richtung Boss ein,
- landet quer oberhalb der drei Plätze,
- Wachssiegel schlägt auf,
- kurzer trockener Klang,
- Text maximal zwei Zeilen,
- bei Tap Detailtext.

### 6.2 Siegelbruch

Core-Fakt:

TurnResult meldet StanceBroken / PhaseChanged beziehungsweise der Enemy-State wechselt Phase.

Presentation:

1. Fate-Treffer endet.
2. Zeitlupe nur sehr kurz.
3. Wachssiegel bekommt Riss.
4. Wachs splittert.
5. Regelkarte wendet sich.
6. verschärfter Regeltext erscheint.
7. Boss spielt phase2.
8. Bühnenlicht wird härter.
9. Eingabe kehrt schnell zurück.

Kein eigenes Phasen-Timing im Core.

### 6.3 Platz stürzt ein

Core-Fakt:

Snapshot nach dem Zug besitzt einen anderen BlockedSlot beziehungsweise neu gesetzten BlockedSlot.

Presentation:

1. Bossaktion / Turm-Cue.
2. betroffener Platz wird kurz vorgewarnt.
3. Riss läuft durch das Platzmotiv.
4. Kartenstaub / Stein / Papierfasern.
5. Platz sackt optisch ab.
6. kurzer Kamerastoß.
7. SlotView wechselt in blocked state.
8. Drag-Ziel wird deaktiviert.

Wenn der Core in einer späteren Runde keinen BlockedSlot mehr liefert, richtet sich der Platz wieder sichtbar auf oder wird neu aufgedeckt.

## 7. Kartenbewegung

Die Godot-Implementierung ist Bewegungsreferenz.

Startwerte für Unity-Tuning:

| Zustand | Referenz |
|---|---|
| Ruhe | leichte periodische Bewegung |
| Hover | Lift, Skalierung ungefähr 1,14, Tilt |
| Auswahl | Lift unter Hover-Höhe, kleiner Stoß |
| Drag | starke Feder, gedämpfte Trägheit |
| Snap | weichere unterdämpfte Feder |
| Platz | leichte Skalierung unter Handgröße |
| Score-Puls | kurzer Scale-/Rotation-Impuls |
| Treffer | visuelle Verbindung Karte -> Ergebnis |

Keine 1:1-Pixelübernahme. Verhalten zählt, nicht die Einheit.

## 8. Layoutprofile

### 8.1 Mobile Portrait

Komposition von oben nach unten:

- Bossbühne / Bossname / kompakte Absicht,
- Bossregelkarte an der Tischkante,
- drei Schicksalsplätze,
- Live-Vorschau,
- Handfächer,
- Ausführen nahe Daumenbereich.

Sekundärwerte:

- kompakte Leiste oder seitliche Tabs,
- Charms nur als kleine physische Tokens / Icons,
- Details per Tap.

Safe Area:

- obere Notch,
- Home Indicator,
- keine Primäraktion direkt am Systemrand.

### 8.2 Desktop 16:9

Komposition:

- Boss und Regelkarte auf der gegenüberliegenden Tischhälfte,
- drei Plätze breit im Zentrum,
- Hand als breiter Fächer unten,
- Vorschau zwischen Legung und Hand,
- Charms / Deck / Ablage seitlich,
- HP und Absicht nah am Boss statt als globale Kopfzeile.

Die Weltkoordinaten beziehungsweise Anchors stammen aus einem CombatLayoutProfile.

Views bleiben identisch.

## 9. HUD und UI Toolkit

Für den Slice bleibt UI Toolkit dort, wo es stark ist:

- HP-Zahl,
- Haltung-Zahl,
- Absichtstext,
- kleine Ressourcen,
- Pause / Einstellungen,
- Detail-Popover,
- Omen-Beute zunächst als Overlay, solange die Auswahl visuell klar ist.

Aus Tartot.uxml herauszulösen:

- Hauptkartenhand,
- drei Hauptplätze,
- Gegner als zentrale Bühne.

CardElement bleibt für:

- Decklisten,
- Händler,
- Belohnungen,
- Debug / Fallback,
- eventuell Accessibility-Ansicht.

## 10. Omen-Beute im Slice

Der vorhandene Core-Pfad bleibt unverändert.

TRÄNKEN:

- die drei Schicksalsträger / Ziele werden als Karten sichtbar,
- Stufe und Verdunkelung animieren auf der Karte,
- keine Änderung der Belohnungsregel.

BINDEN:

- Omen-Karte wird sichtbar in Richtung Deck gezogen,
- Blut-/Umkehrzustand wird gezeigt.

BANNEN:

- Omen zerfällt oder wird verbrannt,
- Heilung / Gold / Licht werden kompakt dargestellt.

Das Overlay darf für den ersten Slice weiterhin UI Toolkit benutzen, muss aber bereits die neue Art Direction respektieren.

## 11. Audio und Haptik

Minimal benötigte Klangfamilien:

- Karte nehmen,
- Karte ablegen,
- ungültiger Platz,
- Score-Step,
- Muster,
- Fate-Aufbau,
- Boss-Treffer,
- Haltung bricht,
- Siegel reißt,
- Turm-Riss,
- Gegnerangriff,
- Spielertreffer,
- Sieg,
- Omen-Beute.

Haptik:

- leichte Auswahl,
- mittleres Einrasten,
- kräftiger Haltungsbruch,
- kurzer harter Turm-Einsturz,
- tödlicher Treffer.

Desktop ignoriert Haptik sauber.

## 12. Umsetzung in überprüfbaren Schritten

### Schritt 0 — Baseline sichern

Keine visuellen Änderungen.

Ausführen:

~~~sh
dotnet build
dotnet test src/Tartot.Tests
dotnet build tools/unity-syntax-check
~~~

Zusätzlich:

- aktuellen Turm-Seed für reproduzierbaren Slice festhalten,
- Screenshot / Video des Ist-Zustands erstellen,
- echte Unity-Version dokumentieren.

Abnahmekriterium:

Baseline ist reproduzierbar.

### Schritt 1 — Presentation Adapter + Snapshot

Nur Datenzugriff.

- CombatPresentationSnapshot.
- Adapter liest vorhandenen Core-Zustand.
- keine neue Regel.
- bestehende TartotView kann noch unverändert bleiben.

Tests:

- Snapshot bildet BlockedSlot, Phase, HP, Haltung und Slots korrekt ab.
- keine Mutation des Core-State.

Danach alle Baseline-Kommandos ausführen.

### Schritt 2 — CardView + Handlayout

Nur Hand und Kartenbewegung.

- Sprite-/2D-basierte CardView.
- Handfächer.
- Hover / Touch-Lift.
- Auswahl.
- Drag.
- Snap.
- Rücknahme.
- ungültiger Platz.

Noch keine neue Zuganimation.

Abnahme:

Eine Karte zehnmal hintereinander legen und zurücknehmen fühlt sich stabil an und erzeugt keinen Zustandsfehler.

Danach Build + Tests + Unity-Gerätetest.

### Schritt 3 — Drei Schicksalsplätze + Live-Vorschau

- Vergangenheit / Gegenwart / Zukunft als 2D-Views.
- Effekte der Positionen lesbar, aber nicht als Textwand.
- PreviewScore bleibt einzige Quelle.
- Lethal / BreaksStance sichtbar.

Abnahme:

Spieler kann ausschließlich anhand des Bildschirms erklären, warum dieselbe Karte in Zukunft anders ist als in Vergangenheit.

### Schritt 4 — Cue-System und Wertungskaskade

- PresentationCue,
- CueBuilder,
- CueRunner,
- ScoreBreakdown.Steps darstellen,
- normale Zugdauer messen.

Abnahme:

keine Regel wird im CueBuilder neu berechnet.

### Schritt 5 — Der Turm als vollständiger Boss

- Bossbühne,
- Regelkarte,
- Wachssiegel,
- Phase2,
- sichtbarer Slot-Einsturz,
- vorhandene Bossanimationen einbinden.

Abnahme:

BlockedSlot stammt ausschließlich aus dem Core.

### Schritt 6 — Kampfende + Omen-Beute

- Victory-Choreografie,
- TRÄNKEN / BINDEN / BANNEN,
- Übergang zurück zum bestehenden Run-Flow.

Abnahme:

Nach jeder Beuteoption stimmt der Core-State mit dem bisherigen Spiel überein.

### Schritt 7 — Responsive Pass

- Mobile Portrait,
- Desktop 16:9,
- Safe Area,
- unterschiedliche Layoutprofile,
- gleiche Views und gleiche Actions.

Abnahme:

kein separater Mobile- oder Desktop-Regelcode.

### Schritt 8 — Polish Gate

Erst jetzt:

- Partikel,
- Licht,
- Material,
- Audio-Mix,
- Haptik,
- Reduced Motion,
- beschleunigte Wiederholungsanimationen.

Kein neuer Content.

## 13. Teststrategie

### 13.1 Core Regression

Nach jeder Implementierungsstufe:

~~~sh
dotnet build
dotnet test src/Tartot.Tests
dotnet build tools/unity-syntax-check
~~~

Bei einer Regeländerung zusätzlich:

~~~sh
dotnet run --project src/Tartot.Sim -c Release -- --runs=400 --detail=1 --stats=1
~~~

Der Vertical Slice selbst sollte zunächst keine Balanceänderung benötigen.

### 13.2 Präsentationstests

PresentationCueBuilder sollte möglichst als reine C#-Logik testbar sein.

Zu testen:

- BlockedSlot neu -> genau ein SlotCollapsed Cue.
- gleiches BlockedSlot ohne Übergang -> kein doppelter Einsturz-Cue.
- PhaseChanged -> SealBreak / Phase cue genau einmal.
- Lethal -> Victory nach Schadensauflösung.
- CueBuilder mutiert keinen Core-State.
- Mobile- und Desktop-Profil ändern nur Layoutdaten.

### 13.3 Manuelle UX-Tests

Mobile:

- Karte mit einem Daumen auswählen und legen.
- keine Interaktion hinter Notch / Home Indicator.
- Text auf kleinem Gerät lesbar.
- Drag darf Scroll-/Systemgesten nicht unnötig blockieren.

Desktop:

- Maus-Hover klar.
- Drag bei schnellen Bewegungen stabil.
- 16:9 nutzt Fläche.
- kein Portrait-Fenster-Look.

### 13.4 Performance-Ziele

Für den Slice:

- stabile 60 fps als Ziel auf einem realistischen Mittelklasse-Mobilgerät,
- keine Allokationsspitzen pro Hover,
- keine neuen Texturen pro Kartenbewegung,
- Effekte gepoolt, wenn sie häufig auftreten,
- Partikelqualität skalierbar.

## 14. UX-Abnahme

Der Slice ist nicht fertig, wenn alle Checkboxen implementiert sind.

Er ist fertig, wenn ein Testspieler ohne Erklärung nach höchstens 60 Sekunden sagen kann:

- Diese drei Plätze bedeuten Vergangenheit, Gegenwart und Zukunft.
- Zukunft ist stärker, aber gefährlicher.
- Ich sehe, was mein Zug ungefähr macht.
- Der Turm kann mir einen Platz wegnehmen.
- Seine Regel ist jetzt schlimmer geworden.
- Ich kann meine Legung dagegen planen.

Zusätzlich muss ein erfahrener Spieler bereits Entscheidungen über Kette, Haltung, DIE WELT und Kartenhalten treffen.

## 15. Definition of Done

Der Vertical Slice gilt als Produktionsfreigabe, wenn:

- echter Core verwendet wird,
- alle bestehenden Core-Tests grün sind,
- Unity-Syntaxprüfung grün ist,
- Kampf gegen den Turm von Start bis Omen-Beute durchspielbar ist,
- Tap und Drag funktionieren,
- Mobile Portrait funktioniert,
- Desktop 16:9 funktioniert,
- Bossregel physisch dargestellt wird,
- Siegelbruch sichtbar transformiert,
- Slot-Einsturz klar inszeniert ist,
- normale Zugauflösung im Zieltempo bleibt,
- Spieler den Kampf ohne Debug-Log verstehen kann,
- keine neue Spielregel in der Unity-Präsentation liegt.

Erst danach werden weitere Bosse und Screens auf die neue Präsentationsarchitektur migriert.
