# XVIII · DER MOND — Asset- und Animationsspezifikation

Zweiter Boss nach dem Muster des Turms
(`assets/sprites/bosses/turm/ASSET_SPEC.md`). Akt III, Bühne „Spiegelsee“.
Die Regel des Kerns: jede 2. Runde verbirgt er seine Absicht und deckt eine
Handkarte zu. In Phase 2 tut er beides jede Runde, mit zwei Karten. Die Figur
zeigt das nur. Welche Karten verdeckt sind, entscheidet der Kern
(`CombatState.veiled_cards`).

## Figur

Eine grinsende Sichel im Stil früher Zeichentrickfilme:
- Sichel nach rechts offen, ein großes Auge auf der Außenseite. Die Pupille
  hat in Idle zwei Blickrichtungen.
- Nase ragt in die Höhlung. Das viel zu breite Grinsen läuft an der Innenkante entlang.
- Schiefe Schlafmütze (Indigo) mit Bommel.
- Gummiarme mit weißen Vierfinger-Handschuhen.
- Drei Sterne hängen an Fäden aus dem Bühnenhimmel.
- Phase 2: **Blutmond**. Der Körper wird rot, das Auge gold, und vom Grinsen tropft es.
  Kein Gore.

## Aseprite

Vorlage: `assets/source/aseprite/create_boss_mond.lua`. Canvas **128 × 160 px**,
**12 fps**, nur die 8 Farben der Stilbibel, 2 px Außenkontur.

| Tag | Frames | Zustand / Cue in Godot | Kernfakt |
|---|---|---|---|
| idle | 4 | idle (Schleife) | — |
| intro | 5 | intro | Kampfbeginn |
| attack | 6 | attack (auch attack2) | Angriff |
| attack1 | 6 | attack1 – Aussaugen | Absicht Drain |
| attack3 | 6 | attack3 – Fluch aus Sternen | Absicht Hex |
| summon | 5 | summon – Wolken | Absicht Guard |
| veil | 6 | veil – Nebel | Karten verdeckt / Absicht verborgen |
| hit | 3 | hit | Fate-Treffer |
| phase_2 | 7 | phase2 | Siegel gebrochen |
| death | 5 | death | Sieg |

Welche Animation zu welcher Absicht gehört, legt der Kern fest
(`core/combat/animation_cues.gd`, wie `AnimationCues.cs`).

Ebenen: `outline / body / face / cap / gloves / stars / fx`

## Export und Import

Wie beim Turm: Aseprite → `boss_mond.png` + `boss_mond.json` hierher, dann

```bash
godot --headless --path godot-next --script res://tools/aseprite_import_cli.gd -- \
  --json=res://assets/sprites/bosses/mond/boss_mond.json \
  --out=res://assets/sprites/bosses/mond/boss_mond_frames.tres
```

`ui/bosse/mond/mond_boss.gd` lädt `boss_mond_frames.tres` automatisch und
zeichnet sonst prozedural.

## Audio

Siehe `assets/audio/bosses/mond/REAPER_CUES.md`.
