# Charaktere

Figurenblätter für Karten, die als Charakter auftreten. Sie sind die Vorlage für
Kartenmotive, spätere Animationen und Bühnenauftritte. Erzeugt mit Higgsfield
(GPT Image 2.6, Qualität hoch), mit dem Motiv des Magiers
(`godot-next/addons/tartot_karten/kunst/motive/major_1.png`) und dem Boss-Blatt
`assets/bossblaetter/magier.jpg` als Stilreferenz.

## 0 · Der Narr

| | |
|---|---|
| Karte | `major_0`, große Arkana, **legendär** (Gold) |
| Rang | spielt mit Rang 1 (Chips), Kraft 4 |
| Figur | schlaksiger Hofnarr im Gummischlauch-Stil der 1930er: zweizipflige Kappe rot/indigo mit Goldschellen, Rautenwams, Halskrause, weiße Handschuhe, Schnabelschuhe, Bündel am Stock, weiße Rose; dazu ein struppiger Hund mit Ringelschwanz |
| Motiv | tritt mit geschlossenen Augen über die Klippe, goldene Scheibe hinter dem Kopf, leerer Himmel mit grinsender Sonne |

**Fähigkeit – Die Reise des Narren.** Der Narr ist die 0 und die Reise zur 21.
In einer Legung mit anderen Karten zählt er als **1 bis 4**, wenn er damit die
Summe 21 schließt und **DIE WELT** ruft. Sonst zählt er 1. Seine Chips bleiben
Rang 1. Liegt er auf der Hand, zeigt die Vorschau „Der Narr vollendet DIE WELT
(21)“, wenn zwei gelegte Karten 17 bis 20 ergeben.

Dazu wie bisher: Er zieht Karten nach (aufrecht 2, umgekehrt 3 und +1 Luck).

Regler: `CombatSystem.FoolMaxStep` (C#) und `FOOL_MAX_STEP` (GDScript). Gemessen
mit `dotnet run --project src/Tartot.Sim -c Release -- --runs=400 --stats=1`:

| Sprungweite | Siege |
|---|---|
| ohne (vorher) | 31,3 % |
| 4 (gewählt) | 34,5 % |
| 7 | 37,8 % |
| 14 | 39,8 % |

## Dateien

| Datei | Inhalt |
|---|---|
| `narr_charakterblatt.jpg` | Drehung (vorn, drei Viertel, Seite, hinten), sechs Gesichter, vier Posen |
| `narr_motiv_gross.png` | Kartenmotiv 480 × 600, Quelle für `kunst/motive/major_0.png` |
| `narr_karte_im_spiel.png` | die fertige Karte im Godot-Kartentisch (`tests/karten_galerie.tscn`) |

Die Motive im Spiel (`godot-next/` und `godot-karten/`, je
`addons/tartot_karten/kunst/motive/major_0.png`) sind daraus auf 344 × 416
eingepasst.
