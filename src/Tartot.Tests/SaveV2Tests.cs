using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Speicherformat 2: Akte, Verdunkelung, Bossregeln und Ereignisse muessen
    /// einen App-Neustart ueberleben - mitten im Bosskampf und mitten in einer
    /// Szene.
    /// </summary>
    public class SaveV2Tests
    {
        private static GameController RoundTrip(GameController game) =>
            GameController.Restore(SaveSystem.Deserialize(game.Save()));

        [Fact]
        public void RunArc_SurvivesARestart()
        {
            var game = new GameController(12, setup: new RunSetup { DeuterId = "aderleser", Veil = 3 });
            game.Run.Darkness = 44;
            game.Run.DefeatedBosses.Add("boss_turm");
            game.Run.SeenEvents.Add("naeherin");
            game.Run.SetStoryFlag("spieler_1");
            game.Run.Stats.WorldSpreads = 9;
            game.Run.Stats.BestHitCombo = "DIE WELT 21";
            game.Run.GraveCardId = "major_13";
            game.Run.StepsSinceShop = 3;

            var restored = RoundTrip(game).Run;

            Assert.Equal("aderleser", restored.DeuterId);
            Assert.Equal(DeuterRule.BloodReader, restored.DeuterRule);
            Assert.Equal(3, restored.Veil);
            Assert.Equal(44, restored.Darkness);
            Assert.Equal(game.Run.ActBosses, restored.ActBosses);
            Assert.Equal(new[] { "boss_turm" }, restored.DefeatedBosses);
            Assert.Contains("naeherin", restored.SeenEvents);
            Assert.Contains("spieler_1", restored.StoryFlags);
            Assert.Contains("spieler_1", restored.NewStoryFlags);
            Assert.Equal(9, restored.Stats.WorldSpreads);
            Assert.Equal("DIE WELT 21", restored.Stats.BestHitCombo);
            Assert.Equal("major_13", restored.GraveCardId);
            Assert.Equal(3, restored.StepsSinceShop);
            Assert.Null(restored.CharmPool);
        }

        [Fact]
        public void TheCharmPool_SurvivesARestart()
        {
            var game = new GameController(12, new MetaProgress());
            var restored = RoundTrip(game).Run;
            Assert.NotNull(restored.CharmPool);
            Assert.Equal(game.Run.CharmPool.OrderBy(x => x), restored.CharmPool.OrderBy(x => x));
        }

        [Fact]
        public void TheScaledEnemy_IsSavedAsItIs()
        {
            // Schleier und Verdunkelung veraendern den Gegner gegenueber dem
            // Katalog - der Speicherstand darf ihn nicht zuruecksetzen.
            var game = new GameController(12, setup: new RunSetup { Veil = 5 });
            TestTools.JumpToFight(game, 4);
            var before = game.Combat.Enemy.Definition;
            var after = RoundTrip(game).Combat.Enemy.Definition;

            Assert.Equal(before.Id, after.Id);
            Assert.Equal(before.MaxHp, after.MaxHp);
            Assert.Equal(before.BaseAttack, after.BaseAttack);
            Assert.Equal(before.Pattern, after.Pattern);
            Assert.NotEqual(ActCatalog.Find(before.Id).MaxHp, after.MaxHp);
        }

        [Fact]
        public void ABossFightMidRule_SurvivesARestart()
        {
            var game = new GameController(12);
            game.Run.DefeatedBosses.AddRange(new[] { "boss_turm", "boss_tod", "boss_teufel" });
            TestTools.JumpToFight(game, ActCatalog.FinaleIndex);
            var combat = game.Combat;
            combat.BlockedSlot = SlotPosition.Present;
            combat.MarkedCardId = game.Run.Deck[2].InstanceId;
            combat.MarkTurnsLeft = 2;
            combat.VeiledCards.Add(combat.Hand[0].InstanceId);
            combat.PatternChain = 3;
            combat.FateBonus = .3f;
            combat.Enemy.Phase = 1;
            combat.Enemy.IntentHidden = true;

            var restored = RoundTrip(game).Combat;

            Assert.Equal(EnemyTier.Finale, restored.Enemy.Definition.Tier);
            Assert.True(restored.Enemy.Definition.RulesWeakened);
            Assert.Equal(game.Combat.Enemy.Definition.Rules, restored.Enemy.Definition.Rules);
            Assert.Equal(SlotPosition.Present, restored.BlockedSlot);
            Assert.Equal(combat.MarkedCardId, restored.MarkedCardId);
            Assert.Equal(2, restored.MarkTurnsLeft);
            Assert.Contains(combat.Hand[0].InstanceId, restored.VeiledCards);
            Assert.Equal(3, restored.PatternChain);
            Assert.Equal(.3f, restored.FateBonus, 3);
            Assert.Equal(1, restored.Enemy.Phase);
            Assert.True(restored.Enemy.IntentHidden);
            Assert.Equal(combat.PactPending, restored.PactPending);
        }

        [Fact]
        public void AnOpenScene_IsNotRerolledByARestart()
        {
            var game = new GameController(12);
            TestTools.WinFight(game);
            game.SkipRewardForFate();
            game.Paths.Clear();
            game.Paths.Add(PathType.Event);
            game.ChoosePath(PathType.Event);
            var id = game.CurrentEvent.Id;

            var restored = RoundTrip(game);
            Assert.Equal(GamePhase.Event, restored.Phase);
            Assert.Equal(id, restored.CurrentEvent.Id);
            Assert.False(restored.EventResolved);

            var index = Enumerable.Range(0, game.CurrentEvent.Choices.Count).First(game.CanChooseEventOption);
            game.ChooseEventOption(index);
            var resolved = RoundTrip(game);
            Assert.True(resolved.EventResolved);
            Assert.Equal(game.EventEpilogue, resolved.EventEpilogue);
        }

        [Fact]
        public void BossLoot_SurvivesARestart()
        {
            var game = new GameController(12);
            TestTools.JumpToFight(game, 4);
            TestTools.WinFight(game);
            Assert.Equal(GamePhase.BossLoot, game.Phase);

            var restored = RoundTrip(game);
            Assert.Equal(GamePhase.BossLoot, restored.Phase);
            Assert.Equal(game.SoakTargets().Select(c => c.InstanceId), restored.SoakTargets().Select(c => c.InstanceId));
            Assert.True(restored.ChooseBossLoot(BossLootChoice.Soak));
        }

        [Fact]
        public void Restore_ContinuesIdenticallyThroughABoss()
        {
            // Das Versprechen gilt auch ueber Bossregeln hinweg: Laden aendert nichts.
            var original = new GameController(91);
            TestTools.JumpToFight(original, 4);
            var json = original.Save();

            var direct = Describe(original);
            var loaded = Describe(GameController.Restore(SaveSystem.Deserialize(json)));
            Assert.Equal(direct, loaded);
        }

        private static string Describe(GameController game)
        {
            var pilot = new Autopilot();
            pilot.PlayCombat(game);
            return $"{game.Phase}|{game.Run.Hp}|{game.Run.MaxHp}|{game.Run.Gold}|{game.Run.Darkness}|{game.Run.Stats.TurnsPlayed}|" +
                   string.Join(",", game.Run.Deck.Select(c => c.InstanceId + ":" + c.Level + ":" + c.Shimmer));
        }

        [Fact]
        public void AVersion1Save_StillLoads()
        {
            // Ein Stand aus der Zeit vor den Akten: ohne Bossplan, ohne
            // Gegnerdefinition. Er muss laden und spielbar bleiben.
            var game = new GameController(13);
            var root = Json.Parse(game.Save());
            root.Set("version", 1);
            var run = root.Get("run");
            foreach (var key in new[] { "actBosses", "deuter", "deuterRule", "darkness", "stats", "charmPool" })
                run.Members.Remove(key);
            root.Get("combat").Get("enemy").Members.Remove("definition");

            var restored = GameController.Restore(SaveSystem.Deserialize(Json.Write(root)));

            Assert.Equal(ActCatalog.ActCount, restored.Run.ActBosses.Count);
            Assert.Equal(DeuterCatalog.DefaultId, restored.Run.DeuterId);
            Assert.Equal(game.Combat.Enemy.Definition.Id, restored.Combat.Enemy.Definition.Id);
            new Autopilot().PlayCombat(restored);
            Assert.NotEqual(GamePhase.Combat, restored.Phase);
        }
    }
}
