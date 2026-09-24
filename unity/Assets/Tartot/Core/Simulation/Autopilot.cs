using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core.Simulation
{
    /// <summary>Ein einzelner Kampf eines Autopilot-Runs - fuer die Kurve je Kampfindex.</summary>
    public sealed class FightRecord
    {
        public int Index;
        public string EnemyId = string.Empty;
        public EnemyTier Tier;
        public int Turns;
        public float HpBefore;
        public float HpAfter;
        public bool Died;
        public int GoldAfter;
    }

    /// <summary>Was ein Autopilot-Run am Ende erreicht hat.</summary>
    public sealed class RunOutcome
    {
        public readonly List<FightRecord> Fights = new List<FightRecord>();
        /// <summary>Die vollstaendige Run-Statistik (RunStats.ToDictionary).</summary>
        public Dictionary<string, int> Stats = new Dictionary<string, int>();
        public int FightsCleared;
        public int DeckSize;
        public int Gold;
        public int Fate;
        public int Hp;
        public int CharmStacks;
        public int TurnsPlayed;
        public int DeckResonance;
        public int ShopRemovals;
        public int GoldSpent;
        public string DiedAgainst = "-";
        public bool ReachedLimit;
        /// <summary>Das Finale wurde geschlagen.</summary>
        public bool Won;
        /// <summary>1-3 Akte, 4 Finale, 5 Spirale.</summary>
        public int ActReached;
        public int SpiralDepth;
        public int Darkness;
        public int WorldSpreads;
        public int LongestChain;
        public int BestHit;
        public int EventsSeen;
        public int PactsAccepted;
        public int CardsLostToDeath;
        public int BossesDefeated;
        public int DarkestShimmer;
        public int RestsTaken;
        public int ElitesFought;
        public int ShopVisits;
        public int PathsWithShop;

        /// <summary>Kurzform zum Vergleich zweier Laeufe (Determinismus-Tests).</summary>
        public string Signature =>
            $"{FightsCleared}|{DeckSize}|{Gold}|{Fate}|{Hp}|{CharmStacks}|{TurnsPlayed}|{DiedAgainst}";
    }

    /// <summary>
    /// Spielt das Spiel ohne Spieler.
    /// </summary>
    /// <remarks>
    /// Der Autopilot soll nicht optimal spielen, sondern *vernuenftig* - etwa
    /// auf dem Niveau eines aufmerksamen Spielers im dritten Run. Gewinnt er
    /// fast immer, ist das Spiel zu leicht; kommt er nie durch, zu schwer.
    ///
    /// Er liegt im Kern, weil Tests und Balancing-Simulation ihn beide
    /// brauchen - und weil dieselbe Bewertung spaeter einen Zughinweis im
    /// Tutorial speisen kann.
    /// </remarks>
    public sealed class Autopilot
    {
        private static readonly SlotPosition[] AllSlots =
            { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future };

        /// <summary>Obergrenze fuer die Deckgroesse, ab der nur noch gedünnt wird.</summary>
        public int DeckTarget = 14;
        public int MaxTurnsPerFight = 120;

        /// <summary>
        /// Dreht das Startdeck komplett auf die umgekehrte Seite. Nur fuer
        /// Messreihen: so laesst sich der Handel "mehr Kraft gegen
        /// Selbstschaden" isoliert gegen dasselbe Deck aufrecht vergleichen.
        /// </summary>
        public bool ReverseStartingDeck;

        /// <summary>Meta-Fortschritt, aus dem die Lesarten uebernommen werden.</summary>
        public MetaProgress Meta;

        /// <summary>Figur und Schleier. Null = Wahrsagerin ohne Schleier.</summary>
        public RunSetup Setup;

        /// <summary>Nach dem Finale in die Spirale weitergehen (fuer Tiefenmessungen).</summary>
        public bool ContinueIntoSpiral;

        /// <summary>Das Spiel des letzten Runs - etwa um es im Meta-Fortschritt zu verbuchen.</summary>
        public GameController LastGame { get; private set; }

        public RunOutcome PlayRun(long seed, int maxFights = 30)
        {
            var game = new GameController(seed, Meta, Setup);
            LastGame = game;
            if (ReverseStartingDeck)
                foreach (var card in game.Run.Deck) card.Orientation = Orientation.Reversed;
            var outcome = new RunOutcome();
            var guard = 0;

            while (game.Phase != GamePhase.GameOver && game.Run.FightIndex < maxFights && guard++ < 5000)
            {
                switch (game.Phase)
                {
                    case GamePhase.Combat:
                    {
                        var record = new FightRecord
                        {
                            Index = game.Run.FightIndex,
                            EnemyId = game.Combat.Enemy.Definition.Id,
                            Tier = game.Combat.Enemy.Definition.Tier,
                            HpBefore = (float)game.Run.Hp / Math.Max(1, game.Run.MaxHp)
                        };
                        record.Turns = PlayCombat(game);
                        outcome.TurnsPlayed += record.Turns;
                        record.HpAfter = (float)game.Run.Hp / Math.Max(1, game.Run.MaxHp);
                        record.Died = game.Phase == GamePhase.GameOver;
                        record.GoldAfter = game.Run.Gold;
                        outcome.Fights.Add(record);
                        if (record.Died)
                            outcome.DiedAgainst = game.Combat?.Enemy?.Definition?.Name ?? "-";
                        break;
                    }
                    case GamePhase.Reward:
                        TakeReward(game);
                        break;
                    case GamePhase.PathChoice:
                        var path = ChoosePath(game);
                        if (path == PathType.Elite) outcome.ElitesFought++;
                        if (path == PathType.Shop) outcome.ShopVisits++;
                        if (game.Paths.Contains(PathType.Shop)) outcome.PathsWithShop++;
                        game.ChoosePath(path);
                        break;
                    case GamePhase.Shop:
                        Shop(game);
                        break;
                    case GamePhase.Ritual:
                        Ritual(game);
                        break;
                    case GamePhase.Oracle:
                        game.ChooseOracle("XXI");
                        game.ContinueFromOffgame();
                        break;
                    case GamePhase.Event:
                        PlayEvent(game);
                        break;
                    case GamePhase.Rest:
                        outcome.RestsTaken++;
                        Rest(game);
                        break;
                    case GamePhase.BossLoot:
                        game.ChooseBossLoot(ChooseBossLoot(game));
                        break;
                    case GamePhase.Victory:
                        if (ContinueIntoSpiral) game.ContinueIntoSpiral();
                        else game.EndRun();
                        break;
                }
            }

            outcome.FightsCleared = game.Run.FightIndex;
            outcome.DeckSize = game.Run.Deck.Count;
            outcome.Gold = game.Run.Gold;
            outcome.Fate = game.Run.FateScoreTotal;
            outcome.Hp = game.Run.Hp;
            outcome.CharmStacks = game.Run.Charms.Values.Sum();
            outcome.DeckResonance = game.Run.DeckResonance;
            outcome.ShopRemovals = game.Run.ShopRemovals;
            outcome.ReachedLimit = game.Run.FightIndex >= maxFights;
            outcome.Won = game.Run.Won;
            outcome.ActReached = game.Run.Act;
            outcome.SpiralDepth = ActCatalog.SpiralDepth(game.Run.FightIndex);
            outcome.Darkness = game.Run.Darkness;
            var stats = game.Run.Stats;
            outcome.Stats = stats.ToDictionary();
            outcome.WorldSpreads = stats.WorldSpreads;
            outcome.LongestChain = stats.LongestChain;
            outcome.BestHit = stats.BestHit;
            outcome.EventsSeen = stats.EventsSeen;
            outcome.PactsAccepted = stats.PactsAccepted;
            outcome.CardsLostToDeath = stats.CardsLostToDeath;
            outcome.BossesDefeated = stats.BossesDefeated;
            outcome.DarkestShimmer = stats.DarkestShimmer;
            return outcome;
        }

        // ------------------------------------------------------------ Kampf
        public int PlayCombat(GameController game)
        {
            var turns = 0;
            while (game.Phase == GamePhase.Combat && turns < MaxTurnsPerFight)
            {
                turns++;
                if (game.Combat.PactPending) game.AnswerPact(AcceptPact(game));
                UseHealingIfLow(game);
                var layout = BestLayout(game);
                ClearSlots(game);
                foreach (var (instanceId, slot) in layout)
                    game.CombatSystem.PlaceCard(game.Combat, instanceId, slot);

                if (game.Combat.Slots.Count == 0)
                {
                    if (game.Combat.Hand.Count == 0) break;
                    foreach (var slot in AllSlots)
                        if (game.CombatSystem.PlaceCard(game.Combat, game.Combat.Hand[0].InstanceId, slot)) break;
                    if (game.Combat.Slots.Count == 0) break;
                }
                game.ResolveTurn();
            }
            return turns;
        }

        /// <summary>
        /// Probiert alle Karten-/Positions-Kombinationen durch und nimmt die mit
        /// der besten Vorschau. Bei fuenf Handkarten und drei Plaetzen sind das
        /// wenige hundert Faelle - billig genug fuer Brute Force.
        /// </summary>
        private List<(string InstanceId, SlotPosition Slot)> BestLayout(GameController game)
        {
            var hand = game.Combat.Hand.ToList();
            var best = new List<(string, SlotPosition)>();
            var bestValue = float.MinValue;
            var incoming = ExpectedIncomingDamage(game);
            // Der Turm: ein eingestuerzter Platz kommt gar nicht erst in Frage.
            var open = AllSlots.Where(s => !game.Combat.BlockedSlot.HasValue || game.Combat.BlockedSlot.Value != s).ToList();

            foreach (var combo in Combinations(hand, Math.Min(open.Count, hand.Count)))
            foreach (var slots in Permutations(open, combo.Count))
            {
                ClearSlots(game);
                for (var i = 0; i < combo.Count; i++)
                    game.CombatSystem.PlaceCard(game.Combat, combo[i].InstanceId, slots[i]);

                var value = Evaluate(game, combo, slots, incoming);
                if (value > bestValue)
                {
                    bestValue = value;
                    best = combo.Select((c, i) => (c.InstanceId, slots[i])).ToList();
                }
            }
            ClearSlots(game);
            return best;
        }

        private float Evaluate(GameController game, List<CardInstance> combo,
            List<SlotPosition> slots, int incoming)
        {
            var score = game.CombatSystem.PreviewScore(game.Run, game.Combat);
            if (score == null) return float.MinValue;

            var value = (float)score.FateDamage;

            // Ueberschuessiger Schaden zaehlt wenig - toeten reicht.
            var enemyPool = game.Combat.Enemy.Hp + game.Combat.Enemy.Shield;
            if (value > enemyPool) value = enemyPool + (value - enemyPool) * 0.15f;

            // In Lebensgefahr zaehlt Verteidigung mehr als Schaden.
            var survivable = game.Run.Hp + game.Combat.PlayerShield - incoming;
            if (survivable <= 0)
            {
                var defensive = combo.Count(c => c.Definition.Suit == Suit.Pentacles
                                                 || c.Definition.Suit == Suit.Cups);
                value += defensive * 40f;
            }

            // Die Zukunft ist wertlos, wenn man den Zug nicht ueberlebt - gemeint
            // ist die Position, an der die Karte wirkt, nicht wo sie liegt.
            var effective = slots.Select(s => game.CombatSystem.EffectiveSlot(game.Combat, s)).ToList();
            if (survivable <= 0 && effective.Contains(SlotPosition.Future)) value -= 25f;

            // Der Mond: verdeckte Karten sind ein Wagnis, die Vorschau luegt ein wenig.
            if (combo.Any(c => game.Combat.VeiledCards.Contains(c.InstanceId))) value *= .7f;

            // Der Tod: die gezeichnete Karte in die Zukunft legen rettet sie.
            var marked = game.Combat.MarkedCardId;
            if (!string.IsNullOrEmpty(marked) && survivable > 0)
                for (var i = 0; i < combo.Count; i++)
                    if (combo[i].InstanceId == marked && effective[i] == SlotPosition.Future)
                        value += 30f;

            // Musterkette halten ist etwas wert, auch wenn der Treffer gleich waere.
            if (score.HasPattern && game.Combat.PatternChain > 0) value += 4f * Math.Min(5, game.Combat.PatternChain);

            return value;
        }

        private static void ClearSlots(GameController game)
        {
            foreach (var slot in AllSlots) game.CombatSystem.ReturnSlotToHand(game.Combat, slot);
        }

        private static int ExpectedIncomingDamage(GameController game)
        {
            var enemy = game.Combat.Enemy;
            // Der Mond verbirgt die Absicht: dann mit einem normalen Angriff rechnen.
            if (enemy.IntentHidden) return enemy.Definition.BaseAttack + enemy.AttackRamp;
            switch (enemy.Intent)
            {
                case IntentType.Guard: return 0;
                case IntentType.Frenzy: return enemy.IntentValue * 2;
                case IntentType.Hex: return Math.Max(1, enemy.IntentValue / 2);
                default: return enemy.IntentValue;
            }
        }

        // ------------------------------------------------------- Off-Game
        private void TakeReward(GameController game)
        {
            if (game.Run.Deck.Count >= DeckTarget || game.Rewards.Count == 0)
            {
                game.SkipRewardForFate();
                return;
            }

            var bestIndex = 0;
            var bestValue = float.MinValue;
            for (var i = 0; i < game.Rewards.Count; i++)
            {
                var value = RewardValue(game.Run, game.Rewards[i]);
                if (value > bestValue) { bestValue = value; bestIndex = i; }
            }
            game.ChooseReward(bestIndex);
        }

        private static float RewardValue(RunState run, RewardOption reward)
        {
            switch (reward.Type)
            {
                case RewardType.Charm: return 30f;
                case RewardType.Item: return 12f;
                case RewardType.Fate: return reward.Fate * 0.2f;
                case RewardType.Card:
                    if (reward.Card == null) return 0f;
                    var value = reward.Card.Rank + (reward.Card.IsMajor ? 10f : 0f);
                    return value + (reward.CardLevel - 1) * 4f + (int)reward.CardShimmer * 2f;
                default: return 0f;
            }
        }

        /// <summary>Ab so viel Gold lohnt der Weg zum Haendler ueberhaupt.</summary>
        private const int WorthShoppingGold = 60;

        private PathType ChoosePath(GameController game)
        {
            var run = game.Run;
            var hp = (float)run.Hp / Math.Max(1, run.MaxHp);
            var paths = game.Paths;

            if (paths.Contains(PathType.Rest) && hp < .55f) return PathType.Rest;
            // Ausduennen hat Vorrang, solange das Deck ueber dem Ziel liegt.
            if (paths.Contains(PathType.Ritual) && run.Deck.Count > DeckTarget) return PathType.Ritual;
            // Frueher lag die Schwelle bei 120 Gold - die ein Run im Schnitt nie
            // erreichte. Der Haendler wurde dadurch faktisch nie besucht, und
            // die Goldsenke sah wirkungslos aus, obwohl sie nur nie drankam.
            if (paths.Contains(PathType.Shop) && run.Gold >= WorthShoppingGold) return PathType.Shop;
            if (paths.Contains(PathType.Elite) && hp > .70f) return PathType.Elite;
            if (paths.Contains(PathType.Event)) return PathType.Event;
            if (paths.Contains(PathType.Rest) && hp < .80f) return PathType.Rest;
            if (paths.Contains(PathType.Ritual)) return PathType.Ritual;
            return PathType.Fight;
        }

        // ------------------------------------------------ Neue Phasen
        /// <summary>
        /// Ereignisse: das Erste, was nicht Weitergehen heisst - ausser bei
        /// wenig Leben, dann Heilung oder Rueckzug. Der Autopilot liest den
        /// Hinweistext wie ein Mensch: was kostet es, was bringt es.
        /// </summary>
        private static void PlayEvent(GameController game)
        {
            var run = game.Run;
            var choices = game.CurrentEvent?.Choices ?? new List<EventChoice>();
            var hp = (float)run.Hp / Math.Max(1, run.MaxHp);
            var bestIndex = -1;
            var bestValue = float.MinValue;
            for (var i = 0; i < choices.Count; i++)
            {
                if (!game.CanChooseEventOption(i)) continue;
                var hint = choices[i].Hint ?? string.Empty;
                var value = choices[i].Label == "Weitergehen" ? 0f : 1f;
                if (hint.Contains("Heile")) value += (1f - hp) * 3f;
                if (hint.Contains("HP") && hint.Contains("−") && hp < .5f) value -= 2f;
                if (hint.Contains("Max-HP") && hint.Contains("Tausche") && run.MaxHp < 60) value -= 2f;
                if (value > bestValue) { bestValue = value; bestIndex = i; }
            }
            if (bestIndex >= 0) game.ChooseEventOption(bestIndex);
            game.ContinueFromOffgame();
        }

        private static void Rest(GameController game)
        {
            var run = game.Run;
            if (run.Hp < run.MaxHp * .65f || run.Deck.Count == 0) game.RestHeal();
            else game.RestStudy(run.Deck.OrderByDescending(Strength).First());
        }

        private BossLootChoice ChooseBossLoot(GameController game)
        {
            var run = game.Run;
            if (run.Hp < run.MaxHp * .40f) return BossLootChoice.Banish;
            if (run.Deck.Count < DeckTarget - 2 && game.OmenCard() != null) return BossLootChoice.Bind;
            return BossLootChoice.Soak;
        }

        /// <summary>Heiltraenke nicht horten: unter einem Drittel HP trinken.</summary>
        private static void UseHealingIfLow(GameController game)
        {
            var run = game.Run;
            if (run.Hp >= run.MaxHp / 3) return;
            foreach (var item in GameCatalog.Items.Where(i => i.Effect == ItemEffectType.Heal))
                if (run.Items.TryGetValue(item.Id, out var count) && count > 0)
                {
                    game.UseItem(item.Id);
                    return;
                }
        }

        /// <summary>Den Pakt nur mit Polster annehmen.</summary>
        private static bool AcceptPact(GameController game)
        {
            var run = game.Run;
            return run.Hp > run.MaxHp * .60f && run.MaxHp - CombatSystem.PactCost(game.Combat) >= 50;
        }

        /// <summary>Unter diese Groesse duennt der Autopilot nicht weiter aus.</summary>
        private const int MinimumDeck = 8;

        private void Shop(GameController game)
        {
            // Erst aufraeumen, dann kaufen. Ein aufgeblaehtes Deck zu verduennen
            // ist messbar wertvoller als eine weitere Karte hineinzulegen
            // (siehe docs/BALANCING.md), und nach dem Kaufblock waere ohnehin
            // kein Gold mehr uebrig.
            while (game.Run.Deck.Count > DeckTarget)
            {
                var worst = game.Run.Deck.OrderBy(Strength).FirstOrDefault();
                if (worst == null || !game.CanRemoveAtShop(worst)) break;
                if (!game.RemoveCardAtShop(worst)) break;
            }

            for (var i = 0; i < game.ShopOffers.Count; i++)
            {
                // Karten nur kaufen, solange Platz im Deck ist. Sonst arbeitet
                // der Autopilot gegen sein eigenes Ausduennen.
                var offer = game.ShopOffers[i];
                if (offer.Reward.Type == RewardType.Card && game.Run.Deck.Count >= DeckTarget) continue;
                game.BuyShopOffer(i);
            }

            // Was uebrig bleibt, wird Kraft: die staerkste Karte veredeln.
            for (var guard = 0; guard < 3 && game.Run.Deck.Count > 0; guard++)
            {
                var best = game.Run.Deck.OrderByDescending(Strength).First();
                if (!game.RefineAtShop(best)) break;
            }

            game.ContinueFromOffgame();
        }

        private void Ritual(GameController game)
        {
            if (game.Run.Deck.Count > MinimumDeck)
            {
                var worst = game.Run.Deck.OrderBy(Strength).First();
                game.RitualRemove(worst);
            }
            else
            {
                var best = game.Run.Deck.OrderByDescending(Strength).First();
                game.RitualEvolve(best);
            }
            game.ContinueFromOffgame();
        }

        private static float Strength(CardInstance card) =>
            card.EffectiveRank + card.Level * 2f + (card.Definition.IsMajor ? 8f : 0f);

        // --------------------------------------------------- Kombinatorik
        private static IEnumerable<List<CardInstance>> Combinations(List<CardInstance> source, int size)
        {
            for (var n = size; n >= 1; n--)
                foreach (var combo in Choose(source, n, 0, new List<CardInstance>()))
                    yield return combo;
        }

        private static IEnumerable<List<CardInstance>> Choose(List<CardInstance> source, int n,
            int start, List<CardInstance> current)
        {
            if (current.Count == n) { yield return new List<CardInstance>(current); yield break; }
            for (var i = start; i < source.Count; i++)
            {
                current.Add(source[i]);
                foreach (var result in Choose(source, n, i + 1, current)) yield return result;
                current.RemoveAt(current.Count - 1);
            }
        }

        private static IEnumerable<List<SlotPosition>> Permutations(List<SlotPosition> remaining, int n)
        {
            if (n == 0) { yield return new List<SlotPosition>(); yield break; }
            for (var i = 0; i < remaining.Count; i++)
            {
                var rest = new List<SlotPosition>(remaining);
                rest.RemoveAt(i);
                foreach (var tail in Permutations(rest, n - 1))
                {
                    var list = new List<SlotPosition> { remaining[i] };
                    list.AddRange(tail);
                    yield return list;
                }
            }
        }
    }
}
