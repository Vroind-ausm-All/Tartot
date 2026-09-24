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
        /// <summary>Wie viele Siegel schon gebrochen sind. Bosse verschaerfen ihre Regel.</summary>
        public int Phase;
        /// <summary>Der Mond: die naechste Absicht ist nicht sichtbar.</summary>
        public bool IntentHidden;

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

        /// <summary>Laenge der Musterkette, wenn diese Legung ausgefuehrt wird.</summary>
        public int Chain;
        /// <summary>Summe 21 - Die Welt.</summary>
        public bool IsWorld;
        /// <summary>Ob die Legung ein kettenfaehiges Muster bildet.</summary>
        public bool HasPattern;
        /// <summary>Fate-Treffer nach Haltung (Deckel oder Durchbruch) - was wirklich ankommt.</summary>
        public int ExpectedHit;
        /// <summary>Die Haltung bricht mit dieser Legung.</summary>
        public bool BreaksStance;
        /// <summary>Der Fate-Treffer allein beendet den Kampf.</summary>
        public bool Lethal;
        /// <summary>Der Mond: eine verdeckte Karte liegt in der Legung, die Vorschau ist ungewiss.</summary>
        public bool Veiled;
        /// <summary>
        /// Beinahe-Treffer: "Die 7 der Kelche vollendet DIE WELT". Nur in der
        /// Vorschau. Das ist der Moment, der eine Hand spannend macht - man
        /// sieht, was fast geht.
        /// </summary>
        public List<string> Hints = new List<string>();
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

        /// <summary>Aufeinanderfolgende Zuege mit einem Muster. Bricht bei einer Legung ohne.</summary>
        public int PatternChain;
        /// <summary>Ueberschuss des letzten, toedlichen Treffers.</summary>
        public int LastOverkill;
        /// <summary>Welt-Legungen in diesem Kampf.</summary>
        public int WorldsThisFight;

        // --- Bossregeln -------------------------------------------------
        /// <summary>Der Turm: dieser Platz ist in diesem Zug eingestuerzt.</summary>
        public SlotPosition? BlockedSlot;
        public int TowerCollapses;
        /// <summary>Der Mond: verdeckte Handkarten (Instanz-Ids).</summary>
        public HashSet<string> VeiledCards = new HashSet<string>();
        /// <summary>Der Tod: gezeichnete Karte und verbleibende Runden.</summary>
        public string MarkedCardId = string.Empty;
        public int MarkTurnsLeft;
        public int NextMarkTurn = 2;
        /// <summary>Der Teufel: ein Pakt liegt auf dem Tisch.</summary>
        public bool PactPending;
        /// <summary>Zusaetzlicher Fate-Schaden aus angenommenen Pakten (0,5 = +50 %).</summary>
        public float FateBonus;
        /// <summary>Zusaetzlicher Gegnerschaden, etwa nach einem abgelehnten Pakt.</summary>
        public float EnemyAttackBonus;
        /// <summary>Wie viele Pakte in diesem Kampf schon angeboten wurden.</summary>
        public int PactsOffered;
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
        public Orientation CardOrientation = Orientation.Upright;
    }

    /// <summary>
    /// Was in einem Run geschah. Speist Prophezeiungen, Rekorde und den
    /// Run-Bericht - also genau die Zahlen, die am Ende "fast" sagen.
    /// </summary>
    public sealed class RunStats
    {
        public int WorldSpreads;
        /// <summary>Wert der staerksten Legung (Chips x Mult), vor dem Haltungsdeckel.</summary>
        public int BestHit;
        public string BestHitCombo = string.Empty;
        public int BestOverkill;
        public int LongestChain;
        public int BossesDefeated;
        public int ElitesDefeated;
        public int FightsWon;
        public int EventsSeen;
        public int PactsAccepted;
        public int ReversedPlayed;
        public int MostShieldAtVictory;
        public int OneTurnKills;
        public int CardsLostToDeath;
        public int TurnsPlayed;
        public int DarkestShimmer;
        /// <summary>Bosse, die mit hoechstens 8 Karten im Deck fielen.</summary>
        public int ThinBossKills;
        /// <summary>Die meisten Welt-Legungen in einem einzigen Kampf.</summary>
        public int MostWorldsInFight;
        /// <summary>Hoechste Verdunkelung, die der Run erreicht hat.</summary>
        public int PeakDarkness;
        /// <summary>Die meisten schwarzen Karten gleichzeitig im Deck.</summary>
        public int MostBlackCards;

        /// <summary>Alle Werte unter stabilen Schluesseln - fuer Meta-Zaehler und Speicherstand.</summary>
        public Dictionary<string, int> ToDictionary() => new Dictionary<string, int>
        {
            ["worldSpreads"] = WorldSpreads,
            ["bestHit"] = BestHit,
            ["bestOverkill"] = BestOverkill,
            ["longestChain"] = LongestChain,
            ["bossesDefeated"] = BossesDefeated,
            ["elitesDefeated"] = ElitesDefeated,
            ["fightsWon"] = FightsWon,
            ["eventsSeen"] = EventsSeen,
            ["pactsAccepted"] = PactsAccepted,
            ["reversedPlayed"] = ReversedPlayed,
            ["mostShield"] = MostShieldAtVictory,
            ["oneTurnKills"] = OneTurnKills,
            ["cardsLostToDeath"] = CardsLostToDeath,
            ["turnsPlayed"] = TurnsPlayed,
            ["darkestShimmer"] = DarkestShimmer,
            ["thinBossKills"] = ThinBossKills,
            ["mostWorldsInFight"] = MostWorldsInFight,
            ["peakDarkness"] = PeakDarkness,
            ["mostBlackCards"] = MostBlackCards
        };

        public void Load(IReadOnlyDictionary<string, int> values)
        {
            int V(string key) => values != null && values.TryGetValue(key, out var v) ? v : 0;
            WorldSpreads = V("worldSpreads");
            BestHit = V("bestHit");
            BestOverkill = V("bestOverkill");
            LongestChain = V("longestChain");
            BossesDefeated = V("bossesDefeated");
            ElitesDefeated = V("elitesDefeated");
            FightsWon = V("fightsWon");
            EventsSeen = V("eventsSeen");
            PactsAccepted = V("pactsAccepted");
            ReversedPlayed = V("reversedPlayed");
            MostShieldAtVictory = V("mostShield");
            OneTurnKills = V("oneTurnKills");
            CardsLostToDeath = V("cardsLostToDeath");
            TurnsPlayed = V("turnsPlayed");
            DarkestShimmer = V("darkestShimmer");
            ThinBossKills = V("thinBossKills");
            MostWorldsInFight = V("mostWorldsInFight");
            PeakDarkness = V("peakDarkness");
            MostBlackCards = V("mostBlackCards");
        }
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
        /// <summary>Wie oft beim Haendler gegen Gold geloescht wurde - der Preis steigt.</summary>
        public int ShopRemovals;
        /// <summary>Wie oft beim Haendler veredelt wurde - der Preis steigt.</summary>
        public int ShopRefines;

        // --- Figur und Schwierigkeit ------------------------------------
        public string DeuterId = DeuterCatalog.DefaultId;
        public DeuterRule DeuterRule = DeuterRule.None;
        public int Veil;
        /// <summary>Tageskarte: gleicher Seed, gleiche Figur, gleicher Schleier fuer alle.</summary>
        public bool IsDaily;

        // --- Bogen des Runs ---------------------------------------------
        /// <summary>1-3 Akte, 4 Finale, 5 Spirale.</summary>
        public int Act => ActCatalog.ActOf(FightIndex);
        /// <summary>Der angekuendigte Boss je Akt, beim Start geplant.</summary>
        public List<string> ActBosses = new List<string>();
        /// <summary>Besiegte Bosse. Das Finale setzt sich aus ihren Regeln zusammen.</summary>
        public List<string> DefeatedBosses = new List<string>();
        public List<string> SeenEnemies = new List<string>();
        public List<string> SeenEvents = new List<string>();
        /// <summary>Das Finale ist geschlagen - alles danach ist Spirale.</summary>
        public bool Won;
        /// <summary>Ein Ereignis kann den naechsten Gegner bestimmen.</summary>
        public string PendingEnemyId = string.Empty;
        public bool NextFightElite;
        public PathType LastPath = PathType.Fight;
        public int StepsSinceShop;
        public int StepsSinceRest;
        /// <summary>Zusaetzliche Belohnungswahlen, die ein Ereignis gewaehrt hat.</summary>
        public int BonusRewardChoices;

        // --- Verdunkelung -----------------------------------------------
        /// <summary>
        /// 0-100. Steigt mit Bossen, Pakten und dunklen Entscheidungen. Je
        /// dunkler, desto staerker umgekehrte Karten - und desto haerter die
        /// Gegner. Das ist die Achse "je weiter, desto duesterer".
        /// </summary>
        public int Darkness;
        public int DarknessStage => Math.Min(5, Math.Max(0, Darkness) / 20);

        public void AddDarkness(int amount)
        {
            Darkness = Math.Max(0, Math.Min(100, Darkness + amount));
            Stats.PeakDarkness = Math.Max(Stats.PeakDarkness, Darkness);
        }

        // --- Geschichte ueber Runs hinweg -------------------------------
        /// <summary>
        /// Story-Flags: beim Start aus dem Meta-Fortschritt kopiert und im Run
        /// ergaenzt. Kopie statt Verweis, damit ein Run reproduzierbar bleibt.
        /// </summary>
        public HashSet<string> StoryFlags = new HashSet<string>();
        /// <summary>In diesem Run neu gesetzte Flags - wandern am Ende in den Meta-Fortschritt.</summary>
        public List<string> NewStoryFlags = new List<string>();

        public void SetStoryFlag(string flag)
        {
            if (string.IsNullOrEmpty(flag) || !StoryFlags.Add(flag)) return;
            NewStoryFlags.Add(flag);
        }

        /// <summary>Die Karte aus dem letzten gescheiterten Run - fuer das Grab.</summary>
        public string GraveCardId = string.Empty;
        public int GraveFight;

        /// <summary>
        /// Charms, die angeboten werden duerfen. Null = alle. Mit
        /// Meta-Fortschritt sind es die Grundausstattung plus Freigeschaltetes.
        /// </summary>
        public HashSet<string> CharmPool;

        public bool CharmAllowed(string charmId) => CharmPool == null || CharmPool.Contains(charmId);

        public RunStats Stats = new RunStats();

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

        /// <summary>
        /// Freigeschaltete Lesarten je Grossem Arkanum, als Abzug aus dem
        /// Meta-Fortschritt beim Run-Start.
        /// </summary>
        /// <remarks>
        /// Bewusst eine Kopie und kein Verweis auf MetaProgress: ein Run muss
        /// in sich geschlossen und reproduzierbar sein. Sonst wuerde ein
        /// Speicherstand anders weiterlaufen, nur weil zwischendurch eine
        /// Lesart dazukam.
        /// </remarks>
        public readonly Dictionary<string, int> Interpretations = new Dictionary<string, int>();

        public int InterpretationCount(string cardId) =>
            cardId != null && Interpretations.TryGetValue(cardId, out var count) ? count : 0;

        public int DistinctSuitCount()
        {
            return Deck.Select(c => c.Definition.Suit).Where(s => s != Suit.Major).Distinct().Count();
        }
    }
}
