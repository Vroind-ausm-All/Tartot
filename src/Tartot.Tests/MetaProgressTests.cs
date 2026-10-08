using System;
using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    public class MetaProgressTests
    {
        [Fact]
        public void FirstEncounter_UnlocksTheFirstReading()
        {
            var meta = new MetaProgress();
            Assert.Equal("Erste Lesart", meta.EncounterArcanum("major_13"));
        }

        [Fact]
        public void FurtherReadings_UnlockAtTheirThresholds()
        {
            var meta = new MetaProgress();
            var unlocked = Enumerable.Range(0, 12)
                .Select(_ => meta.EncounterArcanum("major_13"))
                .Where(name => name != null)
                .ToList();

            Assert.Equal(new[] { "Erste Lesart", "Transformation", "Verkehrte Lesart" }, unlocked);
            Assert.Equal(12, meta.ArcanaEncounters["major_13"]);
        }

        [Fact]
        public void ReadingsAreNotUnlockedTwice()
        {
            var meta = new MetaProgress();
            for (var i = 0; i < 40; i++) meta.EncounterArcanum("major_0");
            Assert.Equal(3, meta.Interpretations["major_0"].Count);
        }

        [Fact]
        public void LosingARun_LeavesADeathCard()
        {
            var meta = new MetaProgress();
            var game = new GameController(5);
            meta.RegisterRun(game, won: false, killedBy: "Der lächelnde Gerichtsdiener");

            Assert.Equal(1, meta.Deaths);
            Assert.Single(meta.DeathCards);
            Assert.Equal("Der lächelnde Gerichtsdiener", meta.DeathCards[0].KilledBy);
            Assert.Equal(game.Seed, meta.DeathCards[0].Seed);
        }

        [Fact]
        public void DeathCards_AreCapped()
        {
            var meta = new MetaProgress();
            for (var i = 0; i < MetaProgress.MaxDeathCards + 10; i++)
                meta.RegisterRun(new GameController(i), won: false);
            Assert.Equal(MetaProgress.MaxDeathCards, meta.DeathCards.Count);
        }

        [Fact]
        public void RegisteringARun_RecordsSeenCards()
        {
            var meta = new MetaProgress();
            var game = new GameController(6);
            meta.RegisterRun(game, won: true);
            Assert.NotEmpty(meta.SeenCards);
            Assert.Equal(1, meta.RunsWon);
        }

        [Fact]
        public void RoundTrip_PreservesEverything()
        {
            var meta = new MetaProgress { Veil = 3 };
            meta.RegisterRun(new GameController(7), won: true);
            meta.RegisterRun(new GameController(8), won: false, killedBy: "Der Mondfresser");
            for (var i = 0; i < 5; i++) meta.EncounterArcanum("major_16");

            var restored = MetaProgress.Deserialize(meta.Serialize(indented: true));

            Assert.Equal(meta.RunsStarted, restored.RunsStarted);
            Assert.Equal(meta.RunsWon, restored.RunsWon);
            Assert.Equal(meta.Deaths, restored.Deaths);
            Assert.Equal(meta.Veil, restored.Veil);
            Assert.Equal(meta.SmallestDeck, restored.SmallestDeck);
            Assert.Equal(meta.SeenCards.Count, restored.SeenCards.Count);
            Assert.Equal(meta.DeathCards.Count, restored.DeathCards.Count);
            Assert.Equal("Der Mondfresser", restored.DeathCards.Last().KilledBy);
            Assert.Equal(meta.ArcanaEncounters["major_16"], restored.ArcanaEncounters["major_16"]);
            Assert.True(restored.HasInterpretation("major_16", "Transformation"));
        }

        [Fact]
        public void EmptyOrBrokenFile_YieldsFreshProgress()
        {
            Assert.Equal(0, MetaProgress.Deserialize("").RunsStarted);
            Assert.Equal(0, MetaProgress.Deserialize("{kaputt").RunsStarted);
        }

        [Fact]
        public void DailySeed_IsStablePerDayAndDiffersBetweenDays()
        {
            var day = new DateTime(2026, 4, 20, 13, 0, 0, DateTimeKind.Utc);
            Assert.Equal(MetaProgress.DailySeed(day), MetaProgress.DailySeed(day.AddHours(5)));
            Assert.NotEqual(MetaProgress.DailySeed(day), MetaProgress.DailySeed(day.AddDays(1)));
        }
    }
}
