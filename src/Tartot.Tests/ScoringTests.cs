using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Das Scoring ist das Herz des Spiels: Chips mal Multiplikator ergibt
    /// Fate-Schaden. Jede Kombination wird einzeln geprueft, damit eine
    /// Balancing-Aenderung nicht versehentlich eine andere mitnimmt.
    /// </summary>
    public class ScoringTests
    {
        private static ScoreBreakdown ScoreOf(params (string Card, SlotPosition Slot)[] layout)
        {
            var ids = layout.Select(l => l.Card).ToArray();
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, ids);
            foreach (var (card, slot) in layout) TestWorld.Place(sys, combat, card, slot);
            return sys.PreviewScore(run, combat);
        }

        [Fact]
        public void Preview_DoesNotGrantRage()
        {
            // Regression: die Vorschau vergab Rage bei einer 21er-Legung. Da die
            // UI bei jeder angefassten Karte eine Vorschau zieht, haette der
            // Spieler durch blosses Hin- und Herschieben Rage gefarmt.
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_3", "wands_8", "cups_10");
            var cards = combat.Hand.ToList();
            TestWorld.Place(sys, combat, "swords_3", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_8", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_10", SlotPosition.Future);

            for (var i = 0; i < 20; i++) sys.PreviewScore(run, combat);
            Assert.All(cards, c => Assert.Equal(0, c.Rage));

            sys.ResolveTurn(run, combat);
            Assert.All(cards, c => Assert.Equal(1, c.Rage));
        }

        [Fact]
        public void Preview_MatchesResolvedScore()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_3", "wands_8", "cups_10");
            TestWorld.Place(sys, combat, "swords_3", SlotPosition.Past);
            TestWorld.Place(sys, combat, "wands_8", SlotPosition.Present);
            TestWorld.Place(sys, combat, "cups_10", SlotPosition.Future);

            var preview = sys.PreviewScore(run, combat);
            var result = sys.ResolveTurn(run, combat);

            Assert.Equal(preview.Chips, result.Score.Chips);
            Assert.Equal(preview.Multiplier, result.Score.Multiplier, 3);
            Assert.Equal(preview.FateDamage, result.Score.FateDamage);
        }

        [Fact]
        public void SumOf21_TriggersTheWorld()
        {
            var score = ScoreOf(("swords_3", SlotPosition.Past),
                                ("wands_8", SlotPosition.Present),
                                ("cups_10", SlotPosition.Future));
            Assert.Contains("DIE WELT 21", score.ComboName);
        }

        [Fact]
        public void SumOf20_DoesNotTriggerTheWorld()
        {
            var score = ScoreOf(("swords_3", SlotPosition.Past),
                                ("wands_8", SlotPosition.Present),
                                ("cups_9", SlotPosition.Future));
            Assert.DoesNotContain("DIE WELT", score.ComboName);
        }

        [Fact]
        public void ConsecutiveRanks_TriggerStraight()
        {
            var score = ScoreOf(("swords_3", SlotPosition.Past),
                                ("wands_4", SlotPosition.Present),
                                ("cups_5", SlotPosition.Future));
            Assert.Contains("Folge", score.ComboName);
        }

        [Fact]
        public void SameSuit_TriggersResonance()
        {
            var score = ScoreOf(("swords_2", SlotPosition.Past),
                                ("swords_5", SlotPosition.Present),
                                ("swords_9", SlotPosition.Future));
            Assert.Contains("Resonanz", score.ComboName);
            Assert.DoesNotContain("Folge", score.ComboName);
        }

        [Fact]
        public void ThreeOfAKind_TriggersTriad()
        {
            var score = ScoreOf(("swords_5", SlotPosition.Past),
                                ("wands_5", SlotPosition.Present),
                                ("cups_5", SlotPosition.Future));
            Assert.Contains("Dreiklang", score.ComboName);
            Assert.DoesNotContain("Paar", score.ComboName);
        }

        [Fact]
        public void TwoOfAKind_TriggersPair()
        {
            var score = ScoreOf(("swords_5", SlotPosition.Past),
                                ("wands_5", SlotPosition.Present),
                                ("cups_2", SlotPosition.Future));
            Assert.Contains("Paar", score.ComboName);
        }

        [Fact]
        public void CombosStack_AndRaiseTheMultiplier()
        {
            var plain = ScoreOf(("swords_2", SlotPosition.Present));
            var world = ScoreOf(("swords_3", SlotPosition.Past),
                                ("wands_8", SlotPosition.Present),
                                ("cups_10", SlotPosition.Future));
            Assert.True(world.Multiplier > plain.Multiplier + 2f,
                $"Die Welt muss den Multiplikator deutlich heben ({world.Multiplier} gegen {plain.Multiplier}).");
        }

        [Fact]
        public void RepeatingTheSameLayout_DecaysTheReward()
        {
            // Gegen das endlose Spammen derselben Legung.
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_3", "wands_8", "cups_10");
            var penalties = new float[4];
            for (var turn = 0; turn < 4; turn++)
            {
                TestWorld.Place(sys, combat, "swords_3", SlotPosition.Past);
                TestWorld.Place(sys, combat, "wands_8", SlotPosition.Present);
                TestWorld.Place(sys, combat, "cups_10", SlotPosition.Future);
                penalties[turn] = sys.ResolveTurn(run, combat).Score.RepeatPenalty;
            }
            Assert.Equal(new[] { 1f, .90f, .75f, .50f }, penalties);
        }

        [Fact]
        public void ChangingTheLayout_ResetsTheDecay()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_3", "wands_8", "cups_10");
            for (var turn = 0; turn < 2; turn++)
            {
                TestWorld.Place(sys, combat, "swords_3", SlotPosition.Past);
                TestWorld.Place(sys, combat, "wands_8", SlotPosition.Present);
                TestWorld.Place(sys, combat, "cups_10", SlotPosition.Future);
                sys.ResolveTurn(run, combat);
            }
            // Andere Legung: die Strafe muss zurueckfallen.
            TestWorld.Place(sys, combat, "swords_3", SlotPosition.Present);
            Assert.Equal(1f, sys.ResolveTurn(run, combat).Score.RepeatPenalty);
        }

        [Fact]
        public void FullRage_BoostsChipsAndIsConsumed()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_9");
            var card = combat.Hand.Single();

            TestWorld.Place(sys, combat, "swords_9", SlotPosition.Present);
            var normal = sys.PreviewScore(run, combat).Chips;

            card.Rage = 3;
            var raging = sys.PreviewScore(run, combat).Chips;
            Assert.True(raging > normal, $"Raserei muss Chips heben ({raging} gegen {normal}).");

            sys.ResolveTurn(run, combat);
            Assert.Equal(0, card.Rage);
        }

        [Fact]
        public void ReversedCards_ScoreHigher()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_9");
            var card = combat.Hand.Single();
            TestWorld.Place(sys, combat, "swords_9", SlotPosition.Present);
            var upright = sys.PreviewScore(run, combat).FateDamage;

            card.Orientation = Orientation.Reversed;
            var reversed = sys.PreviewScore(run, combat).FateDamage;

            Assert.True(reversed > upright,
                $"Umgekehrt muss staerker sein, sonst traegt das Risiko nichts ({reversed} gegen {upright}).");
        }

        [Fact]
        public void FateDamage_IsChipsTimesMultiplierTimesPenalty()
        {
            var score = ScoreOf(("swords_3", SlotPosition.Past),
                                ("wands_8", SlotPosition.Present),
                                ("cups_10", SlotPosition.Future));
            var expected = (int)System.Math.Round(score.Chips * score.Multiplier * score.RepeatPenalty);
            Assert.Equal(System.Math.Max(1, expected), score.FateDamage);
        }
    }
}
