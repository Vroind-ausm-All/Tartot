# Artdirection: Alter Cartoon-Horror, zwei Farben

## Leitsatz

**Nicht Detailreichtum ist Stärke, sondern Form + Kontrast + Wiederholung.**

Jede Karte wird über Silhouette, Symbol und ein bis zwei Akzentfarben
definiert, nicht über Illustration. Man erkennt eine Karte, bevor man den
Text liest. Das ist gleichzeitig die günstigste Produktion und der
stärkste eigene Stil.

## Palette „Occult Clean"

| Rolle | Wert | Verwendung |
|---|---|---|
| Schwarz | `#161616` | Flächen, Linien, Schatten |
| Tiefschwarz | `#0E0E10` | Bildschirmgrund im Kampf |
| Elfenbein | `#F2ECDD` | Schrift, Kontrast |
| Papier | `#E4DCC6` | Kartenfläche bei Tinte 0 |
| Indigo | `#2E3A67` | Akzent B — Kelche, Münzen |
| Indigo hell | `#4A5A96` | Akzent B, hell |
| Ocker | `#C89B3C` | Akzent A — Stäbe, UI-Rahmen, Schicksal |
| Ocker hell | `#E3BC63` | Akzent A, hell — Große Arkana |
| Blut | `#8E2B2B` | Schwerter, HP, Verderbnis |

Nur **zwei** Akzentfarben. Die vier Farben werden nicht über vier eigene
Farben unterschieden — das würde das Zweifarbensystem sofort zerstören —
sondern über **Farbverteilung und Formensprache**:

| Farbe | Dominanz | Formensprache | Animation |
|---|---|---|---|
| ⚔ **Schwerter** | 70 % Schwarz/Weiß, 20 % Blut, 10 % Ocker | Spitze Formen, Diagonalen, viel Negativraum, harte Schatten | Schnitte, Zähne, Klingen, Augen |
| ✸ **Stäbe** | 70 % Schwarz/Weiß, 20 % Ocker, 10 % Indigo | Vertikalen, Funken, organische Bewegungslinien | Flammen, explodierende Cartoon-Sterne |
| ♥ **Kelche** | 70 % Schwarz/Weiß, 20 % Indigo hell, 10 % Ocker | Runde Formen, Wellen, Tropfen, ruhige Komposition | Flüssigkeit fließt nach oben, Augen schwimmen im Kelch |
| ◆ **Münzen** | 70 % Schwarz/Weiß, 20 % Indigo, 10 % Ocker | Kreise, Fünfecke, Gitter, Symmetrie, dicke Linien | Münzen werden zu Augen, Mauern, kreisenden Siegeln |

`ui/thema.gd` hält diese Werte als einzige Quelle; kein Farbwert steht
irgendwo sonst im Code.

## Kartenlayout

```
┌──────────────┐
│     VII      │   ← Zahl/Rang, klein, in Akzentfarbe
│              │
│      ⚔       │   ← das dominante Symbol, ~38 % der Kartenbreite
│              │
│  9 SCHADEN   │   ← Effekttext, klein, sekundär
│  3 Blutung   │
├──────────────┤
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓│   ← Tintestreifen: Schwarz → Blutrot
└──────────────┘
```

Regeln:
1. Nur **eine** starke Akzentfarbe pro Bildschirmelement
2. Keine Verläufe, keine weichen Effekte — Flat-Flächen, maximal zwei
   Schattenstufen
3. Rahmen sehr reduziert
4. Symbole immer größer als Nebendekor
5. Lieber Fläche als Ornament

## Aufrecht und umgekehrt sichtbar machen

Der Spieler muss die Orientierung in **unter einer Sekunde** erkennen.

| Aufrecht | Umgekehrt |
|---|---|
| Saubere Komposition, heller Kartenkopf | Kartenfläche zieht 22 % nach Indigo |
| Symbol aufrecht | **Symbol um 180° gedreht** |
| Dünner, klarer Rahmen | Akzentfarbe stärker, Bruchmotive |

Wichtig: Umgekehrt wird nie durchgestrichen oder abgewertet dargestellt. Es
ist eine andere Karte, keine schlechtere.

## Verdunkelung als sichtbare Mechanik

Die Tinte-Stufe 0–5 färbt die Kartenfläche linear von Papier `#E4DCC6` nach
Schwarz `#161616` (82 % Interpolation bei Stufe 5). Ab Stufe 3 kippt die
Schrift von Schwarz auf Elfenbein.

