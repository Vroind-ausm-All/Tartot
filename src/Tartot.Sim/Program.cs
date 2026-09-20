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

        Console.WriteLine($"=== Tartot Balancing: {runs} Runs, Kampflimit {maxFights} ===\n");

        var pilot = new Autopilot { DeckTarget = deckTarget };
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
    }

    private static void Report(List<RunOutcome> outcomes, List<string> crashes, int runs, int maxFights)
    {
        Console.WriteLine($"Ohne Absturz durchgelaufen : {outcomes.Count}/{runs}");
        if (outcomes.Count == 0) return;

        var cleared = outcomes.Count(o => o.ReachedLimit);
        Console.WriteLine($"Kampflimit erreicht        : {cleared} ({100.0 * cleared / outcomes.Count:0.0} %)");
        Console.WriteLine($"Kaempfe im Schnitt         : {outcomes.Average(o => o.FightsCleared):0.0}  (max {outcomes.Max(o => o.FightsCleared)})");
        Console.WriteLine($"Zuege pro Kampf            : {outcomes.Average(o => (double)o.TurnsPlayed / Math.Max(1, o.FightsCleared)):0.0}");
        Console.WriteLine($"Deckgroesse am Ende        : {outcomes.Average(o => o.DeckSize):0.0}");
        Console.WriteLine($"Charm-Stacks am Ende       : {outcomes.Average(o => o.CharmStacks):0.0}");
        Console.WriteLine($"Deck-Resonanz am Ende      : {outcomes.Average(o => o.DeckResonance):0.0} von 10");
        Console.WriteLine($"Ungenutztes Gold           : {outcomes.Average(o => o.Gold):0}");
        Console.WriteLine($"Fate gesamt                : {outcomes.Average(o => o.Fate):0}");

        Console.WriteLine("\nRun endet nach Kampf:");
        var histogram = outcomes.GroupBy(o => o.FightsCleared).OrderBy(g => g.Key);
        foreach (var bucket in histogram)
            Console.WriteLine($"  Kampf {bucket.Key,2}: {new string('#', bucket.Count())} {bucket.Count()}");

        Console.WriteLine("\nWoran die Runs sterben:");
        var deaths = outcomes.Where(o => !o.ReachedLimit)
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
