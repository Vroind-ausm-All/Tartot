# Tartot Kartentisch (Godot 4.4)

Die Karten von TARTOT als Godot-Addon: deine Kartenvorlage, Bewegung wie bei
Balatro, Seltenheit, vier Editionen als Shader und die Zähl-Kaskade.
**Godot 4.4 .NET · GDScript + C#-Regelkern · GL Compatibility · Hochformat 1080 × 1920** — also
dieselben Einstellungen wie der Godot-Port auf `chatgpt/godot-celluloid-port`.

![Kartentisch](bilder/kartentisch.png)

*Drüberfahren mit Info · Ziehen mit Schwung · Kaskade bis ×1,8 · tödlich,
die Glaskarte zerspringt.*

<img src="bilder/galerie.png" width="360" alt="Editionen und Seltenheit">

## Regelkern in Godot

Der Kartentisch rechnet nichts selbst. `kern/TartotKern.cs` (Autoload
`Kern`) verbindet GDScript mit dem C#-Regelkern. `TartotKartentisch.csproj`
verlinkt die Quellen aus `unity/Assets/Tartot/Core`: Unity, Godot, Tests und
Simulation nutzen also eine einzige Kopie der Regeln.

| Aufruf | Liefert |
|---|---|
| `NeuerRun(saat)` | startet einen Run, der erste Kampf steht bereit |
| `Kampf()` | Gegner (Leben, Haltung, Absicht, Sprite), Spieler, Hand, Plätze, gesperrter Platz |
| `Legen(instanz, platz)`, `Zuruecknehmen(platz)`, `Abraeumen()` | legt Karten in den Kern |
| `Vorschau()` | Chips, Mult, Wert, Muster, Beinahe-Hinweise, tödlich? |
| `Ausfuehren()` | Wertungsschritte für die Kaskade, angekommener Schaden, Gegner-Animationen, Sieg/Niederlage, zersprungene Karten |
| `Vorschlag()` | die beste Legung laut Autopilot |
| `Weiter()` | nach dem Sieg bis zum nächsten Kampf (Belohnung, Weg, Laden entscheidet vorerst der Autopilot) |

Nötig ist **Godot 4.4 mit .NET** und das .NET-8-SDK. Ohne .NET zeigt der
Tisch einen Hinweis; die Galerie läuft auch ohne.

## Klang

`addons/tartot_karten/klang.gd` (`KartenKlang`) spielt 16 prozedural
erzeugte Klänge (`tools/klang/klaenge.py`): Papier beim Nehmen, Ablegen,
Austeilen und Umdrehen, ein Holz-Tick beim Drüberfahren, eine Spieluhr für
Chips und Mult. Dazu kommen ein Schlag mit Blech für jeden ×-Faktor, ein
Dur-Arpeggio bei tödlichen Treffern, Glas, Feuer und ein leises
Projektorrattern.

Die Kaskade steigt **je Schritt einen Halbton**, wie bei Balatro, gedeckelt
bei einer Oktave. Eigene Aufnahmen mit gleichem Dateinamen ersetzen die
erzeugten Klänge. Ohne `KartenKlang`-Knoten bleibt es still.

## Starten

```sh
godot --path godot-karten                 # Kartentisch zum Selberspielen
godot --path godot-karten res://demo/galerie.tscn   # alle Editionen und Seltenheiten
```

Karten antippen (wählen) oder auf **Vergangenheit**, **Gegenwart**,
**Zukunft** ziehen, dann **Schicksal ausführen**. Maus und Touch gehen beide.

Aufnehmen ohne Bildschirm (so sind die Bilder oben entstanden):

```sh
xvfb-run -a -s "-screen 0 1080x1920x24" \
  godot --path godot-karten --write-movie film/f.png --fixed-fps 30 -- --autoplay
ffmpeg -framerate 30 -i film/f%08d.png -c:v libx264 -pix_fmt yuv420p kartentisch.mp4
```

Mit `--autoplay` führt ein Handschuh die Szene selbst vor und beendet sie.

## Was drin ist