**Das ist der wichtigste visuelle Effekt des Spiels.** Nach 20 Räumen hält
der Spieler ein sichtbar anderes Deck in der Hand, ohne dass ihm eine Zahl
das gesagt hätte. Parallel dunkelt der Bildschirmgrund ab, das Filmkorn wird
kräftiger, und der Raum hinter dem Gegner verliert Kontrast.

## Große Arkana sehen anders aus

Kleine Arkana sind **systemisch und funktional lesbar**. Große Arkana sind
**ikonisch und autonom, fast wie Titelkarten**:

- mehr Schwarz/Weiß-Anteil, weniger Farblogik
- **eine** zentrale Figur oder Komposition, große ruhige Flächen
- deutlich „heroischer" als das Raster der Kleinen Arkana

| Arkanum | Bildidee |
|---|---|
| Der Narr | Figur am Rand einer Klippe, großer leerer Himmel, ein Kreis hinter dem Kopf, ein Akzent in Gold |
| Der Mond | Riesiger Mond, zwei Wölfe, schwarzes Wasser, kaum Details |
| Der Turm | Schwarzer Turm, **ein** Blitz in Akzentfarbe, brechende Silhouette |
| Die Sonne | Große Scheibe, frontal, offen, kaum Hintergrund |
| Die Welt | Kreisförmige Komposition, beide Akzentfarben in Balance |

## Große Arkana im Kampf

Sie fühlen sich beim Ausspielen **nicht wie normale Karten** an, sondern wie
eine kurze Unterbrechung der Regeln. Jeweils ~2 Sekunden:

- **Der Tod** — Bildschirm wird fast schwarz. Ein weißes Gesicht erscheint.
  Ein roter Schnitt zieht sich durch den Bildschirm. Dann: „Wähle eine Karte
  zum Vernichten."
- **Der Turm** — Der Screen zittert. Hinter dem Gegner wächst ein Turm hoch.
  Ein Blitz. Alle Schilde zerbrechen.
- **Das Rad** — Die drei Positionen drehen sich physisch umeinander.

Dadurch fühlen sie sich mächtig an, obwohl die Grafik sehr simpel bleibt.

## Animation

**Rubber-Hose-Cartoon, kein realistischer Horror.** Übertriebene Gesichter,
zitternde Konturen, Filmkorn, sehr kurze groteske Reaktionen.

Der ganze Zug dauert **3–4 Sekunden, nicht länger**:

1. Die Münze klappt auf wie ein Auge → schwarzer Schild entsteht
2. Das Schwert schießt aus der Karte → der Gegner wird getroffen
3. Der Magier verschwindet lachend in seinem eigenen Hut → seine Kopie
   erscheint als Schatten für den nächsten Zug

Gegner sind große stilisierte Cartoon-Silhouetten mit wenigen Animationen:
Augen bewegen sich, der Mund verzieht sich, Schatten zittern, Blut tropft,
Gliedmaßen reagieren auf Treffer. Keine 3D-Szene.

## Horror-Regel

**Nicht realistisch und blutig, sondern surreal, falsch und unheimlich.**

Grinsende Monde. Augen in Kelchen. Münzen mit Zähnen. Schwerter, die selbst
schreien. Figuren, deren Schatten etwas anderes tun als sie selbst. Ein
Hutmann, unter dessen Hut noch ein Hut ist. Eine Orgel, deren Pfeifen Finger
sind. Ein Lächeln ohne Gesicht, das breiter wird, je länger der Kampf
dauert.

Die Gegnerbeschreibungen in `data/gegner.json` sind bereits in diesem Ton
geschrieben und dienen als Briefing für die Illustration.

## Produktionsaufwand

| Posten | Menge | Hinweis |
|---|---|---|
| Suit-Symbole | 4 | Silhouetten, je 2–3 Zustände |
| Zahlenkarten | 40 | Rahmen + Symbol, Zahl aus Schrift — **keine Einzelillustration** |
| Hofkarten | 16 | vereinfachte Figuren |
| Große Arkana | 22 | die eigentliche Kunstarbeit, je ein Poster |
| Gegner | 24 | Silhouette + 4–6 Animationszustände |
| Charm-Symbole | 50 | einfarbige Piktogramme, 64×64 |
| Item-Symbole | 22 | dito |
| UI | — | fast vollständig aus Flächen und Schrift |

Der überwiegende Teil des Spiels besteht aus Flächen, Rahmen und Schrift.
Die Kunst konzentriert sich auf 22 Arkana-Poster und 24 Gegner-Silhouetten —
das ist ein Umfang, den eine Person stemmen kann.
