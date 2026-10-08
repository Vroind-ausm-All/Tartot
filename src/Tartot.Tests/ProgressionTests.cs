using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    public class ProgressionTests
    {
        private static ProgressionSystem Sys(int seed = 99) =>
            new ProgressionSystem(new DeterministicRandom(seed));

        [Fact]
        public void CardReward_CarriesLevelAndShimmerAsData()
        {
            // Regression: Stufe und Schimmer wurden aus dem Anzeigetext
            // zurueckgelesen ("endet auf +", "beginnt mit Indigo"). Das bricht
            // bei der ersten Uebersetzung.
            var run = TestWorld.Run();
            var reward = new RewardOption
            {
                Type = RewardType.Card,
                Card = GameCatalog.Card("swords_7"),
                Title = "Irgendein uebersetzter Titel",
                Description = "Irgendeine uebersetzte Beschreibung",
                CardLevel = 2,
                CardShimmer = Shimmer.Indigo
            };

            Sys().TakeReward(run, reward);

            var card = run.Deck.Single();
            Assert.Equal(2, card.Level);
            Assert.Equal(Shimmer.Indigo, card.Shimmer);
        }

        [Fact]
        public void Rewards_DoNotOfferTheSameCharmTwice()
        {
            for (var seed = 0; seed < 40; seed++)
            {
                var run = GameCatalog.CreateStarterRun();
                var rewards = Sys(seed).GenerateRewards(run, 5);
                var charmIds = rewards.Where(r => r.Charm != null).Select(r => r.Charm.Id).ToList();
                Assert.Equal(charmIds.Count, charmIds.Distinct().Count());
            }
        }

        [Fact]
        public void Rewards_DoNotOfferMaxedOutCharms()
        {
            var run = TestWorld.Run();
            // Alles bis auf einen Charm ausreizen.
            foreach (var charm in GameCatalog.Charms.Skip(1)) run.AddCharm(charm, charm.MaxStacks);
            var open = GameCatalog.Charms.First();

            for (var seed = 0; seed < 20; seed++)
                foreach (var reward in Sys(seed).GenerateRewards(run, 5).Where(r => r.Charm != null))
                    Assert.Equal(open.Id, reward.Charm.Id);
        }

        [Fact]
        public void Victory_GivesExperienceToContributingCards()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 5), 1, "swords_14");
            var card = combat.Hand.Single();
            TestWorld.Place(sys, combat, "swords_14", SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            var summary = Sys().ResolveVictory(run, combat);

            Assert.True(summary.FateEarned > 0);
            Assert.True(summary.GoldEarned > 0);
            Assert.NotNull(summary.Champion);
            Assert.Equal(card.InstanceId, summary.Champion.InstanceId);
        }

        [Fact]
        public void Champion_GetsAGuaranteedLevelUp()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 5), 1, "swords_14");
            var card = combat.Hand.Single();
            var levelBefore = card.Level;
            TestWorld.Place(sys, combat, "swords_14", SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            Sys().ResolveVictory(run, combat);

            Assert.True(card.Level > levelBefore,
                $"Der Schicksalstraeger muss sicher aufsteigen ({levelBefore} -> {card.Level}).");
        }

        [Fact]
        public void CardLevels_RaiseEffectivePower()
        {
            var card = new CardInstance(GameCatalog.Card("swords_9"));
            var before = card.PowerMultiplier;
            card.AddExperience(500);
            Assert.True(card.Level > 1);
            Assert.True(card.PowerMultiplier > before);
        }

        [Fact]
        public void ShimmerLadder_StopsAtGoldThroughNormalLeveling()
        {
            // Blut und Schwarz sind Sieger-Evolutionen, nicht Routine.
            var card = new CardInstance(GameCatalog.Card("swords_9"));
            card.AddExperience(100000);
            Assert.True(card.Shimmer <= Shimmer.Gold,
                $"Normales Leveln darf hoechstens Gold erreichen, war {card.Shimmer}.");
        }

        [Fact]
        public void VictoryMarks_AccelerateEvolution()
        {
            var card = new CardInstance(GameCatalog.Card("cups_6"));
            var level = card.Level;
            for (var i = 0; i < 3; i++) card.AddVictoryMark();
            Assert.True(card.Level > level, "Drei Siegesmale muessen eine Stufe geben.");
        }
    }
}
