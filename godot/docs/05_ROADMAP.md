# Roadmap

Der Regelkern steht und ist gemessen. Was fehlt, ist überwiegend Kunst,
Gefühl und Ladenarbeit — nicht Mechanik.

## M1 — Spielbarer Vertikalschnitt *(erreicht)*

- [x] Legung mit drei Positionen, Echo, Muster, Schicksalsfäden
- [x] 56 Kleine Arkana, 22 Große Arkana in drei Gesichtern
- [x] 50 Charms, 22 Items, 24 Gegner, 7 Bosse, 6 Deuter
- [x] Run mit Schicksalskarten-Wegwahl, Händler, Ritual, Beute
- [x] Verderbnis als sichtbare und spürbare Achse
- [x] Endlosmodus mit stapelnden verderbten Arkana
- [x] Speichern/Laden mitten im Run
- [x] 176 Tests, Balancing-Simulation, Screenshot-Werkzeug
- [x] Spielbare Hochformat-UI

## M2 — Es fühlt sich wie ein Spiel an

- [ ] Restliche Großen-Arkana-Spezialeffekte verdrahten (~20 % offen:
      *Mäßigkeit*, *Die Liebenden*, *Das Gericht* umgekehrt)
- [ ] Kartenanimationen: Legen, Auslösen, Treffer — der ganze Zug in 3–4 s
- [ ] Große Arkana als 2-Sekunden-Unterbrechung inszenieren
- [ ] Gegner-Silhouetten mit Augen-, Mund- und Trefferreaktion
- [ ] Bildschirmzittern, Filmkorn, Verdunkelung bei steigender Verderbnis
- [ ] Ton: kurze trockene Effekte, kein Soundtrack im Kampf
- [ ] Haptik auf Treffer und Musterauslösung

## M3 — Inhalt und Tiefe

- [ ] Interpretationen wirksam machen: freigeschaltete Lesarten ändern
      Arkana-Effekte in künftigen Runs
- [ ] Totenkarten tauchen in späteren Runs auf
- [ ] Die restlichen 3 Deuter freischaltbar und balanciert
- [ ] Schleier 0–8 (Schwierigkeitsstufen)
- [ ] Tageskarte mit Bestenliste
- [ ] Sammlung: 78 Karten, Kunst wird freigeschaltet
- [ ] Ereignis-Zwischensequenzen für „Unbekannt" ausformulieren (aktuell
      nur Gold oder Schaden)

## M4 — Veröffentlichung

- [ ] Kunst: 22 Arkana-Poster, 24 Gegner, 50 Charm-Symbole, 22 Item-Symbole
- [ ] Lokalisierung Deutsch + Englisch (Texte liegen bereits in `data/`)
- [ ] Tutorial: die drei Positionen in 60 Sekunden erklären, ohne Text
- [ ] Android-AAB, iOS-Build über Xcode, Store-Einträge
- [ ] Datenschutz: kein Tracking, entsprechend ausgefüllte Formulare
- [ ] Altersfreigabe (IARC, realistisch USK 12 / PEGI 12)
- [ ] Kostenlose Version mit Abschnitt I als Konversionspfad
- [ ] Cloud-Speicher (Play Games Services, iCloud) — Format ist vorbereitet

## Die größten Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| **Der erste Boss killt 35 % der Runs** | siehe `04_BALANCING.md`; Abschnitt 1 auf 12 Räume kürzen und erneut messen |
| **Premium-Mobile ist ein harter Markt** | Wiedererkennbarkeit im Screenshot ist die eigentliche Marketingarbeit; kostenlose Version als Einstieg |
| **Die Positionsregel ist neu und muss sitzen** | Tutorial ohne Text; die ersten drei Kämpfe müssen sie lehren, nicht erklären |
| **Kunstumfang** | Das System braucht Silhouetten, keine Illustrationen. 22 Poster + 24 Gegner sind der harte Kern, alles andere ist Fläche und Schrift |
| **Apple verlangt macOS zum Bauen** | Einziger Hardware-Zwang; Mac-Mini oder gemieteter CI-Runner |
