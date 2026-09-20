# Architektur

## Die eine Regel

**Spielregeln liegen nie in der Oberfläche.** `Tartot.Core` hat keine
Unity-Abhängigkeit — die `asmdef` setzt `noEngineReferences`, damit das nicht
versehentlich aufweicht. Ein kompletter Run läuft ohne Fenster, ohne Renderer,
ohne Hauptschleife.

Das ist kein Selbstzweck: nur deshalb kann `Tartot.Sim` 200 Runs in einer
halben Minute spielen und Balancing wird **gemessen statt geraten**.

---

## Eine Kopie des Kerns, zwei Toolchains

Unity kompiliert nur, was unter `Assets` liegt. Ein separates `src/Tartot.Core`
mit eigenen Quellen hätte zwei Kopien bedeutet — und zwei Kopien laufen
auseinander.

Deshalb:

```
unity/Assets/Tartot/Core/**/*.cs     ← die Quellen, Unity kompiliert sie direkt
src/Tartot.Core/Tartot.Core.csproj   ← verlinkt genau dieselben Dateien
```

Die Alternativen wären gewesen: den Kern als DLL nach `Assets/Plugins` bauen
(zusätzlicher Build-Schritt bei jeder Regeländerung) oder als lokales
Unity-Paket einbinden (dann liegen `bin/` und `obj/` im Paket und Unity
importiert die DLL doppelt). Die Verlinkung ist der Weg mit den wenigsten
beweglichen Teilen.

---

## Determinismus von Anfang an

`System.Random` ist **nicht** reproduzierbar: der Algorithmus ist nicht
spezifiziert und hat sich mit .NET 6 geändert. Derselbe Seed liefert in Unity
(Mono/IL2CPP) und in den Tests (.NET 8) verschiedene Folgen.

Stattdessen PCG32 — klein, gut verteilt, arbeitet nur auf `ulong`-Arithmetik
mit definiertem Überlauf, also überall identisch. Eine goldene Folge ist als
Test festgeschrieben: ändert sie sich, ist das eine bewusste Entscheidung.

**Benannte Teilströme** sind kein Luxus:

```csharp
var root = new DeterministicRandom(seed);
_rng        = root.Stream("world");
CombatSystem = new CombatSystem(root.Stream("combat"));
Progression  = new ProgressionSystem(root.Stream("progression"));
```

Liegen Kampf, Belohnung und Laden auf einem Strom, verschiebt ein Reroll im
Laden die Kartenzüge im nächsten Kampf — und der Seed ist wertlos. Genau das
prüft `GameFlowTests.ShopReroll_DoesNotShiftCombatDraws`.

Das lässt sich später nicht nachrüsten, ohne jeden geteilten Seed zu
entwerten. Deshalb steht es am Anfang.

---

## Speicherstände ohne Fremdpakete

Unitys `JsonUtility` kann weder Dictionaries noch Polymorphie; ein NuGet-Paket
wäre in Unity ein eigenes Integrationsproblem. Also ein eigener, kleiner
JSON-Baustein im Kern (`Infrastructure/Json.cs`).

Zwei Eigenschaften, die dabei zählen:

- **Invariante Zahlenformate.** Auf einem deutschen Gerät darf kein Komma im
  JSON landen. Als Test festgehalten.
- **Karten liegen einmal als Pool** und werden sonst nur über ihre `InstanceId`
  referenziert. Eine Karte, die zugleich im Deck und auf der Hand liegt, muss
  nach dem Laden **dasselbe Objekt** sein — sonst laufen Level, Rage und
  Schimmer auseinander. Auch das ist ein Test.

Die RNG-Ströme werden mitgespeichert: **Laden ändert den weiteren Verlauf
nicht.** Fehlende Felder fallen auf Vorgaben zurück, unbekannte Karten aus
älteren Versionen werden übersprungen statt den Stand unbrauchbar zu machen.

Gespeichert wird auch ein **laufender Kampf**. Auf dem Handy wird die App
jederzeit weggeräumt, auch mitten im Zug.

---

## Der Autopilot liegt im Kern

`Core/Simulation/Autopilot.cs` spielt das Spiel ohne Spieler. Er liegt im Kern,
weil Tests und Balancing-Simulation ihn beide brauchen — und weil dieselbe
Bewertung später einen Zughinweis im Tutorial speisen kann.

Er soll **nicht optimal** spielen, sondern vernünftig: etwa auf dem Niveau
eines aufmerksamen Spielers im dritten Run. Gewinnt er fast immer, ist das
Spiel zu leicht; kommt er nie durch, zu schwer.

Eine Warnung aus der Praxis: ein fehlerhafter Autopilot ist ein fehlerhaftes
Messinstrument. Die erste Balancing-Messung war ungültig, weil er im Laden
Karten kaufte und damit gegen sein eigenes Ausdünnen arbeitete. Details in
[`BALANCING.md`](BALANCING.md).

---

## Syntaxprüfung für den Unity-Code

Unity lässt sich in einer Kommandozeilenumgebung nicht bauen. `tools/unity-syntax-check`
kompiliert den Unity-Code gegen minimale Stubs der verwendeten Unity-Typen.

Das **beweist nicht**, dass der Code in Unity läuft — weicht eine echte
Signatur von der Nachbildung ab, fällt es erst dort auf. Es fängt aber
Tippfehler und falsche Zugriffe auf `Tartot.Core` ab. Beim ersten Lauf hat es
sofort einen echten Compilerfehler gefunden.

---

## Nächste Schritte

1. Charms in Trigger-Gruppen strukturieren (`OnDraw`, `OnScore`, `OnCardPlayed`,
   `OnKill`, `OnReward`) statt eines gewachsenen `switch`.
2. Items mit eigenen Zielmodi versehen (`Combat`, `Deck`, `Reward`, `Shop`).
3. Große Arkana als eigene Animations-/Unterbrechungsschicht.
4. Die freigeschalteten Lesarten aus `MetaProgress` in die Kartenwirkung
   einspeisen — gesammelt werden sie bereits.
5. Akt-Struktur: die acht gebauten Gegner sind derzeit eher ein Tutorial als
   ein Spannungsbogen (siehe `BALANCING.md`).
