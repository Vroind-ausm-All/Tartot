using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Der einzelne Zug: Musterkette, Ueberschuss, Beinahe-Treffer, Rekord.
    /// Das sind die Momente, die eine Hand spannend machen.
    /// </summary>
    public class MomentTests
    {
        // ----------------------------------------------------------- Kette
        [Fact]
        public void Chain_GrowsWithConsecutivePatterns()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_5", "wands_5", "cups_3", "pentacles_3");

            TestWorld.Place(sys, combat, "swords_5", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_5", SlotPosition.Present);
            var first = sys.PreviewScore(run, combat);
            Assert.True(first.HasPattern);
            Assert.Equal(1, first.Chain);
            sys.ResolveTurn(run, combat);

            TestWorld.Place(sys, combat, "cups_3", SlotPosition.Past);
            TestWorld.Place(sys, combat, "pentacles_3", SlotPosition.Present);
            var second = sys.PreviewScore(run, combat);

            Assert.Equal(2, second.Chain);
            // Gleiche Musterart, gleiche Plaetze: der einzige Unterschied ist das Kettenglied.
            Assert.Equal(first.Multiplier + CombatSystem.ChainBonusPerLink, second.Multiplier, 3);
        }

        [Fact]
        public void Chain_BreaksWithoutAPattern()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_5", "wands_5", "swords_2", "wands_4", "cups_9");
            TestWorld.Place(sys, combat, "swords_5", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_5", SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            Assert.Equal(1, combat.PatternChain);

            // Drei verschiedene Farben ohne Paar, Folge oder 21: nur "Drei Pfade".
            TestWorld.Place(sys, combat, "swords_2", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_4", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_9", SlotPosition.Future);
            var preview = sys.PreviewScore(run, combat);
            Assert.Contains("Drei Pfade", preview.ComboName);
            Assert.False(preview.HasPattern);
            sys.ResolveTurn(run, combat);

            Assert.Equal(0, combat.PatternChain);
        }

        [Fact]
        public void Chain_BonusIsCapped()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_5", "wands_5");
            combat.PatternChain = 40;
            TestWorld.Place(sys, combat, "swords_5", SlotPosition.Past);
            var single = sys.PreviewScore(run, combat).Multiplier;
            TestWorld.Place(sys, combat, "wands_5", SlotPosition.Present);
            var withChain = sys.PreviewScore(run, combat);
            // Paar (+0,50), Gegenwart (+0,15), Kette hoechstens 5 Glieder.
            Assert.Equal(single + .50f + .15f + CombatSystem.MaxChainLinks * CombatSystem.ChainBonusPerLink,
                withChain.Multiplier, 3);
        }

        [Fact]
        public void Preview_DoesNotAdvanceTheChain()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_5", "wands_5");
            TestWorld.Place(sys, combat, "swords_5", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_5", SlotPosition.Present);
            for (var i = 0; i < 5; i++) sys.PreviewScore(run, combat);
            Assert.Equal(0, combat.PatternChain);
            Assert.Equal(0, run.Stats.LongestChain);
        }

        // ------------------------------------------------------ Ueberschuss
        [Fact]
        public void Overkill_IsMeasured()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 3), 1, "swords_10");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Present);
            var result = sys.ResolveTurn(run, combat);

            Assert.True(result.Victory);
            Assert.True(result.Overkill > 0);
            Assert.Equal(combat.LastOverkill, result.Overkill);
        }

        [Fact]
        public void Overkill_PaysGoldWithACap()
        {
            var game = new GameController(11);
            game.Combat.Enemy.Hp = 1;
            game.Combat.Enemy.Stance = 0;
            var goldBefore = game.Run.Gold;
            foreach (var card in game.Combat.Hand.Take(3).ToList())
                TestTools.PlaceSomewhere(game, card);
            game.ResolveTurn();

            Assert.Equal(GamePhase.Reward, game.Phase);
            var overkill = game.Combat.LastOverkill;
            var expected = System.Math.Min(GameController.OverkillGoldCap(1), overkill / GameController.OverkillPerGold);
            Assert.Equal(expected, game.LastVictory.OverkillGold);
            Assert.Equal(goldBefore + game.LastVictory.GoldEarned + expected, game.Run.Gold);
            Assert.Equal(overkill, game.Run.Stats.BestOverkill);
        }

        // ------------------------------------------------------- Beinahe
        [Fact]
        public void Hint_NamesTheCardThatCompletesTheWorld()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_10", "wands_4", "cups_7");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_4", SlotPosition.Present);

            var preview = sys.PreviewScore(run, combat);
            var seven = GameCatalog.Card("cups_7").Name;
            Assert.Contains(preview.Hints, h => h.Contains(seven) && h.Contains("DIE WELT"));
        }

        [Fact]
        public void Hint_NamesTheThirdOfATriad()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_6", "wands_6", "cups_6");
            TestWorld.Place(sys, combat, "swords_6", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_6", SlotPosition.Present);
            var preview = sys.PreviewScore(run, combat);
            Assert.Contains(preview.Hints, h => h.Contains("Dreiklang"));
        }

        [Fact]
        public void Hint_ShowsANearMissOnAFullSpread()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_10", "wands_4", "cups_5");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_4", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_5", SlotPosition.Future);
            var preview = sys.PreviewScore(run, combat);
            Assert.Contains(preview.Hints, h => h.Contains("Summe 19"));
        }

        [Fact]
        public void Preview_FlagsALethalSpread()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 5), 1, "swords_10");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Present);
            var preview = sys.PreviewScore(run, combat);
            Assert.True(preview.Lethal);
            Assert.StartsWith("TÖDLICH", preview.Hints[0]);
        }

        [Fact]
        public void Preview_ShowsTheStanceCap()
        {
            // Die Vorschau zeigt, was ankommt - nicht nur den nackten Wert.
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 100, stance: 500), 1,
                "swords_10", "wands_10", "cups_10");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_10", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_10", SlotPosition.Future);
            var preview = sys.PreviewScore(run, combat);
            Assert.True(preview.FateDamage > 35);
            Assert.Equal(35, preview.ExpectedHit);
            Assert.False(preview.BreaksStance);
        }

        // --------------------------------------------------------- Rekord
        [Fact]
        public void Record_CountsTheSpreadNotTheCappedDamage()
        {
            // 200 HP: der Deckel liegt bei 70, der Dreiklang aus drei Zehnen darueber.
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 200, stance: 100000), 1,
                "swords_10", "wands_10", "cups_10");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_10", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_10", SlotPosition.Future);
            var preview = sys.PreviewScore(run, combat);
            var result = sys.ResolveTurn(run, combat);

            Assert.True(result.FateDamage < preview.FateDamage, "Der Deckel muss hier greifen.");
            Assert.Equal(preview.FateDamage, run.Stats.BestHit);
            Assert.False(result.NewBestHit, "Der erste Treffer ist kein gebrochener Rekord.");
        }

        [Fact]
        public void Record_IsReportedWhenBroken()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_2", "swords_10", "wands_10", "cups_10");
            run.Stats.BestHit = 1;
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_10", SlotPosition.Present);
            var result = sys.ResolveTurn(run, combat);
            Assert.True(result.NewBestHit);
        }

        [Fact]
        public void WorldSpreads_AreCountedPerRunAndPerFight()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_10", "wands_4", "cups_7");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_4", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_7", SlotPosition.Future);
            sys.ResolveTurn(run, combat);

            Assert.Equal(1, run.Stats.WorldSpreads);
            Assert.Equal(1, run.Stats.MostWorldsInFight);
        }
    }

    internal static class TestTools
    {
        /// <summary>Legt eine Handkarte auf den ersten freien Platz, den der Kampf zulaesst.</summary>
        public static bool PlaceSomewhere(GameController game, CardInstance card)
        {
            foreach (var slot in new[] { SlotPosition.Present, SlotPosition.Past, SlotPosition.Future })
                if (!game.Combat.Slots.ContainsKey(slot) && game.CombatSystem.PlaceCard(game.Combat, card.InstanceId, slot))
                    return true;
            return false;
        }

        /// <summary>Beendet den laufenden Kampf mit einem Sieg (Gegner auf 1 HP, dann legen).</summary>
        public static void WinFight(GameController game)
        {
            game.Combat.Enemy.Hp = 1;
            game.Combat.Enemy.Sigils = 0;
            game.Combat.Enemy.Stance = 0;
            game.Combat.Enemy.Shield = 0;
            if (game.Combat.PactPending) game.AnswerPact(false);
            PlaceSomewhere(game, game.Combat.Hand.First());
            game.ResolveTurn();
        }

        /// <summary>Springt direkt vor einen Kampfindex und beginnt ihn.</summary>
        public static void JumpToFight(GameController game, int index)
        {
            game.Run.FightIndex = index - 1;
            game.StartFight(true);
        }
    }
}
