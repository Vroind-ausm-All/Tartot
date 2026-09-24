using System;
using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Die Schleife ueber Runs: Prophezeiungen schalten frei, der Bericht sagt
    /// "fast", Schleier oeffnen sich, Geschichten wandern weiter.
    /// </summary>
    public class MetaLoopTests
    {
        [Fact]
        public void AFreshPlayer_FindsOnlyTheStarterCharms()
        {
            var meta = new MetaProgress();
            var pool = meta.CharmPool();
            Assert.NotEmpty(ProphecyCatalog.LockedCharmIds);
            Assert.All(ProphecyCatalog.LockedCharmIds, id => Assert.DoesNotContain(id, pool));
            Assert.True(pool.Count >= 30, "Die Grundausstattung muss fuer einen vollen Run reichen.");
        }

        [Fact]
        public void LockedCharms_AreNeverOffered()
        {
            var meta = new MetaProgress();
            for (var seed = 0; seed < 20; seed++)
            {
                var game = new GameController(seed, meta);
                Assert.NotNull(game.Run.CharmPool);
                for (var i = 0; i < 10; i++)
                {
                    var rewards = game.Progression.GenerateRewards(game.Run, 5, elite: true);
                    Assert.All(rewards.Where(r => r.Charm != null),
                        r => Assert.DoesNotContain(r.Charm.Id, ProphecyCatalog.LockedCharmIds));
                }
                game.OpenShop();
                Assert.All(game.ShopOffers.Where(o => o.Reward.Charm != null),
                    o => Assert.DoesNotContain(o.Reward.Charm.Id, ProphecyCatalog.LockedCharmIds));
            }
        }

        [Fact]
        public void TheFirstRun_AlreadyUnlocksSomething()
        {
            var meta = new MetaProgress();
            var report = meta.CompleteRun(new GameController(4), won: false, killedBy: "Der Turm");

            Assert.Contains("erste_lesung", meta.CompletedProphecies);
            Assert.Contains(report.Unlocked, text => text.Contains("Die erste Lesung"));
            Assert.Contains("star_dust", meta.CharmPool());
        }

        [Fact]
        public void Prophecies_AreFulfilledOnlyOnce()
        {
            var meta = new MetaProgress();
            meta.CompleteRun(new GameController(4), won: false);
            var second = meta.CompleteRun(new GameController(5), won: false);
            Assert.DoesNotContain(second.Unlocked, text => text.Contains("Die erste Lesung"));
        }

        [Fact]
        public void Deuters_AreUnlockedByTheirProphecy()
        {
            var meta = new MetaProgress();
            Assert.True(meta.IsDeuterUnlocked(DeuterCatalog.DefaultId));
            Assert.False(meta.IsDeuterUnlocked("aderleser"));

            var game = new GameController(4);
            game.Run.Stats.ReversedPlayed = 40;
            meta.CompleteRun(game, won: false);

            Assert.True(meta.IsDeuterUnlocked("aderleser"));
            Assert.Contains(meta.UnlockedDeuters, d => d.Id == "aderleser");
        }

        [Fact]
        public void PendingFulfilled_ShowsTheMomentMidRun()
        {
            var meta = new MetaProgress();
            var game = new GameController(4, meta);
            Assert.DoesNotContain(meta.PendingFulfilled(game.Run), p => p.Id == "welt_oeffnet");
            game.Run.Stats.WorldSpreads = 30;
            Assert.Contains(meta.PendingFulfilled(game.Run), p => p.Id == "welt_oeffnet");
        }

        [Fact]
        public void LifetimeAndBestStats_Accumulate()
        {
            var meta = new MetaProgress();
            var a = new GameController(1);
            a.Run.Stats.WorldSpreads = 7;
            a.Run.Stats.BestHit = 300;
            var b = new GameController(2);
            b.Run.Stats.WorldSpreads = 5;
            b.Run.Stats.BestHit = 200;
            meta.CompleteRun(a, won: false);
            meta.CompleteRun(b, won: false);

            Assert.Equal(12, meta.Lifetime("worldSpreads"));
            Assert.Equal(300, meta.Best("bestHit"));
        }

        // ---------------------------------------------------------- Bericht
        [Fact]
        public void TheReport_EndsWithAtMostThreeNearMisses()
        {
            var meta = new MetaProgress();
            var game = new GameController(4);
            game.Run.Stats.WorldSpreads = 20;       // 20 von 30 fuer "Die Welt oeffnet sich"
            game.Run.Stats.LongestChain = 7;         // 7 von 8 fuer "Kettenleser"
            var report = meta.CompleteRun(game, won: false, killedBy: "Der Turm");

            Assert.InRange(report.NearMisses.Count, 1, 3);
            for (var i = 1; i < report.NearMisses.Count; i++)
                Assert.True(report.NearMisses[i - 1].Progress >= report.NearMisses[i].Progress);
            Assert.Contains(report.NearMisses, n => n.Title == "Kettenleser");
            Assert.StartsWith("GEFALLEN IN AKT", report.Headline);
            Assert.Equal("Der Turm", report.KilledBy);
        }

        [Fact]
        public void TheReport_NamesAnArcanumOneEncounterAway()
        {
            var meta = new MetaProgress();
            for (var i = 0; i < 3; i++) meta.EncounterArcanum("major_1");
            // Das Verbuchen zaehlt die vierte Begegnung - bis zur Lesart
            // "Transformation" (5) fehlt dann genau eine.
            var report = meta.CompleteRun(new GameController(4), won: false);
            Assert.Equal(4, meta.ArcanaEncounters["major_1"]);
            Assert.Contains(report.NearMisses, n => n.Title.StartsWith("Der Magier") && n.Detail.Contains("Transformation"));
        }

        [Fact]
        public void Winning_OpensTheNextVeil()
        {
            var meta = new MetaProgress();
            var game = new GameController(4, meta, new RunSetup { Veil = 0 });
            game.Run.Won = true;
            var report = meta.CompleteRun(game);

            Assert.True(report.Won);
            Assert.Equal(1, meta.Veil);
            Assert.Equal(0, meta.HighestVeilWon);
            Assert.StartsWith("DIE WELT FIEL", report.Headline);

            var harder = new GameController(5, meta, new RunSetup { Veil = 3 });
            harder.Run.Won = true;
            meta.CompleteRun(harder);
            Assert.Equal(4, meta.Veil);
            Assert.Contains("schleierlaeufer", meta.CompletedProphecies);
        }

        [Fact]
        public void Losing_DoesNotOpenAVeil()
        {
            var meta = new MetaProgress();
            meta.CompleteRun(new GameController(4), won: false);
            Assert.Equal(0, meta.Veil);
            Assert.Equal(-1, meta.HighestVeilWon);
        }

        [Fact]
        public void StoryFlags_TravelToTheNextRun()
        {
            var meta = new MetaProgress();
            var game = new GameController(4, meta);
            game.Run.SetStoryFlag("spieler_1");
            meta.CompleteRun(game, won: false);

            Assert.Contains("spieler_1", meta.StoryFlags);
            var next = new GameController(5, meta);
            Assert.Contains("spieler_1", next.Run.StoryFlags);
            Assert.Empty(next.Run.NewStoryFlags);
        }

        [Fact]
        public void TheDailyCard_IsTheSameForEveryone()
        {
            var day = new DateTime(2026, 9, 24, 8, 0, 0, DateTimeKind.Utc);
            var a = RunSetup.Daily(day);
            var b = RunSetup.Daily(day.AddHours(10));
            Assert.Equal(a.DeuterId, b.DeuterId);
            Assert.Equal(a.Veil, b.Veil);
            Assert.True(a.IsDaily);

            // Kein Meta-Fortschritt darin: der Veteran spielt dieselbe Karte wie der Neuling.
            var veteran = new MetaProgress();
            for (var i = 0; i < 12; i++) veteran.EncounterArcanum("major_1");
            var seed = MetaProgress.DailySeed(day);
            var daily = new GameController(seed, veteran, a);
            Assert.Empty(daily.Run.Interpretations);
            Assert.Null(daily.Run.CharmPool);
            Assert.True(daily.Run.IsDaily);
        }

        [Fact]
        public void TheDailyCard_CountsOncePerDay()
        {
            var meta = new MetaProgress();
            var day = new DateTime(2026, 9, 24, 8, 0, 0, DateTimeKind.Utc);
            var seed = MetaProgress.DailySeed(day);
            meta.CompleteRun(new GameController(seed, meta, RunSetup.Daily(day)), won: false);
            meta.CompleteRun(new GameController(seed, meta, RunSetup.Daily(day)), won: false);
            Assert.Equal(1, meta.DailiesPlayed);
        }

        [Fact]
        public void MetaV2_RoundTrips()
        {
            var meta = new MetaProgress();
            var game = new GameController(4, meta);
            game.Run.Stats.WorldSpreads = 31;
            game.Run.SetStoryFlag("tinte_1");
            game.Run.Deck[0].Level = 7;
            meta.CompleteRun(game, won: false, killedBy: "Der Tod");

            var restored = MetaProgress.Deserialize(meta.Serialize(indented: true));

            Assert.Equal(meta.Lifetime("worldSpreads"), restored.Lifetime("worldSpreads"));
            Assert.Equal(meta.Best("worldSpreads"), restored.Best("worldSpreads"));
            Assert.Equal(meta.CompletedProphecies.OrderBy(x => x), restored.CompletedProphecies.OrderBy(x => x));
            Assert.Contains("tinte_1", restored.StoryFlags);
            Assert.Equal(meta.DeathCards.Last().CardId, restored.DeathCards.Last().CardId);
            Assert.Equal(meta.HighestVeilWon, restored.HighestVeilWon);
        }

        [Fact]
        public void AMetaV1File_StillLoads()
        {
            const string v1 = "{\"version\":1,\"runsStarted\":3,\"runsWon\":1,\"deaths\":2,\"veil\":1," +
                              "\"arcana\":{\"major_13\":5},\"seen\":[\"swords_7\"],\"deathCards\":[]}";
            var meta = MetaProgress.Deserialize(v1);
            Assert.Equal(3, meta.RunsStarted);
            Assert.Equal(-1, meta.HighestVeilWon);
            Assert.Empty(meta.CompletedProphecies);
            Assert.Equal(5, meta.ArcanaEncounters["major_13"]);
        }

        [Fact]
        public void AutopilotRuns_FeedTheMetaLoop()
        {
            // Zehn Runs hintereinander, mit Meta-Fortschritt: es muss etwas
            // freigeschaltet werden, und nichts darf dabei abstuerzen.
            var meta = new MetaProgress();
            var pilot = new Autopilot { Meta = meta };
            for (var i = 0; i < 10; i++)
            {
                var outcome = pilot.PlayRun(600 + i, 20);
                meta.CompleteRun(pilot.LastGame, won: outcome.Won, killedBy: outcome.DiedAgainst);
            }
            Assert.True(meta.CompletedProphecies.Count >= 1);
            Assert.Equal(10, meta.RunsStarted);
        }
    }
}
