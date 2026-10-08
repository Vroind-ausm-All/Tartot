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
| Bildformat | Hochformat, Viewport 1080 × 1920 (`canvas_items`, linear gefiltert) |
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
    combat/animation_cues.gd  welche Bossanimation ein Zug auslöst (Port von AnimationCues.cs)
  ui/                       Oberfläche (Autoload Spiel = ui/spiel.gd)
    main.gd                 Seiten je Spielphase (Titel, Belohnung, Wege, Händler, ...)
    thema.gd, kartenblatt.gd  Stil der Seiten und Karten auf den Seiten
    tisch/                  Kampftisch (kampftisch.gd), KernBruecke, CueBuilder, Filmgrund
  addons/tartot_karten/     Karten (karte.gd, karten_front.gd, Shader), Hand und Plätze
                            (tisch.gd, platz.gd), Erklärung bei langem Druck (detail.gd),
                            Bühne (buehne.gd, effekte.gd, choreografie.gd), Greifarm
                            (greifarm.gd), Wertungskaskade, Klang und Musik (klang.gd)
  buehnen/<boss>/           gemalte Bühne, Figur, Plätze je Boss (aus den Boss-Blättern)
  assets/                   HISTORISCH: Pixel-Spezifikationen; REAPER-Cue-Blätter
  tests/smoke.gd            Rauchtest Kern
  tests/ui_walk.tscn        Laufzeittest aller Seiten mit echtem Spielzustand
  tests/boss_slice.gd       Bosskampf am Tisch; turm_slice, mond_slice, tod_slice setzen
                            Boss und Pflicht-Cues (optional mit Bildschirmabzügen)
  tests/karten_galerie.tscn Karten in allen Zuständen (nur zum Anschauen, --foto=)
  tests/video.tscn          Vorführfilm für den Movie Maker
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
godot --headless --path godot-next res://tests/turm_slice.tscn    # Turm-Slice
godot --headless --path godot-next res://tests/mond_slice.tscn    # Mond-Slice
godot --headless --path godot-next res://tests/tod_slice.tscn     # Tod-Slice
tools/godot_tests.sh                                              # alle Godot-Tests auf einmal
tools/paritaet.sh                                                 # C# gegen Godot, Zeile für Zeile
```

Stand 2026-10-08 (Godot 4.7.2, .NET 8):

| Prüfung | Ergebnis |
|---|---|
| C#-Tests | 281 / 281 grün |
| Rauchtest godot-next | grün (0 Fehler) |
| UI-Durchlauf | alle 11 Phasen gebaut (Kampf am neuen Tisch), keine Skriptfehler |
| Turm-Slice | echter Run bis zum Turm, der Tisch spielt selbst (Ziehen, Knopf): Turm packt einen Platz und schlägt ihn ein, Wiederaufrichten, Siegelbruch, Phase 2, Turmtod, Omen-Beute |
| Mond-Slice | echter Run bis zum Mond (Akt III): Fluch, der Mond zieht ein Sternentuch über die Hand (Verhüllen), Siegelbruch, Blutmond, Mondtod, Omen-Beute |
| Tod-Slice | echter Run bis zum Tod (Akt II): der Tod zeigt auf die gezeichnete Karte (auch aus dem Stapel) und greift sich eine Karte (Verlust), Siegelbruch, Omen-Beute |
| Parität | **99 / 99 Fälle identisch**: 40 Seeds, 4 Deuter × 5, Schleier 1–8 × 3, Spirale × 6, Tageskarte × 2, Laufbahn 2 × 25 Runs mit Meta-Fortschritt, Speichern/Laden nach jedem Zug × 5 |

Die Spur enthält je Kampfzug Legung, Wertung (floats als Bitmuster), Gegner,
Hand, die Zahl der Zufallszüge je Strom und den Protokolltext, je Schritt den
ganzen Run (Deck, Charms, Items, Belohnungen, Händler, Nachricht) und am Ende
den Speicherstand, dazu die Animations-Cues jedes Zugs. Abgedeckt sind alle
10 Bosse samt Finale und alle 18 Ereignisse.

Warum der Port so genau ist: Der C#-Kern rechnet mit `float` (32 Bit) und
`Math.Round` (Banker's Rounding). GDScript rechnet mit 64 Bit und rundet x,5
weg von der Null. Jede float-Rechnung des Ports läuft deshalb durch `Num.f`
(Rundung auf float32), gerundet wird mit `Num.rnd`, sortiert stabil mit
`Num.sortiert`. Wer am Kern etwas ändert, ändert es **in beiden** und lässt
`tools/paritaet.sh` laufen.

## 6. Android

- **Debug-APK gebaut** am 2026-10-08 mit `tools/android_apk.sh`:
  `Build/Android/TARTOT-godot-next-debug.apk` (≈ 75,6 MB, arm64-v8a,
  Paket `com.tartot.prototype`, Version 0.3.0, mit Kartentisch, Bühnen und
  Klängen). Signatur v2/v3, `apksigner verify` grün. Berechtigung `VIBRATE`
  für die Haptik; `tests/` und `tools/` sind vom Export ausgenommen.
- **Vorführfilm**: `tests/video.tscn` mit dem Movie Maker aufgenommen
  (Befehl im Kopf von `tests/video.gd`). Er liegt unter
  `Build/Video/TARTOT-schritt1.mp4` und wird nicht eingecheckt.
- **Auf keinem Gerät getestet.** Im Container gibt es weder Gerät noch Emulator.
  Die Emulator-Images kämen von dl.google.com, und das sperrt die Netzrichtlinie
  dieser Umgebung.
- Weil dl.google.com gesperrt war, lief der Bau mit einem Minimal-SDK aus
  Ubuntu-Paketen (`apksigner`, `zipalign`, `adb`). Für den Export ohne Gradle
  reicht das. Wie man es einrichtet, steht im Kopf von `tools/android_apk.sh`.
- Projekteinstellungen für Android: `textures/vram_compression/import_etc2_astc=true`
  und das Projektsymbol `icon.svg`. Preset „Android Prototype“ steht in
  `godot-next/export_presets.cfg`.
- Release-APK/AAB, ein eigener Keystore und Gradle-Builds fehlen noch.

## 7. Assets und Darstellung

Seit 2026-10-08 zeigt godot-next den Kartentisch aus `godot-karten/` bei
1080 × 1920 auf dem GDScript-Kern. Die Pixel-Oberfläche (270 × 480,
`ui/kampf/`, `ui/bosse/`, Aseprite-Import) ist entfernt.

- **Kampftisch** (`ui/tisch/kampftisch.gd`): Aufbau wie die Boss-Blätter:
  Kopf mit Akt, Name, Leben und Runde, darunter die Bühne mit Absicht, Regel
  und Haltung, dann die drei Plätze, die Hand und der Fuß mit dem Knopf
  SCHICKSAL AUSFÜHREN. Er rechnet nichts selbst: `KernBruecke` liest den
  Kernzustand als Dictionary und gibt Legung und Ausführen an den Kern.
  Nach jeder Folge gleicht der Tisch sich mit dem Kern ab. `CueBuilder` baut
  die Folge allein aus Kernfakten.
- **Karten** (`addons/tartot_karten/karte.gd`, `karten_front.gd`): randlos wie
  Tarotkarten. Das Motiv füllt die ganze Karte, darüber liegen ein Goldrahmen,
  eine Zahlkartusche, ein Namensband und der Seltenheitsstein. Karten ohne
  eigenes Motiv zeigen die Sinnbilder ihrer Farbe auf einem Strahlengrund,
  also nie das Motiv einer anderen Karte. Zustände:
  - umgekehrt (Motiv steht kopf, rote Dreiecke),
  - Stufe (Goldpunkte),
  - Schimmer (Rahmenfarbe),
  - vom Mond verhüllt (Rückseite mit Nebel),
  - vom Tod gezeichnet (Wachssiegel mit Rundenzahl).
- **Kartenshader** (`shader/karte_basis.gdshaderinc`):
  - falsche 3D-Neigung zum Finger und runde Ecken;
  - Metallglanz auf allem Gold;
  - Holo-Folie nach Seltenheit (gewöhnlich keine, legendär voll), mit Regenbogen, Beugungslinien und Funken, die mit der Neigung wandern;
  - Editionen (schimmernd, leuchtend, brennend, gläsern).

  Unter dem Finger verschiebt sich das Motiv gegen den Rahmen (Parallaxe).
- **Langes Drücken** (`detail.gd`, `tisch.gd`): Nach 0,4 s ohne Ziehen kommt
  die Karte groß in die Mitte und darunter klappt die Erklärung auf. Sie zeigt:
  - Name, Zahl, Farbe und Seltenheit,
  - den Kerntext und die Edition,
  - den Umkehrpreis,
  - Rang und Wirkungsfaktor aus dem Kern,
  - das Todesmal.

  Bewegt man den Finger, kippt die große Karte mit. Loslassen schließt die Erklärung. Das gilt am Tisch und auf allen Seiten mit Karten (Händler, Ritual, Rast, Omen). Verhüllte Karten bleiben verhüllt.
- **Bühne** (`buehne.gd`, `buehnen/<boss>/`): gemalte Figur auf gemalter
  Kulisse. Die Figur bewegt sich als Gummischlauch-Puppe über Federn und einen
  Biege-Shader. Mehrere Ebenen verschieben sich verschieden weit (Kulisse,
  Schlagschatten, Figur, Nebel, Staub). Den Blick steuert am Handy der
  Neigungssensor, sonst der Finger.
- **Greifende Bosse** (`greifarm.gd`): Ein Gummischlauch-Arm mit weißem
  Handschuh wächst aus der Schulter der Figur über den Bühnenrahmen auf den
  Tisch. Der Boss beugt sich dabei vor.
  - **Turm**, Einsturz: packt den Platz, holt aus und schlägt ihn in Trümmer.
  - **Tod**, neues Mal: zeigt auf die Karte, die notfalls kurz aus dem Stapel kommt.
  - **Tod**, Verlust: greift sich die Karte und zieht sie in die Bühne, wo sie zerfällt.
  - **Mond**, Verhüllen: zieht ein Sternentuch über die ganze Hand.

  Ausgelöst wird nur von Kernfakten (`CueBuilder`, `KernBruecke`).
- **Seiten außerhalb des Kampfes** (`ui/main.gd`, `ui/thema.gd`): derselbe Stil
  wie der Tisch, mit IM Fell, dunklen Zierplatten und roten Zierknöpfen.
  Ereignisse zeigen eine gemalte Bühne statt Pixelbildern.
- **Klang** (`klang.gd`): Musik (Walzer, Bossschicht), Kartengeräusche,
  Angriffe, Haptik. Die Pixel-Klänge `ui/audio_bank.gd` sind entfernt.
- **Vorführung**: Im Titel starten (nur in Debug-Builds) „VORFÜHRUNG“ für
  Turm, Tod und Mond je einen echten Run, den der Autopilot bis vor diesen
  Boss spielt. Nichts wird gespeichert oder verbucht.

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

- Eigene Motive gibt es für 27 von 78 Karten (aus den Boss-Blättern). Die
  übrigen zeigen Sinnbilder statt Malerei. Die Motive sind 344 × 416 groß
  und werden für die große Ansicht hochskaliert.
- Gemalte Figuren gibt es für 13 Boss-Blätter; Gegner ohne Figur zeigen
  die Blockout-Animation vor der Bühne ihres Akts. Nur Turm, Tod und Mond
  greifen nach dem Tisch.
- Der Greifarm ist gezeichnet (Bezier, Handschuh) und nicht gemalt. Er passt
  zum Gummischlauch-Stil, aber nicht ganz zur Malerei der Figuren.
- Godot im Headless-Modus meldet beim Übersetzen des Kartenshaders
  `custom_samplers.has(...)` (Dummy-Renderer). Unter OpenGL tritt das nicht auf.
- Kein „Reduced Motion“-Schalter. Das Intro lässt sich noch nicht beschleunigen.
- Items sind im Kampf benutzbar; Zielkarten-Items wirken auf die gewählte
  Handkarte. Das Unity-Frontend bietet Items gar nicht an.
- Lesarten wachsen wie im Unity-Frontend nach jedem gewonnenen Kampf
  (`ui/spiel.gd: after_turn`). Diese Regel liegt in der Oberfläche, nicht im Kern.
- Kein iOS-Export, kein Release-Build.
- Godot-JSON liest Zahlen als double, deshalb verlieren Seeds über 2^53
  Stellen. Der Port erzeugt Seeds unter 2^53 (`Spiel.fresh_seed`).
  C#-Speicherstände mit Tick-Seeds laden zwar, aber der Seed wird ungenau angezeigt.
- Beim Beenden meldet Godot einige verwaiste Objekte (statische Kataloge mit
  Lambdas). Das hat keine Folgen.

## 10. Nächste Aufgabe

1. Das Debug-APK auf einem Android-Gerät installieren
   (`adb install -r Build/Android/TARTOT-godot-next-debug.apk`) und Turm, Tod
   und Mond über die Vorführung spielen. Zu prüfen sind:
   - Touch und Ziehen,
   - langes Drücken,
   - Lesbarkeit,
   - Neigungssensor (Parallaxe),
   - Bildrate mit vielen Karten-Viewports,
   - Ton und Vibration.
2. Kartenkunst: Motive für die übrigen 51 Karten in höherer Auflösung (das
   Motiv füllt jetzt die ganze Karte). Dateiname `kunst/motive/<id>.png` reicht.
3. Weitere Bosse greifen lassen, etwa Rad (dreht die Plätze), Teufel (Pakt auf
   den Tisch legen) und Gehängter (Zeit verkehrt), jeweils mit eigener
   `*_slice.tscn` und Pflicht-Cues.
4. Optional: Godot-Tests und `tools/paritaet.sh quick` in die CI aufnehmen.
