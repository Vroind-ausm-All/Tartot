# XVIII · DER MOND — Audio Cue Sheet (REAPER)

Projektziel: Wie beim Turm ein trockener, enger Klang aus dem Kino der 1930er.
Der Mond klingt aber weich und unheimlich: Theremin, Spieluhr,
Bandrauschen. Mono-kompatibel, kaum Hall.

## Cues

- `mond_intro.wav` — 0.9–1.1 s. Theremin gleitet von oben herab, ein Spieluhrton am Ende.
- `mond_attack.wav` — 0.15–0.25 s. gedämpfter Schlag, Filz statt Stein.
- `mond_hex.wav` — 0.5–0.6 s. vier verstimmte Spieluhrtöne (Fluch aus Sternen).
- `mond_drain.wav` — 0.4–0.5 s. Theremin fällt, Schlürfen, Bandrauschen.
- `mond_veil.wav` — 0.5–0.7 s. Nebel: gefiltertes Rauschen, das an- und abschwillt.
- `mond_hit.wav` — 0.12–0.18 s. hohler Treffer, leichter Glockenrest.
- `mond_break.wav` — 0.3–0.4 s. Spieluhr verliert die Feder (abwärts).
- `mond_phase2.wav` — 0.9–1.0 s. Theremin steigt in eine kleine None, tiefe Orgel darunter.
- `mond_death.wav` — 1.1–1.3 s. Theremin stürzt über zwei Oktaven, Filmflattern.

## REAPER Track-Aufbau

1. PROJECTOR — leises mechanisches Rattern (wie beim Turm)
2. THEREMIN — Sinus mit Portamento und 5–6 Hz Vibrato
3. MUSICBOX — kurze Glockentöne
4. NOISE — Bandrauschen / Crackle
5. PRINT — Master-Cue-Render

## Master-Chain

- HPF ca. 80 Hz
- LPF ca. 6–7 kHz
- leichte Sättigung
- 80–120 ms Slap, sehr leise
- Mono-Check
- Peak ca. -3 dBFS

Render: WAV, 44.1 kHz oder 48 kHz, 16/24 bit.

Godot nutzt prozedurale Platzhalter aus `ui/bosse/mond/mond_audio.gd`. Sobald eine Datei
`godot-next/assets/audio/bosses/mond/mond_<cue>.wav` (oder `.ogg`) existiert, wird sie ohne Codeänderung benutzt.
