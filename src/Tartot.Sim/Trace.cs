using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using Tartot.Core;
using Tartot.Core.Simulation;

/// <summary>
/// Spur eines Autopilot-Runs fuer den Paritaetsbeweis gegen den Godot-Port.
///
///   dotnet run --project src/Tartot.Sim -- --trace=7 --deuter=eremit --veil=3 --spiral=1
///
/// Eine Zeile je Kampfzug ("T") und je Schritt ausserhalb des Kampfes ("S").
/// godot-next/tools/trace.gd schreibt dasselbe Format; tools/paritaet.sh
/// vergleicht beide Zeile fuer Zeile. Nur ganze Zahlen und Texte - floats
/// stehen als Bitmuster darin, damit keine Formatierung luegen kann.
/// </summary>
public static class Trace
{
    /// <param name="career">Mehr als 0: so viele Runs hintereinander mit einem gemeinsamen Meta-Fortschritt.</param>
    /// <param name="roundtrip">Nach jeder Zeile speichern und neu laden - prueft Restore in beiden Kernen.</param>
    public static void Write(long seed, int maxFights, RunSetup setup, bool spiral, int career = 0, bool roundtrip = false)
    {
        // Das Spiel ist deutsch: Kommazahlen in Texten wie auf einem deutschen Geraet.
        CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("de-DE");
        var output = new StringBuilder();
        if (career <= 0)
        {
            PlayTraced(seed, maxFights, setup, spiral, null, roundtrip, output);
        }
        else
        {
            var meta = new MetaProgress();
            for (var i = 0; i < career; i++)
            {
                var game = PlayTraced(seed + i, maxFights, setup, spiral, meta, roundtrip, output);
                var won = game.Run.Won;
                var killedBy = !won && game.Phase == GamePhase.GameOver ? game.Combat?.Enemy?.Definition?.Name ?? "-" : "-";
                var report = meta.CompleteRun(game, won, killedBy);
                output.Append(ReportLine(report)).Append('\n');
                output.Append("M ").Append(meta.Serialize()).Append('\n');
            }
        }
        Console.Out.Write(output.ToString());
    }

    private static GameController PlayTraced(long seed, int maxFights, RunSetup setup, bool spiral,
        MetaProgress meta, bool roundtrip, StringBuilder output)
    {
        var pilot = new Autopilot { Setup = setup, ContinueIntoSpiral = spiral, Meta = meta };
        var game = new GameController(seed, meta, setup);
        output.Append(StepLine(game, "start")).Append('\n');

        var guard = 0;
        while (game.Phase != GamePhase.GameOver && game.Run.FightIndex < maxFights && guard++ < 5000)
        {
            if (game.Phase == GamePhase.Combat)
            {
                // Wie Autopilot.PlayCombat, aber mit einer Zeile je Zug.
                var turns = 0;
                while (game.Phase == GamePhase.Combat && turns < pilot.MaxTurnsPerFight)
                {
                    turns++;
                    if (!pilot.Arrange(game)) break;
                    var layout = Layout(game);
                    var result = game.ResolveTurn();
                    output.Append(TurnLine(game, result, layout)).Append('\n');
                    if (roundtrip) game = RoundTrip(game);
                }
                output.Append(StepLine(game, "combat")).Append('\n');
                continue;
            }

            var before = game.Phase;
            pilot.Step(game);
            output.Append(StepLine(game, PhaseName(before))).Append('\n');
            if (roundtrip) game = RoundTrip(game);
        }

        output.Append($"E won={B(game.Run.Won)} fi={game.Run.FightIndex} fate={game.Run.FateScoreTotal} " +
                      $"stats={Counts(game.Run.Stats.ToDictionary())} combo={game.Run.Stats.BestHitCombo}\n");
        // Ein Speicherstand am Ende: das Format muss in beiden Kernen gleich sein.
        output.Append("J ").Append(game.Save()).Append('\n');
        return game;
    }

