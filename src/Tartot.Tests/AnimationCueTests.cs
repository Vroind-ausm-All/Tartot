using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>Welcher Zug welche Animation abspielt - die Blaetter uebersetzt in Kampfereignisse.</summary>
    public class AnimationCueTests
    {
        private static EnemyState Boss(BossRule rule, int phase = 0)
        {
            var state = new EnemyState(TestWorld.Boss(rule)) { Phase = phase };
            return state;
        }

        [Fact]
        public void AHit_ThenTheEnemyAnswers()
        {
            var turn = new TurnResult { FateDamage = 20, EnemyDamage = 5 };
            var cues = AnimationCues.ForTurn(turn, new EnemyState(TestWorld.Dummy()), IntentType.Attack, 1);
            Assert.Equal(new[] { "hit", "attack" }, cues);
        }

        [Fact]
        public void TheKillingBlow_EndsInDeath()
        {
            var turn = new TurnResult { FateDamage = 99, Victory = true };
            Assert.Equal(new[] { "hit", "death" }, AnimationCues.ForTurn(turn, Boss(BossRule.Moon), IntentType.Attack, 3));
        }

        [Fact]
        public void ABrokenSigil_PlaysThePhaseChange()
        {
            var turn = new TurnResult { FateDamage = 50, PhaseChanged = true };
            Assert.Contains("phase2", AnimationCues.ForTurn(turn, Boss(BossRule.Tower), IntentType.Attack, 2));
        }

        [Fact]
        public void Temperance_WaterAndFireRounds()
        {
            var water = AnimationCues.EnemyAction(new TurnResult(), Boss(BossRule.Temperance), IntentType.Attack, 1);
            var fire = AnimationCues.EnemyAction(new TurnResult(), Boss(BossRule.Temperance), IntentType.Attack, 2);
            var mixed = AnimationCues.EnemyAction(new TurnResult(), Boss(BossRule.Temperance, 1), IntentType.Attack, 2);
            Assert.Equal(("attack1", "attack2", "attack3"), (water, fire, mixed));
        }

        [Fact]
        public void Sun_SupernovaWins()
        {
            var turn = new TurnResult { Supernova = true };
            Assert.Equal("supernova", AnimationCues.EnemyAction(turn, Boss(BossRule.Sun), IntentType.Attack, 4));
        }

        [Fact]
        public void Hierophant_CallingAnAcolyte_ShowsTheAcolytes()
        {
            var turn = new TurnResult();
            turn.Log.Add("Der Hierophant ruft einen Akolythen. Es sind 2.");
            Assert.Equal("attack2", AnimationCues.EnemyAction(turn, Boss(BossRule.Hierophant), IntentType.Attack, 2));
        }

        [Fact]
        public void SpiralEnemies_UseTheirTemplateSprites()
        {
            var d = TestWorld.Dummy();
            d.Id = "uhrenwurm_spirale_3";
            Assert.Equal("uhrenwurm", AnimationCues.SpriteId(d));
        }
    }
}
