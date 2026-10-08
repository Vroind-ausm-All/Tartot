using System;
using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Ereignisse: jede Szene muss spielbar sein, jede Wahl darf den Run nicht
    /// kaputt machen, und die Geschichten ueber mehrere Runs muessen in der
    /// richtigen Reihenfolge erscheinen.
    /// </summary>
    public class EventTests
    {
        /// <summary>Ein Run, in dem jede Wahl moeglich ist.</summary>
        private static RunState RichRun(int act = 3, int darkness = 60)
        {
            var run = GameCatalog.CreateStarterRun();
            run.Gold = 500;
            run.Darkness = darkness;
            run.FightIndex = (act - 1) * ActCatalog.FightsPerAct;
            run.GraveCardId = "major_13";
            run.GraveFight = 9;
            return run;
        }

        [Fact]
        public void EventIds_AreUnique()
        {
            var ids = EventCatalog.All.Select(e => e.Id).ToList();
            Assert.Equal(ids.Count, ids.Distinct().Count());
        }

        [Fact]
        public void EveryEvent_HasAScene()
        {
            var run = RichRun();
            foreach (var definition in EventCatalog.All)
            {
                Assert.False(string.IsNullOrEmpty(definition.Title), definition.Id);
                Assert.True(definition.Choices.Count >= 2, $"{definition.Id}: zu wenige Wahlen.");
                var beats = definition.BeatsFor(run);
                Assert.True(beats.Length >= 2, $"{definition.Id}: eine Szene braucht mindestens zwei Beats.");
                Assert.All(beats, beat => Assert.False(string.IsNullOrWhiteSpace(beat)));
                Assert.All(definition.Choices, c => Assert.False(string.IsNullOrEmpty(c.Hint), $"{definition.Id}: {c.Label} ohne Hinweis."));
            }
        }

        [Fact]
        public void EveryChoice_ResolvesWithoutBreakingTheRun()
        {
            foreach (var definition in EventCatalog.All)
                for (var i = 0; i < definition.Choices.Count; i++)
                    for (var seed = 0; seed < 6; seed++)
                    {
                        var run = RichRun();
                        var choice = definition.Choices[i];
                        if (!choice.Available(run)) continue;

                        var epilogue = choice.Resolve(new EventContext { Run = run, Rng = new DeterministicRandom(seed) });

                        var where = $"{definition.Id}/{choice.Label}/{seed}";
                        Assert.False(string.IsNullOrWhiteSpace(epilogue), where);
                        Assert.True(run.Deck.Count >= GameCatalog.MinimumDeckSize, where);
                        Assert.InRange(run.Hp, 1, run.MaxHp);
                        Assert.True(run.Gold >= 0, where);
                        Assert.InRange(run.Darkness, 0, 100);
                        Assert.All(run.Charms, pair => Assert.True(pair.Value <= GameCatalog.Charm(pair.Key).MaxStacks, where));
                    }
        }

        [Fact]
        public void Choices_CheckWhatTheyCost()
        {
            var poor = RichRun();
            poor.Gold = 0;
            var gamble = EventCatalog.Find("kartenspieler_1").Choices[0];
            Assert.False(gamble.Available(poor));
        }

        [Fact]
        public void DarkRuns_SeeDarkerScenes()
        {
            var confessional = EventCatalog.Find("beichtstuhl");
            var light = confessional.BeatsFor(RichRun(darkness: 0));
            var dark = confessional.BeatsFor(RichRun(darkness: 80));
            Assert.NotEqual(light[0], dark[0]);
        }

        // --------------------------------------------------- Geschichten
        [Fact]
        public void TheCardPlayer_TellsHisStoryInOrder()
        {
            var part1 = EventCatalog.Find("kartenspieler_1");
            var part2 = EventCatalog.Find("kartenspieler_2");
            var part3 = EventCatalog.Find("kartenspieler_3");

            var act1 = RichRun(act: 1);
            Assert.True(part1.IsEligible(act1));
            Assert.False(part2.IsEligible(act1));

            // Die erste Begegnung setzt das Flag, egal wie sie ausgeht.
            part1.Choices.Last().Resolve(new EventContext { Run = act1, Rng = new DeterministicRandom(1) });
            Assert.Contains("spieler_1", act1.StoryFlags);
            Assert.Contains("spieler_1", act1.NewStoryFlags);
            Assert.False(part1.IsEligible(act1));

            var act2 = RichRun(act: 2);
            act2.StoryFlags.Add("spieler_1");
            Assert.True(part2.IsEligible(act2));
            Assert.False(part3.IsEligible(act2));

            var act3 = RichRun(act: 3);
            act3.StoryFlags.Add("spieler_1");
            act3.StoryFlags.Add("spieler_2");
            Assert.True(part3.IsEligible(act3));
        }

        [Fact]
        public void TheInk_OnlyFindsDarkRuns()
        {
            var ink = EventCatalog.Find("tinte_1");
            Assert.False(ink.IsEligible(RichRun(darkness: 0)));
            Assert.True(ink.IsEligible(RichRun(darkness: 40)));
        }

        [Fact]
        public void TheGrave_NeedsAPreviousDeath()
        {
            var grave = EventCatalog.Find("grab");
            var run = RichRun();
            run.GraveCardId = string.Empty;
            Assert.False(grave.IsEligible(run));

            run = RichRun();
            Assert.True(grave.IsEligible(run));
            var deck = run.Deck.Count;
            grave.Choices[0].Resolve(new EventContext { Run = run, Rng = new DeterministicRandom(1) });
            Assert.Equal(deck + 1, run.Deck.Count);
            var returned = run.Deck.Last();
            Assert.Equal("major_13", returned.Definition.Id);
            Assert.Equal(3, returned.Level);
            Assert.True(string.IsNullOrEmpty(run.GraveCardId), "Das Grab gibt nur einmal.");
        }

        [Fact]
        public void TheGrave_IsFilledFromTheLastDeath()
        {
            var meta = new MetaProgress();
            var dead = new GameController(5);
            dead.Run.Deck[0].Level = 9;
            meta.RegisterRun(dead, won: false, killedBy: "Der Turm");

            var next = new GameController(6, meta);
            Assert.Equal(dead.Run.Deck[0].Definition.Id, next.Run.GraveCardId);
        }

        [Fact]
        public void SeenEvents_DoNotRepeatWithinARun()
        {
            var run = RichRun(act: 1, darkness: 0);
            var definition = EventCatalog.Find("naeherin");
            Assert.True(definition.IsEligible(run));
            run.SeenEvents.Add(definition.Id);
            Assert.False(definition.IsEligible(run));
        }

        [Fact]
        public void EveryActHasScenes()
        {
            for (var act = 1; act <= 4; act++)
            {
                var run = RichRun(act: act, darkness: 0);
                run.GraveCardId = string.Empty;
                Assert.True(EventCatalog.All.Count(e => e.IsEligible(run)) >= 5,
                    $"Akt {act} braucht mehr als eine Handvoll Szenen.");
            }
        }
    }
}