    private static GameController RoundTrip(GameController game) =>
        GameController.Restore(SaveSystem.Deserialize(game.Save()));

    private static string ReportLine(RunReport r) =>
        $"R won={B(r.Won)} head={r.Headline} fights={r.FightsCleared} act={r.Act} spiral={r.SpiralDepth} fate={r.FateTotal} " +
        $"best={r.BestHit} combo={r.BestHitCombo} by={r.KilledBy} dark={r.Darkness} " +
        $"records={string.Join(" ; ", r.Records)} unlocked={string.Join(" ; ", r.Unlocked)} " +
        $"near={string.Join(" ; ", r.NearMisses.Select(n => $"{n.Title}|{n.Detail}|{n.Reward}|{Bits(n.Progress)}"))}";

    private static string PhaseName(GamePhase phase) => phase.ToString();

    private static string B(bool b) => b ? "1" : "0";

    private static string Bits(float f) =>
        BitConverter.ToInt32(BitConverter.GetBytes(f), 0).ToString(CultureInfo.InvariantCulture);

    private static string Card(CardInstance c) =>
        $"{c.Definition.Id}:{c.Level}:{(int)c.Shimmer}:{(int)c.Orientation}:{(int)c.Edition}:{c.Experience}:{c.VictoryMarks}:{c.Rage}{(c.IsCopy ? ":c" : "")}";

    private static string Cards(IEnumerable<CardInstance> cards) => string.Join(",", cards.Select(Card));

