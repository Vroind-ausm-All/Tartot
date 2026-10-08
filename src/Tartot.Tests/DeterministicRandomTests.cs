using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Der Zufall ist die Grundlage von Seed-Teilen, Tageskarte und
    /// reproduzierbaren Fehlerberichten. Bricht er, bricht alles darueber.
    /// </summary>
    public class DeterministicRandomTests
    {
        [Fact]
        public void SameSeed_ProducesSameSequence()
        {
            var a = new DeterministicRandom(12345);
            var b = new DeterministicRandom(12345);
            for (var i = 0; i < 200; i++)
                Assert.Equal(a.Next(1000), b.Next(1000));
        }

        [Fact]
        public void DifferentSeed_ProducesDifferentSequence()
        {
            var a = new DeterministicRandom(12345);
            var b = new DeterministicRandom(12346);
            var same = 0;
            for (var i = 0; i < 100; i++)
                if (a.Next(1000) == b.Next(1000)) same++;
            Assert.True(same < 10, $"Zu viele Uebereinstimmungen: {same}");
        }

        [Fact]
        public void KnownSeed_ProducesStableSequence()
        {
            // Aendert sich dieser Wert, aendert sich jeder geteilte Seed und jede
            // Tageskarte. Dann ist das eine bewusste Entscheidung, kein Zufall.
            var rng = new DeterministicRandom(1);
            var actual = string.Join(",", Enumerable.Range(0, 8).Select(_ => rng.Next(1000)));
            Assert.Equal("199,446,908,995,314,408,749,110", actual);
        }

        [Fact]
        public void NamedStreams_AreReproducible()
        {
            var first = new DeterministicRandom(99).Stream("shop");
            var second = new DeterministicRandom(99).Stream("shop");
            Assert.Equal(first.Next(100000), second.Next(100000));
        }

        [Fact]
        public void NamedStreams_AreIndependent()
        {
            // Der entscheidende Punkt: Ziehen aus dem einen Strom darf den
            // anderen nicht verschieben.
            var root = new DeterministicRandom(99);
            var shop = root.Stream("shop");
            var expectedCombat = root.Stream("combat").Next(100000);

            for (var i = 0; i < 50; i++) shop.Next(10);

            var actualCombat = root.Stream("combat").Next(100000);
            Assert.Equal(expectedCombat, actualCombat);
        }

        [Fact]
        public void DifferentStreamNames_Diverge()
        {
            var root = new DeterministicRandom(7);
            Assert.NotEqual(root.Stream("a").Next(1000000), root.Stream("b").Next(1000000));
        }

        [Fact]
        public void Next_StaysInBounds()
        {
            var rng = new DeterministicRandom(3);
            for (var i = 0; i < 2000; i++)
            {
                var v = rng.Next(7);
                Assert.InRange(v, 0, 6);
            }
        }

        [Fact]
        public void Next_IsRoughlyUniform()
        {
            var rng = new DeterministicRandom(5);
            var buckets = new int[4];
            for (var i = 0; i < 40000; i++) buckets[rng.Next(4)]++;
            foreach (var count in buckets)
                Assert.InRange(count, 9400, 10600);
        }

        [Fact]
        public void NextInclusive_IncludesBothEnds()
        {
            var rng = new DeterministicRandom(11);
            var sawMin = false;
            var sawMax = false;
            for (var i = 0; i < 500; i++)
            {
                var v = rng.NextInclusive(3, 5);
                Assert.InRange(v, 3, 5);
                if (v == 3) sawMin = true;
                if (v == 5) sawMax = true;
            }
            Assert.True(sawMin && sawMax);
        }

        [Fact]
        public void Shuffle_IsDeterministicAndKeepsAllElements()
        {
            var a = Enumerable.Range(0, 30).ToList();
            var b = Enumerable.Range(0, 30).ToList();
            new DeterministicRandom(42).Shuffle(a);
            new DeterministicRandom(42).Shuffle(b);
            Assert.Equal(a, b);
            Assert.Equal(Enumerable.Range(0, 30).OrderBy(x => x), a.OrderBy(x => x));
            Assert.NotEqual(Enumerable.Range(0, 30).ToList(), a);
        }

        [Fact]
        public void PickWeighted_RespectsWeights()
        {
            var rng = new DeterministicRandom(17);
            var items = new List<string> { "selten", "haeufig" };
            var weights = new List<float> { 1f, 9f };
            var haeufig = 0;
            for (var i = 0; i < 10000; i++)
                if (rng.PickWeighted(items, weights) == "haeufig") haeufig++;
            Assert.InRange(haeufig, 8700, 9300);
        }

        [Fact]
        public void PickWeighted_IgnoresZeroWeights()
        {
            var rng = new DeterministicRandom(21);
            var items = new List<string> { "nie", "immer" };
            var weights = new List<float> { 0f, 1f };
            for (var i = 0; i < 200; i++)
                Assert.Equal("immer", rng.PickWeighted(items, weights));
        }

        [Fact]
        public void Snapshot_RestoresExactPosition()
        {
            var rng = new DeterministicRandom(2024);
            for (var i = 0; i < 17; i++) rng.Next(100);

            var snapshot = rng.Snapshot();
            var expected = Enumerable.Range(0, 10).Select(_ => rng.Next(1000)).ToList();

            var restored = DeterministicRandom.Restore(snapshot);
            var actual = Enumerable.Range(0, 10).Select(_ => restored.Next(1000)).ToList();

            Assert.Equal(expected, actual);
        }
    }
}
