using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Kampfregeln: Positionen, Haltung, Schicksalssiegel, Schild und die
    /// Charms, die in den Ablauf eingreifen.
    /// </summary>
    public class CombatTests
    {
        // ------------------------------------------------------- Positionen
        [Fact]
        public void PastSlot_IsWeakerThanPresent()
        {
            var past = DamageFromSingleCard("swords_9", SlotPosition.Past);
            var present = DamageFromSingleCard("swords_9", SlotPosition.Present);
            Assert.True(past < present,
                $"Vergangenheit muss schwaecher sein als Gegenwart ({past} gegen {present}).");
        }

        [Fact]
        public void FutureSlot_IsStrongerThanPresent()
        {
            var present = DamageFromSingleCard("swords_9", SlotPosition.Present);
            var future = DamageFromSingleCard("swords_9", SlotPosition.Future);
            Assert.True(future > present,
                $"Die Zukunft muss den Einsatz lohnen ({future} gegen {present}).");
        }

        [Fact]
        public void FutureCard_ResolvesInTheSameTurn_AfterTheEnemy()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "pentacles_8");
            TestWorld.Place(sys, combat, "pentacles_8", SlotPosition.Future);
            var result = sys.ResolveTurn(run, combat);
            Assert.True(result.ShieldGained > 0, "Die Zukunft loest noch in diesem Zug aus.");
        }

        [Fact]
        public void FutureCard_IsLostWhenThePlayerDiesFirst()
        {
            // Das ist der ganze Sinn der Zukunft: hohe Belohnung, echtes Risiko.
            var deadly = TestWorld.Dummy(hp: 100000, stance: 0, attack: 500);
            var (run, combat, sys) = TestWorld.Fight(deadly, 1, "pentacles_8");
            TestWorld.Place(sys, combat, "pentacles_8", SlotPosition.Future);

            var result = sys.ResolveTurn(run, combat);

            Assert.True(combat.PlayerLost);
            Assert.Equal(0, result.ShieldGained);
        }

        // ---------------------------------------------------------- Haltung
        [Fact]
        public void Stance_CapsASingleFateHit()
        {
            // Solange Haltung steht, kann kein einzelner Schlag den Gegner
            // zerlegen - Bosse sollen nicht in einem Zug fallen.
            var tough = TestWorld.Dummy(hp: 200, stance: 500);
            var (run, combat, sys) = TestWorld.Fight(tough, 1, "swords_7", "wands_7", "cups_7");
            foreach (var (id, slot) in new[]
                     {
                         ("swords_7", SlotPosition.Past),
                         ("wands_7", SlotPosition.Present),
                         ("cups_7", SlotPosition.Future)
                     })
                TestWorld.Place(sys, combat, id, slot);

            var before = combat.Enemy.Hp;
            var result = sys.ResolveTurn(run, combat);

            Assert.False(result.StanceBroken);
            Assert.True(result.FateDamage <= 70,
                $"Fate-Schaden muss bei 35 % der maximalen HP gedeckelt sein, war {result.FateDamage}.");
            Assert.True(before - combat.Enemy.Hp > 0);
        }

        [Fact]
        public void BreakingStance_OpensABurstWindow()
        {
            var glass = TestWorld.Dummy(hp: 100000, stance: 1);
            var (run, combat, sys) = TestWorld.Fight(glass, 1, "swords_9");
            TestWorld.Place(sys, combat, "swords_9", SlotPosition.Present);
            var broken = sys.ResolveTurn(run, combat);
            Assert.True(broken.StanceBroken, "Haltung 1 muss sofort brechen.");

            // Zum Vergleich derselbe Schlag gegen einen Gegner ohne Haltung.
            var plain = TestWorld.Dummy(hp: 100000, stance: 0);
            var (run2, combat2, sys2) = TestWorld.Fight(plain, 1, "swords_9");
            TestWorld.Place(sys2, combat2, "swords_9", SlotPosition.Present);
            var normal = sys2.ResolveTurn(run2, combat2);

            Assert.True(broken.FateDamage > normal.FateDamage,
                $"Der Bruch muss ein Schadensfenster oeffnen ({broken.FateDamage} gegen {normal.FateDamage}).");
        }

        [Fact]
        public void Stance_ReturnsAfterTheBurstWindow()
        {
            var enemy = TestWorld.Dummy(hp: 100000, stance: 1);
            var (run, combat, sys) = TestWorld.Fight(enemy, 1, "swords_9", "swords_8", "swords_7");
            TestWorld.Place(sys, combat, "swords_9", SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            Assert.Equal(0, combat.Enemy.Stance);

            TestWorld.Place(sys, combat, "swords_8", SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            Assert.True(combat.Enemy.Stance > 0, "Der Gegner faengt sich nach dem Fenster wieder.");
        }

        // -------------------------------------------- Schicksalssiegel
        [Fact]
        public void Sigil_BringsTheEnemyBackForAnotherPhase()
        {
            var sealed_ = TestWorld.Dummy(hp: 30, stance: 0, attack: 0, sigils: 1);
            var (run, combat, sys) = TestWorld.Fight(sealed_, 1, "swords_14");
            TestWorld.Place(sys, combat, "swords_14", SlotPosition.Present);

            var result = sys.ResolveTurn(run, combat);

            Assert.False(result.Victory);
            Assert.Equal(0, combat.Enemy.Sigils);
            Assert.True(combat.Enemy.Hp > 0, "Das Siegel bringt ihn mit neuen HP zurueck.");
        }

        [Fact]
        public void WithoutStance_ABigTurnBreaksThroughSigilAndEnemy()
        {
            // Dokumentiert bewusst: das Siegel allein schuetzt nicht. Der Schutz
            // ist die Haltung, die den Einzelschlag deckelt. Ohne sie darf ein
            // starker Zug beide Phasen durchschlagen - das ist der Payoff fuer
            // einen Build, der die Haltung vorher gebrochen hat.
            var sealed_ = TestWorld.Dummy(hp: 30, stance: 0, attack: 0, sigils: 1);
            var (run, combat, sys) = TestWorld.Fight(sealed_, 1, "swords_14", "swords_13", "swords_12");
            foreach (var (id, slot) in new[]
                     {
                         ("swords_14", SlotPosition.Past),
                         ("swords_13", SlotPosition.Present),
                         ("swords_12", SlotPosition.Future)
                     })
                TestWorld.Place(sys, combat, id, slot);

            Assert.True(sys.ResolveTurn(run, combat).Victory);
        }

        [Fact]
        public void WithoutSigils_TheEnemyStaysDead()
        {
            var frail = TestWorld.Dummy(hp: 5, stance: 0, attack: 0, sigils: 0);
            var (run, combat, sys) = TestWorld.Fight(frail, 1, "swords_14");
            TestWorld.Place(sys, combat, "swords_14", SlotPosition.Present);
            Assert.True(sys.ResolveTurn(run, combat).Victory);
        }

        // ------------------------------------------------------------ Schild
        [Fact]
        public void PlayerShield_AbsorbsDamageBeforeHp()
        {
            var attacker = TestWorld.Dummy(hp: 100000, stance: 0, attack: 10);
            var (run, combat, sys) = TestWorld.Fight(attacker, 1, "pentacles_10");
            TestWorld.Place(sys, combat, "pentacles_10", SlotPosition.Present);

            var hpBefore = run.Hp;
            sys.ResolveTurn(run, combat);

            Assert.Equal(hpBefore, run.Hp);
            Assert.True(combat.PlayerShield >= 0);
        }

        // ------------------------------------------------------------ Charms
        [Fact]
        public void EveryThirdCard_TriggersOnTheThirdCard()
        {
            // Regression: der Zaehler stieg erst nach dem gesamten Zug, deshalb
            // sahen alle drei Karten denselben Stand und der Charm zuendete nie.
            var charm = TestWorld.CharmWith(CharmEffectType.EveryThirdCardDamage);

            var withoutCharm = ThreeCardDamage(null);
            var withCharm = ThreeCardDamage(charm.Id);

            Assert.True(withCharm > withoutCharm,
                $"Der Charm muss beim dritten Ausspielen zuenden ({withCharm} gegen {withoutCharm}).");
        }

        [Fact]
        public void ArmorPierce_IsNotCountedTwice()
        {
            // Regression: die Durchdringung wurde zusaetzlich vom Restschild
            // abgezogen, wodurch der Charm doppelt so stark wirkte.
            var pierce = TestWorld.CharmWith(CharmEffectType.ArmorPierce);
            var enemy = TestWorld.Dummy(hp: 100000, stance: 0);
            var (run, combat, sys) = TestWorld.Fight(enemy, 1, "swords_2");
            run.AddCharm(pierce, 2);
            combat.Enemy.Shield = 50;

            TestWorld.Place(sys, combat, "swords_2", SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            // Das Schild darf nur um den tatsaechlich geblockten Betrag sinken.
            Assert.True(combat.Enemy.Shield >= 20,
                $"Schild ist unerwartet stark gefallen: {combat.Enemy.Shield}.");
        }

        [Fact]
        public void CharmStacks_RespectTheirMaximum()
        {
            var run = TestWorld.Run();
            var charm = GameCatalog.Charms.First();
            run.AddCharm(charm, 99);
            Assert.Equal(charm.MaxStacks, run.CharmStacks(charm.Id));
        }

        [Fact]
        public void StartShieldCharm_AppliesAtCombatStart()
        {
            var charm = TestWorld.CharmWith(CharmEffectType.StartShield);
            var run = TestWorld.Run("swords_2");
            run.AddCharm(charm, 2);
            var sys = TestWorld.System();
            var combat = sys.StartCombat(run, TestWorld.Dummy());
            Assert.True(combat.PlayerShield >= 6, $"Erwartet mindestens 6 Schild, war {combat.PlayerShield}.");
        }

        // ------------------------------------------------------------ Ziehen
        [Fact]
        public void Hand_IsRefilledEachTurn()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_2", "swords_3", "swords_4", "swords_5", "swords_6",
                "wands_2", "wands_3", "wands_4");
            Assert.Equal(CombatSystem.HandSize, combat.Hand.Count);

            // Irgendeine Handkarte - welche, entscheidet das Mischen.
            sys.PlaceCard(combat, combat.Hand[0].InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            Assert.Equal(CombatSystem.HandSize, combat.Hand.Count);
        }

        [Fact]
        public void DrawPile_ReshufflesFromDiscardWhenEmpty()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_2", "swords_3", "swords_4");
            var reshufflesBefore = combat.Reshuffles;

            for (var i = 0; i < 3; i++)
            {
                var card = combat.Hand.FirstOrDefault();
                if (card == null) break;
                sys.PlaceCard(combat, card.InstanceId, SlotPosition.Present);
                sys.ResolveTurn(run, combat);
            }

            Assert.True(combat.Reshuffles > reshufflesBefore, "Die Ablage muss nachgemischt werden.");
        }

        // ------------------------------------------------------------- Hilfe
        private static int DamageFromSingleCard(string cardId, SlotPosition slot)
        {
            var enemy = TestWorld.Dummy(hp: 100000, stance: 0);
            var (run, combat, sys) = TestWorld.Fight(enemy, 1, cardId);
            TestWorld.Place(sys, combat, cardId, slot);
            var before = combat.Enemy.Hp;
            sys.ResolveTurn(run, combat);
            return before - combat.Enemy.Hp;
        }

        private static int ThreeCardDamage(string charmId)
        {
            var enemy = TestWorld.Dummy(hp: 100000, stance: 0);
            var run = TestWorld.Run("swords_2", "swords_3", "swords_4");
            if (charmId != null) run.AddCharm(GameCatalog.Charm(charmId), 1);
            var sys = TestWorld.System(1);
            var combat = sys.StartCombat(run, enemy);
            TestWorld.Place(sys, combat, "swords_2", SlotPosition.Past);
            TestWorld.Place(sys, combat, "swords_3", SlotPosition.Present);
            TestWorld.Place(sys, combat, "swords_4", SlotPosition.Future);
            var before = combat.Enemy.Hp;
            sys.ResolveTurn(run, combat);
            return before - combat.Enemy.Hp;
        }
    }
}
