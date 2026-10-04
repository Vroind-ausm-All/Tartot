# Unity: Turm-Vertical-Slice starten

## Schnellstart

1. In Unity Hub **Unity 6000.6.2f1** installieren bzw. auswählen. Das ist die in
   `unity/ProjectSettings/ProjectVersion.txt` festgelegte und geprüfte Version.
   Für einen Windows-Build genügt der Windows-Mono-Support des Editors.
2. Repository auf dem richtigen Branch holen:

   ```powershell
   git clone --branch claude/compassionate-archimedes-ebvgo2 --single-branch https://github.com/Vroind-ausm-All/Tartot.git
   cd Tartot
   ```

   Das Repository ist privat: GitHub-Anmeldung erforderlich. Alternativ auf
   GitHub den Branch auswählen, **Code → Download ZIP**, dann entpacken.
3. Unity Hub → **Add project from disk** → **Tartot/unity** auswählen.
   Nicht die Repository-Wurzel und nicht `godot-karten` öffnen.
4. Den Import und die C#-Kompilierung abwarten. Es ist kein eigenes Theme,
   kein neues Unity-Projekt und kein Kopieren des Cores nötig.
5. **Assets/Scenes/Tartot.unity** öffnen und **Play** drücken.
   Das automatische Editor-Setup setzt diese Szene außerdem als Play-Startszene,
   sodass auch Play aus einer anderen offenen Szene den Slice startet.
6. Im Game-Tab **540 × 960** oder **1080 × 1920** wählen. Die Szene startet sofort
   gegen **DER TURM**, reproduzierbar mit Seed **1337**.

Bedienung: Karte anklicken, danach Vergangenheit/Gegenwart/Zukunft anklicken;
oder eine Karte auf einen Platz ziehen. Ein belegter Platz gibt die Karte per
Klick zurück. **SCHICKSAL AUSFÜHREN** löst die Legung auf. Während der Auflösung
sind weitere Kampfaktionen gesperrt. Nach Sieg oder Niederlage führt
**TURM ERNEUT SPIELEN** direkt in einen frischen Kampf.

Der Slice verwendet das normale Startdeck und die echten Turm-Regeln.
Er überspringt nur den Weg zum Boss. Keine Ersatz-Schadensrechnung in Unity.

## Was automatisch eingerichtet wird

| Bestandteil | Gespeicherter Pfad / Verhalten |
|---|---|
| Startszene | `Assets/Scenes/Tartot.unity`, erster aktivierter Build-Eintrag |
| UIDocument | Auf GameObject `Tartot`, mit UXML und PanelSettings verbunden |
| View | Auf demselben Objekt: `TowerDemo = true`, `AutoSave = false`, `Seed = 1337` |
| Oberfläche | `Assets/Resources/Tartot/Tartot.uxml`, bindet `Tartot.uss` ein |
| Panel | `Assets/Resources/Tartot/TartotPanelSettings.asset`, Referenzauflösung 1080 × 1920, Match 0,5 |
| Theme | `Assets/Resources/Tartot/TartotTheme.tss`, importiert Unitys Standardtheme |
| Hintergrund / Audio | Kamera mit schwarzer Löschfarbe und ohne Szenenrendering, ein AudioListener |
| Desktop / Mobil | Fenster 540 × 960; Portrait als mobile Ausrichtung |
| Ressourcen | `Resources/Tartot/Anim`, `CardArt`, `Stage`, `Audio` |

`.meta`-Dateien, Szene, ProjectSettings, Paketmanifest und Paket-Lock sind
versioniert. Ihre GUIDs zusammen mit den Assets behalten. `Library`, `Temp`,
Builds und lokale Einstellungen sind ausgeschlossen.

`TartotSetup` läuft nach dem Editor-Import, ergänzt fehlende PanelSettings und
die Startszene und registriert den Build-Eintrag. Eine vorhandene Szene wird
beim automatischen Setup nicht überschrieben. Eine ungespeicherte, bearbeitete
Anfangsszene wird ebenfalls nicht verworfen: zuerst speichern, dann das Menü nutzen.

