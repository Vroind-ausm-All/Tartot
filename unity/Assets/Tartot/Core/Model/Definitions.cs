// Unveraenderliche Definitionen aus dem Katalog: Charms, Items, Gegner.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    [Serializable]
    public sealed class CharmDefinition
    {
        public string Id;
        public string Name;
        public CharmEffectType Effect;
        public float Magnitude;
        public int MaxStacks;
        public string Description;

        public CharmDefinition(string id, string name, CharmEffectType effect, float magnitude, int maxStacks, string description)
        {
            Id = id; Name = name; Effect = effect; Magnitude = magnitude; MaxStacks = maxStacks; Description = description;
        }
    }

    [Serializable]
    public sealed class ItemDefinition
    {
        public string Id;
        public string Name;
        public ItemEffectType Effect;
        public int Magnitude;
        public string Description;

        public ItemDefinition(string id, string name, ItemEffectType effect, int magnitude, string description)
        {
            Id = id; Name = name; Effect = effect; Magnitude = magnitude; Description = description;
        }
    }

    [Serializable]
    public sealed class EnemyDefinition
    {
        public string Id;
        public string Name;
        public int MaxHp;
        public int MaxStance;
        public int BaseAttack;
        public int Sigils;
        public string Flavor;
    }
}
