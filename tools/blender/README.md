# Blender-Blockouts

Figuren und Charms von TARTOT als prozedurale Blender-Modelle, gerendert als
Pixel-Sprites im Stil „Schicksal auf Zelluloid“. Alles läuft headless per
Python. Man braucht nur Blender (getestet mit 4.0.2) und dessen Python mit
`numpy` und `Pillow`.

```bash
blender -b --factory-startup --python tools/blender/bauen.py              # alles
blender -b --factory-startup --python tools/blender/bauen.py -- figuren   # nur Figuren
blender -b --factory-startup --python tools/blender/bauen.py -- charms --nur thorn_ring,gold_die
```

Der komplette Lauf dauert auf einer CPU etwa 15 Sekunden. Mit `TARTOT_FONT=/pfad/zu/schrift.ttf`
beschriften die Kontaktbögen in dieser Schrift, sonst mit Pillows Ersatzschrift.

## Was herauskommt (`assets/blockout/`)

| Datei | Inhalt |
|---|---|
| `figuren/<id>.png` | 31 Gegner, Pixel 1:1. Normal 96 px, Elite 112 px, Boss 160 px, Finale 176 px |
| `charms/<id>.png` | 50 Charms, 32 px |
| `*/x4/<id>.png` | dieselben Sprites vierfach, ohne Glättung |
| `kontaktbogen_*.png` | Übersicht mit den Namen aus `Acts.cs` und `GameCatalog.cs` |
| `figuren.blend`, `charms.blend` | Bibliotheken: jede Figur und jeder Charm in einer eigenen Sammlung |

Die Ids sind dieselben wie im Spielkern (`ActCatalog`, `GameCatalog.Charms`).

## Wie der Pixellook entsteht

1. **Toon-Material** (`kit.py`, `Kit.mat`): reiner Emissionsshader. Eine Normale-mal-Licht-Rampe
   wählt zwischen genau zwei Palettentönen, das Licht kommt von links oben vorn. So bleiben es
   höchstens zwei Tonstufen je Fläche, ohne Verlauf und ohne Rauschen.
2. **Render**: Cycles auf der CPU, 1 Sample, Kastenfilter 0,01, orthografische Kamera, 4° von oben.
   Jedes Pixel trifft genau eine Fläche, es entstehen harte Pixelkanten.
3. **Nachbearbeitung** (`postprocess`): Farben rasten auf die Palette ein, danach kommen die Konturen.
   - **Außen:** 2 px Tinte um die Silhouette (Charms: 1 px, sonst frisst die Kontur das Motiv).
   - **Innen:** 1 px, wo Objekt- oder Material-Index wechselt. Die Linie liegt immer auf dem
     *hinteren* Pixel (Tiefenpass), deshalb bleiben Augen, Zähne und Handschuhfinger frei.

## Der Baukasten (`kit.py`)

| Teil | Funktion |
|---|---|
| Grundformen | `ball` (auch als Birne mit `taper`), `cyl`, `box`, `torus`, `poly`, `cut` (Boolesch, z. B. Mondsichel) |
| Gummischlauch | `hose`: Bézierkurve mit runder Dicke, ohne Gelenk; die Enden haben dieselbe Kennung, also keine Linie |
| Gesicht | `face_surface` merkt sich ein Ellipsoid, `decal` projiziert flache Formen darauf. Dazu `eye` (Kuchenauge mit Tortenstück-Kerbe, Lid, Wutbraue), `grin` (zu breit, zu viele Zähne, Zunge), `brow`, `nose` |
| Hände, Füße | `glove` (weißer Vier-Finger-Handschuh: offen, winkend, zeigend, Faust), `shoe` |
| Hüte | `tophat`, `bowler`, `crown` (auch gebrochen) |
| Sonstiges | `bolt` (Blitz), `turn` (ganze Figur drehen, z. B. verkehrt hängen) |

`figuren.py` und `charms.py` enthalten je eine kurze Bauanleitung pro Eintrag, mit dem Flavor-Text
aus dem Spiel als Kommentar.

## Palette

Die Grundfarben der Stilbibel (Ruß, Filmvergilbt, Sepia 1–3, Gold, Blut, Indigo) plus Hilfstöne für
Schatten und Akzente: dunkles Gold, helles Gold, Glut, dunkles und helles Indigo, Mundrot, Moos für
Kranz und Klee. Zahlenkarten-Gegner bleiben sepia, Eliten tragen einen Akzent, volle Farbe haben nur
die Bosse. Die Tabelle steht in `kit.py` (`PAL`, `TONES`).

## Was das ist - und was nicht

Das sind **Blockouts**: Silhouette, Proportion, Farbverteilung und Lesbarkeit auf Spielgröße.
Sie beantworten die drei Prüffragen der Stilbibel (32-px-Silhouette? Grinst es? Wirkt es
gefährlich, obwohl es niedlich ist?) früh und billig. Sie ersetzen keine gezeichneten Sprites:

- keine Animation (die Stilbibel will 12 fps „on twos“ mit Squash & Stretch),
- Gesichter sind auf 96 px teils nur angedeutet (Nadelwitwe, Augensammlerin),
- Phasen der Bosse (Risse, Verwandlung) fehlen noch.

Ein Artist kann die Sprites direkt übermalen oder die `.blend`-Dateien öffnen, Posen ändern und
neu rendern. In Unity gehören die PNGs auf *Filter Mode: Point* und *Compression: None*.
