# Android-Prototyp: Schicksal auf Zelluloid

Branch: `chatgpt/android-celluloid-prototype`

Dieser Branch setzt die Stil-Bibel als spielbaren Unity-Mobile-Vertical-Slice auf den bestehenden Regelkern.

## Enthalten

- 270 × 480 Referenzauflösung für den Pixel-Look
- Safe-Area-Anpassung für Android-Geräte
- neue Sepia-/Gold-/Rot-/Indigo-Palette
- Karten als Filmkader mit Perforationsrand
- prozedural erzeugte Pixel-Suit-Symbole
- prozedural erzeugte Gegnerbilder; eigene Bossbilder für Turm, Mond, Tod, Rad, Teufel, Gehängten und Welt
- prozedural erzeugte Stummfilm-Bilder für Ereignisse
- Filmkorn, Vignette, Kratzer und 12-fps-Wippen
- Boss-Zwischentitel im Stummfilmstil
- synthetischer Jahrmarkt-/Orgel-Kampfloop
- Projektorloop und SFX für Karten, Treffer, Haltungsbruch, Bossauftritt und Filmbrand
- Tonhöhen-Verschleiß mit steigender Verdunkelung
- Haptik bei Haltungsbruch/Bossintro auf Mobilgeräten
- Android-Ein-Klick-Build über `Tartot → Android-Prototyp bauen`

Die Prototype-Grafik und der Prototype-Ton sind absichtlich vollständig im Code erzeugt. Dadurch gibt es keine fremden Platzhalterlizenzen und keine Importabhängigkeiten. Später können die Generatoren schrittweise durch finale PNG/Sprite-Sheets und WAV/OGG-Dateien ersetzt werden, ohne den Regelkern zu ändern.

## Starten

Empfohlen: Unity 2022.3.62f1 mit Android Build Support.

1. Repository klonen und diesen Branch auschecken.
2. In Unity Hub den Ordner `unity/` öffnen.
3. Menü `Tartot → Projekt einrichten` ausführen.
4. Play drücken.

Der Bootstrap kann das Panel auch ohne gespeichertes PanelSettings-Asset erzeugen. Für reproduzierbare Android-Builds ist der Setup-Schritt trotzdem vorgesehen.

## Android APK

Im Unity-Editor:

`Tartot → Android-Prototyp bauen`

Das Skript wechselt auf Android, baut die Startszene und schreibt:

`unity/Build/Android/TARTOT-prototype.apk`

Voraussetzung ist, dass in Unity Hub für die installierte 2022.3-Version Android Build Support inklusive SDK/NDK/OpenJDK installiert ist.

## Was noch kein Release-Asset ist

Die Grafik ist ein belastbarer Style-/UX-Prototyp, keine finale Illustration. Die Bossbilder zeigen bereits die Silhouetten- und Farbregeln, besitzen aber noch keine handgezeichneten Frame-Sheets für vollständige Rubberhose-Aktionen. Der Kampfloop ist synthetisch und dient als Klangrichtung, nicht als finaler Score.

Die Präsentationsschicht berührt keine Spielregeln. `Tartot.Core` bleibt die Quelle für Kampf, Progression, Savegame und Balancing.

## Prüfstatus

Die vorhandenen Core-Tests und die Simulation bleiben unverändert. Die Unity-Stubs wurden um die neuen Textur-, Audio-, Safe-Area- und Android-Build-APIs erweitert.

Wichtig: In der ChatGPT-Ausführungsumgebung steht kein Unity-Editor zur Verfügung. Der Branch ist deshalb als Unity-Projekt ausgereift und für den lokalen Editor/Android-Build vorbereitet, aber ein APK konnte hier nicht tatsächlich kompiliert oder auf einem Gerät gestartet werden. Der erste echte Editor-Import ist der nächste Integrationscheck.
