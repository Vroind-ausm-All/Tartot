using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Die Bosse aus den Boss-Blaettern: Maessigkeit, Hierophant, rote Sonne,
    /// und die Phasen-LP ("220 / 320"), die ihre zweite Phase staerker macht.
    /// </summary>
    public class SheetBossTests
    {
        private static (RunState Run, CombatState Combat, CombatSystem Sys) BossFight(
            BossRule rule, bool weakened = false, int attack = 0, int stance = 1000, params string[] cards)
            => TestWorld.Fight(TestWorld.Boss(rule, attack: attack, stance: stance, weakened: weakened), 4711,
                cards.Length > 0 ? cards : TestWorld.EightCards);

        private static void PlayAnyTurn(RunState run, CombatState combat, CombatSystem sys)
        {
            Assert.NotNull(TestWorld.PlaceAny(sys, combat));
            sys.ResolveTurn(run, combat);
        }

        // ------------------------------------------------------ Maessigkeit
        [Fact]
        public void Temperance_WaterHalvesWands_FireHalvesCups()
        {
            var (_, combat, _) = BossFight(BossRule.Temperance);
            var wand = new CardInstance(GameCatalog.Card("wands_4"));
            var cup = new CardInstance(GameCatalog.Card("cups_5"));
            var sword = new CardInstance(GameCatalog.Card("swords_3"));

            Assert.False(CombatSystem.IsFireRound(combat));
            Assert.Equal(CombatSystem.TemperanceHalf, CombatSystem.TemperanceFactor(combat, wand));
            Assert.Equal(1f, CombatSystem.TemperanceFactor(combat, cup));
            combat.Turn = 2;
            Assert.Equal(1f, CombatSystem.TemperanceFactor(combat, wand));
            Assert.Equal(CombatSystem.TemperanceHalf, CombatSystem.TemperanceFactor(combat, cup));
            Assert.Equal(1f, CombatSystem.TemperanceFactor(combat, sword));
        }

        [Fact]
        public void Temperance_SecondPhase_RewardsBalanceAndMirrorsTheRest()
        {
            var (run, combat, sys) = BossFight(BossRule.Temperance, cards: new[] { "wands_4", "cups_5", "swords_3", "swords_7", "swords_9" });
            combat.Enemy.Phase = 1;
            TestWorld.Place(sys, combat, "wands_4", SlotPosition.Past);
            TestWorld.Place(sys, combat, "cups_5", SlotPosition.Present);
            Assert.Contains("Gleichgewicht", sys.PreviewScore(run, combat).ComboName);
            var balanced = sys.ResolveTurn(run, combat);
            Assert.Equal(0, balanced.Reflected);

            var sword = combat.Hand.First(c => c.Definition.Suit == Suit.Swords);
            sys.PlaceCard(combat, sword.InstanceId, SlotPosition.Present);
            var before = run.Hp;
            var unbalanced = sys.ResolveTurn(run, combat);
            Assert.True(unbalanced.Reflected > 0);
            Assert.True(run.Hp < before);
        }

        [Fact]
        public void Temperance_InTheFinale_OnlyAlternates()
        {
            var (_, combat, _) = BossFight(BossRule.Temperance, weakened: true);
            combat.Enemy.Phase = 1;
            Assert.False(CombatSystem.TemperanceMixing(combat));
        }

        // ------------------------------------------------------ Hierophant
        [Fact]
        public void Hierophant_CallsAcolytesWhoBlessHimWithShield()
        {
            var (run, combat, sys) = BossFight(BossRule.Hierophant);
            PlayAnyTurn(run, combat, sys);
            Assert.Equal(1, combat.Acolytes);
            Assert.Equal(2, combat.Turn);

            TestWorld.PlaceAny(sys, combat);
            var result = sys.ResolveTurn(run, combat);
            Assert.Contains(result.Log, l => l.Contains("segnen") && l.Contains($"+{CombatSystem.AcolyteBlessing} Schild"));
        }

        [Fact]
        public void Hierophant_NeverExceedsThreeAcolytesInTheFirstPhase()
        {
            var (run, combat, sys) = BossFight(BossRule.Hierophant);
            for (var i = 0; i < 10; i++) PlayAnyTurn(run, combat, sys);
            Assert.Equal(3, combat.Acolytes);
        }

        [Fact]
        public void Hierophant_BrokenStanceDrivesTheAcolytesAway()
        {
            var (run, combat, sys) = BossFight(BossRule.Hierophant, stance: 1);
            combat.Acolytes = 3;
            TestWorld.PlaceAny(sys, combat);
            var result = sys.ResolveTurn(run, combat);
            Assert.Contains(result.Log, l => l.Contains("Akolythen fliehen"));
            Assert.DoesNotContain(result.Log, l => l.Contains("segnen"));
            Assert.True(combat.Acolytes <= 1); // hoechstens der naechste, neu gerufene
        }

        // ------------------------------------------------------ Sonne
        [Fact]
        public void Sun_FourSunsBecomeASupernova()
        {
            var (run, combat, sys) = BossFight(BossRule.Sun);
            run.MaxHp = run.Hp = 500;
            Assert.Equal(1, combat.Suns);
            TurnResult last = null;
            for (var i = 0; i < 4 && (last == null || !last.Supernova); i++)
            {
                TestWorld.PlaceAny(sys, combat);
                last = sys.ResolveTurn(run, combat);
            }
            Assert.True(last.Supernova);
            Assert.Equal(1, combat.Suns); // nach der Supernova geht eine neue auf
            Assert.True(last.EnemyDamage >= CombatSystem.SupernovaAt * CombatSystem.SupernovaPerSun);
        }

        [Fact]
        public void Sun_BrokenStanceExtinguishesTheSuns()
        {
            var (run, combat, sys) = BossFight(BossRule.Sun, stance: 1);
            combat.Suns = 3;
            PlayAnyTurn(run, combat, sys);
            Assert.Equal(1, combat.Suns);
        }

        // ------------------------------------------------------ Phasen-LP
        [Fact]
        public void SheetBosses_ReturnWithTheirPhaseTwoLife()
        {
            var boss = TestWorld.Boss(BossRule.Moon, hp: 10, sigils: 1);
            boss.PhaseHp = 320;
            var (run, combat, sys) = TestWorld.Fight(boss, 4711, TestWorld.EightCards);
            var result = sys.ResolveTurn(run, PlaceSomething(sys, combat));
            Assert.True(result.PhaseChanged);
            Assert.Equal(320, combat.Enemy.Definition.MaxHp);
            Assert.True(combat.Enemy.Hp > 250);
        }

        private static CombatState PlaceSomething(CombatSystem sys, CombatState combat)
        {
            foreach (var slot in new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future })
                TestWorld.PlaceAny(sys, combat);
            return combat;
        }

        [Fact]
        public void Catalog_FollowsTheSheets()
        {
            Assert.Equal(1, ActCatalog.Find("boss_hierophant").Act);
            Assert.Equal(3, ActCatalog.Find("boss_mond").Act);
            Assert.Equal(3, ActCatalog.Find("boss_teufel").Act);
            Assert.Equal(3, ActCatalog.Find("boss_maessigkeit").Act);
            Assert.Equal(EnemyTier.Finale, ActCatalog.Find("boss_sonne").Tier);
            Assert.Equal(320, ActCatalog.Find("boss_hierophant").PhaseHp);
            Assert.Equal(420, ActCatalog.Find("boss_sonne").PhaseHp);
        }

        [Fact]
        public void SunFinale_EndsTheRunLikeTheWorld()
        {
            var game = new GameController(5);
            game.Run.ActBosses[ActCatalog.ActCount] = ActCatalog.Sun.Id;
            TestTools.JumpToFight(game, ActCatalog.FinaleIndex);
            Assert.Equal("boss_sonne", game.Combat.Enemy.Definition.Id);
            Assert.Contains(BossRule.Sun, game.Combat.Enemy.Definition.Rules);
            Assert.Equal(ActCatalog.Sun, game.UpcomingBoss());
        }
    }
}