    private static string Counts(IReadOnlyDictionary<string, int> d) =>
        string.Join(",", d.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => $"{p.Key}={p.Value}"));

    private static string Clean(string s) => (s ?? string.Empty).Replace("\n", " | ");

    private static string Rng(GameController game) =>
        $"{game.WorldRandomSnapshot.DrawCount}/{game.CombatRandomSnapshot.DrawCount}/{game.ProgressionRandomSnapshot.DrawCount}";

    private static string Layout(GameController game) =>
        string.Join(",", new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future }
            .Where(s => game.Combat.Slots.ContainsKey(s))
            .Select(s => $"{(int)s}={game.Combat.Slots[s].Definition.Id}"));

    private static string TurnLine(GameController game, TurnResult r, string layout)
    {
        var c = game.Combat;
        var e = c.Enemy;
        var s = r?.Score;
        var sb = new StringBuilder("T");
        sb.Append($" fi={game.Run.FightIndex} turn={c.Turn} lay={layout}");
        if (s != null)
            sb.Append($" chips={s.Chips} mult={Bits(s.Multiplier)} fd={s.FateDamage} exp={s.ExpectedHit} combo={s.ComboName} rep={Bits(s.RepeatPenalty)} chain={s.Chain}");
        if (r != null)
            sb.Append($" dmg={r.FateDamage} edmg={r.EnemyDamage} heal={r.Healing} sg={r.ShieldGained} br={B(r.StanceBroken)} v={B(r.Victory)} d={B(r.Defeat)} ok={r.Overkill} lost={r.CardLost} nova={B(r.Supernova)} refl={r.Reflected} shat={string.Join(",", r.Shattered)}");
        sb.Append($" e={e.Definition.Id} ehp={e.Hp} est={e.Stance} sig={e.Sigils} esh={e.Shield} burn={e.Burn} ramp={e.AttackRamp} int={(int)e.Intent}:{e.IntentValue}:{B(e.IntentHidden)} eph={e.Phase}");
        sb.Append($" hp={game.Run.Hp}/{game.Run.MaxHp} sh={c.PlayerShield} luck={c.TemporaryLuck} chainc={c.PatternChain} sig={c.LastComboSignature} reps={c.SameComboRepeats}");
        sb.Append($" blk={(c.BlockedSlot.HasValue ? ((int)c.BlockedSlot.Value).ToString() : "-")} acol={c.Acolytes} suns={c.Suns} mark={B(!string.IsNullOrEmpty(c.MarkedCardId))}:{c.MarkTurnsLeft} pact={B(c.PactPending)}:{c.PactsOffered}:{Bits(c.FateBonus)}:{Bits(c.EnemyAttackBonus)}");
        sb.Append($" hand={string.Join(",", c.Hand.Select(x => x.Definition.Id))} veil={c.Hand.Count(x => c.VeiledCards.Contains(x.InstanceId))}");
        sb.Append($" draw={c.DrawPile.Count} disc={c.DiscardPile.Count} rng={Rng(game)}");
        if (r != null) sb.Append(" log=").Append(Clean(string.Join(" / ", r.Log)));
        return sb.ToString();
    }

    private static string StepLine(GameController game, string what)
    {
        var run = game.Run;
        var sb = new StringBuilder("S ");
        sb.Append(what);
        sb.Append($" phase={(int)game.Phase} fi={run.FightIndex} act={run.Act} hp={run.Hp}/{run.MaxHp} gold={run.Gold} fate={run.Fate} total={run.FateScoreTotal}");
        sb.Append($" luck={run.Luck} dark={run.Darkness} res={run.DeckResonance} veil={run.Veil} bonus={run.BonusRewardChoices} free={B(run.FreeNextShopPurchase)} rev={run.ReviveCharges} ssb={run.StartShieldBuff}");
        sb.Append($" proph={run.Prophecy} rem={run.ShopRemovals} ref={run.ShopRefines} pend={run.PendingEnemyId} elite={B(run.NextFightElite)} last={(int)run.LastPath} ss={run.StepsSinceShop} sr={run.StepsSinceRest}");
        sb.Append($" bosses={string.Join(",", run.ActBosses)} def={string.Join(",", run.DefeatedBosses)} seen={string.Join(",", run.SeenEnemies)} ev={string.Join(",", run.SeenEvents)}");
        sb.Append($" flags={string.Join(",", run.StoryFlags.OrderBy(f => f, StringComparer.Ordinal))} new={string.Join(",", run.NewStoryFlags)}");
        sb.Append($" charms={Counts(run.Charms)} items={Counts(run.Items)}");
        sb.Append($" deck={Cards(run.Deck)} removed={Cards(run.RemovedCards)}");
        sb.Append($" paths={string.Join(",", game.Paths.Select(p => (int)p))}");
        sb.Append($" rewards={string.Join(" ; ", game.Rewards.Select(x => $"{(int)x.Type}:{x.Title}:{x.CardLevel}:{(int)x.CardShimmer}:{(int)x.CardOrientation}:{(int)x.CardEdition}"))}");
        sb.Append($" shop={string.Join(" ; ", game.ShopOffers.Select(o => $"{o.Reward.Title}:{o.Price}:{B(o.Sold)}"))}");
        sb.Append($" event={game.CurrentEvent?.Id ?? "-"}:{B(game.EventResolved)}");
        if (game.LastVictory != null)
            sb.Append($" vic={game.LastVictory.FateEarned}:{game.LastVictory.GoldEarned}:{game.LastVictory.OverkillGold}:{game.LastVictory.Champion?.Definition.Id ?? "-"}:{string.Join(",", game.LastVictory.CardXp.Select(x => x.Xp))}");
        if (game.Combat != null)
            sb.Append($" enemy={game.Combat.Enemy.Definition.Id}:{game.Combat.Enemy.Definition.MaxHp}:{game.Combat.Enemy.Definition.MaxStance}:{game.Combat.Enemy.Definition.BaseAttack}:{game.Combat.Enemy.Definition.Sigils}:{string.Join("+", game.Combat.Enemy.Definition.Rules.Select(x => (int)x))}");
        sb.Append($" rng={Rng(game)}");
        sb.Append(" msg=").Append(Clean(game.Message));
        return sb.ToString();
    }
}
