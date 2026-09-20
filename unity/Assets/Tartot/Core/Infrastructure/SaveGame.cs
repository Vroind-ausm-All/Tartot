using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>Ein vollstaendiger Speicherstand eines laufenden Runs.</summary>
    public sealed class SaveData
    {
        public const int CurrentVersion = 1;

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
                .Set("interpretations", WriteCounts(run.Interpretations));
        }

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
                ShopRemovals = node.GetInt("shopRemovals")
            };

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
                .Set("intentValue", enemy.IntentValue);

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
                .Set("lastPlayed", WriteCardRefs(combat.LastPlayedCards));
        }

        private static CombatState ReadCombat(JsonValue node,
            IReadOnlyDictionary<string, CardInstance> pool, string enemyId)
        {
            var definition = GameCatalog.Enemies.FirstOrDefault(e => e.Id == enemyId)
                             ?? GameCatalog.Enemies.First();
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