**Tartot → Projekt einrichten** öffnet die Startszene und repariert deren
UXML-/Panel-Zuordnung sowie Hintergrundkamera und AudioListener. Vor einem
Szenenwechsel fragt Unity nach ungespeicherten Änderungen. Das Menü kann mehrfach
ausgeführt werden, ohne weitere Spielobjekte oder Build-Einträge anzulegen.

`TartotBootstrap` bleibt als Fallback für leere Szenen vorhanden. Er lädt
`Tartot/Tartot` und `Tartot/TartotPanelSettings` aus Resources und baut die View
auf, wenn noch keine aktive vorhanden ist. Die ausgelieferte Startszene benötigt
diesen Fallback nicht.

## Spielstände und Inspector

Die Demo liest und schreibt weder `tartot.save` noch `tartot.meta` oder
`tartot.setup`. Ein normaler Run bleibt dadurch unberührt. Jeder Play-Start und
jeder Demo-Neustart beginnt frisch. Der Seed bleibt beim Neustart gleich.

Am Objekt `Tartot` lassen sich `Seed`, `Audio Enabled` und `Haptics Enabled`
ändern. Seed 0 verwendet in der Demo den festen Fallback 1337.

Für den normalen Run-Modus **Tower Demo deaktivieren** und nach Wunsch
**Auto Save aktivieren**. Danach Play neu starten. Dieser Modus verwendet die
bisherigen PlayerPrefs und beginnt am Titel bzw. setzt einen gespeicherten Run
fort. `Auto Save = false` unterbindet dort nur das Schreiben, nicht das Laden.

## Prüfungen und Windows-Build

Für die folgenden drei Befehle ist das **.NET-8-SDK** nötig. Eine reine
.NET-Runtime reicht nicht. Unity Play selbst benötigt das separate SDK nicht.
Aus der Repository-Wurzel:

```powershell
dotnet build Tartot.sln -c Release
dotnet test src/Tartot.Tests/Tartot.Tests.csproj -c Release --no-restore
dotnet build tools/unity-syntax-check/UnitySyntaxCheck.csproj -c Release
```

Der Syntaxcheck kompiliert gegen Stubs. Er ersetzt keinen Unity-Import.
Die nur für Editor/Development-Builds kompilierten Build- und Smoke-Helfer
werden durch den echten Unity-Build geprüft.

**Tartot → Regelkern pruefen (ohne Play)** führt außerdem einen Core-Run im
Editor aus. **Tartot → Windows-Demo bauen** prüft die Startverdrahtung und wichtige
Resources und erstellt einen Development-Build unter
`unity/Build/Windows/Tartot.exe`. Den ganzen Windows-Ordner zusammen behalten.
Die Startszene muss für diesen Build weiterhin als Tower-Demo konfiguriert sein.

Ohne geöffneten Editor, mit der Unity-CLI:

```powershell
unity run ./unity --editor-version 6000.6.2f1 -- -executeMethod Tartot.Unity.EditorTools.TartotBuild.ValidateProject
unity build ./unity --editor-version 6000.6.2f1 --target StandaloneWindows64 --execute-method Tartot.Unity.EditorTools.TartotBuild.BuildWindows --no-tail
```

Die CLI ist optional. Direkt mit dem Editor geht es ebenso:

```powershell
& 'C:/Program Files/Unity/Hub/Editor/6000.6.2f1/Editor/Unity.exe' -batchmode -quit -projectPath "$PWD/unity" -executeMethod Tartot.Unity.EditorTools.TartotBuild.BuildWindows -logFile "$PWD/unity/Logs/build.log"
```

Nach dem Build den automatischen Player-Test starten:

```powershell
powershell -ExecutionPolicy Bypass -File tools/Test-UnityDemo.ps1
```

