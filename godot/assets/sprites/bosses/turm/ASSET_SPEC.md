# XVI · DER TURM — Asset- und Animationsspezifikation

## Ziel
Der Turm ist der Referenzboss für TARTOTs gesamte Art-/Animations-/Audio-Pipeline.

## Aseprite
Canvas: **128 × 160 px**, 12 fps.

Tags:
- idle: 4 Frames
- intro: 5 Frames
- attack: 6 Frames
- hit: 3 Frames
- break: 6 Frames
- phase_2: 7 Frames
- death: 4 Frames

Layer:
`outline / body / face / gloves / cracks / lightning / fx`

Pflicht:
- 2 px Außenkontur
- keine Zwischenfarben außerhalb der TARTOT-Palette
- Augen/Pupillen müssen in Idle 2 Blickrichtungen besitzen
- Hände als weiße Vierfinger-Handschuhe
- Phase 2 öffnet rote/goldene Risse
- Attacke braucht klare Anticipation → Impact → Overshoot
- Death endet als flacher Trümmerhaufen, nicht als Gore

## Godot
`TurmBoss.gd` ist aktuell eine prozedurale Ersatzdarstellung und definiert Timing/States.
Später ersetzt ein `AnimatedSprite2D`/SpriteFrames-Asset nur die Visuals; die State-Namen bleiben.

States:
`intro, idle, attack, hit, collapse, phase2, death`

## REAPER
Siehe `audio/turm/REAPER_CUES.md`.

## Export
Empfohlenes Sprite-Sheet:
- PNG, Point Filter
- 128×160 pro Frame
- horizontal oder Aseprite JSON-Atlas
- Tags mit exportieren

Zielpfad:
`godot/assets/sprites/bosses/turm/`
