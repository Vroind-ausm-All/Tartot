# TARTOT · Godot Next (aktueller Regelport)

Dieser Ordner enthält den laufenden Port des aktuellen C#-Regelkerns auf Godot/GDScript.

**Status:** umfangreich umgesetzt, aber in der ChatGPT-Umgebung nicht mit einem echten Godot-4.7.2-Parser ausgeführt. Deshalb ist `godot/` im selben Branch derzeit die direkt startbare, bekannte Basis; `godot-next/` ist der aktuelle Paritätsport, der beim ersten lokalen Godot-Lauf syntaktisch bereinigt und anschließend zur Hauptversion werden soll.

Umgesetzt sind bereits:
- 78 Karten, 50 Charms, 22 Items, 4 Deuter
- Schleier 0–8
- drei Akte, sechs Bossregeln, Welt und Spirale
- 90/100/150-%-Positionen, Haltung, Siegel, Musterkette, Wiederholungsmalus
- Bossbeute, Ereignisstruktur, Prophezeiungen, Lesarten, Meta-Speicher
- neue Godot-Control-UI, Kartenansicht und Zelluloid-Pixel-Art
- synthetischer Projektor-/Jahrmarkt-Sound
- Android-Exportpreset und headless Smoke-Test

Erster lokaler Check:

```bash
godot --headless --path godot-next --editor --quit
godot --headless --path godot-next --script tests/smoke.gd
```

Nach erfolgreichem Parser-/Smoke-Durchlauf kann dieser Ordner `godot/` ersetzen.
