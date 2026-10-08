# TARTOT · Godot-Übergabe

Stand: 2026-10-08 · Branch `claude/compassionate-archimedes-ebvgo2`

Dieses Dokument ist der Einstieg für jede weitere Arbeit am Godot-Port. Es
hält fest, was **im Code bestätigt** ist, was **nachweislich läuft** und was
noch fehlt. Zahlen zur Spielmechanik stehen hier nur als Wegweiser; maßgeblich
ist immer der Code.

---

## 1. Engine und Version

| | |
|---|---|
| Zielengine | **Godot 4.7.x**, GDScript (getestet mit 4.7.2.stable) |
| Renderer | GL Compatibility (Mobil und Desktop) |
| Bildformat | Hochformat, Viewport 270 × 480, ganzzahlig skaliert |
| Hauptprojekt | `godot-next/` |
| Regel- und Testreferenz | C#-Kern `unity/Assets/Tartot/Core/` (Unity 6000.6.2f1, netstandard2.1) |

Unity bleibt als Referenz bestehen. Den C#-Kern **nicht löschen**: er ist das
Orakel, gegen das jeder Godot-Lauf geprüft wird (Abschnitt 5).

## 2. Quelle der Wahrheit

1. C#-Kern `unity/Assets/Tartot/Core/` und seine Tests `src/Tartot.Tests/` (281 Tests)
2. `godot-next/` (Port, Spur für Spur gleich dem C#-Kern)
3. Übergabe-Prompts und Konzeptnotizen
4. `godot/` (HISTORISCH: alter Prototyp mit anderen Regeln)
5. `reference/godot/docs/` (HISTORISCH)

Bei Widerspruch gewinnt die höhere Stufe. Zahlen aus Konzeptblättern,
importierten Chats oder Prompts sind **nicht kanonisch**, bis sie im Code stehen.

## 3. Wo was liegt

```
godot-next/                 Hauptprojekt Godot 4.7
  core/                     Regelkern, kennt keine Oberfläche (Port von unity/.../Core)
    infrastructure/         DeterministicRandom (PCG32), Num (float32, Banker's Rounding),
                            SaveSystem/SaveData (gleiches JSON wie C#)
    model/                  Enums, Definitionen, Zustände
    content/                GameCatalog, ActCatalog, DeuterCatalog, EventCatalog
    combat/                 CombatSystem inkl. BossRules
    progression/            ProgressionSystem, Prophezeiungen, MetaProgress, Run-Bericht
    simulation/             Autopilot
    game_controller.gd      Ablauf eines Runs
  ui/                       Oberfläche (Autoload Spiel = ui/spiel.gd)
  tests/smoke.gd            Rauchtest Kern
  tests/ui_walk.tscn        Laufzeittest aller Seiten mit echtem Spielzustand
  tools/trace.gd            Paritätsspur
godot/                      HISTORISCH: Prototyp Godot 4.4 (70/100/200, Schicksalsfäden).
                            Enthält die Turm-Darstellung (turm_boss.gd, turm_audio.gd) und
                            die Turm-Asset-Spezifikation, die noch zu portieren sind.
reference/godot/            HISTORISCH: Kopie von godot/ ohne Turm-Dateien
unity/Assets/Tartot/Core/   C#-Regelkern (Referenz)
src/Tartot.Sim              Simulation; --trace=SEED schreibt die Paritätsspur
tools/paritaet.sh           Paritätsbeweis C# gegen Godot
```

## 4. Mechanik (im Code bestätigt)

Fundstellen beziehen sich auf den C#-Kern; der Port trägt dieselben Namen in
snake_case (`CombatSystem.cs` ↔ `core/combat/combat_system.gd`).

- **Legung**: bis zu 3 Karten je Zug auf Vergangenheit / Gegenwart / Zukunft,
  Faktoren **90 % / 100 % / 150 %**; die Zukunft wirkt nach der Gegneraktion
  (`CombatSystem.ApplyCard`, `ResolveTurn`). Kein Mana.
- **Fate-Schaden** = Chips × Multiplikator × Wiederholung (× Pakt), mindestens 1.
  Summe 21 ruft DIE WELT.
- **Haltung**: steht sie, ist ein Fate-Treffer auf **35 % der Max-HP**
  gedeckelt; bricht sie oder ist sie gebrochen, wirkt er **× 1,5**. Sie kehrt
  auf **60 %** der Max-Haltung zurück. Haltungsschaden = Chips/9 + 2 je Schwert.
- **Siegel** (Bosse): beim Fall auf 0 HP bricht ein Siegel, der Boss steht mit
  Phasen-HP wieder auf und verschärft seine Regel.
- **Musterkette**: +10 % je Glied, höchstens 5 Glieder.
- **Wiederholung** derselben Legung: 100 % → 90 % → 75 % → 50 %.
- **Inhalte**: 78 Karten, 50 Charms, 22 Items, 4 Deuter (Wahrsagerin,
  Aderleser, Buchhalter, Eremit), Schleier 0–8, 18 Ereignisse,
  19 Prophezeiungen.
- **Runstruktur**: 3 Akte à 5 Kämpfe (4 + Boss), dann das Finale, danach die
  Schwarze Spirale (jeder 4. Kampf der Weltenwurm). Bosse und Finale stehen
  ab Runbeginn fest und sind angekündigt.
- **Bosse** (8) und ihre Regeln:
  - Akt I: XVI Der Turm (Plätze stürzen ein), V Der Hierophant (Akolythen segnen)
  - Akt II: XIII Der Tod (zeichnet eine Karte), X Rad des Schicksals (Plätze drehen)
  - Akt III: XV Der Teufel (Pakt), XII Der Gehängte (Zeit verkehrt),
    XVIII Der Mond (verdeckte Karten, verborgene Absicht), XIV Die Mäßigkeit (Ausgleich)
- **Finale**: XXI Die Welt (trägt die Regeln der geschlagenen Bosse,
  abgeschwächt) **oder** XIX Die rote Sonne (Supernova) – ab Runbeginn bekannt.
- **Verdunkelung** 0–100 (fünf Stufen): Bossbeute, Pakte, Ereignisse und
  Veredeln dunkeln; ab 25 je +1 Gegnerangriff; Ereignisse zeigen ab 40 andere Texte.
- **Omen-Beute** nach jedem Boss: TRÄNKEN, BINDEN, BANNEN.
- **Zufall**: PCG32 mit getrennten Strömen `world`, `combat`, `progression`
  (FNV-1a über den Stromnamen). Tageskarte: Seed = JJJJMMTT, Deuter = Seed mod 4,
  Schleier 2.

## 5. Tests und Paritätsnachweis

Alle Befehle aus dem Wurzelverzeichnis; `godot` = Godot 4.7.x.

```bash
dotnet test src/Tartot.Tests                                      # 281 C#-Tests
godot --headless --path godot-next --editor --quit                # Import/Parser
godot --headless --path godot-next --script res://tests/smoke.gd  # Rauchtest, Exit 1 bei Fehler
godot --headless --path godot-next res://tests/ui_walk.tscn       # alle Seiten zur Laufzeit
tools/paritaet.sh                                                 # C# gegen Godot, Zeile für Zeile
```

Stand 2026-10-08 (Godot 4.7.2, .NET 8):

| Prüfung | Ergebnis |
|---|---|
| C#-Tests | 281 / 281 grün |
| Rauchtest godot-next | grün (0 Fehler) |
| UI-Durchlauf | alle 11 Phasen gebaut, keine Laufzeitfehler |
| Parität | **99 / 99 Fälle identisch**: 40 Seeds, 4 Deuter × 5, Schleier 1–8 × 3, Spirale × 6, Tageskarte × 2, Laufbahn 2 × 25 Runs mit Meta-Fortschritt, Speichern/Laden nach jedem Zug × 5 |

Die Spur enthält je Kampfzug Legung, Wertung (floats als Bitmuster), Gegner,
Hand, die Zahl der Zufallszüge je Strom und den Protokolltext, je Schritt den
ganzen Run (Deck, Charms, Items, Belohnungen, Händler, Nachricht) und am Ende
den Speicherstand. Abgedeckt sind alle 10 Bosse samt Finale und alle 18 Ereignisse.

Warum der Port so genau ist: Der C#-Kern rechnet mit `float` (32 Bit) und
`Math.Round` (Banker's Rounding). GDScript rechnet mit 64 Bit und rundet x,5
weg von der Null. Jede float-Rechnung des Ports läuft deshalb durch `Num.f`
(Rundung auf float32), gerundet wird mit `Num.rnd`, sortiert stabil mit
`Num.sortiert`. Wer am Kern etwas ändert, ändert es **in beiden** und lässt
`tools/paritaet.sh` laufen.

## 6. Android

- `godot-next/export_presets.cfg`: Preset „Android Prototype“, arm64-v8a, Ziel
  `Build/Android/TARTOT-godot-prototype.apk`.
- **Noch kein APK gebaut.** Dazu fehlen im Container Android-SDK,
  Export-Templates 4.7.2 und ein Debug-Keystore. Das ist der nächste Schritt.

## 7. Assets

- Die Oberfläche in `godot-next/ui` zeichnet alles prozedural (Palette siehe
  `ui/thema.gd`: #1A1412 #EFE3C8 #C9B48E #8F7A5A #4E4032 #E3A83B #B3262B #3B4A8C).
  Die Klänge erzeugt `ui/audio_bank.gd` synthetisch.
- Turm-Referenzboss in `godot/`:
  - `assets/sprites/bosses/turm/ASSET_SPEC.md`: 128 × 160 px, 12 fps, Tags und Layer.
  - `assets/source/aseprite/create_boss_turm.lua`: legt die Aseprite-Datei an.
  - `assets/audio/turm/REAPER_CUES.md`: sieben Cues.
  - **Es gibt noch keine fertigen Sprites oder WAVs.** `turm_boss.gd` und
    `turm_audio.gd` sind prozedurale Platzhalter mit festen State-Namen.
  - Kleine Unstimmigkeit: REAPER_CUES nennt `res://assets/audio/bosses/turm/`,
    der Ordner heißt `assets/audio/turm/`.

## 8. Übergabe-Aussagen: bestätigt und widerlegt

Bestätigt im Code: 90/100/150, Zukunft nach dem Gegner, Haltungsdeckel 35 %,
Bruch × 1,5, Rückkehr auf 60 %, Siegel, Muster, Kette +10 %/max. 5,
Wiederholung 100/90/75/50, 78/50/22 Inhalte, 4 Deuter, Schleier 0–8,
18 Ereignisse, 3 Akte + Finale + Spirale, Omen-Beute, Verdunkelung, PCG32-Ströme.

Widersprüche zwischen Prompts und Code (es gilt der Code):

| Aussage | Code |
|---|---|
| „6 Bossregeln“ | 8 Bosse mit 8 Regeln (zusätzlich Mäßigkeit, Hierophant) und die Sonnenregel des zweiten Finales |
| Mond als Akt-I-Boss | Der Mond ist **Akt III** (220 HP, Phasen-HP 320 auf Schleier 0) |
| „246 C#-Tests“ | 281 Tests |
| Ein Finale (Die Welt) | Zwei: Die Welt **oder** die rote Sonne; „rote_sonne“ als Gegner heißt jetzt Sonnenkind (Elite) |
| Tageskarte mit Schleier aus dem Seed | Schleier fest **2**, Deuter = Seed mod 4 |
| godot-next sei paritätisch | Der alte godot-next-Kern wich ab (Zukunfts-Timing, Turm, Rad, Gehängter, Tod, Pakt, Signatur, Ereignisse, Belohnungen, FNV-Startwert). Er ist ersetzt; Parität ist jetzt nachgewiesen |
| godot/ als startbare Basis | godot/ ist Godot 4.4 mit alten Regeln (70/100/200, Schicksalsfäden) → HISTORISCH |
| „TAROCK'S OMEN“-Masterprompt: Unity/C#, Welten, Maskottchen Tarock | Widerspricht der Entscheidung für Godot/GDScript und dem bestehenden Spiel; wird als ergänzende Ideensammlung behandelt, nichts davon ist umgesetzt |

## 9. Bekannte Lücken

- Kampfdarstellung ist funktional, nicht final: keine Bühne, keine
  Wertungskaskade, kein Drag-and-drop (nur Tippen), keine Boss-Animationen.
- Turm-Präsentation aus `godot/` ist noch nicht portiert.
- Items: im Kampf benutzbar (Zielkarten-Items wirken auf die gewählte
  Handkarte). Das Unity-Frontend bietet Items gar nicht an.
- Lesarten wachsen wie im Unity-Frontend nach jedem gewonnenen Kampf
  (`ui/spiel.gd: after_turn`); diese Regel liegt in der Oberfläche, nicht im Kern.
- Kein APK, kein iOS-Export, keine Haptik.
- Godot-JSON liest Zahlen als double: Seeds über 2^53 verlieren Stellen. Der
  Port erzeugt Seeds unter 2^53 (`Spiel.fresh_seed`); C#-Speicherstände mit
  Tick-Seeds (Unity) laden, aber der Seed wird ungenau angezeigt.
- Beim Beenden meldet Godot einige verwaiste Objekte (statische Kataloge mit
  Lambdas). Ohne Folgen; aufräumen, wenn es stört.

## 10. Nächste Aufgabe

1. Turm als Vertical Slice in godot-next: `turm_boss.gd`/`turm_audio.gd` aus
   `godot/` portieren, an `GameController`-Zustand und `TurnResult`
   anschließen (eingestürzter Platz, Siegelbruch, Phase 2, Tod), Bühne und
   Wertungskaskade nach `docs/VERTICAL_SLICE.md`.
2. Android-Debug-APK bauen (SDK, Export-Templates 4.7.2, Debug-Keystore).
3. Danach der Mond nach demselben Muster: `mond_boss.gd`, `mond_audio.gd`,
   Aseprite-Vorlage, ASSET_SPEC, REAPER-Cues, Registry für Bossdarstellungen.
