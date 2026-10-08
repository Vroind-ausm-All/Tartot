using System;
using System.Collections.Generic;

namespace Tartot.Core
{
    /// <summary>
    /// Reproduzierbarer Zufallsgenerator (PCG32).
    /// </summary>
    /// <remarks>
    /// Warum nicht <see cref="System.Random"/>? Dessen Algorithmus ist nicht
    /// spezifiziert und hat sich mit .NET 6 geaendert. Derselbe Seed liefert in
    /// Unity (Mono/IL2CPP) und in den Tests (.NET 8) unterschiedliche Folgen.
    /// Fuer ein Roguelike mit geteilten Seeds, Tageskarte, Bestenliste und
    /// reproduzierbaren Fehlerberichten ist das untragbar.
    ///
    /// PCG32 ist klein, schnell, gut verteilt und arbeitet nur auf ulong-
    /// Arithmetik mit definiertem Ueberlauf - also ueberall identisch.
    ///
    /// Benannte Teilstroeme sind kein Luxus: liegen Kampf, Belohnung und Laden
    /// auf demselben Strom, verschiebt ein Reroll im Laden die Kartenzuege im
    /// naechsten Kampf. Genau das macht Seeds wertlos.
    /// </remarks>
    public sealed class DeterministicRandom
    {
        private const ulong Multiplier = 6364136223846793005UL;
        private const ulong DefaultIncrement = 1442695040888963407UL;

        private ulong _state;
        private readonly ulong _increment;

        /// <summary>Wie oft gezogen wurde. Nur fuer Diagnose und Divergenzsuche.</summary>
        public long DrawCount { get; private set; }

        public DeterministicRandom(long seed, ulong increment = DefaultIncrement)
        {
            // Das Inkrement muss ungerade sein, sonst verkuerzt sich die Periode.
            _increment = increment | 1UL;
            _state = 0UL;
            NextUInt();
            _state = unchecked(_state + (ulong)seed);
            NextUInt();
        }

        private DeterministicRandom(ulong state, ulong increment, long drawCount)
        {
            _state = state;
            _increment = increment | 1UL;
            DrawCount = drawCount;
        }

        /// <summary>
        /// Ein eigener Strom, abgeleitet vom aktuellen Zustand. Ziehungen aus dem
        /// abgeleiteten Strom veraendern diesen hier nicht.
        /// </summary>
        public DeterministicRandom Stream(string name)
        {
            // FNV-1a ueber den Namen: stabil ueber Plattformen und Laufzeiten,
            // anders als string.GetHashCode().
            var hash = 14695981039346656037UL;
            for (var i = 0; i < name.Length; i++)
                hash = unchecked((hash ^ name[i]) * 1099511628211UL);
            return new DeterministicRandom(unchecked((long)(_state ^ hash)), unchecked(_increment + hash));
        }

        public uint NextUInt()
        {
            var old = _state;
            _state = unchecked(old * Multiplier + _increment);
            DrawCount++;
            var xorshifted = (uint)(((old >> 18) ^ old) >> 27);
            var rot = (int)(old >> 59);
            return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
        }

        /// <summary>Ganzzahl in [0, exclusiveMax). Ohne Modulo-Verzerrung.</summary>
        public int Next(int exclusiveMax)
        {
            if (exclusiveMax <= 1) return 0;
            var bound = (uint)exclusiveMax;
            // Rueckweisungsbereich: die letzten unvollstaendigen Werte verwerfen,
            // sonst sind kleine Ergebnisse minimal wahrscheinlicher.
            var threshold = (uint)(-(int)bound) % bound;
            while (true)
            {
                var r = NextUInt();
                if (r >= threshold) return (int)(r % bound);
            }
        }

        /// <summary>Ganzzahl in [min, max], beide einschliesslich.</summary>
        public int NextInclusive(int min, int max)
        {
            if (max <= min) return min;
            return min + Next(max - min + 1);
        }

        /// <summary>Gleitkommazahl in [0, 1).</summary>
        public float NextFloat() => (NextUInt() >> 8) * (1.0f / 16777216.0f);

        public bool Chance(float probability) => NextFloat() < probability;

        public bool ChancePercent(float percent) => NextFloat() * 100f < percent;

        public T Pick<T>(IReadOnlyList<T> list)
        {
            if (list == null || list.Count == 0) return default;
            return list[Next(list.Count)];
        }

        /// <summary>Gewichtete Wahl. Nicht-positive Gewichte zaehlen als 0.</summary>
        public T PickWeighted<T>(IReadOnlyList<T> items, IReadOnlyList<float> weights)
        {
            if (items == null || items.Count == 0) return default;
            if (weights == null || weights.Count != items.Count) return Pick(items);

            var total = 0f;
            for (var i = 0; i < weights.Count; i++)
                if (weights[i] > 0f) total += weights[i];
            if (total <= 0f) return Pick(items);

            var target = NextFloat() * total;
            var running = 0f;
            for (var i = 0; i < items.Count; i++)
            {
                if (weights[i] <= 0f) continue;
                running += weights[i];
                if (target < running) return items[i];
            }
            return items[items.Count - 1];
        }

        /// <summary>Fisher-Yates, in-place.</summary>
        public void Shuffle<T>(IList<T> list)
        {
            if (list == null) return;
            for (var i = list.Count - 1; i > 0; i--)
            {
                var j = Next(i + 1);
                var tmp = list[i];
                list[i] = list[j];
                list[j] = tmp;
            }
        }

        /// <summary>Zieht bis zu <paramref name="count"/> verschiedene Elemente.</summary>
        public List<T> PickDistinct<T>(IReadOnlyList<T> source, int count)
        {
            var copy = new List<T>(source);
            Shuffle(copy);
            if (count < copy.Count) copy.RemoveRange(count, copy.Count - count);
            return copy;
        }

        // ------------------------------------------------------------ Speichern
        public RandomSnapshot Snapshot() => new RandomSnapshot
        {
            State = _state,
            Increment = _increment,
            DrawCount = DrawCount
        };

        public static DeterministicRandom Restore(RandomSnapshot snapshot) =>
            new DeterministicRandom(snapshot.State, snapshot.Increment, snapshot.DrawCount);
    }

    /// <summary>Serialisierbarer Zustand eines <see cref="DeterministicRandom"/>.</summary>
    [Serializable]
    public struct RandomSnapshot
    {
        public ulong State;
        public ulong Increment;
        public long DrawCount;
    }
}