Er spielt mit dem vorhandenen Core-Autopiloten als Kartenberater einen Kampf
über View-Auswahl und UI-Toolkit-Submit-Ereignisse. Er prüft Layout/Erreichbarkeit
des Ausführen-Buttons, Turmeinsturz, Siegelbruch, Ende der Auflösungsanimationen,
Ergebnisbildschirm, Neustart, erneutes Aktivieren der View und unveränderte
normale Spielstände. Erfolg: Exitcode 0 und `TARTOT_SMOKE_PASS` im Protokoll.
Der Test beendet den gestarteten Player. Er ist ausschließlich per
`-tartot-smoke-test` in einem Development-Build aktiv.

## Verifizierter Stand und verbleibende Risiken

Lokale Prüfung am 04.10.2026 mit Windows und Unity **6000.6.2f1**:

- Solution-Build erfolgreich; **281 Tests bestanden** (279 bestehende plus
  zwei Demo-Regressionsprüfungen).
- Unity-Syntaxcheck erfolgreich.
- Echter Unity-Import, Szeneneinrichtung und Windows-Development-Build erfolgreich.
- Frischer Import aus dem Git-Archiv ohne Library-Cache erfolgreich; fehlende
  Startszene und PanelSettings in einer separaten Testkopie automatisch neu erzeugt
  und nach erneutem Öffnen korrekt verbunden.
- Player-Smoke-Test: Turm besiegt, **10 Züge**, Ergebnis `BossLoot`, Neustart und
  View-Lebenszyklus erfolgreich, sowohl bei **540 × 960** als auch **1280 × 720**.
- `Tartot.Core`-Quellcode unverändert; lediglich Unitys Import-Metadaten ergänzt.

Offen bzw. bewusst begrenzt:

- **Kein manueller visueller/akustischer Abnahmetest.** Der automatisierte Test
  bestätigt Ablauf und UI-Anbindung, nicht die subjektive Lesbarkeit, Lautstärke
  oder das endgültige FX-Tuning. Maus-Drag und echtes Touch-Verhalten manuell prüfen.
- **Android/iOS, Haptik, Safe Areas und IL2CPP** wurden nicht gebaut oder auf Geräten
  geprüft. Der Windows-Mono-Build ist kein Nachweis dafür.
- **Andere Unity-Versionen:** Die frühere pauschale Zusage „2022.3 oder neuer“
  gilt nicht als getestet. Den gepinnten Editor verwenden; Up-/Downgrades können
  Scene-, PanelSettings- und ProjectSettings-Dateien neu serialisieren.
- **Unicode-Symbole/Fonts:** Suit- und Arkana-Zeichen können je nach Font-Fallback
  unterschiedlich aussehen. Das Standardtheme ist vorhanden, eine eigene vollständige
  Symbolschrift ist nicht Teil dieser Änderung.
- **Unity-6-Serializerwarnung UAC1001** zu `CardDefinition.Major` (`MajorArcana?`):
  Der Core nutzt seinen eigenen JSON-Speicherpfad, keinen Unity-Inspector-Serializer
  für den Run. Daher wurde der Regelkern dafür nicht geändert.
- Der lokale Editor meldete **„LicensingClient has failed validation; ignoring“**,
  konnte danach die Unity-Personal-Lizenz erfolgreich auflösen und bauen. Bei einem
  tatsächlich abgebrochenen Lizenzstart Unity Hub/Lizenz prüfen; das ist kein
  bestandener Build allein aufgrund dieser Warnung.
- Das automatische Editor-Setup setzt die Demo als Play-Startszene. Für andere
  Szenenexperimente diese Einstellung bewusst ändern bzw. das Setup anpassen.

Die C#-Bindung orientiert sich am Lebenszyklus des
[Unity-UIDocument](https://github.com/Unity-Technologies/UnityCsReference/blob/master/Modules/UIElements/Core/GameObjects/UIDocument.cs):
bei erneutem Aktivieren wird ein neuer UI-Baum gebunden; der alte Baum wird
abgehängt, damit geplante Animationen und Eingabecallbacks nicht weiterlaufen.
