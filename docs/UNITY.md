# Unity: Einrichtung und offene Punkte

## Ehrlicher Hinweis vorweg

**Der Unity-Teil ist nicht in Unity ausgeführt worden.** Diese Umgebung hat
keine Unity-Installation. Geprüft ist:

- `Tartot.Core` kompiliert gegen `netstandard2.1` (Unitys API-Ebene) mit
  `TreatWarningsAsErrors`, und 246 Tests laufen grün
- der Unity-Code kompiliert gegen Stubs der verwendeten Unity-Typen
  (`dotnet build tools/unity-syntax-check`)

Nicht geprüft ist alles, was erst zur Laufzeit oder im Editor auffällt:
das Einrichtungs-Menü, UXML-Pfade, `PanelSettings`, Layoutverhalten auf einem
echten Gerät, Touch-Bedienung, Schriftarten für die Suit-Symbole. Die
Stub-Prüfung fängt Tippfehler, keine falschen Annahmen über Unity.

Rechne also damit, dass beim ersten Öffnen Kleinigkeiten zu richten sind. Für
jeden automatisierten Schritt steht unten der Weg von Hand daneben.

---

## Den Code auf deinen Rechner holen

Es ist **nichts zu übertragen**: der Regelkern liegt bereits unter
`unity/Assets/Tartot/Core`, also dort, wo Unity ihn kompiliert. Du holst dir
das Repository und öffnest den Ordner `unity/` — fertig.

```bash
git clone -b claude/compassionate-archimedes-ebvgo2 \
  https://github.com/Vroind-ausm-All/Tartot.git
cd Tartot
```

Ohne Git geht es auch: auf GitHub den Branch wählen → *Code → Download ZIP* →
entpacken.

In Unity Hub dann **`Add project from disk`** und den Unterordner **`Tartot/unity`**
auswählen — nicht die Repo-Wurzel. Unity legt beim ersten Öffnen `Library/`,
`ProjectSettings/` und `Packages/manifest.json` selbst an.

### Nach dem ersten Import: .meta-Dateien committen

Unity erzeugt beim Import zu jeder Datei eine `.meta`-Datei mit einer GUID.
Diese GUIDs verbinden Szenen, Prefabs und Assets miteinander. Sie gehören ins
Repository — sonst reißen die Verbindungen, sobald jemand anderes das Projekt
öffnet oder du es auf einem zweiten Rechner klonst.

```bash
git add unity/Assets unity/ProjectSettings unity/Packages
git commit -m "Unity-Import: meta-Dateien und Projekteinstellungen"
```

`unity/Library/` und `unity/Temp/` bleiben ausgeschlossen — die sind
generiert und riesig. Das steht schon in der `.gitignore`.

---

## In ein bestehendes Unity-Projekt übernehmen

Falls du den Code lieber in ein eigenes Projekt holst, kopierst du zwei
Ordner in dessen `Assets`:

```
unity/Assets/Tartot/            → DeinProjekt/Assets/Tartot/
unity/Assets/Resources/Tartot/  → DeinProjekt/Assets/Resources/Tartot/
```

Das genügt für Unity — die asmdef-Dateien kommen mit, der Kern bleibt
gekapselt.

**Ein Haken:** `src/Tartot.Core/Tartot.Core.csproj` verlinkt die Quellen über
einen relativen Pfad (`../../unity/Assets/Tartot/Core/**`). Kopierst du den
Kern woandershin, laufen Tests und Simulation gegen die *alte* Kopie weiter —
und du bearbeitest fortan zwei Stände. Dann entweder den Pfad im csproj
anpassen oder mit dem Repo als Projektwurzel arbeiten. Die zweite Variante ist
der Grund, warum das Projekt so geschnitten ist.

---

## Wie das Ganze aussieht, ohne Unity

Für einen ersten Eindruck lässt sich der echte Spielzustand aus dem Kern
ziehen und im vorgesehenen Design zeichnen:

```bash
dotnet run --project src/Tartot.Sim -c Release -- --snapshot=/tmp/tartot_state
python3 tools/screenshots/render.py /tmp/tartot_state /tmp/tartot_html
python3 tools/screenshots/shoot.py  /tmp/tartot_html  /tmp/tartot_shots
```

Die Zahlen und Karten stammen aus dem Regelkern, die Gestaltung bildet
`Tartot.uss` nach — gezeichnet wird von Chromium, **nicht von Unity**.
Schriftart, Abstände und Theme können dort abweichen. Es ersetzt also keinen
Unity-Build, zeigt aber verlässlich, welche Werte wo landen.

---

