using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core.Simulation
{
    /// <summary>Was ein Autopilot-Run am Ende erreicht hat.</summary>
    public sealed class RunOutcome
    {
        public int FightsCleared;
        public int DeckSize;
        public int Gold;
        public int Fate;
        public int Hp;
        public int CharmStacks;
        public int TurnsPlayed;
        public int DeckResonance;
        public string DiedAgainst = "-";
        public bool ReachedLimit;

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

        public RunOutcome PlayRun(long seed, int maxFights = 30)
        {
            var game = new GameController(seed);
            var outcome = new RunOutcome();
            var guard = 0;

            while (game.Phase != GamePhase.GameOver && game.Run.FightIndex < maxFights && guard++ < 5000)
            {
                switch (game.Phase)
                {
                    case GamePhase.Combat:
                        outcome.TurnsPlayed += PlayCombat(game);
                        if (game.Phase == GamePhase.GameOver)
                            outcome.DiedAgainst = game.Combat?.Enemy?.Definition?.Name ?? "-";
                        break;
                    case GamePhase.Reward:
                        TakeReward(game);
                        break;
                    case GamePhase.PathChoice:
                        game.ChoosePath(ChoosePath(game));
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
                }
            }

            outcome.FightsCleared = game.Run.FightIndex;
            outcome.DeckSize = game.Run.Deck.Count;
            outcome.Gold = game.Run.Gold;
            outcome.Fate = game.Run.FateScoreTotal;
            outcome.Hp = game.Run.Hp;
            outcome.CharmStacks = game.Run.Charms.Values.Sum();
            outcome.DeckResonance = game.Run.DeckResonance;
            outcome.ReachedLimit = game.Run.FightIndex >= maxFights;
            return outcome;
        }

        // ------------------------------------------------------------ Kampf
        public int PlayCombat(GameController game)
        {
            var turns = 0;
            while (game.Phase == GamePhase.Combat && turns < MaxTurnsPerFight)
            {
                turns++;
                var layout = BestLayout(game);
                ClearSlots(game);
                foreach (var (instanceId, slot) in layout)
                    game.CombatSystem.PlaceCard(game.Combat, instanceId, slot);

                if (game.Combat.Slots.Count == 0)
                {
                    if (game.Combat.Hand.Count == 0) break;
                    game.CombatSystem.PlaceCard(game.Combat, game.Combat.Hand[0].InstanceId, SlotPosition.Present);
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

            foreach (var combo in Combinations(hand, Math.Min(3, hand.Count)))
            foreach (var slots in Permutations(AllSlots.ToList(), combo.Count))
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

            // Die Zukunft ist wertlos, wenn man den Zug nicht ueberlebt.
            if (survivable <= 0 && slots.Contains(SlotPosition.Future)) value -= 25f;

            return value;
        }

        private static void ClearSlots(GameController game)
        {
            foreach (var slot in AllSlots) game.CombatSystem.ReturnSlotToHand(game.Combat, slot);
        }

        private static int ExpectedIncomingDamage(GameController game)
        {
            var enemy = game.Combat.Enemy;
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

        private PathType ChoosePath(GameController game)
        {
            // Ausduennen hat Vorrang, solange das Deck ueber dem Ziel liegt.
            if (game.Paths.Contains(PathType.Ritual) && game.Run.Deck.Count > DeckTarget)
                return PathType.Ritual;
            if (game.Paths.Contains(PathType.Shop) && game.Run.Gold > 120) return PathType.Shop;
            return game.Paths[0];
        }

        /// <summary>Unter diese Groesse duennt der Autopilot nicht weiter aus.</summary>
        private const int MinimumDeck = 8;

        private void Shop(GameController game)
        {
            for (var i = 0; i < game.ShopOffers.Count; i++)
            {
                // Karten nur kaufen, solange Platz im Deck ist. Sonst arbeitet
                // der Autopilot gegen sein eigenes Ausduennen.
                var offer = game.ShopOffers[i];
                if (offer.Reward.Type == RewardType.Card && game.Run.Deck.Count >= DeckTarget) continue;
                game.BuyShopOffer(i);
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
