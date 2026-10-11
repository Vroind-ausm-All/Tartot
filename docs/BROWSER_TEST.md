# TARTOT im Browser testen

Dieser Branch exportiert das **vorhandene `godot-next/`-Spiel** als WebAssembly/HTML5.
Der GDScript-Regelkern bleibt unverändert. Der C#-Kern unter `unity/` ist weiterhin
die maßgebliche Test- und Paritätsreferenz. Es wird kein zweites Spiel in JavaScript gepflegt.

## Online spielen (GitHub Pages)

1. Auf GitHub **Settings → Pages → Build and deployment → Source: GitHub Actions** auswählen.
2. Den Workflow [TARTOT Browser Playtest](../.github/workflows/browser-game.yml) öffnen und den Lauf für `feature/browser-playtest` prüfen.
3. Bei erfolgreichem Deployment `https://vroind-ausm-all.github.io/Tartot/` öffnen.
4. Auf **RUN BEGINNEN** klicken oder die drei **VORFÜHRUNG**-Schaltflächen für Turm/Tod/Mond verwenden.

**Achtung:** Das Repository ist privat. GitHub Pages ist je nach GitHub-Tarif für private
Repositories nicht verfügbar; eine aktivierte Pages-Seite ist normalerweise trotzdem
öffentlich zugänglich und enthält die exportierten Spielassets. Veröffentliche nur, was
du öffentlich zeigen möchtest. Ohne aktivierte Pages-Einstellung kann der Build trotzdem
als GitHub-Actions-Artefakt heruntergeladen werden.

## Alternative: Browser-Build als Artefakt

In **Actions → TARTOT Browser Playtest → aktueller Lauf → Artifacts**
`tartot-browser-playtest` herunterladen und entpacken. Im entpackten Ordner:

```bash
python3 -m http.server 8000
```

Dann `http://localhost:8000` öffnen. HTML5-Exporte brauchen einen HTTP-Server;
die `index.html` nicht einfach per `file://` öffnen.

## Lokal mit Godot 4.7.2 exportieren

```bash
godot --headless --path godot-next --editor --quit
godot --headless --path godot-next --script res://tests/smoke.gd
mkdir -p build/web
godot --headless --path godot-next --export-release "Web Browser" "$PWD/build/web/index.html"
python3 -m http.server 8000 --directory build/web
```

Godot 4.7.2 benötigt installierte Standard-Exporttemplates für Web.

## Bedienbarkeit

Nach **RUN BEGINNEN** lassen sich Handkarten anklicken, anheben und auf
Vergangenheit/Gegenwart/Zukunft ziehen. Die Eingaben laufen über
`KartenTisch._unhandled_input`; der Hauptbildschirm lässt deshalb
nicht-behandelte Mausereignisse an den Kartentisch durch.
Der CI-Test `tests/browser_input.tscn` prüft echte Maus-Drücken-/Loslassen-Events.

Auf dem Titelbildschirm sind weitere **Deuter** und **Schleier** erst nach
entsprechendem Spielfortschritt verfügbar (absichtlich deaktiviert).

## Browser-Bedienung und Technik

- Maus entspricht Touch; Karten ziehen, Plätze belegen und SCHICKSAL AUSFÜHREN.
- Hochformat 1080 × 1920 wird unter Beibehaltung des Seitenverhältnisses skaliert.
- Boss-Vorführungen sind im Web auch beim Release-Export sichtbar und speichern
  keine Daten ab.
- Normale Runs speichern in Godots `user://`-Ablage des jeweiligen Browsers;
  private Fenster oder gelöschte Website-Daten können den Speicherstand verlieren.
- Single-threaded Web-Export; keine Cross-Origin-Isolation-Header nötig.
- Audio kann erst nach dem ersten Klick/Tap beginnen (Browser-Autoplay-Richtlinien).

### Fehlersuche

- Wenn der Pages-Deploy fehlschlägt: **Settings → Pages → Source: GitHub Actions** prüfen
  sowie GitHub-Tarif, Umgebungs-/Branchregeln und Workflow-Berechtigungen.
- Wenn der Build fehlschlägt: Logs unter **Actions** lesen; vor dem Export laufen
  Resource-Import und der Godot-Smoke-Test.
- Wenn die Seite leer bleibt: Browserkonsole öffnen; ein moderner Browser
  mit WebGL 2.0 und WebAssembly ist erforderlich.

## Unberührt

`main`, Unity-Frontend, C#-Regelkern, Paritätstests und Android-Export bleiben unverändert.
Weitere Änderungen dieses Branches betreffen ausschließlich den Web-Testzugang.
