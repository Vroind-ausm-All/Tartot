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

        public EnemyTier Tier = EnemyTier.Normal;
        /// <summary>Akt, in dem der Gegner auftaucht (1-3, 4 = Finale).</summary>
        public int Act = 1;
        /// <summary>
        /// Absichtsfolge, die der Gegner zyklisch durchlaeuft. Leer heisst:
        /// das allgemeine Muster (Angriff, Schild jede dritte, Fluch jede
        /// fuenfte Runde). Ein eigenes Muster macht Gegner lesbar - und
        /// lesbare Gegner kann man ueberlisten.
        /// </summary>
        public IntentType[] Pattern = new IntentType[0];
        /// <summary>Die Regeln, die dieser Gegner bricht (Bosse, Finale).</summary>
        public List<BossRule> Rules = new List<BossRule>();
        /// <summary>Im Finale wirken die Regeln der besiegten Bosse abgeschwaecht.</summary>
        public bool RulesWeakened;
        /// <summary>Das Grosse Arkanum, das ein Boss verkoerpert - fuer BINDEN.</summary>
        public string OmenCardId = string.Empty;
        /// <summary>Schluessel fuer die Silhouette in der Darstellung.</summary>
        public string Art = string.Empty;
        /// <summary>Mehr Gold beim Sieg (die fette Ratte des Haendlers).</summary>
        public float GoldFactor = 1f;

        public bool IsBoss => Tier == EnemyTier.Boss || Tier == EnemyTier.Finale;

        /// <summary>Flache Kopie - der Katalog bleibt unveraendert.</summary>
        public EnemyDefinition Clone()
        {
            var copy = (EnemyDefinition)MemberwiseClone();
            copy.Pattern = (IntentType[])Pattern.Clone();
            copy.Rules = new List<BossRule>(Rules);
            return copy;
        }
    }

    /// <summary>
    /// Eine spielbare Figur. Jeder Deuter bringt ein eigenes Startdeck und
    /// eine eigene Grundregel mit - der wichtigste Wiederspiel-Hebel neben
    /// den Arkana, weil er dieselben Karten anders lesen laesst.
    /// </summary>
    public sealed class DeuterDefinition
    {
        public string Id;
        public string Name;
        public string Subtitle;
        public string RuleText;
        public DeuterRule Rule;
        public int MaxHp = 72;
        public int Gold = 90;
        public int Luck = 2;
        public string[] Deck = new string[0];
        /// <summary>Karten-Ids im Startdeck, die umgekehrt liegen.</summary>
        public string[] ReversedCards = new string[0];
        public string[] Charms = new string[0];
        public string[] Items = new string[0];
        /// <summary>Leer = von Anfang an spielbar.</summary>
        public string UnlockedBy = string.Empty;
    }

    /// <summary>Eine Schwierigkeitsstufe. Sie stapeln: Schleier 5 enthaelt 1-4.</summary>
    public sealed class VeilDefinition
    {
        public int Level;
        public string Name;
        public string Text;
    }
}
