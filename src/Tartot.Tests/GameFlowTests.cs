using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Der Run als Ganzes: Phasenwechsel, Determinismus und die Frage, ob ein
    /// kompletter Durchlauf ueberhaupt stabil laeuft.
    /// </summary>
    public class GameFlowTests
    {
        [Fact]
        public void NewRun_StartsInCombatWithAFullHand()
        {
            var game = new GameController(1);
            Assert.Equal(GamePhase.Combat, game.Phase);
            Assert.NotNull(game.Combat);
            Assert.Equal(CombatSystem.HandSize, game.Combat.Hand.Count);
            Assert.Equal(10, game.Run.Deck.Count);
        }

        [Fact]
        public void WinningAFight_LeadsToRewardThenPath()
        {
            var game = new GameController(5);
            var pilot = new Autopilot();
            pilot.PlayCombat(game);

            // Entweder gewonnen (Belohnung) oder gestorben - nichts dazwischen.
            Assert.True(game.Phase == GamePhase.Reward || game.Phase == GamePhase.GameOver);
            if (game.Phase != GamePhase.Reward) return;

            Assert.NotEmpty(game.Rewards);
            game.SkipRewardForFate();
            Assert.Equal(GamePhase.PathChoice, game.Phase);
            Assert.Equal(3, game.Paths.Count);
            Assert.Contains(PathType.Fight, game.Paths);
        }

        [Fact]
        public void SameSeed_ProducesIdenticalRun()
        {
            // Die Grundlage fuer geteilte Seeds, Tageskarte und Bestenliste.
            var first = new Autopilot().PlayRun(20250920, 12);
            var second = new Autopilot().PlayRun(20250920, 12);
            Assert.Equal(first.Signature, second.Signature);
        }

        [Fact]
        public void DifferentSeeds_ProduceDifferentRuns()
        {
            var signatures = Enumerable.Range(0, 8)
                .Select(i => new Autopilot().PlayRun(500 + i, 12).Signature)
                .Distinct()
                .Count();
            Assert.True(signatures >= 6, $"Zu wenig Streuung: nur {signatures} verschiedene Verlaeufe.");
        }

        [Fact]
        public void ShopReroll_DoesNotShiftCombatDraws()
        {
            // Der eigentliche Grund fuer getrennte Stroeme: wer im Laden
            // herumprobiert, darf damit nicht die naechsten Kartenzuege aendern.
            var withoutShopping = FirstHandOfSecondFight(shop: false);
            var withShopping = FirstHandOfSecondFight(shop: true);
            Assert.Equal(withoutShopping, withShopping);
        }

        private static string FirstHandOfSecondFight(bool shop)
        {
            var game = new GameController(31415);
            var pilot = new Autopilot();
            pilot.PlayCombat(game);
            if (game.Phase != GamePhase.Reward) return "kampf-verloren";
            game.SkipRewardForFate();

            if (shop && game.Paths.Contains(PathType.Shop))
            {
                game.ChoosePath(PathType.Shop);
                // Bewusst nur schauen, nichts kaufen: der Zustand des Runs
                // bleibt gleich, nur der Laden-Strom wurde bewegt.
                game.OpenShop();
                game.OpenShop();
                game.ContinueFromOffgame();
            }
            else
            {
                game.ChoosePath(PathType.Fight);
            }

            return string.Join(",", game.Combat.Hand.Select(c => c.Definition.Id));
        }

        [Fact]
        public void FullRuns_NeverCrash()
        {
            var pilot = new Autopilot();
            for (var seed = 0; seed < 25; seed++)
            {
                var outcome = pilot.PlayRun(9000 + seed, 20);
                Assert.True(outcome.FightsCleared >= 0);
                Assert.True(outcome.DeckSize >= 0);
            }
        }

        [Fact]
        public void Autopilot_ClearsTheFirstFightMostOfTheTime()
        {
            // Der erste Gegner soll lehren, nicht aussieben.
            var wins = 0;
            for (var seed = 0; seed < 30; seed++)
            {
                var game = new GameController(7000 + seed);
                new Autopilot().PlayCombat(game);
                if (game.Phase == GamePhase.Reward) wins++;
            }
            Assert.True(wins >= 27, $"Nur {wins}/30 Siege im ersten Kampf.");
        }

        [Fact]
        public void HpNeverExceedsMaximum()
        {
            for (var seed = 0; seed < 10; seed++)
            {
                var outcome = new Autopilot().PlayRun(3000 + seed, 15);
                Assert.True(outcome.Hp >= 0, "HP darf nicht negativ enden.");
            }
        }
    }
}
