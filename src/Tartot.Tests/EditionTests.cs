using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>Seltenheit und Editionen: was sie an der Wertung aendern und was sie kosten.</summary>
    public class EditionTests
    {
        private static (RunState Run, CombatState Combat, CombatSystem Sys) Fight(params string[] cards) =>
            TestWorld.Fight(TestWorld.Dummy(stance: 1000), 4711, cards);

        private static ScoreBreakdown Preview(CardEdition edition, out RunState run, out CombatState combat, out CombatSystem sys)
        {
            (run, combat, sys) = Fight("swords_7", "cups_7", "swords_2", "wands_3", "pentacles_4",
                "swords_5", "cups_6", "wands_8", "cups_9");
            combat.Hand.First(c => c.Definition.Id == "swords_7").Edition = edition;
            TestWorld.Place(sys, combat, "swords_7", SlotPosition.Past);
            TestWorld.Place(sys, combat, "cups_7", SlotPosition.Present);
            return sys.PreviewScore(run, combat);
        }

        [Fact]
        public void Rarity_FollowsTheCardKind()
        {
            Assert.Equal(Rarity.Common, GameCatalog.Card("swords_7").Rarity);
            Assert.Equal(Rarity.Uncommon, GameCatalog.Card("cups_12").Rarity);
            Assert.Equal(Rarity.Rare, GameCatalog.Card("major_16").Rarity);
            Assert.Equal(Rarity.Legendary, GameCatalog.Card("major_0").Rarity);
            Assert.Equal(Rarity.Legendary, GameCatalog.Card("major_21").Rarity);
            Assert.Equal(3, GameCatalog.Cards.Count(c => c.Rarity == Rarity.Legendary));
        }

        [Theory]
        [InlineData(0, "0")]
        [InlineData(4, "IV")]
        [InlineData(14, "XIV")]
        [InlineData(19, "XIX")]
        [InlineData(21, "XXI")]
        public void Roman_CoversAllArcana(int value, string expected) =>
            Assert.Equal(expected, MetaProgress.Roman(value));

        [Fact]
        public void Shimmering_AddsChips_Glowing_AddsMult()
        {
            var plain = Preview(CardEdition.None, out _, out _, out _);
            var shimmer = Preview(CardEdition.Shimmering, out _, out _, out _);
            var glow = Preview(CardEdition.Glowing, out _, out _, out _);
            Assert.Equal(plain.Chips + CardEditions.ShimmerChips, shimmer.Chips);
            Assert.Equal(plain.Multiplier + CardEditions.GlowMult, glow.Multiplier, 3);
        }

        [Fact]
        public void Burning_AndGlass_MultiplyTheMult()
        {
            var plain = Preview(CardEdition.None, out _, out _, out _);
            var burning = Preview(CardEdition.Burning, out _, out _, out _);
            var glass = Preview(CardEdition.Glass, out _, out _, out _);
            Assert.Equal(plain.Multiplier * CardEditions.BurnXMult, burning.Multiplier, 3);
            Assert.Equal(plain.Multiplier * CardEditions.GlassXMult, glass.Multiplier, 3);
            Assert.True(glass.FateDamage > plain.FateDamage);
        }

        [Fact]
        public void Burning_SetsTheEnemyAflame_AndCostsLife()
        {
            // Die Kelche heilen - beide Laeufe starten verwundet, damit die Kosten sichtbar bleiben.
            Preview(CardEdition.None, out var plainRun, out var plainCombat, out var plainSys);
            plainRun.Hp = 30;
            plainSys.ResolveTurn(plainRun, plainCombat);
            Preview(CardEdition.Burning, out var run, out var combat, out var sys);
            run.Hp = 30;
            var result = sys.ResolveTurn(run, combat);
            Assert.Contains(result.Log, l => l.Contains("brennt") && l.Contains($"+{CardEditions.BurnBrand} Brand"));
            Assert.Equal(plainRun.Hp - CardEditions.BurnSelfDamage, run.Hp);
        }

        [Fact]
        public void Glass_ShattersSometimes_AndLeavesTheDeck()
        {
            var shattered = 0;
            for (var seed = 1; seed <= 200; seed++)
            {
                var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(stance: 1000), seed,
                    "swords_7", "cups_7", "swords_2", "wands_3", "pentacles_4", "swords_5", "cups_6", "wands_8", "cups_9");
                var glass = run.Deck.First(c => c.Definition.Id == "swords_7");
                glass.Edition = CardEdition.Glass;
                if (!combat.Hand.Contains(glass)) continue;
                sys.PlaceCard(combat, glass.InstanceId, SlotPosition.Present);
                var result = sys.ResolveTurn(run, combat);
                if (result.Shattered.Count > 0)
                {
                    shattered++;
                    Assert.DoesNotContain(glass, run.Deck);
                    Assert.DoesNotContain(glass, combat.DiscardPile);
                }
            }
            Assert.InRange(shattered, 10, 60);
        }

        [Fact]
        public void ScoreSteps_ListEveryCardThenThePattern()
        {
            var score = Preview(CardEdition.Glowing, out _, out var combat, out _);
            Assert.Equal(3, score.Steps.Count);
            Assert.Equal(CardEdition.Glowing, score.Steps[0].Edition);
            Assert.Equal(score.Chips, score.Steps.Sum(s => s.Chips));
            Assert.Equal("Paar", score.Steps[2].Label);
        }

        [Fact]
        public void Edition_SurvivesSaveAndLoad()
        {
            var game = new GameController(7);
            game.Run.Deck[0].Edition = CardEdition.Glass;
            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));
            Assert.Equal(CardEdition.Glass, restored.Run.Deck.First(c => c.InstanceId == game.Run.Deck[0].InstanceId).Edition);
        }

        [Fact]
        public void Rewards_OfferEditionsNowAndThen()
        {
            var editions = 0;
            var cards = 0;
            for (var seed = 1; seed <= 300; seed++)
            {
                var game = new GameController(seed);
                TestTools.WinFight(game);
                foreach (var r in game.Rewards.Where(r => r.Type == RewardType.Card))
                {
                    cards++;
                    if (r.CardEdition != CardEdition.None) editions++;
                }
            }
            Assert.True(cards > 100);
            Assert.InRange(editions * 1000 / cards, 20, 120);
        }
    }
}
