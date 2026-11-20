using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Der Narr, Karte 0: die Reise des Narren. In der Legung zaehlt er als 1
    /// bis 4, wenn das die Summe 21 schliesst; seine Chips bleiben Rang 1.
    /// </summary>
    public class FoolTests
    {
        private static ScoreBreakdown ScoreOf(params (string Card, SlotPosition Slot)[] layout)
        {
            var ids = layout.Select(l => l.Card).ToArray();
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, ids);
            foreach (var (card, slot) in layout) TestWorld.Place(sys, combat, card, slot);
            return sys.PreviewScore(run, combat);
        }

        [Theory]
        [InlineData(new[] { 8, 10 }, 3)]   // 8 + 10 + 3 = 21
        [InlineData(new[] { 10, 10 }, 1)]  // 10 + 10 + 1: er bleibt 1, auch das ist DIE WELT
        [InlineData(new[] { 17 }, 4)]      // zwei Karten: der Stern (17) + 4
        [InlineData(new[] { 6, 10 }, 1)]   // 5 fehlen: zu weit gesprungen
        [InlineData(new[] { 12, 12 }, 1)]  // ueber 21: nichts zu schliessen
        public void WildValue_ClosesTheWorldWithinFourSteps(int[] others, int expected)
        {
            Assert.Equal(expected, CombatSystem.FoolWildValue(others));
        }

        [Fact]
        public void Fool_TooFarFromTheWorld_StaysOne()
        {
            var score = ScoreOf(("swords_6", SlotPosition.Past),
                                ("major_0", SlotPosition.Present),
                                ("cups_10", SlotPosition.Future));
            Assert.False(score.IsWorld);
            Assert.DoesNotContain(score.Notes, n => n.Contains("Der Narr zählt"));
        }

        [Fact]
        public void Fool_CompletesTheWorld()
        {
            var score = ScoreOf(("swords_8", SlotPosition.Past),
                                ("major_0", SlotPosition.Present),
                                ("cups_10", SlotPosition.Future));
            Assert.True(score.IsWorld);
            Assert.Contains("DIE WELT 21", score.ComboName);
            Assert.Contains(score.Notes, n => n.Contains("Der Narr zählt als 3"));
        }

        [Fact]
        public void Fool_KeepsRankOneChips()
        {
            // Die Wildheit gilt fuer Muster, nicht fuer die Chips der Karte.
            var score = ScoreOf(("swords_8", SlotPosition.Past),
                                ("major_0", SlotPosition.Present),
                                ("cups_10", SlotPosition.Future));
            var foolStep = score.Steps.Single(s => s.Label == "Der Narr");
            Assert.Equal(1, foolStep.Chips);
        }

        [Fact]
        public void Fool_AloneStaysAnOpenSpread()
        {
            var score = ScoreOf(("major_0", SlotPosition.Present));
            Assert.DoesNotContain(score.Notes, n => n.Contains("Der Narr zählt"));
            Assert.False(score.IsWorld);
        }

        [Fact]
        public void Hint_FoolInHandCompletesTheWorld()
        {
            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1,
                "swords_8", "cups_10", "major_0");
            TestWorld.Place(sys, combat, "swords_8", SlotPosition.Past);
            TestWorld.Place(sys, combat, "cups_10", SlotPosition.Present);
            var score = sys.PreviewScore(run, combat);
            Assert.Contains(score.Hints, h => h.Contains("Der Narr vollendet DIE WELT"));
        }
    }
}
