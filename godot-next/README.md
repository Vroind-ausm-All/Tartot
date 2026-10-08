# TARTOT · godot-next

Das Godot-Hauptprojekt (Godot 4.7.x, GDScript, Hochformat 1080 × 1920).

`core/` ist ein Port des C#-Regelkerns `unity/Assets/Tartot/Core/` in derselben
Ordnerstruktur. Gleicher Seed und gleiche Entscheidungen ergeben in beiden
Kernen denselben Run, Zug für Zug; das prüft `tools/paritaet.sh` im
Wurzelverzeichnis. `ui/` ist die Oberfläche, Autoload `Spiel` (`ui/spiel.gd`).
Der Kampf läuft am Kartentisch `ui/tisch/kampftisch.gd`, gebaut aus dem
Addon `addons/tartot_karten/` (Karten, Bühne, Greifarm, Klang) und den
gemalten Bühnen unter `buehnen/`.

```bash
godot --headless --path godot-next --editor --quit                # Import und Parser
godot --headless --path godot-next --script res://tests/smoke.gd  # Rauchtest Kern
godot --headless --path godot-next res://tests/ui_walk.tscn       # alle Seiten zur Laufzeit
godot --headless --path godot-next res://tests/turm_slice.tscn    # Bosskampf am Tisch (auch mond_, tod_)
godot --path godot-next                                           # spielen
```

Stand, Mechanik, Testergebnisse, Lücken und nächste Schritte:
[`docs/GODOT_HANDOFF.md`](../docs/GODOT_HANDOFF.md).
