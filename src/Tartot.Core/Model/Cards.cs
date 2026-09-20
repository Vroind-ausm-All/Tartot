// Kartendefinition (unveraenderlich, aus dem Katalog) und Karteninstanz
// (veraenderlich, gehoert dem Run: Level, Schimmer, Rage, Orientierung).
using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    [Serializable]
    public sealed class CardDefinition
    {
        public string Id;
        public string Name;
        public Suit Suit;
        public int Rank;
        public int BasePower;
        public MajorArcana? Major;
        public string Description;

        public bool IsMajor => Suit == Suit.Major;
    }

    [Serializable]
    public sealed class CardInstance
    {
        public string InstanceId;
        public CardDefinition Definition;
        public int Level = 1;
        public Shimmer Shimmer = Shimmer.Matte;
        public Orientation Orientation = Orientation.Upright;
        public bool IsCopy;
        public int Experience;
        public int VictoryMarks;
        public int Rage;

        public CardInstance(CardDefinition definition, bool isCopy = false)
        {
            Definition = definition;
            IsCopy = isCopy;
            InstanceId = Guid.NewGuid().ToString("N");
        }

        public int EffectiveRank => Math.Max(1, Definition.Rank + (Level - 1) / 2 + ShimmerBonus());

        public float PowerMultiplier
        {
            get
            {
                var shimmer = 1f + ((int)Shimmer * 0.10f);
                var level = 1f + ((Level - 1) * 0.06f);
                var reversed = Orientation == Orientation.Reversed ? 1.18f : 1f;
                return shimmer * level * reversed;
            }
        }

        public bool IsUpgraded => Level > 1 || Shimmer > Shimmer.Matte;

        public int XpToNextLevel => 20 + (Level - 1) * 15;

        public void AddExperience(int amount)
        {
            Experience += Math.Max(0, amount);
            while (Experience >= XpToNextLevel)
            {
                var need = XpToNextLevel;
                Experience -= need;
                Level++;
                if (Level % 3 == 0 && Shimmer < Shimmer.Gold)
                    Shimmer = (Shimmer)((int)Shimmer + 1);
            }
        }

        public void AddVictoryMark()
        {
            VictoryMarks++;
            if (VictoryMarks >= 3)
            {
                VictoryMarks -= 3;
                Level++;
                if (Shimmer < Shimmer.Gold) Shimmer = (Shimmer)((int)Shimmer + 1);
            }
        }

        private int ShimmerBonus()
        {
            switch (Shimmer)
            {
                case Shimmer.White: return 1;
                case Shimmer.Indigo: return 2;
                case Shimmer.Gold: return 3;
                case Shimmer.Blood: return 4;
                case Shimmer.Black: return 5;
                default: return 0;
            }
        }

        public string ShortLabel()
        {
            var rev = Orientation == Orientation.Reversed ? "↕ " : string.Empty;
            var copy = IsCopy ? "✦ " : string.Empty;
            var rage = Rage > 0 ? $" · RAGE {Rage}/3" : string.Empty;
            return $"{copy}{rev}{Definition.Name} L{Level}{rage}";
        }
    }
}
