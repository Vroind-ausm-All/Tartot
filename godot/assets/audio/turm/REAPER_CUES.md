# XVI · DER TURM — Audio Cue Sheet (REAPER)

Projektziel: trockener, enger 1930er-Kino-/Jahrmarkt-Sound. Mono-kompatibel, kaum Hall.

## Cues

- `turm_intro.wav` — 0.7–0.9 s. Tiefer Orgel-Dreiklang + Projektorklick.
- `turm_attack.wav` — 0.15–0.25 s. Holz-/Stein-WHOMP, kein moderner Subbass.
- `turm_lightning.wav` — 0.35–0.5 s. kurzer elektrischer Snap + dumpfes Grollen.
- `turm_hit.wav` — 0.12–0.2 s. trockener Stein-/Holztreffer.
- `turm_break.wav` — 0.3–0.45 s. Riss + perkussiver Knack, für Haltung/Phase.
- `turm_phase2.wav` — 0.8–1.0 s. schiefer Orgelakkord, leichte Bandverstimmung.
- `turm_death.wav` — 0.9–1.2 s. kollabierender Stein + Filmflattern.

## REAPER Track-Aufbau

1. PROJECTOR — leises mechanisches Rattern
2. ORGAN — ReaSynth / Orgel-Plugin oder gesampelte Pfeife
3. STONE — kurze Stein-/Holzimpulse
4. NOISE — Bandrauschen / Crackle
5. THUNDER — tiefer gefilterter Noise-Burst
6. PRINT — Master-Cue-Render

## Master-Chain

- HPF ca. 60 Hz
- LPF ca. 7–8 kHz
- leichte Sättigung
- sehr kurze Room-IR oder 80–140 ms Slap
- Mono-Check
- Peak ca. -3 dBFS

Render: WAV, 44.1 kHz oder 48 kHz, 16/24 bit. Godot kann OGG/WAV importieren.

Godot nutzt aktuell prozedurale Platzhalter via `TurmAudio.gd`. Sobald die WAVs existieren,
werden sie nur in `TurmAudio.cue()` durch `preload("res://assets/audio/bosses/turm/...")` ersetzt.
