using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;

/// <summary>
/// Balancing-Simulation: spielt komplette Runs ohne Spieler und misst.
///
///   dotnet run --project src/Tartot.Sim -- --runs=200 --fights=30
///
/// Ausgegeben wird, was man zum Tunen braucht: Wie weit kommt ein solider,
/// aber nicht genialer Spieler? Woran stirbt er? Wie gross wird das Deck?
/// </summary>
public static class Program
{
    public static void Main(string[] args)
    {
        var runs = ArgValue(args, "runs", 100);
        var maxFights = ArgValue(args, "fights", 30);
        var seedBase = ArgValue(args, "seed", 1000);
        var deckTarget = ArgValue(args, "deck", 14);
        var reversed = ArgValue(args, "reversed", 0) != 0;
        var allReadings = ArgValue(args, "readings", 0) != 0;
        var veil = ArgValue(args, "veil", 0);
        var spiral = ArgValue(args, "spiral", 0) != 0;
        var deuter = ArgString(args, "deuter", DeuterCatalog.DefaultId);
        var sweep = ArgValue(args, "veilsweep", 0) != 0;

        // Zustandsabzug fuer die Bildschirmdarstellung - kein Balancing-Lauf.
        foreach (var arg in args)
            if (arg.StartsWith("--snapshot=", StringComparison.Ordinal))
            {
                Snapshot.Write(arg.Substring("--snapshot=".Length));
                return;
            }

        if (ArgValue(args, "career", 0) != 0)
        {
            Career(runs, maxFights, seedBase);
            return;
        }

        if (sweep)
        {
            VeilSweep(runs, maxFights, seedBase, deckTarget, deuter);
            return;
        }

        Console.WriteLine($"=== Tartot Balancing: {runs} Runs, Kampflimit {maxFights}, Deuter {deuter}, Schleier {veil} ===\n");

        var pilot = new Autopilot
        {
            DeckTarget = deckTarget,
            ReverseStartingDeck = reversed,
            Setup = new RunSetup { DeuterId = deuter, Veil = veil },
            ContinueIntoSpiral = spiral
        };
        if (reversed) Console.WriteLine("Messreihe: Startdeck vollstaendig umgekehrt.\n");
        if (allReadings)
        {
            var meta = new MetaProgress();
            foreach (var card in GameCatalog.Cards)
                if (card.IsMajor)
                    for (var i = 0; i < 12; i++) meta.EncounterArcanum(card.Id);
            pilot.Meta = meta;
            Console.WriteLine("Messreihe: alle Lesarten freigeschaltet.\n");
        }
        var outcomes = new List<RunOutcome>();
        var crashes = new List<string>();

        for (var i = 0; i < runs; i++)
        {
            try
            {
                outcomes.Add(pilot.PlayRun(seedBase + i, maxFights));
            }
            catch (Exception ex)
            {
                var message = $"Seed {seedBase + i}: {ex.GetType().Name}: {ex.Message}";
                crashes.Add(message);
                Console.WriteLine("  [ABSTURZ] " + message);
            }
        }

        Report(outcomes, crashes, runs, maxFights);
        if (ArgValue(args, "detail", 0) != 0) FightTable(outcomes);
        if (ArgValue(args, "stats", 0) != 0) StatTable(outcomes);
    }

    /// <summary>Verteilung der Run-Statistik - zum Eichen der Prophezeiungs-Ziele.</summary>
    private static void StatTable(List<RunOutcome> outcomes)
    {
        Console.WriteLine("\nStatistik je Run        |  Schnitt |   p50 |   p90 |   max");
        var keys = outcomes[0].Stats.Keys.OrderBy(k => k, StringComparer.Ordinal);
        foreach (var key in keys)
        {
            var values = outcomes.Select(o => o.Stats.TryGetValue(key, out var v) ? v : 0).OrderBy(v => v).ToList();
            int P(double q) => values[Math.Min(values.Count - 1, (int)(q * values.Count))];
            Console.WriteLine($"{key,-24} | {values.Average(),8:0.0} | {P(.5),5} | {P(.9),5} | {values.Max(),5}");
        }
    }

