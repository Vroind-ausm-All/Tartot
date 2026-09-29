using System.Linq;
using Godot;
using Tartot.Core;
using Tartot.Core.Simulation;
using GArray = Godot.Collections.Array;
using GDict = Godot.Collections.Dictionary;

/// <summary>
/// Die Bruecke zwischen Godot und dem Regelkern. Als Autoload "Kern"
/// eingetragen; GDScript ruft sie wie jeden anderen Knoten auf
/// (Kern.Legen(id, 0), Kern.Ausfuehren() ...).
///
/// Hier stehen keine Regeln. Alles, was gerechnet wird, rechnet derselbe
/// Kern wie in Unity, in den Tests und in der Simulation - die Quellen sind
/// ueber die csproj verlinkt, nicht kopiert. Die Bruecke uebersetzt nur:
/// Zustand hinaus als Dictionary, Absichten hinein als Methodenaufruf.
///
/// Plaetze sind Zahlen: 0 Vergangenheit, 1 Gegenwart, 2 Zukunft.
/// </summary>
public partial class TartotKern : Node
{
    private GameController _spiel;
    private readonly Autopilot _autopilot = new Autopilot();

    public bool Laeuft => _spiel != null;

    /// <summary>Neuer Run mit Seed. Danach steht der erste Kampf bereit.</summary>
    public void NeuerRun(long saat)
    {
        _spiel = new GameController(saat);
    }

    public string Phase() => _spiel?.Phase.ToString() ?? "";

    public string Nachricht() => _spiel?.Message ?? "";

    // ------------------------------------------------------------ Zustand
    /// <summary>Alles, was der Kampftisch zeigen muss.</summary>
    public GDict Kampf()
    {
        var k = _spiel?.Combat;
        if (k == null) return new GDict();
        var run = _spiel.Run;
        var g = k.Enemy;

        var hand = new GArray();
        foreach (var karte in k.Hand) hand.Add(KarteNach(karte, k));

        var plaetze = new GDict();
        foreach (var kv in k.Slots) plaetze[(int)kv.Key] = KarteNach(kv.Value, k);

        return new GDict
        {
            ["akt"] = run.Act,
            ["kampf"] = run.FightIndex + 1,
            ["zug"] = k.Turn,
            ["gegner"] = new GDict
            {
                ["id"] = g.Definition.Id,
                ["sprite"] = AnimationCues.SpriteId(g.Definition),
                ["name"] = g.Definition.Name,
                ["lp"] = g.Hp,
                ["max_lp"] = g.Definition.MaxHp,
                ["haltung"] = g.Stance,
                ["max_haltung"] = g.Definition.MaxStance,
                ["siegel"] = g.Sigils,
                ["schild"] = g.Shield,
                ["brand"] = g.Burn,
                ["absicht"] = g.IntentHidden ? "Verborgen" : g.Intent.ToString(),
                ["absicht_wert"] = g.IntentHidden ? 0 : g.IntentValue,
                ["boss"] = g.Definition.IsBoss,
                ["phase"] = g.Phase,
            },
            ["spieler"] = new GDict
            {
                ["lp"] = run.Hp,
                ["max_lp"] = run.MaxHp,
                ["schild"] = k.PlayerShield,
                ["glueck"] = k.TemporaryLuck,
                ["gold"] = run.Gold,
            },
            ["hand"] = hand,
            ["plaetze"] = plaetze,
            ["gesperrt"] = k.BlockedSlot.HasValue ? (int)k.BlockedSlot.Value : -1,
            ["stapel"] = k.DrawPile.Count,
            // Wie oft die Ablage schon zurueck in den Stapel gemischt wurde.
            ["mischungen"] = k.Reshuffles,
            ["ablage"] = k.DiscardPile.Count,
        };
    }