```
addons/tartot_karten/
  karte.gd          TarotKarte   Karte aus der Vorlage, Federbewegung, Neigung, Umdrehen, Auflösen
  tisch.gd          KartenTisch  Hand als Fächer, Schweben, Wählen, Ziehen, Plätze, Einsortieren
  platz.gd          KartenPlatz  Legeplatz im Filmrahmen (auch „eingestürzt“ für den Turm)
  info.gd           KartenInfo   Info-Fenster mit Seltenheits- und Editions-Pille
  kaskade.gd        WertungsKaskade  Chips × Mult, Karte für Karte, Faktoren zuletzt
  karten_daten.gd   KartenDaten  liest daten/karten.json (aus dem Spielkern exportiert)
  klang.gd          KartenKlang  Klänge, Tonleiter der Kaskade
  handschuh.gd      Zeigehand für Vorführungen
  shader/           Neigung (2D-Perspektive), Editionen, Glas, Auflösen, Schatten
  kunst/            Rahmen, Rückseite, Farbsymbole, Motive, Vorlage
  schrift/          Abril Fatface, Alfa Slab One, Jersey 10 (OFL)
  VORLAGE.md        Karten selbst malen: Maße, Dateinamen, Stellschrauben
demo/               Kartentisch und Galerie
```

### Bewegung wie bei Balatro

- Jede Karte hängt an einer **leicht unterdämpften Feder**: sie schießt über
  ihr Ziel hinaus und schwingt ein.
- Beim Ziehen **legt sie sich in die Bewegung** und kippt nach
  der Geschwindigkeit.
- Unter dem Zeiger **hebt sie sich** und kippt ihm entgegen (Fake-3D im
  Shader). Die Nachbarn weichen aus.
- Im Stillstand **wiegt** sie sich leise.
- **Stoß** beim Zählen, Einrasten und Wählen: ein kurzer Ausschlag, der
  nachfedert.
- Der **Schatten** fällt weiter, je höher die Karte schwebt.
- Die Hand ist ein **Fächer**, der enger wird, je mehr Karten sie hat.
  Beim Zurückziehen öffnet sich eine Lücke, wo die Karte landen wird.
- **Austeilen** wie ein Croupier: erst fliegen, dann aufdecken.

### Seltenheit und Editionen

Wie die Karten aussehen und was die Editionen im Spiel tun, steht in
[`addons/tartot_karten/VORLAGE.md`](addons/tartot_karten/VORLAGE.md). Kurz:

- Die Seltenheit steht als Raute auf der Karte und als Pille im Info-Fenster.
  Legendäre Karten tragen zusätzlich einen goldenen Glanz.
- Die Editionen sind schimmernd, leuchtend, brennend und gläsern. Gläsern ist
  echte Glasmorphism: der Tisch dahinter wird weichgezeichnet.

### Kaskade

`WertungsKaskade.abspielen(schritte, karten, gegner_lp)` spielt die
Wertungsschritte ab, die der Kern schon liefert
(`ScoreBreakdown.Steps` in C#).

1. Jede Karte springt an und wirft ihre Chips und ihren Mult
   in die Kästen. Das Tempo zieht dabei an.
2. Dann folgen die Muster.
3. Zuletzt kommen die ×-Faktoren mit Bildschirmwackeln.
4. Die Summe zählt hoch. Ist sie tödlich, wird sie golden und sprüht Funken.

## In den Godot-Port übernehmen

Das Addon kennt keine Spielregeln, nur Karten-IDs, Editionen und
Wertungsschritte. Übernehmen:

1. `addons/tartot_karten/` nach `godot/addons/tartot_karten/` kopieren.
2. Für Karten `TarotKarte.erzeugen(id, edition)` benutzen und für die Hand
   einen `KartenTisch` mit drei `KartenPlatz`-Knoten.
3. Den Autoload `Kern` (`kern/TartotKern.cs`) und die Kern-Verlinkung aus
   `TartotKartentisch.csproj` übernehmen. `demo/demo.gd` zeigt, wie Tisch,
   Kaskade und Kern zusammenspielen.

## Daten

`addons/tartot_karten/daten/karten.json` ist ein Export aus dem Spielkern.
Er enthält alle 78 Karten, die Seltenheiten und die Editionen. Nach
Regeländerungen neu erzeugen:

```sh
dotnet run --project src/Tartot.Sim -- --export-cards=godot-karten/addons/tartot_karten/daten/karten.json
```

## Grenzen

- Nur 20 der 78 Karten haben ein Beispielmotiv. Es ist aus deinen
  Entwürfen ausgeschnitten. Die übrigen zeigen das Farbsymbol als
  Platzhalter, bis du sie malst.
- Für Belohnung, Wegwahl, Laden und Ereignisse gibt es am Tisch noch
  keine Oberfläche. Nach einem Sieg entscheidet dort der Autopilot.
- Die Demo gibt der ersten Hand je eine Edition (Vorführdeck).
- Geprüft ist das Addon unter Linux mit Software-Rendering
  (llvmpipe, GL Compatibility). Auf Geräten fehlt die Prüfung noch.
