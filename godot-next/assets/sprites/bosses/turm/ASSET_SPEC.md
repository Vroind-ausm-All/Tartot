# XVI · DER TURM — Asset- und Animationsspezifikation

Der Turm ist der Referenzboss für die gesamte Art-, Animations- und
Audio-Pipeline. Jeder weitere Boss folgt diesem Muster.

## Aseprite

Vorlage anlegen: `assets/source/aseprite/create_boss_turm.lua` in Aseprite
ausführen (File → Scripts). Canvas **128 × 160 px**, **12 fps**, Palette
der Stilbibel (8 Farben).

| Tag | Frames | Zustand in Godot |
|---|---|---|
| idle | 4 | idle (Schleife) |
| intro | 5 | intro |
| attack | 6 | attack |
| hit | 3 | hit |
| break | 6 | collapse |
| phase_2 | 7 | phase2 |
| death | 4 | death |

Layer: `outline / body / face / gloves / cracks / lightning / fx`

Pflicht:
- 2 px Außenkontur
- keine Zwischenfarben außerhalb der TARTOT-Palette
- Augen/Pupillen in Idle mit 2 Blickrichtungen
- Hände als weiße Vierfinger-Handschuhe
- Phase 2 öffnet rote/goldene Risse
- Attacke: Anticipation → Impact → Overshoot
- Death endet als flacher Trümmerhaufen, nicht als Gore

## Export und Import

1. Aseprite: File → Export Sprite Sheet, PNG, „JSON Data“ und „Tags“ an.
   Ziel: `godot-next/assets/sprites/bosses/turm/boss_turm.png` und `boss_turm.json`.
2. Import zu SpriteFrames:

   ```bash
   godot --headless --path godot-next --script res://tools/aseprite_import_cli.gd -- \
     --json=res://assets/sprites/bosses/turm/boss_turm.json \
     --out=res://assets/sprites/bosses/turm/boss_turm_frames.tres
   ```

3. Fertig. `ui/bosse/turm/turm_boss.gd` lädt `boss_turm_frames.tres`, sobald
   die Datei existiert, und zeichnet sonst prozedural. Bewegung, Blitz und
   Wackeln kommen in beiden Fällen aus `ui/bosse/boss_darstellung.gd`.

Tag-Namen aus Aseprite werden abgebildet (`phase_2` → `phase2`, `break` →
`collapse`, siehe `tools/aseprite_import.gd`). `tests/asset_pipeline.gd`
prüft die Kette mit einem künstlichen Blatt.

## Audio

Siehe `assets/audio/bosses/turm/REAPER_CUES.md`.