    private static GDict KarteNach(CardInstance karte, CombatState k) => new GDict
    {
        ["instanz"] = karte.InstanceId,
        ["id"] = karte.Definition.Id,
        ["edition"] = karte.Edition == CardEdition.None ? "" : karte.Edition.ToString(),
        ["umgekehrt"] = karte.Orientation == Tartot.Core.Orientation.Reversed,
        ["stufe"] = karte.Level,
        ["verschleiert"] = k.VeiledCards.Contains(karte.InstanceId),
    };

    // ------------------------------------------------------------ Legen
    public bool Legen(string instanz, int platz)
    {
        if (_spiel?.Combat == null) return false;
        // Liegt auf dem Platz schon etwas, geht es erst zurueck auf die Hand.
        _spiel.CombatSystem.ReturnSlotToHand(_spiel.Combat, (SlotPosition)platz);
        // Liegt die Karte auf einem anderen Platz, wandert sie.
        foreach (var kv in _spiel.Combat.Slots.ToList())
            if (kv.Value.InstanceId == instanz)
                _spiel.CombatSystem.ReturnSlotToHand(_spiel.Combat, kv.Key);
        return _spiel.CombatSystem.PlaceCard(_spiel.Combat, instanz, (SlotPosition)platz);
    }

    public bool Zuruecknehmen(int platz) =>
        _spiel?.Combat != null && _spiel.CombatSystem.ReturnSlotToHand(_spiel.Combat, (SlotPosition)platz);

    /// <summary>Alle Plaetze leeren (die Karten gehen auf die Hand).</summary>
    public void Abraeumen()
    {
        if (_spiel?.Combat == null) return;
        foreach (var platz in _spiel.Combat.Slots.Keys.ToList())
            _spiel.CombatSystem.ReturnSlotToHand(_spiel.Combat, platz);
    }

    /// <summary>Die beste Legung laut Autopilot: [{instanz, platz}, ...]. Veraendert nichts.</summary>
    public GArray Vorschlag()
    {
        var liste = new GArray();
        if (_spiel?.Combat == null) return liste;
        foreach (var (instanz, platz) in _autopilot.SuggestLayout(_spiel))
            liste.Add(new GDict { ["instanz"] = instanz, ["platz"] = (int)platz });
        return liste;
    }

    // ------------------------------------------------------------ Wertung
    /// <summary>Was die aktuelle Legung ergaebe - ohne Nebenwirkung.</summary>
    public GDict Vorschau()
    {
        if (_spiel?.Combat == null) return new GDict();
        return WertungNach(_spiel.CombatSystem.PreviewScore(_spiel.Run, _spiel.Combat));
    }

    private static GDict WertungNach(ScoreBreakdown w)
    {
        var schritte = new GArray();
        foreach (var s in w.Steps)
            schritte.Add(new GDict
            {
                ["id"] = s.InstanceId,
                ["label"] = s.Label,
                ["chips"] = s.Chips,
                ["mult"] = s.MultAdd,
                ["xmult"] = s.MultX,
            });
        var hinweise = new GArray();
        foreach (var h in w.Hints) hinweise.Add(h);
        return new GDict
        {
            ["chips"] = w.Chips,
            ["mult"] = w.Multiplier,
            ["schicksal"] = w.FateDamage,
            ["muster"] = w.ComboName ?? "",
            ["treffer"] = w.ExpectedHit,
            ["toedlich"] = w.Lethal,
            ["haltung_bricht"] = w.BreaksStance,
            ["welt"] = w.IsWorld,
            ["kette"] = w.Chain,
            ["schritte"] = schritte,
            ["hinweise"] = hinweise,
        };
    }

