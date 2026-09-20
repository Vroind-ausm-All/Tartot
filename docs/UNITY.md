# Unity: Einrichtung und offene Punkte

## Ehrlicher Hinweis vorweg

**Der Unity-Teil ist nicht in Unity ausgeführt worden.** Diese Umgebung hat
keine Unity-Installation. Geprüft ist:

- `Tartot.Core` kompiliert gegen `netstandard2.1` (Unitys API-Ebene) mit
  `TreatWarningsAsErrors`, und 101 Tests laufen grün
- der Unity-Code kompiliert gegen Stubs der verwendeten Unity-Typen
  (`dotnet build tools/unity-syntax-check`)

Nicht geprüft ist alles, was erst zur Laufzeit oder im Editor auffällt:
UXML-Pfade, `PanelSettings`, Layoutverhalten auf einem echten Gerät, Touch-
Bedienung, Schriftarten für die Suit-Symbole. Die Stub-Prüfung fängt
Tippfehler, keine falschen Annahmen über Unity.

Rechne also damit, dass beim ersten Öffnen Kleinigkeiten zu richten sind.

---

## Projekt öffnen

1. Unity Hub → *Add project from disk* → den Ordner `unity/` wählen
2. Unity **2022.3 LTS** oder neuer
3. Beliebige leere Szene öffnen und **Play** drücken

`TartotBootstrap` baut das Spiel per `RuntimeInitializeOnLoadMethod` auf. Damit
das funktioniert, müssen UXML und PanelSettings unter `Resources` liegen:

```
Assets/Resources/Tartot/Tartot.uxml            (Kopie oder Verschiebung von Assets/Tartot/UI/)
Assets/Resources/Tartot/TartotPanelSettings.asset
```

`PanelSettings` anlegen: *Assets → Create → UI Toolkit → Panel Settings
Asset*. Empfohlene Werte für Hochformat:

| Feld | Wert |
|---|---|
| Scale Mode | Scale With Screen Size |
| Reference Resolution | 1080 × 1920 |
| Screen Match Mode | Match Width Or Height, Match = 1 (Höhe) |

**Für den Produktionsbuild** ist der Bootstrap der falsche Weg: dann eine
richtige Szene mit einem `UIDocument`-GameObject anlegen, dort
`Tartot.uxml` und die PanelSettings zuweisen und `TartotView` daraufsetzen.
Der Bootstrap kann danach weg.

### Player Settings für Mobile

- **Orientation**: Portrait, Auto-Rotation aus
- **Android**: AAB, `arm64-v8a` (+ `armeabi-v7a`), IL2CPP
- **iOS**: Xcode-Projekt exportieren, auf einem Mac signieren

---

## Wie die Oberfläche aufgebaut ist

Vier Zonen von oben nach unten, mehr zeigt der Kampfschirm nicht:

1. **Gegner** — Silhouette, HP-Balken, Haltungsbalken, nächster Zug
2. **Spielerleiste** — HP, Schild, Fate, Luck, Runde; darunter die Charms
   als Namen mit Anzahl
3. **Die Legung** — Vergangenheit, Gegenwart, Zukunft mit ihren Prozentwerten
4. **Vorschau, Protokoll, Hand** und `SCHICKSAL AUSFÜHREN`

Alles Weitere — Belohnung, Wegwahl, Händler, Ritual, Orakel, Ende — läuft über
ein Overlay.

**Bedienung**: Karte antippen, dann einen Platz antippen. Ein belegter Platz
gibt die Karte auf Tipp zurück auf die Hand.

**Charmtexte öffnen sich erst auf Tipp.** Im Kampf steht nur Name und Anzahl —
so bleibt der Kampfschirm sauber, während die Komplexität darunter wächst.

### Farben stehen nur im USS

`Tartot.uss` hält die Palette „Occult Clean": Schwarz und Elfenbein tragen
alles, Indigo und Ocker sind die einzigen Akzente. Im C#-Code steht **kein
einziger Farbwert** — Karten bekommen USS-Klassen (`karte--schwerter`,
`karte--gold`), nicht Farben.

Die Schimmer-Leiter verdunkelt die Kartenfläche schrittweise
(`Matt → Weiß → Indigo → Gold → Blut → Schwarz`). Damit ist die Verdunkelung
des eigenen Decks unmittelbar sichtbar, ohne dass eine Zahl es sagt.

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
| **Lokalisierung** | Texte liegen derzeit im Katalog-Code. Für Deutsch + Englisch gehören sie in Tabellen. |