## Ohne Unity testen — geht sofort

Der komplette Regelkern lässt sich ohne Unity prüfen und spielen lassen:

```bash
dotnet test src/Tartot.Tests                                    # 246 Tests
dotnet run --project src/Tartot.Sim -c Release -- --runs=50     # 50 Runs durchspielen
dotnet build tools/unity-syntax-check                           # Unity-Code auf Syntax prüfen
```

Das deckt alle Regeln ab. Unity brauchst du nur, um die Oberfläche zu sehen.

---

## Projekt in Unity öffnen

**Voraussetzung:** Unity **2022.3 LTS** oder neuer.

1. Unity Hub → *Add* → *Add project from disk* → den Ordner **`unity/`** wählen
   (nicht das Repo-Wurzelverzeichnis).
2. Projekt öffnen. Unity legt beim ersten Start `Library/`,
   `ProjectSettings/` und `Packages/manifest.json` an — das dauert einen
   Moment. Der Paketsatz kommt bewusst von Unity selbst: eine von Hand
   geschriebene `manifest.json` hätte die IDE-Pakete weggelassen, und dann
   erzeugt Unity keine `.csproj` für Rider oder Visual Studio.
3. **Ein Theme anlegen**, falls noch keines existiert:
   *Assets → Create → UI Toolkit → TSS Theme File*, Name egal.
   UI Toolkit zeichnet zur Laufzeit ohne Theme gar nichts — das ist der
   häufigste Stolperstein.
4. Im Menü **`Tartot → Projekt einrichten`** aufrufen.
   Das legt die PanelSettings an (Hochformat, 1080 × 1920), baut die Szene
   `Assets/Scenes/Tartot.unity` mit UIDocument und `TartotView` und stellt die
   Player Settings auf Portrait.
5. **Play** drücken.

Wenn Schritt 4 fehlschlägt, steht unten, wie es von Hand geht.

### Vorher kurz gegenprüfen

**`Tartot → Regelkern prüfen (ohne Play)`** spielt einen kompletten Run im
Editor durch und schreibt das Ergebnis in die Konsole. Kommt dort eine
sinnvolle Zeile an, ist der Kern in Unity korrekt eingebunden — dann liegt ein
Problem, falls eines auftritt, sicher an der Oberfläche und nicht am Kern.

### Von Hand, falls das Menü nicht greift

1. *Assets → Create → UI Toolkit → Panel Settings Asset*, ablegen unter
   `Assets/Resources/Tartot/TartotPanelSettings.asset`
   (der Name muss genau so lauten, der Bootstrap sucht danach).
2. Im Inspector setzen:

   | Feld | Wert |
   |---|---|
   | Theme Style Sheet | das Theme aus Schritt 3 oben |
   | Scale Mode | Scale With Screen Size |
   | Reference Resolution | 1080 × 1920 |
   | Screen Match Mode | Match Width Or Height |
   | Match | 1 (an der Höhe ausrichten) |

3. Leere Szene, leeres GameObject anlegen, Komponente **UI Document**
   hinzufügen, dort die PanelSettings und
   `Assets/Resources/Tartot/Tartot.uxml` zuweisen.
4. Am selben GameObject die Komponente **TartotView** hinzufügen.
5. Play.

### Was du im Inspector einstellen kannst

`TartotView` hat zwei Felder:

| Feld | Bedeutung |
|---|---|
| **Seed** | 0 = zufällig. Ein fester Wert macht den Run reproduzierbar — praktisch zum Nachstellen eines Fehlers. |
| **Auto Save** | Schreibt nach jedem Zug in die PlayerPrefs. Zum Testen ruhig ausschalten, sonst setzt der letzte Stand beim nächsten Play fort. |

Gespeichert wird unter den PlayerPrefs-Schlüsseln `tartot.save` und
`tartot.meta`. Zum Zurücksetzen: *Edit → Clear All PlayerPrefs*.

### Im Game-View aufs Hochformat stellen

Oben im Game-Tab die Auflösung auf ein Portrait-Format setzen, etwa
`1080 × 1920` oder ein Handy-Preset. Im Landscape-Standard sieht das Layout
falsch aus — das ist dann keine Fehlfunktion.

---

## Wie die Oberfläche aufgebaut ist

Eine Kopfzeile und vier Zonen von oben nach unten, mehr zeigt der Kampfschirm
nicht:

0. **Kopfzeile** — wo du stehst: `AKT II · KAMPF 3/5 · RUNDE 4`, `FINALE`
   oder `SPIRALE 6`