    /// <summary>
    /// Fuehrt den Zug aus. Liefert die Wertungsschritte fuer die Kaskade und
    /// was danach geschah: Schaden, Sieg, Niederlage, zersprungene Karten.
    /// </summary>
    public GDict Ausfuehren()
    {
        if (_spiel?.Combat == null || _spiel.Phase != GamePhase.Combat) return new GDict();
        var vorher = _spiel.Run.Deck.Select(c => c.InstanceId).ToHashSet();
        var gelegt = _spiel.Combat.Slots.Values.Select(c => c.InstanceId).ToList();
        var lpVorher = _spiel.Run.Hp;
        var gegner = _spiel.Combat.Enemy;
        var absicht = gegner.Intent;
        var zugNummer = _spiel.Combat.Turn;

        var zug = _spiel.ResolveTurn();
        if (zug == null) return new GDict();

        var weg = new GArray();
        foreach (var id in gelegt)
            if (vorher.Contains(id) && _spiel.Run.Deck.All(c => c.InstanceId != id)) weg.Add(id);

        var log = new GArray();
        foreach (var zeile in zug.Log) log.Add(zeile);

        // "schicksal" ist der Wert der Legung (die Kaskade zaehlt ihn hoch),
        // "angekommen" das, was nach Haltung und Schild beim Gegner landet.
        var ergebnis = WertungNach(zug.Score);
        ergebnis["angekommen"] = zug.FateDamage;
        ergebnis["gegner_angriff"] = zug.EnemyDamage;
        ergebnis["heilung"] = zug.Healing;
        ergebnis["schild"] = zug.ShieldGained;
        ergebnis["lp_verlust"] = System.Math.Max(0, lpVorher - _spiel.Run.Hp);
        ergebnis["haltung_gebrochen"] = zug.StanceBroken;
        ergebnis["phase_wechsel"] = zug.PhaseChanged;
        ergebnis["sieg"] = zug.Victory;
        ergebnis["niederlage"] = zug.Defeat;
        ergebnis["ueberschuss"] = zug.Overkill;
        ergebnis["rekord"] = zug.NewBestHit;
        ergebnis["zersprungen"] = weg;
        ergebnis["log"] = log;
        var bilder = new GArray();
        foreach (var b in AnimationCues.ForTurn(zug, gegner, absicht, zugNummer)) bilder.Add(b);
        ergebnis["animationen"] = bilder;
        // Die Absicht, die der Gegner in diesem Zug ausgefuehrt hat - danach klingt der Angriff.
        ergebnis["angriff"] = absicht.ToString();
        ergebnis["boss"] = gegner.Definition.IsBoss;
        return ergebnis;
    }

    /// <summary>
    /// Gibt einer Karte im Deck eine Edition - wie es eine Belohnung taete.
    /// Fuer Vorfuehrungen und zum Ausprobieren der Editionen.
    /// </summary>
    public bool EditionGeben(string instanz, string edition)
    {
        var karte = _spiel?.Run.Deck.FirstOrDefault(c => c.InstanceId == instanz);
        if (karte == null || !System.Enum.TryParse(edition, out CardEdition e)) return false;
        karte.Edition = e;
        return true;
    }

    /// <summary>Instanz-Ids aller Karten im Deck.</summary>
    public GArray Deck()
    {
        var liste = new GArray();
        if (_spiel == null) return liste;
        foreach (var c in _spiel.Run.Deck)
            liste.Add(new GDict { ["instanz"] = c.InstanceId, ["id"] = c.Definition.Id });
        return liste;
    }

    /// <summary>
    /// Nach einem Sieg: Belohnung, Weg, Laden ... bis zum naechsten Kampf.
    /// Diese Phasen haben im Kartentisch noch keine eigene Oberflaeche, also
    /// entscheidet der Autopilot. Gibt false zurueck, wenn der Run vorbei ist.
    /// </summary>
    public bool Weiter()
    {
        if (_spiel == null) return false;
        var schutz = 0;
        while (_spiel.Phase != GamePhase.Combat && _spiel.Phase != GamePhase.GameOver && schutz++ < 200)
            _autopilot.Step(_spiel);
        return _spiel.Phase == GamePhase.Combat;
    }
}
