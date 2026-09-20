// Veraenderlicher Zustand: was im Kampf und im Run passiert.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    [Serializable]
    public sealed class EnemyState
    {
        public EnemyDefinition Definition;
        public int Hp;
        public int Stance;
        public int Sigils;
        public int Shield;
        public int Burn;
        public int AttackRamp;
        public bool BrokenThisRound;
        public IntentType Intent;
        public int IntentValue;

        public EnemyState(EnemyDefinition definition)
        {
            Definition = definition;
            Hp = definition.MaxHp;
            Stance = definition.MaxStance;
            Sigils = definition.Sigils;
        }

        public bool IsDead => Hp <= 0 && Sigils <= 0;
    }

    public sealed class PlayedCardContribution
    {
        public CardInstance Card;
        public int Damage;
        public int Shield;
        public int Healing;
        public float MultContribution;
        public int StanceDamage;

        public float Score => Damage + Shield * 0.65f + Healing * 0.65f + StanceDamage * 1.5f + MultContribution * 10f;
    }

    public sealed class ScoreBreakdown
    {
        public int Chips;
        public float Multiplier;
        public int FateDamage;
        public string ComboName;
        public float RepeatPenalty = 1f;
        public List<string> Notes = new List<string>();
    }

    public sealed class CombatState
    {
        public List<CardInstance> DrawPile = new List<CardInstance>();
        public List<CardInstance> DiscardPile = new List<CardInstance>();
        public List<CardInstance> Hand = new List<CardInstance>();
        public Dictionary<SlotPosition, CardInstance> Slots = new Dictionary<SlotPosition, CardInstance>();
        public Dictionary<string, PlayedCardContribution> Contributions = new Dictionary<string, PlayedCardContribution>();
        public EnemyState Enemy;
        public int Turn = 1;
        public int PlayerShield;
        public int TemporaryLuck;
        public int CardsPlayedThisCombat;
        public int Reshuffles;
        public string LastComboSignature = string.Empty;
        public int SameComboRepeats;
        public int FutureQueuedDamage;
        public int FutureQueuedShield;
        public int FutureQueuedHeal;
        public bool SkipEnemyIntent;
        public int TemporaryDrawBonus;
        public bool PlayerWon;
        public bool PlayerLost;
        public ScoreBreakdown LastScore;
        public List<CardInstance> LastPlayedCards = new List<CardInstance>();
    }

    public sealed class RewardOption
    {
        public RewardType Type;
        public string Title;
        public string Description;
        public CardDefinition Card;
        public CharmDefinition Charm;
        public ItemDefinition Item;
        public int Fate;

        // Zustand der angebotenen Karte als Daten. Vorher wurde er aus dem
        // Anzeigetext zurueckgelesen ("endet auf +", "beginnt mit Indigo") -
        // das bricht bei der ersten Uebersetzung und bei jeder Textaenderung.
        public int CardLevel = 1;
        public Shimmer CardShimmer = Shimmer.Matte;
    }

    public sealed class RunState
    {
        public List<CardInstance> Deck = new List<CardInstance>();
        public List<CardInstance> RemovedCards = new List<CardInstance>();
        public Dictionary<string, int> Charms = new Dictionary<string, int>();
        public Dictionary<string, int> Items = new Dictionary<string, int>();
        public int MaxHp = 72;
        public int Hp = 72;
        public int Gold = 90;
        public int Fate;
        public int Luck = 2;
        public int FightIndex;
        public int EndlessTier;
        public int DeckResonance = 1;
        public int RewardRerolls = 1;
        public int ShopRerolls = 1;
        public int ReviveCharges;
        public int StartShieldBuff;
        public bool FreeNextShopPurchase;
        public int FateScoreTotal;
        public string Prophecy = string.Empty;

        public int CharmStacks(string charmId)
        {
            return Charms.TryGetValue(charmId, out var count) ? count : 0;
        }

        public void AddCharm(CharmDefinition charm, int amount = 1)
        {
            var current = CharmStacks(charm.Id);
            Charms[charm.Id] = Math.Min(charm.MaxStacks, current + amount);
        }

        public void AddItem(ItemDefinition item, int amount = 1)
        {
            if (!Items.ContainsKey(item.Id)) Items[item.Id] = 0;
            Items[item.Id] += amount;
        }

        public bool ConsumeItem(string itemId)
        {
            if (!Items.TryGetValue(itemId, out var count) || count <= 0) return false;
            Items[itemId] = count - 1;
            return true;
        }

        public int DistinctSuitCount()
        {
            return Deck.Select(c => c.Definition.Suit).Where(s => s != Suit.Major).Distinct().Count();
        }
    }
}