    /// <summary>Die Kurve je Kampfindex: Zuege, HP davor und danach, Todesrate, Gold.</summary>
    private static void FightTable(List<RunOutcome> outcomes)
    {
        Console.WriteLine("\nKampf | Art    | erreicht | Zuege | HP davor | HP danach | Tod    | Gold");
        var all = outcomes.SelectMany(o => o.Fights).ToList();
        foreach (var group in all.GroupBy(f => f.Index).OrderBy(g => g.Key))
        {
            var list = group.ToList();
            var tier = list.GroupBy(f => f.Tier).OrderByDescending(g => g.Count()).First().Key;
            var survivors = list.Where(f => !f.Died).ToList();
            Console.WriteLine($"{group.Key,5} | {tier,-6} | {list.Count,8} | {list.Average(f => f.Turns),5:0.0} | {list.Average(f => f.HpBefore) * 100,7:0}% | {(survivors.Count > 0 ? survivors.Average(f => f.HpAfter) * 100 : 0),8:0}% | {100.0 * list.Count(f => f.Died) / list.Count,5:0.0}% | {list.Average(f => f.GoldAfter),4:0}");
        }
        Console.WriteLine("\nNach Gegnertyp (Zuege, Todesrate):");
        foreach (var group in all.GroupBy(f => f.EnemyId).OrderBy(g => g.Min(f => f.Index)))
            Console.WriteLine($"  {group.Key,-24} {group.Count(),5}x  {group.Average(f => f.Turns),4:0.0} Zuege  {100.0 * group.Count(f => f.Died) / group.Count(),5:0.0}% Tod");
    }

    private static void Report(List<RunOutcome> outcomes, List<string> crashes, int runs, int maxFights)
    {
        Console.WriteLine($"Ohne Absturz durchgelaufen : {outcomes.Count}/{runs}");
        if (outcomes.Count == 0) return;

        var won = outcomes.Count(o => o.Won);
        Console.WriteLine($"Siege (Finale geschlagen)  : {won} ({100.0 * won / outcomes.Count:0.0} %)");
        var cleared = outcomes.Count(o => o.ReachedLimit);
        Console.WriteLine($"Kampflimit erreicht        : {cleared} ({100.0 * cleared / outcomes.Count:0.0} %)");
        Console.WriteLine($"Kaempfe im Schnitt         : {outcomes.Average(o => o.FightsCleared):0.0}  (max {outcomes.Max(o => o.FightsCleared)})");
        Console.WriteLine($"Zuege pro Kampf            : {outcomes.Average(o => (double)o.TurnsPlayed / Math.Max(1, o.FightsCleared)):0.0}");
        Console.WriteLine($"Deckgroesse am Ende        : {outcomes.Average(o => o.DeckSize):0.0}");
        Console.WriteLine($"Charm-Stacks am Ende       : {outcomes.Average(o => o.CharmStacks):0.0}");
        Console.WriteLine($"Deck-Resonanz am Ende      : {outcomes.Average(o => o.DeckResonance):0.0} von 10");
        Console.WriteLine($"Ungenutztes Gold           : {outcomes.Average(o => o.Gold):0}");
        Console.WriteLine($"Vergessen beim Haendler    : {outcomes.Average(o => o.ShopRemovals):0.0} Karten pro Run");
        Console.WriteLine($"Fate gesamt                : {outcomes.Average(o => o.Fate):0}");
        Console.WriteLine($"Verdunkelung am Ende       : {outcomes.Average(o => o.Darkness):0}");
        Console.WriteLine($"DIE WELT gelegt            : {outcomes.Average(o => o.WorldSpreads):0.0} pro Run");
        Console.WriteLine($"Laengste Musterkette       : {outcomes.Average(o => o.LongestChain):0.0}");
        Console.WriteLine($"Haertester Treffer         : {outcomes.Average(o => o.BestHit):0}  (max {outcomes.Max(o => o.BestHit)})");
        Console.WriteLine($"Ereignisse / Rasten / Elites: {outcomes.Average(o => o.EventsSeen):0.0} / {outcomes.Average(o => o.RestsTaken):0.0} / {outcomes.Average(o => o.ElitesFought):0.0}");
        Console.WriteLine($"Haendler angeboten/besucht : {outcomes.Average(o => o.PathsWithShop):0.0} / {outcomes.Average(o => o.ShopVisits):0.0}");
        Console.WriteLine($"Pakte angenommen           : {outcomes.Average(o => o.PactsAccepted):0.00}");
        Console.WriteLine($"Karten an den Tod verloren : {outcomes.Average(o => o.CardsLostToDeath):0.00}");
        Console.WriteLine($"Dunkelster Schimmer        : {outcomes.Average(o => o.DarkestShimmer):0.0} (4 = Blut, 5 = Schwarz)");
        if (outcomes.Any(o => o.SpiralDepth > 0))
            Console.WriteLine($"Spiraltiefe (Sieger)       : {outcomes.Where(o => o.Won).Select(o => (double)o.SpiralDepth).DefaultIfEmpty(0).Average():0.0}  (max {outcomes.Max(o => o.SpiralDepth)})");

        Console.WriteLine("\nWo die Runs enden:");
        foreach (var act in Enumerable.Range(1, 5))
        {
            var ended = outcomes.Count(o => !o.Won && o.ActReached == act);
            if (ended == 0 && act != 4) continue;
            var label = act <= 3 ? $"Akt {act}" : act == 4 ? "Finale" : "Spirale";
            Console.WriteLine($"  {label,-8} {new string('#', ended * 60 / Math.Max(1, outcomes.Count))} {ended} ({100.0 * ended / outcomes.Count:0} %)");
        }
        Console.WriteLine($"  {"Sieg",-8} {new string('#', won * 60 / Math.Max(1, outcomes.Count))} {won} ({100.0 * won / outcomes.Count:0} %)");

        Console.WriteLine("\nRun endet nach Kampf:");
        var histogram = outcomes.GroupBy(o => o.FightsCleared).OrderBy(g => g.Key);
        foreach (var bucket in histogram)
            Console.WriteLine($"  Kampf {bucket.Key,2}: {new string('#', bucket.Count())} {bucket.Count()}");

        Console.WriteLine("\nWoran die Runs sterben:");
        var deaths = outcomes.Where(o => !o.ReachedLimit && !o.Won)
            .GroupBy(o => o.DiedAgainst)
            .OrderByDescending(g => g.Count());
        foreach (var death in deaths.Take(10))
            Console.WriteLine($"  {death.Key,-34} {death.Count(),3} ({100.0 * death.Count() / outcomes.Count:0} %)");

        if (crashes.Count > 0)
        {
            Console.WriteLine($"\n{crashes.Count} Abstuerze:");
            foreach (var crash in crashes.Distinct().Take(5)) Console.WriteLine("  " + crash);
        }
    }