1. **Gegner** — Silhouette, Name, **Bossregel als rotes Banner**, HP-Balken,
   Haltungsbalken, nächster Zug (beim Mond: `???`)
2. **Spielerleiste** — HP, Schild, Fate und Gold, Luck, Verdunkelung;
   darunter die Charms als Namen mit Anzahl
3. **Die Legung** — Vergangenheit, Gegenwart, Zukunft. Ein eingestürzter Platz
   (Turm) wird rot und nimmt keine Karte; ein verschobener Platz (Rad,
   Gehängter) sagt, wo er wirkt: „wirkt als GEGENWART“
4. **Vorschau, Beinahe-Hinweis, Protokoll, Hand** und `SCHICKSAL AUSFÜHREN`.
   Beim Teufel erscheint darüber das Pakt-Feld mit zwei Knöpfen.

Karten zeigen zwei Bosszustände: **verdeckt** (Mond: Rückseite, kein Wert)
und **gezeichnet** (Tod: ☠ mit den verbleibenden Runden).

Alles Weitere läuft über ein Overlay: Titel (Deuter, Schleier, Tageskarte),
Belohnung, Wegwahl mit angekündigtem Omen, Händler (Vergessen oder Veredeln),
Ritual, Orakel, Rast, **Ereignis** (Satz für Satz mit „…“, dann die Wahl,
dann der Schlusssatz), **Omen-Beute**, Sieg und der **Run-Bericht** mit der
Beinahe-Liste.

Eine erfüllte Prophezeiung, ein neuer Rekord oder eine vom Tod genommene
Karte erscheinen sofort als **Einblendung** in der Mitte; ein Tipp schließt sie.

**Bedienung**: Karte antippen, dann einen Platz antippen. Ein belegter Platz
gibt die Karte auf Tipp zurück auf die Hand.

**Charmtexte öffnen sich erst auf Tipp.** Im Kampf steht nur Name und Anzahl —
so bleibt der Kampfschirm sauber, während die Komplexität darunter wächst.

Die View ist zweigeteilt: `TartotView.cs` bindet den Kern an den Kampfschirm,
`TartotView.Overlays.cs` baut die Overlays. Beide enthalten keine Spielregel.

### Farben stehen nur im USS

`Tartot.uss` hält die Palette „Occult Clean": Schwarz und Elfenbein tragen
alles, Indigo und Ocker sind die einzigen Akzente. Im C#-Code steht **kein
einziger Farbwert** — Karten bekommen USS-Klassen (`karte--schwerter`,
`karte--gold`), nicht Farben.

Die Schimmer-Leiter verdunkelt die Kartenfläche schrittweise
(`Matt → Weiß → Indigo → Gold → Blut → Schwarz`). Damit ist die Verdunkelung
des eigenen Decks unmittelbar sichtbar, ohne dass eine Zahl es sagt. Die
Verdunkelung des Runs färbt zusätzlich den Hintergrund in fünf Stufen
(`wurzel--dunkel-1` bis `-5`) ins Blutrote.

---

## Was noch fehlt

| | |
|---|---|
| **Kunst** | Gegner-Silhouetten, Kartenillustrationen, Charm- und Item-Symbole. Aktuell sind es Flächen und Unicode-Zeichen. |
| **Schrift** | Die Suit-Symbole (⚔ ✸ ♥ ◆ ★) brauchen eine Schriftart, die sie enthält — Unitys Standardschrift tut das nicht zuverlässig. Besser: als Sprites ersetzen. |
| **Animation** | Karten legen, auslösen, treffen. Ziel sind 3–4 Sekunden für den ganzen Zug, nicht länger. |
| **Große Arkana** | sollen sich als kurze Unterbrechung anfühlen (Bildschirm verdunkelt, Symbol, ~2 Sekunden), nicht wie normale Karten. |
| **Ton und Haptik** | kurze trockene Effekte, Vibration auf Treffer und Musterauslösung. |
| **Tutorial** | Die drei Positionen müssen in 60 Sekunden sitzen — am besten gezeigt, nicht erklärt. |
| **Lokalisierung** | Texte liegen derzeit im Katalog-Code, auch die 18 Ereignisse. Für Deutsch + Englisch gehören sie in Tabellen. |
| **Szenenbilder** | Ereignisse haben einen Bildschlüssel (`szene--kartenspieler`, `szene--grab` …), aber noch kein Bild — die Fläche ist ein Platzhalter. |
| **Bossregeln inszenieren** | Der Turm, der einen Platz einstürzen lässt, braucht zwei Sekunden Bühne (Riss, Staub). Heute wird der Platz einfach rot. |
