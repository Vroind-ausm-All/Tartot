// Aufzaehlungen des Spiels. Die Reihenfolge der Werte ist Teil des
// Speicherformats - neue Eintraege gehoeren ans Ende, nicht in die Mitte.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    public enum Suit { Swords, Wands, Cups, Pentacles, Major }
    public enum Orientation { Upright, Reversed }
    public enum SlotPosition { Past, Present, Future }
    public enum Shimmer { Matte, White, Indigo, Gold, Blood, Black }
    public enum GamePhase { Combat, Reward, PathChoice, Shop, Ritual, Oracle, GameOver, Event, BossLoot, Rest, Victory }
    public enum RewardType { Card, Charm, Item, Fate }
    public enum PathType { Fight, Shop, Ritual, Oracle, Elite, Event, Rest }
    public enum IntentType { Attack, Guard, Hex, Drain, Frenzy }

    /// <summary>Wie schwer ein Gegner innerhalb seines Akts ist.</summary>
    public enum EnemyTier { Normal, Elite, Boss, Finale }

    /// <summary>
    /// Die Grundregel, die ein Boss bricht. Jeder Boss nimmt dir eine
    /// Selbstverstaendlichkeit weg - nicht mehr HP, sondern eine andere Frage.
    /// </summary>
    public enum BossRule { None, Tower, Moon, Death, Wheel, Devil, HangedMan }

    /// <summary>Sonderregel eines Deuters (spielbare Figur).</summary>
    public enum DeuterRule { None, BloodReader, Bookkeeper, Hermit }

    /// <summary>Was nach einem Boss mit dem gefallenen Omen geschieht.</summary>
    public enum BossLootChoice { Soak, Bind, Banish }

    public enum CharmEffectType
    {
        SwordsChips, WandsBurn, SelfDamagePower, DebuffedLifesteal, FirstAttackBonus,
        EveryThirdCardDamage, AttackVsAttacker, KillRamp, Thorns, FuturePower,
        PentacleShield, OverhealToShield, StartShield, DebuffWard, LowHpShield,
        ReversedShield, ShieldRetention, EveryFifthHeal, Phoenix, GlassHeart,
        CopyPower, RemoveDiscount, OpeningDraw, DiscardBoost, UpgradedPower,
        ReshuffleDraw, MemoryReturn, CopyBase, RemoveMaxHp, OracleSight,
        SwordBridge, WandCombo, CupAfterAttack, PentacleGold, FourSuitBonus,
        HealDamage, BurnPower, ArmorPierce, PentacleLuck, CupCleanse,
        StartLuck, ShopDiscount, RewardReroll, RareChance, PositiveEvent,
        Greed, ExtraRewardChoice, UpgradedRewardChance, EliteCharmChance, WorldThread
    }

    public enum ItemEffectType
    {
        MirrorCard, RemoveCard, FlipCard, UpgradeCard, ReorderDeck,
        Heal, CleanseReveal, TowerBlast, DevilsBargain, LinkCards,
        SkipEnemyIntent, GainGold, Unlock, RerollShop, Revive,
        GainLuck, StartShieldBuff, TransformCard, RerollReward, RevealPath,
        RemoveCurse, RestoreRemovedCard
    }

    public enum MajorArcana
    {
        Fool = 0, Magician = 1, HighPriestess = 2, Empress = 3, Emperor = 4,
        Hierophant = 5, Lovers = 6, Chariot = 7, Strength = 8, Hermit = 9,
        Wheel = 10, Justice = 11, HangedMan = 12, Death = 13, Temperance = 14,
        Devil = 15, Tower = 16, Star = 17, Moon = 18, Sun = 19,
        Judgement = 20, World = 21
    }
}