    /// <summary>Siegquote und Todesort je Schleier - die Schwierigkeitskurve in einer Tabelle.</summary>
    private static void VeilSweep(int runs, int maxFights, int seedBase, int deckTarget, string deuter)
    {
        Console.WriteLine($"=== Schleier-Kurve: {runs} Runs je Stufe, Deuter {deuter} ===\n");
        Console.WriteLine("Schleier | Sieg   | Akt I  | Akt II | Akt III | Finale | Kaempfe");
        for (var veil = 0; veil <= VeilCatalog.MaxVeil; veil++)
        {
            var pilot = new Autopilot { DeckTarget = deckTarget, Setup = new RunSetup { DeuterId = deuter, Veil = veil } };
            var list = Enumerable.Range(0, runs).Select(i => pilot.PlayRun(seedBase + i, maxFights)).ToList();
            double Pct(Func<RunOutcome, bool> f) => 100.0 * list.Count(f) / list.Count;
            Console.WriteLine($"{veil,8} | {Pct(o => o.Won),5:0}% | {Pct(o => !o.Won && o.ActReached == 1),5:0}% | {Pct(o => !o.Won && o.ActReached == 2),5:0}% | {Pct(o => !o.Won && o.ActReached == 3),6:0}% | {Pct(o => !o.Won && o.ActReached == 4),5:0}% | {list.Average(o => o.FightsCleared),6:0.0}");
        }
    }

    /// <summary>
    /// Eine Spielerlaufbahn: ein Meta-Fortschritt ueber alle Runs, wie bei
    /// einem echten Spieler. Misst, ob Veteranen staerker werden (sollen sie
    /// kaum) und wann was freigeschaltet wird.
    /// </summary>
    private static void Career(int runs, int maxFights, int seedBase)
    {
        Console.WriteLine($"=== Laufbahn: {runs} Runs mit einem Meta-Fortschritt, immer Schleier 0 ===\n");
        var meta = new MetaProgress();
        var pilot = new Autopilot { Meta = meta };
        var buckets = new List<int>();
        var wins = 0;
        for (var i = 0; i < runs; i++)
        {
            var outcome = pilot.PlayRun(seedBase + i, maxFights);
            var report = meta.CompleteRun(pilot.LastGame, outcome.Won, outcome.DiedAgainst);
            if (outcome.Won) wins++;
            foreach (var unlocked in report.Unlocked)
                Console.WriteLine($"  Run {i + 1,4}: {unlocked}");
            if ((i + 1) % 50 == 0)
            {
                buckets.Add(wins);
                wins = 0;
            }
        }
        Console.WriteLine("\nSiegquote je 50 Runs der Laufbahn:");
        for (var b = 0; b < buckets.Count; b++)
            Console.WriteLine($"  Runs {b * 50 + 1,4}-{(b + 1) * 50,4}: {buckets[b] * 2,3} %");
        Console.WriteLine($"\nProphezeiungen erfuellt: {meta.CompletedProphecies.Count}/{ProphecyCatalog.All.Count}");
        Console.WriteLine($"Lesarten: {meta.InterpretationCount}");
    }

    private static string ArgString(string[] args, string name, string fallback)
    {
        var prefix = "--" + name + "=";
        foreach (var arg in args)
            if (arg.StartsWith(prefix, StringComparison.Ordinal)) return arg.Substring(prefix.Length);
        return fallback;
    }

    private static int ArgValue(string[] args, string name, int fallback)
    {
        var prefix = "--" + name + "=";
        foreach (var arg in args)
            if (arg.StartsWith(prefix, StringComparison.Ordinal)
                && int.TryParse(arg.Substring(prefix.Length), out var value))
                return value;
        return fallback;
    }
}
