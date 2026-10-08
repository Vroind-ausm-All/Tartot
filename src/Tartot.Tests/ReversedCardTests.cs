using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Umgekehrte Karten sollen riskanter sein, nicht besser. Vorher kostete
    /// eine 9 genau 1 HP gegen +18 % Kraft und +0,10 Multiplikator - damit gab
    /// es keine Entscheidung, man drehte einfach alles um.
    /// </summary>
    public class ReversedCardTests
    {
        private static int SelfDamageOf(string cardId, SlotPosition slot = SlotPosition.Present)
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, cardId);
            var card = combat.Hand.Single();
            card.Orientation = Orientation.Reversed;
            var before = run.Hp;
            TestWorld.Place(sys, combat, cardId, slot);
            sys.ResolveTurn(run, combat);
            return before - run.Hp;
        }

        [Fact]
        public void ReversedCost_ScalesWithCardPower()
        {
            // Basiskarten liegen bei Wirkung 4 bis 13. Bei diesem Anteil rundet
            // der Preis dort auf 1 HP - der Unterschied wird erst sichtbar,
            // wenn eine Karte durch Level und Schimmer wirklich stark wird.
            var weak = SelfDamageOf("swords_2");
            var strong = SelfDamageOfUpgraded("swords_10", level: 8, Shimmer.Gold);
            Assert.True(strong > weak,
                $"Eine gewachsene Karte muss mehr kosten als eine schwache ({strong} gegen {weak}).");
        }

        [Fact]
        public void ReversedCost_HasAFloorOfOne()
        {
            // Auch die schwaechste Karte kostet etwas - sonst waere Umkehren bei
            // niedrigen Werten wieder gratis. Der Nebeneffekt ist gewollt: eine
            // schwache Karte umzudrehen ist schlechtes Geschaeft (1 HP auf
            // Wirkung 4), eine starke gutes. Das macht die Wahl aus.
            Assert.Equal(1, SelfDamageOf("swords_2"));
        }

        [Fact]
        public void ReversedCost_IsChargedAtAll()
        {
            Assert.True(SelfDamageOf("swords_9") > 0);
        }

        [Fact]
        public void UprightCards_CostNothing()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_9");
            var before = run.Hp;
            TestWorld.Place(sys, combat, "swords_9", SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            Assert.Equal(before, run.Hp);
        }

        [Fact]
        public void ReversedCost_ScalesWithSlotFactor()
        {
            // Die Zukunft wirkt staerker - also kostet sie umgekehrt auch mehr.
            var present = SelfDamageOf("swords_9", SlotPosition.Present);
            var future = SelfDamageOf("swords_9", SlotPosition.Future);
            Assert.True(future > present,
                $"Zukunft muss teurer sein als Gegenwart ({future} gegen {present}).");
        }

        [Fact]
        public void ReversedCost_NeverKills()
        {
            // An der eigenen Karte zu sterben faehlt sich nach Willkuer an.
            // Der Druck entsteht aus der Zehrung ueber den Run.
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_10");
            run.Hp = 1;
            combat.Hand.Single().Orientation = Orientation.Reversed;
            TestWorld.Place(sys, combat, "swords_10", SlotPosition.Future);
            sys.ResolveTurn(run, combat);

            Assert.True(run.Hp >= 1);
            Assert.False(combat.PlayerLost);
        }

        [Fact]
        public void MajorArcana_AlsoPayTheReversedCost()
        {
            // Regression: der Zweig fuer Grosse Arkana kehrte vor der
            // Preisberechnung zurueck - sie zahlten gar nichts.
            var major = GameCatalog.Cards.First(c => c.IsMajor && c.Major == MajorArcana.Tower);
            var run = TestWorld.Run();
            run.Deck.Add(new CardInstance(major) { Orientation = Orientation.Reversed });
            var sys = TestWorld.System(1);
            var combat = sys.StartCombat(run, TestWorld.Dummy());

            var before = run.Hp;
            sys.PlaceCard(combat, combat.Hand.Single().InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            Assert.True(before - run.Hp > 0, "Ein umgekehrtes Grosses Arkanum muss zahlen.");
        }

        [Fact]
        public void ThreeReadings_WaiveTheCostForThatArcanum()
        {
            var major = GameCatalog.Cards.First(c => c.IsMajor && c.Major == MajorArcana.Tower);
            var run = TestWorld.Run();
            run.Interpretations[major.Id] = 3;
            run.Deck.Add(new CardInstance(major) { Orientation = Orientation.Reversed });
            var sys = TestWorld.System(1);
            var combat = sys.StartCombat(run, TestWorld.Dummy());

            var before = run.Hp;
            sys.PlaceCard(combat, combat.Hand.Single().InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            Assert.Equal(before, run.Hp);
        }

        [Fact]
        public void TwoReadings_DoNotYetWaiveTheCost()
        {
            var major = GameCatalog.Cards.First(c => c.IsMajor && c.Major == MajorArcana.Tower);
            var run = TestWorld.Run();
            run.Interpretations[major.Id] = 2;
            run.Deck.Add(new CardInstance(major) { Orientation = Orientation.Reversed });
            var sys = TestWorld.System(1);
            var combat = sys.StartCombat(run, TestWorld.Dummy());

            var before = run.Hp;
            sys.PlaceCard(combat, combat.Hand.Single().InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            Assert.True(before - run.Hp > 0);
        }

        [Fact]
        public void ReversedStillHitsHarder_TheCostBuysSomething()
        {
            var upright = DamageOf(Orientation.Upright);
            var reversed = DamageOf(Orientation.Reversed);
            Assert.True(reversed > upright,
                $"Ohne Mehrwert waere der Preis sinnlos ({reversed} gegen {upright}).");
        }

        private static int SelfDamageOfUpgraded(string cardId, int level, Shimmer shimmer)
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, cardId);
            var card = combat.Hand.Single();
            card.Orientation = Orientation.Reversed;
            card.Level = level;
            card.Shimmer = shimmer;
            var before = run.Hp;
            TestWorld.Place(sys, combat, cardId, SlotPosition.Future);
            sys.ResolveTurn(run, combat);
            return before - run.Hp;
        }

        private static int DamageOf(Orientation orientation)
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(hp: 100000), 1, "swords_9");
            combat.Hand.Single().Orientation = orientation;
            var before = combat.Enemy.Hp;
            TestWorld.Place(sys, combat, "swords_9", SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            return before - combat.Enemy.Hp;
        }
    }
}
