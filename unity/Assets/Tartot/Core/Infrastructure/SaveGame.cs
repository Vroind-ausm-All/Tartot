using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>Ein vollstaendiger Speicherstand eines laufenden Runs.</summary>
    public sealed class SaveData
    {
        /// <summary>
        /// Version 2: Akte, Verdunkelung, Deuter, Schleier, Ereignisse und
        /// Bossregeln. Version-1-Staende laden weiter - fehlende Felder fallen
        /// auf den Anfang eines Runs zurueck.
        /// </summary>
        public const int CurrentVersion = 2;

        public int Version = CurrentVersion;
        public long Seed;
        public GamePhase Phase = GamePhase.Combat;
        public RandomSnapshot WorldRandom;
        public RandomSnapshot CombatRandom;
        public RandomSnapshot ProgressionRandom;
        public RunState Run;
        /// <summary>Null, wenn gerade kein Kampf laeuft.</summary>
        public CombatState Combat;
        public string EnemyId = string.Empty;
        /// <summary>Das laufende Ereignis - sonst wuerde ein Neustart es neu wuerfeln.</summary>
        public string EventId = string.Empty;
        public bool EventResolved;
        public string EventEpilogue = string.Empty;
    }

    /// <summary>
    /// Speichern und Laden.
    /// </summary>
    /// <remarks>
    /// Auf dem Handy wird die App jederzeit weggeraeumt - auch mitten in einem
    /// Zug. Deshalb wird der Kampf mitgespeichert und nicht nur der Run.
    ///
    /// Karten werden einmal als Pool abgelegt und ueberall sonst nur ueber ihre
    /// Instanz-Id referenziert. Sonst wuerde eine Karte, die zugleich im Deck
    /// und im Ablagestapel liegt, beim Laden zu zwei verschiedenen Objekten -
    /// und Level, Rage und Schimmer wuerden auseinanderlaufen.
    /// </remarks>
    public static class SaveSystem
    {
        public static string Serialize(GameController game, bool indented = false)
        {
            if (game == null) throw new ArgumentNullException(nameof(game));
            var root = JsonValue.Object()
                .Set("version", SaveData.CurrentVersion)
                .Set("seed", game.Seed)
                .Set("phase", game.Phase.ToString());

            root.Set("rng", JsonValue.Object()
                .Set("world", WriteRandom(game.WorldRandomSnapshot))
                .Set("combat", WriteRandom(game.CombatRandomSnapshot))
                .Set("progression", WriteRandom(game.ProgressionRandomSnapshot)));

            // Alle Karteninstanzen, die irgendwo vorkommen, genau einmal.
            var pool = CollectCards(game);
            var cards = JsonValue.Array();
            foreach (var card in pool.Values) cards.Add(WriteCard(card));
            root.Set("cards", cards);

            root.Set("run", WriteRun(game.Run));
            if (game.Combat != null)
            {
                root.Set("combat", WriteCombat(game.Combat));
                root.Set("enemyId", game.Combat.Enemy?.Definition?.Id ?? string.Empty);
            }
            if (game.CurrentEvent != null)
                root.Set("event", JsonValue.Object()
                    .Set("id", game.CurrentEvent.Id)
                    .Set("resolved", game.EventResolved)
                    .Set("epilogue", game.EventEpilogue ?? string.Empty));
            return Json.Write(root, indented);
        }

        public static SaveData Deserialize(string text)
        {
            var root = Json.Parse(text);
            var save = new SaveData
            {
                Version = root.GetInt("version", 1),
                Seed = root.GetLong("seed"),
                Phase = root.GetEnum("phase", GamePhase.Combat),
                EnemyId = root.GetString("enemyId")
            };

            var rng = root.Get("rng") ?? JsonValue.Object();
            save.WorldRandom = ReadRandom(rng.Get("world"));
            save.CombatRandom = ReadRandom(rng.Get("combat"));
            save.ProgressionRandom = ReadRandom(rng.Get("progression"));

            var pool = new Dictionary<string, CardInstance>();
            foreach (var entry in root.GetArray("cards"))
            {
                var card = ReadCard(entry);
                if (card != null) pool[card.InstanceId] = card;
            }

            save.Run = ReadRun(root.Get("run"), pool);
            var combatNode = root.Get("combat");
            if (combatNode != null) save.Combat = ReadCombat(combatNode, pool, save.EnemyId);
            var eventNode = root.Get("event");
            if (eventNode != null)
            {
                save.EventId = eventNode.GetString("id");
                save.EventResolved = eventNode.GetBool("resolved");
                save.EventEpilogue = eventNode.GetString("epilogue");
            }
            return save;
        }

        public static bool TryDeserialize(string text, out SaveData save, out string error)
        {
            try
            {
                save = Deserialize(text);
                error = null;
                return save.Run != null;
            }
            catch (Exception ex)
            {
                save = null;
                error = ex.Message;
                return false;
            }
        }

        // ------------------------------------------------------------ Karten
        private static Dictionary<string, CardInstance> CollectCards(GameController game)
        {
            var pool = new Dictionary<string, CardInstance>();
            void Add(IEnumerable<CardInstance> cards)
            {
                if (cards == null) return;
                foreach (var card in cards)
                    if (card != null) pool[card.InstanceId] = card;
            }

            Add(game.Run.Deck);
            Add(game.Run.RemovedCards);
            if (game.Combat != null)
            {
                Add(game.Combat.DrawPile);
                Add(game.Combat.DiscardPile);
                Add(game.Combat.Hand);
                Add(game.Combat.Slots.Values);
                Add(game.Combat.LastPlayedCards);
            }
            return pool;
        }

        private static JsonValue WriteCard(CardInstance card) => JsonValue.Object()
            .Set("id", card.InstanceId)
            .Set("def", card.Definition.Id)
            .Set("level", card.Level)
            .Set("shimmer", card.Shimmer.ToString())
            .Set("orientation", card.Orientation.ToString())
            .Set("copy", card.IsCopy)
            .Set("xp", card.Experience)
            .Set("marks", card.VictoryMarks)
            .Set("rage", card.Rage);

        private static CardInstance ReadCard(JsonValue node)
        {
            var definitionId = node.GetString("def");
            var definition = GameCatalog.Cards.FirstOrDefault(c => c.Id == definitionId);
            if (definition == null) return null;   // Karte aus einer alten Version
            return new CardInstance(definition, node.GetBool("copy"))
            {
                InstanceId = node.GetString("id"),
                Level = Math.Max(1, node.GetInt("level", 1)),
                Shimmer = node.GetEnum("shimmer", Shimmer.Matte),
                Orientation = node.GetEnum("orientation", Orientation.Upright),
                Experience = node.GetInt("xp"),
                VictoryMarks = node.GetInt("marks"),
                Rage = node.GetInt("rage")
            };
        }

        private static JsonValue WriteCounts(IReadOnlyDictionary<string, int> counts)
        {
            var node = JsonValue.Object();
            foreach (var pair in counts) node.Set(pair.Key, pair.Value);
            return node;
        }

        private static JsonValue WriteCardRefs(IEnumerable<CardInstance> cards)
        {
            var array = JsonValue.Array();
            foreach (var card in cards) array.Add(JsonValue.Of(card.InstanceId));
            return array;
        }

        private static List<CardInstance> ReadCardRefs(JsonValue node, string key,
            IReadOnlyDictionary<string, CardInstance> pool)
        {
            var list = new List<CardInstance>();
            foreach (var entry in node.GetArray(key))
                if (entry.Kind == JsonKind.String && pool.TryGetValue(entry.StringValue, out var card))
                    list.Add(card);
            return list;
        }

        // --------------------------------------------------------------- Run
        private static JsonValue WriteRun(RunState run)
        {
            var charms = JsonValue.Object();
            foreach (var pair in run.Charms) charms.Set(pair.Key, pair.Value);
            var items = JsonValue.Object();
            foreach (var pair in run.Items) items.Set(pair.Key, pair.Value);

            return JsonValue.Object()
                .Set("deck", WriteCardRefs(run.Deck))
                .Set("removed", WriteCardRefs(run.RemovedCards))
                .Set("charms", charms)
                .Set("items", items)
                .Set("maxHp", run.MaxHp)
                .Set("hp", run.Hp)
                .Set("gold", run.Gold)
                .Set("fate", run.Fate)
                .Set("luck", run.Luck)
                .Set("fightIndex", run.FightIndex)
                .Set("endlessTier", run.EndlessTier)
                .Set("deckResonance", run.DeckResonance)
                .Set("rewardRerolls", run.RewardRerolls)
                .Set("shopRerolls", run.ShopRerolls)
                .Set("reviveCharges", run.ReviveCharges)
                .Set("startShieldBuff", run.StartShieldBuff)
                .Set("freeShop", run.FreeNextShopPurchase)
                .Set("fateTotal", run.FateScoreTotal)
                .Set("prophecy", run.Prophecy ?? string.Empty)
                .Set("shopRemovals", run.ShopRemovals)
                .Set("shopRefines", run.ShopRefines)
                .Set("interpretations", WriteCounts(run.Interpretations))
                .Set("deuter", run.DeuterId ?? DeuterCatalog.DefaultId)
                .Set("deuterRule", run.DeuterRule.ToString())
                .Set("veil", run.Veil)
                .Set("daily", run.IsDaily)
                .Set("actBosses", WriteStrings(run.ActBosses))
                .Set("defeatedBosses", WriteStrings(run.DefeatedBosses))
                .Set("seenEnemies", WriteStrings(run.SeenEnemies))
                .Set("seenEvents", WriteStrings(run.SeenEvents))
                .Set("won", run.Won)
                .Set("pendingEnemy", run.PendingEnemyId ?? string.Empty)
                .Set("nextElite", run.NextFightElite)
                .Set("lastPath", run.LastPath.ToString())
                .Set("sinceShop", run.StepsSinceShop)
                .Set("sinceRest", run.StepsSinceRest)
                .Set("bonusRewards", run.BonusRewardChoices)
                .Set("darkness", run.Darkness)
                .Set("storyFlags", WriteStrings(run.StoryFlags.OrderBy(f => f, StringComparer.Ordinal)))
                .Set("newStoryFlags", WriteStrings(run.NewStoryFlags))
                .Set("graveCard", run.GraveCardId ?? string.Empty)
                .Set("graveFight", run.GraveFight)
                .Set("charmPool", run.CharmPool == null
                    ? JsonValue.Null()
                    : WriteStrings(run.CharmPool.OrderBy(f => f, StringComparer.Ordinal)))
                .Set("stats", WriteCounts(run.Stats.ToDictionary()))
                .Set("bestHitCombo", run.Stats.BestHitCombo ?? string.Empty);
        }

        private static JsonValue WriteStrings(IEnumerable<string> values)
        {
            var array = JsonValue.Array();
            foreach (var value in values) array.Add(JsonValue.Of(value));
            return array;
        }

        private static List<string> ReadStrings(JsonValue node, string key) =>
            node.GetArray(key).Where(v => v.Kind == JsonKind.String).Select(v => v.StringValue).ToList();

        private static RunState ReadRun(JsonValue node, IReadOnlyDictionary<string, CardInstance> pool)
        {
            if (node == null) return null;
            var run = new RunState
            {
                MaxHp = node.GetInt("maxHp", 72),
                Hp = node.GetInt("hp", 72),
                Gold = node.GetInt("gold"),
                Fate = node.GetInt("fate"),
                Luck = node.GetInt("luck"),
                FightIndex = node.GetInt("fightIndex"),
                EndlessTier = node.GetInt("endlessTier"),
                DeckResonance = node.GetInt("deckResonance", 1),
                RewardRerolls = node.GetInt("rewardRerolls"),
                ShopRerolls = node.GetInt("shopRerolls"),
                ReviveCharges = node.GetInt("reviveCharges"),
                StartShieldBuff = node.GetInt("startShieldBuff"),
                FreeNextShopPurchase = node.GetBool("freeShop"),
                FateScoreTotal = node.GetInt("fateTotal"),
                Prophecy = node.GetString("prophecy"),
                ShopRemovals = node.GetInt("shopRemovals"),
                ShopRefines = node.GetInt("shopRefines"),
                DeuterId = node.GetString("deuter", DeuterCatalog.DefaultId),
                DeuterRule = node.GetEnum("deuterRule", DeuterRule.None),
                Veil = node.GetInt("veil"),
                IsDaily = node.GetBool("daily"),
                Won = node.GetBool("won"),
                PendingEnemyId = node.GetString("pendingEnemy"),
                NextFightElite = node.GetBool("nextElite"),
                LastPath = node.GetEnum("lastPath", PathType.Fight),
                StepsSinceShop = node.GetInt("sinceShop"),
                StepsSinceRest = node.GetInt("sinceRest"),
                BonusRewardChoices = node.GetInt("bonusRewards"),
                Darkness = node.GetInt("darkness"),
                GraveCardId = node.GetString("graveCard"),
                GraveFight = node.GetInt("graveFight")
            };

            run.ActBosses.AddRange(ReadStrings(node, "actBosses"));
            run.DefeatedBosses.AddRange(ReadStrings(node, "defeatedBosses"));
            run.SeenEnemies.AddRange(ReadStrings(node, "seenEnemies"));
            run.SeenEvents.AddRange(ReadStrings(node, "seenEvents"));
            foreach (var flag in ReadStrings(node, "storyFlags")) run.StoryFlags.Add(flag);
            run.NewStoryFlags.AddRange(ReadStrings(node, "newStoryFlags"));
            var charmPool = node.Get("charmPool");
            if (charmPool != null && charmPool.Kind == JsonKind.Array)
                run.CharmPool = new HashSet<string>(ReadStrings(node, "charmPool"));

            // Staende aus Version 1 kennen keine geplanten Bosse: nachholen,
            // deterministisch aus dem, was der Katalog hergibt.
            if (run.ActBosses.Count == 0)
                for (var act = 1; act <= ActCatalog.ActCount; act++)
                    run.ActBosses.Add(ActCatalog.BossesOf(act).First().Id);

            var stats = new Dictionary<string, int>();
            var statsNode = node.Get("stats");
            if (statsNode != null && statsNode.Kind == JsonKind.Object)
                foreach (var pair in statsNode.Members)
                    stats[pair.Key] = (int)Math.Round(pair.Value.NumberValue);
            run.Stats.Load(stats);
            run.Stats.BestHitCombo = node.GetString("bestHitCombo");

            var interpretations = node.Get("interpretations");
            if (interpretations != null && interpretations.Kind == JsonKind.Object)
                foreach (var pair in interpretations.Members)
                    run.Interpretations[pair.Key] = (int)Math.Round(pair.Value.NumberValue);

            run.Deck.AddRange(ReadCardRefs(node, "deck", pool));
            run.RemovedCards.AddRange(ReadCardRefs(node, "removed", pool));

            var charms = node.Get("charms");
            if (charms != null && charms.Kind == JsonKind.Object)
                foreach (var pair in charms.Members)
                    if (GameCatalog.Charms.Any(c => c.Id == pair.Key))
                        run.Charms[pair.Key] = (int)Math.Round(pair.Value.NumberValue);

            var items = node.Get("items");
            if (items != null && items.Kind == JsonKind.Object)
                foreach (var pair in items.Members)
                    if (GameCatalog.Items.Any(i => i.Id == pair.Key))
                        run.Items[pair.Key] = (int)Math.Round(pair.Value.NumberValue);

            return run;
        }

        // ------------------------------------------------------------- Kampf
        private static JsonValue WriteCombat(CombatState combat)
        {
            var slots = JsonValue.Object();
            foreach (var pair in combat.Slots) slots.Set(pair.Key.ToString(), pair.Value.InstanceId);

            var enemy = combat.Enemy;
            var enemyNode = JsonValue.Object()
                .Set("hp", enemy.Hp)
                .Set("stance", enemy.Stance)
                .Set("sigils", enemy.Sigils)
                .Set("shield", enemy.Shield)
                .Set("burn", enemy.Burn)
                .Set("ramp", enemy.AttackRamp)
                .Set("broken", enemy.BrokenThisRound)
                .Set("intent", enemy.Intent.ToString())
                .Set("intentValue", enemy.IntentValue)
                .Set("phase", enemy.Phase)
                .Set("intentHidden", enemy.IntentHidden)
                .Set("definition", WriteEnemyDefinition(enemy.Definition));

            var contributions = JsonValue.Array();
            foreach (var c in combat.Contributions.Values)
                contributions.Add(JsonValue.Object()
                    .Set("card", c.Card.InstanceId)
                    .Set("damage", c.Damage)
                    .Set("shield", c.Shield)
                    .Set("healing", c.Healing)
                    .Set("stance", c.StanceDamage)
                    .Set("mult", c.MultContribution));

            return JsonValue.Object()
                .Set("draw", WriteCardRefs(combat.DrawPile))
                .Set("discard", WriteCardRefs(combat.DiscardPile))
                .Set("hand", WriteCardRefs(combat.Hand))
                .Set("slots", slots)
                .Set("enemy", enemyNode)
                .Set("turn", combat.Turn)
                .Set("playerShield", combat.PlayerShield)
                .Set("luck", combat.TemporaryLuck)
                .Set("cardsPlayed", combat.CardsPlayedThisCombat)
                .Set("reshuffles", combat.Reshuffles)
                .Set("lastCombo", combat.LastComboSignature ?? string.Empty)
                .Set("comboRepeats", combat.SameComboRepeats)
                .Set("skipIntent", combat.SkipEnemyIntent)
                .Set("drawBonus", combat.TemporaryDrawBonus)
                .Set("lastPlayed", WriteCardRefs(combat.LastPlayedCards))
                .Set("chain", combat.PatternChain)
                .Set("overkill", combat.LastOverkill)
                .Set("blocked", combat.BlockedSlot.HasValue ? combat.BlockedSlot.Value.ToString() : string.Empty)
                .Set("towerCollapses", combat.TowerCollapses)
                .Set("veiled", WriteStrings(combat.VeiledCards.OrderBy(v => v, StringComparer.Ordinal)))
                .Set("marked", combat.MarkedCardId ?? string.Empty)
                .Set("markTurns", combat.MarkTurnsLeft)
                .Set("nextMark", combat.NextMarkTurn)
                .Set("pactPending", combat.PactPending)
                .Set("pactsOffered", combat.PactsOffered)
                .Set("fateBonus", combat.FateBonus)
                .Set("attackBonus", combat.EnemyAttackBonus)
                .Set("worlds", combat.WorldsThisFight)
                .Set("contributions", contributions);
        }

        private static JsonValue WriteEnemyDefinition(EnemyDefinition d)
        {
            var pattern = JsonValue.Array();
            foreach (var intent in d.Pattern) pattern.Add(JsonValue.Of(intent.ToString()));
            var rules = JsonValue.Array();
            foreach (var rule in d.Rules) rules.Add(JsonValue.Of(rule.ToString()));
            return JsonValue.Object()
                .Set("id", d.Id)
                .Set("name", d.Name)
                .Set("maxHp", d.MaxHp)
                .Set("maxStance", d.MaxStance)
                .Set("attack", d.BaseAttack)
                .Set("sigils", d.Sigils)
                .Set("flavor", d.Flavor ?? string.Empty)
                .Set("tier", d.Tier.ToString())
                .Set("act", d.Act)
                .Set("pattern", pattern)
                .Set("rules", rules)
                .Set("weakened", d.RulesWeakened)
                .Set("omen", d.OmenCardId ?? string.Empty)
                .Set("art", d.Art ?? string.Empty)
                .Set("goldFactor", d.GoldFactor);
        }

        /// <summary>
        /// Der Gegner wird vollstaendig gespeichert, nicht nur seine Id: Schleier,
        /// Verdunkelung, Spirale und Finale veraendern ihn gegenueber dem Katalog.
        /// </summary>
        private static EnemyDefinition ReadEnemyDefinition(JsonValue node)
        {
            if (node == null || node.Kind != JsonKind.Object) return null;
            var d = new EnemyDefinition
            {
                Id = node.GetString("id"),
                Name = node.GetString("name"),
                MaxHp = Math.Max(1, node.GetInt("maxHp", 1)),
                MaxStance = node.GetInt("maxStance"),
                BaseAttack = node.GetInt("attack"),
                Sigils = node.GetInt("sigils"),
                Flavor = node.GetString("flavor"),
                Tier = node.GetEnum("tier", EnemyTier.Normal),
                Act = node.GetInt("act", 1),
                RulesWeakened = node.GetBool("weakened"),
                OmenCardId = node.GetString("omen"),
                Art = node.GetString("art"),
                GoldFactor = node.GetFloat("goldFactor", 1f)
            };
            d.Pattern = node.GetArray("pattern")
                .Where(v => v.Kind == JsonKind.String && Enum.TryParse<IntentType>(v.StringValue, out _))
                .Select(v => (IntentType)Enum.Parse(typeof(IntentType), v.StringValue))
                .ToArray();
            foreach (var v in node.GetArray("rules"))
                if (v.Kind == JsonKind.String && Enum.TryParse<BossRule>(v.StringValue, out var rule))
                    d.Rules.Add(rule);
            return d;
        }

        private static CombatState ReadCombat(JsonValue node,
            IReadOnlyDictionary<string, CardInstance> pool, string enemyId)
        {
            var enemyNodeForDefinition = node.Get("enemy");
            var definition = ReadEnemyDefinition(enemyNodeForDefinition?.Get("definition"))
                             ?? GameCatalog.Enemies.FirstOrDefault(e => e.Id == enemyId)?.Clone()
                             ?? GameCatalog.Enemies.First().Clone();
            var combat = new CombatState { Enemy = new EnemyState(definition) };

            var enemyNode = node.Get("enemy");
            if (enemyNode != null)
            {
                combat.Enemy.Hp = enemyNode.GetInt("hp", definition.MaxHp);
                combat.Enemy.Stance = enemyNode.GetInt("stance", definition.MaxStance);
                combat.Enemy.Sigils = enemyNode.GetInt("sigils", definition.Sigils);
                combat.Enemy.Shield = enemyNode.GetInt("shield");
                combat.Enemy.Burn = enemyNode.GetInt("burn");
                combat.Enemy.AttackRamp = enemyNode.GetInt("ramp");
                combat.Enemy.BrokenThisRound = enemyNode.GetBool("broken");
                combat.Enemy.Intent = enemyNode.GetEnum("intent", IntentType.Attack);
                combat.Enemy.IntentValue = enemyNode.GetInt("intentValue");
                combat.Enemy.Phase = enemyNode.GetInt("phase");
                combat.Enemy.IntentHidden = enemyNode.GetBool("intentHidden");
            }

            combat.DrawPile.AddRange(ReadCardRefs(node, "draw", pool));
            combat.DiscardPile.AddRange(ReadCardRefs(node, "discard", pool));
            combat.Hand.AddRange(ReadCardRefs(node, "hand", pool));
            combat.LastPlayedCards.AddRange(ReadCardRefs(node, "lastPlayed", pool));

            var slots = node.Get("slots");
            if (slots != null && slots.Kind == JsonKind.Object)
                foreach (var pair in slots.Members)
                    if (Enum.TryParse<SlotPosition>(pair.Key, out var slot)
                        && pair.Value.Kind == JsonKind.String
                        && pool.TryGetValue(pair.Value.StringValue, out var card))
                        combat.Slots[slot] = card;

            combat.Turn = node.GetInt("turn", 1);
            combat.PlayerShield = node.GetInt("playerShield");
            combat.TemporaryLuck = node.GetInt("luck");
            combat.CardsPlayedThisCombat = node.GetInt("cardsPlayed");
            combat.Reshuffles = node.GetInt("reshuffles");
            combat.LastComboSignature = node.GetString("lastCombo");
            combat.SameComboRepeats = node.GetInt("comboRepeats");
            combat.SkipEnemyIntent = node.GetBool("skipIntent");
            combat.TemporaryDrawBonus = node.GetInt("drawBonus");
            combat.PatternChain = node.GetInt("chain");
            combat.LastOverkill = node.GetInt("overkill");
            var blocked = node.GetString("blocked");
            if (Enum.TryParse<SlotPosition>(blocked, out var blockedSlot)) combat.BlockedSlot = blockedSlot;
            combat.TowerCollapses = node.GetInt("towerCollapses");
            foreach (var id in ReadStrings(node, "veiled")) combat.VeiledCards.Add(id);
            combat.MarkedCardId = node.GetString("marked");
            combat.MarkTurnsLeft = node.GetInt("markTurns");
            combat.NextMarkTurn = node.GetInt("nextMark", 2);
            combat.PactPending = node.GetBool("pactPending");
            combat.PactsOffered = node.GetInt("pactsOffered");
            combat.FateBonus = node.GetFloat("fateBonus");
            combat.EnemyAttackBonus = node.GetFloat("attackBonus");
            combat.WorldsThisFight = node.GetInt("worlds");

            foreach (var entry in node.GetArray("contributions"))
            {
                var cardId = entry.GetString("card");
                if (!pool.TryGetValue(cardId, out var card)) continue;
                combat.Contributions[cardId] = new PlayedCardContribution
                {
                    Card = card,
                    Damage = entry.GetInt("damage"),
                    Shield = entry.GetInt("shield"),
                    Healing = entry.GetInt("healing"),
                    StanceDamage = entry.GetInt("stance"),
                    MultContribution = entry.GetFloat("mult")
                };
            }
            return combat;
        }

        // --------------------------------------------------------------- RNG
        private static JsonValue WriteRandom(RandomSnapshot snapshot) => JsonValue.Object()
            // Als Zeichenkette, weil ulong nicht verlustfrei in double passt.
            .Set("state", snapshot.State.ToString())
            .Set("inc", snapshot.Increment.ToString())
            .Set("draws", snapshot.DrawCount);

        private static RandomSnapshot ReadRandom(JsonValue node)
        {
            if (node == null) return default;
            return new RandomSnapshot
            {
                State = node.GetULong("state"),
                Increment = node.GetULong("inc"),
                DrawCount = node.GetLong("draws")
            };
        }
    }
}
