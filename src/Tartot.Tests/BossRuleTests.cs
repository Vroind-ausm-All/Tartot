using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Die Regelbrecher. Jeder Test prueft eine Regel, ihre Verschaerfung
    /// nach einem Siegel und ihre abgeschwaechte Form im Finale.
    /// </summary>
    public class BossRuleTests
    {
        private static (RunState Run, CombatState Combat, CombatSystem Sys) BossFight(
            BossRule rule, bool weakened = false, int attack = 0, int hp = 100000, int sigils = 0)
            => TestWorld.Fight(TestWorld.Boss(rule, hp: hp, attack: attack, sigils: sigils, weakened: weakened),
                4711, TestWorld.EightCards);

        private static void PlayAnyTurn(RunState run, CombatState combat, CombatSystem sys)
        {
            Assert.NotNull(TestWorld.PlaceAny(sys, combat));
            sys.ResolveTurn(run, combat);
        }

        // ------------------------------------------------------------ Turm
        [Fact]
        public void Tower_CollapsesTheFutureOnTheThirdTurn()
        {
            var (run, combat, sys) = BossFight(BossRule.Tower);
            Assert.Null(combat.BlockedSlot);
            PlayAnyTurn(run, combat, sys);
            Assert.Null(combat.BlockedSlot);
            PlayAnyTurn(run, combat, sys);

            Assert.Equal(3, combat.Turn);
            Assert.Equal(SlotPosition.Future, combat.BlockedSlot);
        }

        [Fact]
        public void Tower_BlockedSlotTakesNoCard()
        {
            var (run, combat, sys) = BossFight(BossRule.Tower);
            PlayAnyTurn(run, combat, sys);
            PlayAnyTurn(run, combat, sys);

            var card = combat.Hand.First();
            Assert.False(sys.PlaceCard(combat, card.InstanceId, SlotPosition.Future));
            Assert.True(sys.PlaceCard(combat, card.InstanceId, SlotPosition.Present));
        }

        [Fact]
        public void Tower_CollapsesFasterAfterASigil()
        {
            var (run, combat, sys) = BossFight(BossRule.Tower);
            combat.Enemy.Phase = 1;
            PlayAnyTurn(run, combat, sys);
            Assert.Equal(2, combat.Turn);
            Assert.NotNull(combat.BlockedSlot);
        }

        [Fact]
        public void Tower_WeakenedWaitsFourTurns()
        {
            var (run, combat, sys) = BossFight(BossRule.Tower, weakened: true);
            for (var i = 0; i < 2; i++) PlayAnyTurn(run, combat, sys);
            Assert.Null(combat.BlockedSlot);
            PlayAnyTurn(run, combat, sys);
            Assert.Equal(4, combat.Turn);
            Assert.NotNull(combat.BlockedSlot);
        }

        // ------------------------------------------------------------- Mond
        [Fact]
        public void Moon_HidesIntentAndVeilsACardEverySecondTurn()
        {
            var (run, combat, sys) = BossFight(BossRule.Moon);
            Assert.False(combat.Enemy.IntentHidden);
            Assert.Empty(combat.VeiledCards);

            PlayAnyTurn(run, combat, sys);

            Assert.True(combat.Enemy.IntentHidden);
            Assert.Single(combat.VeiledCards);
            Assert.Contains(combat.Hand, c => combat.VeiledCards.Contains(c.InstanceId));
        }

        [Fact]
        public void Moon_VeiledSpreadGivesNoHints()
        {
            var (run, combat, sys) = BossFight(BossRule.Moon);
            PlayAnyTurn(run, combat, sys);
            var veiled = combat.Hand.First(c => combat.VeiledCards.Contains(c.InstanceId));
            sys.PlaceCard(combat, veiled.InstanceId, SlotPosition.Present);

            var preview = sys.PreviewScore(run, combat);
            Assert.True(preview.Veiled);
            Assert.Empty(preview.Hints);
        }

        [Fact]
        public void Moon_VeilsTwoCardsAfterASigil()
        {
            var (run, combat, sys) = BossFight(BossRule.Moon);
            combat.Enemy.Phase = 1;
            PlayAnyTurn(run, combat, sys);
            Assert.True(combat.Enemy.IntentHidden);
            Assert.Equal(2, combat.VeiledCards.Count);
        }

        // -------------------------------------------------------------- Tod
        private static (RunState, CombatState, CombatSystem, CardInstance) DeathFight()
        {
            var (run, combat, sys) = BossFight(BossRule.Death);
            // Der Tod zeichnet die staerkste Karte - also eine deutlich staerker machen.
            var favourite = run.Deck.First(c => c.Definition.Id == "cups_9");
            favourite.Level = 6;
            return (run, combat, sys, favourite);
        }

        private static void PlayAvoiding(RunState run, CombatState combat, CombatSystem sys, CardInstance avoid)
        {
            var card = combat.Hand.First(c => c != avoid);
            sys.PlaceCard(combat, card.InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);
        }

        [Fact]
        public void Death_MarksYourStrongestCardOnTurnTwo()
        {
            var (run, combat, sys, favourite) = DeathFight();
            Assert.True(string.IsNullOrEmpty(combat.MarkedCardId));
            PlayAvoiding(run, combat, sys, favourite);
            Assert.Equal(favourite.InstanceId, combat.MarkedCardId);
            Assert.Equal(3, combat.MarkTurnsLeft);
        }

        [Fact]
        public void Death_TakesTheCardWhenTimeRunsOut()
        {
            var (run, combat, sys, favourite) = DeathFight();
            PlayAvoiding(run, combat, sys, favourite);
            for (var i = 0; i < 3; i++) PlayAvoiding(run, combat, sys, favourite);

            Assert.DoesNotContain(favourite, run.Deck);
            Assert.Contains(favourite, run.RemovedCards);
            Assert.DoesNotContain(favourite, combat.Hand);
            Assert.Equal(1, run.Stats.CardsLostToDeath);
        }

        [Fact]
        public void Death_FacingTheFutureSavesTheCard()
        {
            var (run, combat, sys, favourite) = DeathFight();
            PlayAvoiding(run, combat, sys, favourite);
            Assert.Equal(favourite.InstanceId, combat.MarkedCardId);

            // Die gezeichnete Karte auf die Hand holen und in die Zukunft legen.
            combat.DrawPile.Remove(favourite);
            combat.DiscardPile.Remove(favourite);
            if (!combat.Hand.Contains(favourite)) combat.Hand.Add(favourite);
            Assert.True(sys.PlaceCard(combat, favourite.InstanceId, SlotPosition.Future));
            sys.ResolveTurn(run, combat);

            Assert.True(string.IsNullOrEmpty(combat.MarkedCardId));
            Assert.Contains(favourite, run.Deck);
        }

        [Fact]
        public void Death_NeverTakesBelowTheMinimumDeck()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Boss(BossRule.Death), 4711,
                "swords_2", "swords_3", "wands_4", "cups_5", "pentacles_6");
            for (var i = 0; i < 6; i++) PlayAnyTurn(run, combat, sys);
            Assert.Equal(GameCatalog.MinimumDeckSize, run.Deck.Count);
        }

        // -------------------------------------------------------------- Rad
        [Fact]
        public void Wheel_ShiftsEveryPositionOneAhead()
        {
            var (run, combat, sys) = BossFight(BossRule.Wheel);
            Assert.Equal(SlotPosition.Present, sys.EffectiveSlot(combat, SlotPosition.Past));
            Assert.Equal(SlotPosition.Future, sys.EffectiveSlot(combat, SlotPosition.Present));
            Assert.Equal(SlotPosition.Past, sys.EffectiveSlot(combat, SlotPosition.Future));
        }

        [Fact]
        public void Wheel_PreviewScoresWhereTheCardActs()
        {
            // Eine Karte in der Vergangenheit wirkt unter dem Rad als Gegenwart
            // und bekommt deren Bonus - die Vorschau muss das zeigen.
            var plain = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_7");
            TestWorld.Place(plain.Sys, plain.Combat, "swords_7", SlotPosition.Past);
            var plainMult = plain.Sys.PreviewScore(plain.Run, plain.Combat).Multiplier;

            var wheel = TestWorld.Fight(TestWorld.Boss(BossRule.Wheel), 1, "swords_7");
            TestWorld.Place(wheel.Sys, wheel.Combat, "swords_7", SlotPosition.Past);
            var wheelMult = wheel.Sys.PreviewScore(wheel.Run, wheel.Combat).Multiplier;

            Assert.Equal(plainMult + .15f, wheelMult, 3);
        }

        [Fact]
        public void Wheel_TurnsBackwardsAfterASigil()
        {
            var (_, combat, sys) = BossFight(BossRule.Wheel);
            combat.Enemy.Phase = 1;
            Assert.Equal(SlotPosition.Future, sys.EffectiveSlot(combat, SlotPosition.Past));
        }

        [Fact]
        public void Wheel_WeakenedOnlyTurnsOnEvenRounds()
        {
            var (_, combat, sys) = BossFight(BossRule.Wheel, weakened: true);
            Assert.Equal(SlotPosition.Past, sys.EffectiveSlot(combat, SlotPosition.Past));
            combat.Turn = 2;
            Assert.Equal(SlotPosition.Present, sys.EffectiveSlot(combat, SlotPosition.Past));
        }

        // -------------------------------------------------------- Gehaengter
        [Fact]
        public void HangedMan_SwapsPastAndFuture()
        {
            var (_, combat, sys) = BossFight(BossRule.HangedMan);
            Assert.Equal(SlotPosition.Future, sys.EffectiveSlot(combat, SlotPosition.Past));
            Assert.Equal(SlotPosition.Present, sys.EffectiveSlot(combat, SlotPosition.Present));
            Assert.Equal(SlotPosition.Past, sys.EffectiveSlot(combat, SlotPosition.Future));
        }

        [Fact]
        public void HangedMan_AFutureCardActsBeforeTheEnemy()
        {
            // Normalerweise verfaellt die Zukunft, wenn man im selben Zug stirbt.
            // Unter dem Gehaengten liegt die "Zukunft" vorn - sie wirkt sofort.
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Boss(BossRule.HangedMan, attack: 500), 1, "cups_9");
            run.Hp = 10;
            TestWorld.Place(sys, combat, "cups_9", SlotPosition.Future);
            var result = sys.ResolveTurn(run, combat);
            Assert.True(result.Healing > 0, "Die Kelchkarte muss vor dem toedlichen Treffer heilen.");
        }

        [Fact]
        public void HangedMan_TakesAHandCardAfterASigil()
        {
            var (run, combat, sys) = BossFight(BossRule.HangedMan);
            combat.Enemy.Phase = 1;
            Assert.Equal(CombatSystem.HandSize - 1, sys.HandSizeFor(combat));
            PlayAnyTurn(run, combat, sys);
            Assert.Equal(CombatSystem.HandSize - 1, combat.Hand.Count);
        }

        // ----------------------------------------------------------- Teufel
        [Fact]
        public void Devil_OffersAPactAtTheStart()
        {
            var (_, combat, _) = BossFight(BossRule.Devil);
            Assert.True(combat.PactPending);
        }

        [Fact]
        public void Devil_AcceptingTradesLifeForDamage()
        {
            var (run, combat, sys) = BossFight(BossRule.Devil);
            TestWorld.Place(sys, combat, combat.Hand[0].Definition.Id, SlotPosition.Present);
            var before = sys.PreviewScore(run, combat).FateDamage;

            Assert.True(sys.AnswerPact(run, combat, true));

            Assert.False(combat.PactPending);
            Assert.Equal(CombatSystem.PactFateBonus, combat.FateBonus, 3);
            Assert.Equal(72 - CombatSystem.PactMaxHpCost, run.MaxHp);
            Assert.Equal(CombatSystem.PactDarkness, run.Darkness);
            Assert.Equal(1, run.Stats.PactsAccepted);
            Assert.True(sys.PreviewScore(run, combat).FateDamage > before);
        }

        [Fact]
        public void Devil_DecliningAngersHim()
        {
            var (run, combat, sys) = BossFight(BossRule.Devil, attack: 20);
            var before = combat.Enemy.IntentValue;
            sys.AnswerPact(run, combat, false);
            Assert.True(combat.Enemy.IntentValue > before,
                $"Die Absicht muss den Zorn zeigen ({combat.Enemy.IntentValue} gegen {before}).");
            Assert.Equal(72, run.MaxHp);
        }

        [Fact]
        public void Devil_UnansweredPactIsDeclined()
        {
            var (run, combat, sys) = BossFight(BossRule.Devil, attack: 20);
            PlayAnyTurn(run, combat, sys);
            Assert.False(combat.PactPending);
            Assert.Equal(CombatSystem.PactDeclinePenalty, combat.EnemyAttackBonus, 3);
        }

        [Fact]
        public void Devil_OffersAgainAfterASigilAndChargesMore()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Boss(BossRule.Devil, hp: 5, sigils: 1), 1, "swords_10");
            sys.AnswerPact(run, combat, false);
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Present);
            var result = sys.ResolveTurn(run, combat);

            Assert.True(result.PhaseChanged);
            Assert.True(combat.PactPending);
            Assert.Equal(CombatSystem.SecondPactMaxHpCost, CombatSystem.PactCost(combat));
        }

        // -------------------------------------------------------- Phasen
        [Fact]
        public void BreakingASigil_AdvancesThePhase()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Boss(BossRule.Tower, hp: 5, sigils: 1), 1, "swords_10");
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Present);
            var result = sys.ResolveTurn(run, combat);

            Assert.True(result.PhaseChanged);
            Assert.Equal(1, combat.Enemy.Phase);
            Assert.Contains(result.Log, line => line.StartsWith("Neue Phase"));
        }

        [Fact]
        public void EveryRule_HasATextForEveryPhase()
        {
            foreach (BossRule rule in System.Enum.GetValues(typeof(BossRule)))
            {
                if (rule == BossRule.None) continue;
                foreach (var weakened in new[] { false, true })
                    for (var phase = 0; phase < 3; phase++)
                        Assert.False(string.IsNullOrEmpty(ActCatalog.RuleText(rule, phase, weakened)));
            }
        }
    }
}
