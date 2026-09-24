using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    public sealed class VictorySummary
    {
        public int FateEarned;
        public int GoldEarned;
        public CardInstance Champion;
        public readonly List<(CardInstance Card, int Xp)> CardXp = new List<(CardInstance, int)>();
        public string BestCombo;
        /// <summary>Gold aus dem Ueberschuss des letzten Treffers.</summary>
        public int OverkillGold;
    }

    public sealed class ProgressionSystem
    {
        private readonly DeterministicRandom _rng;

        public ProgressionSystem(DeterministicRandom rng)
        {
            _rng = rng ?? throw new ArgumentNullException(nameof(rng));
        }

        /// <summary>Zustand des Fortschrittsstroms fuer den Speicherstand.</summary>
        public RandomSnapshot RandomSnapshot() => _rng.Snapshot();

        public VictorySummary ResolveVictory(RunState run, CombatState combat)
        {
            var summary = new VictorySummary();
            var contributions = combat.Contributions.Values.OrderByDescending(c => c.Score).ToList();
            var total = Math.Max(1f, contributions.Sum(c => c.Score));
            var fateBase = combat.LastScore?.FateDamage ?? 10;
            var qualityBonus = Math.Max(0, combat.LastScore?.Chips ?? 0) + (int)Math.Round((combat.LastScore?.Multiplier ?? 1f) * 20f);
            var deckBonus = run.Deck.Count <= 10 ? 1.20f : 1f;
            if (run.Prophecy == "XXI" && run.Deck.Count <= 10) deckBonus += .15f;
            summary.FateEarned = Math.Max(15, (int)Math.Round((fateBase + qualityBonus) * deckBonus));

            var greed = CharmStacks(run, CharmEffectType.Greed);
            var enemy = combat.Enemy.Definition;
            var tierGold = enemy.IsBoss ? 1.5f : enemy.Tier == EnemyTier.Elite ? 1.3f : 1f;
            var veilGold = run.Veil >= 1 ? .75f : 1f;
            summary.GoldEarned = (int)Math.Round((12 + run.FightIndex * 3) * (1f + greed * .10f)
                                                 * tierGold * enemy.GoldFactor * veilGold);
            run.Fate += summary.FateEarned;
            run.FateScoreTotal += summary.FateEarned;
            run.Gold += summary.GoldEarned;
            summary.BestCombo = combat.LastScore?.ComboName ?? "Offene Legung";

            foreach (var contribution in contributions)
            {
                var share = contribution.Score / total;
                var xp = Math.Max(4, (int)Math.Round(8 + share * 28));
                contribution.Card.AddExperience(xp);
                summary.CardXp.Add((contribution.Card, xp));
            }

            if (contributions.Count > 0)
            {
                var topThree = contributions.Take(3).ToList();
                var weightedTotal = topThree.Sum(x => Math.Max(1f, x.Score));
                var roll = _rng.NextFloat() * weightedTotal;
                var accumulator = 0f;
                var chosen = topThree[0];
                foreach (var candidate in topThree)
                {
                    accumulator += Math.Max(1f, candidate.Score);
                    if (roll <= accumulator)
                    {
                        chosen = candidate;
                        break;
                    }
                }

                summary.Champion = chosen.Card;
                chosen.Card.AddExperience(chosen.Card.XpToNextLevel);
                chosen.Card.AddVictoryMark();

                // Gold bleibt der stabile Pfad. Blut ist eine riskante Sieger-Evolution.
                if (chosen.Card.Shimmer == Shimmer.Gold && chosen.Card.Level >= 8 && chosen.Card.VictoryMarks >= 2)
                    chosen.Card.Shimmer = Shimmer.Blood;
                else if (chosen.Card.Shimmer == Shimmer.Blood && chosen.Card.Level >= 12 && chosen.Card.VictoryMarks >= 2)
                    chosen.Card.Shimmer = Shimmer.Black;
            }

            var pentacleGold = CharmStacks(run, CharmEffectType.PentacleGold);
            if (pentacleGold > 0 && combat.PlayerShield >= 10)
                run.Gold += pentacleGold * 2;

            UpdateDeckResonance(run);
            return summary;
        }

        /// <summary>
        /// Waehlt einen Charm, der noch Platz hat und nicht schon im selben
        /// Angebot liegt. Vorher konnte dieselbe Belohnung mehrfach erscheinen
        /// oder ein bereits voll gestapelter Charm angeboten werden.
        /// </summary>
        private CharmDefinition PickOfferableCharm(RunState run, List<RewardOption> alreadyOffered)
        {
            var candidates = new List<CharmDefinition>();
            foreach (var charm in GameCatalog.Charms)
            {
                if (run.CharmStacks(charm.Id) >= charm.MaxStacks) continue;
                if (!run.CharmAllowed(charm.Id)) continue;
                var duplicate = false;
                foreach (var offered in alreadyOffered)
                    if (offered.Charm != null && offered.Charm.Id == charm.Id) { duplicate = true; break; }
                if (!duplicate) candidates.Add(charm);
            }
            return candidates.Count == 0 ? null : _rng.Pick(candidates);
        }

        /// <param name="elite">Elites geben verlaesslich Charms: die ersten zwei Wahlen sind welche.</param>
        public List<RewardOption> GenerateRewards(RunState run, int count = 3, bool elite = false)
        {
            count += CharmStacks(run, CharmEffectType.ExtraRewardChoice) / 2;
            if (run.BonusRewardChoices > 0)
            {
                run.BonusRewardChoices--;
                count++;
            }
            if (run.Veil >= 3) count--;
            count = Math.Max(1, Math.Min(5, count));
            var rewards = new List<RewardOption>();
            var rareChance = .08f + CharmStacks(run, CharmEffectType.RareChance) * .04f + run.Luck * .01f;
            var upgradedChance = .05f + CharmStacks(run, CharmEffectType.UpgradedRewardChance) * .08f;
            // Der Eremit findet seltener Karten - er soll duenn bleiben wollen.
            var cardShare = run.DeuterRule == DeuterRule.Hermit ? 25 : 45;
            var reversedChance = run.Darkness * .005f;

            if (elite)
            {
                for (var i = 0; i < 2 && rewards.Count < count; i++)
                {
                    var charm = PickOfferableCharm(run, rewards);
                    if (charm == null) break;
                    rewards.Add(new RewardOption { Type=RewardType.Charm, Title=charm.Name, Description=charm.Description, Charm=charm });
                }
            }

            var guard = 0;
            while (rewards.Count < count && guard++ < 200)
            {
                var roll = _rng.Next(100);
                if (roll < cardShare)
                {
                    var card = RandomCardReward(run, rareChance);
                    var shimmer = _rng.Chance(rareChance) ? Shimmer.Indigo : Shimmer.Matte;
                    var upgraded = _rng.Chance(upgradedChance);
                    var reversed = _rng.Chance(reversedChance);
                    rewards.Add(new RewardOption
                    {
                        Type = RewardType.Card,
                        Title = (reversed ? "↕ " : string.Empty) + (upgraded ? $"{card.Name}+" : card.Name),
                        Description = $"{(shimmer == Shimmer.Indigo ? "Indigo-Schimmer" : "Matt")}{(reversed ? ", umgekehrt" : string.Empty)}. {card.Description}",
                        Card = card,
                        CardLevel = upgraded ? 2 : 1,
                        CardShimmer = shimmer,
                        CardOrientation = reversed ? Orientation.Reversed : Orientation.Upright
                    });
                }
                else if (roll < 75)
                {
                    var charm = PickOfferableCharm(run, rewards);
                    if (charm == null) continue;
                    rewards.Add(new RewardOption { Type=RewardType.Charm, Title=charm.Name, Description=charm.Description, Charm=charm });
                }
                else if (roll < 92)
                {
                    var item = _rng.Pick(GameCatalog.Items);
                    rewards.Add(new RewardOption { Type=RewardType.Item, Title=item.Name, Description=item.Description, Item=item });
                }
                else
                {
                    var fate = 45 + run.FightIndex * 10;
                    rewards.Add(new RewardOption { Type=RewardType.Fate, Title=$"{fate} Fate", Description="Überspringe neue Teile und verdichte deinen bestehenden Build.", Fate=fate });
                }
            }
            return rewards;
        }

        public void TakeReward(RunState run, RewardOption reward)
        {
            switch (reward.Type)
            {
                case RewardType.Card:
                {
                    var instance = new CardInstance(reward.Card)
                    {
                        Level = Math.Max(1, reward.CardLevel),
                        Shimmer = reward.CardShimmer,
                        Orientation = reward.CardOrientation
                    };
                    run.Deck.Add(instance);
                    break;
                }
                case RewardType.Charm:
                    run.AddCharm(reward.Charm);
                    break;
                case RewardType.Item:
                    run.AddItem(reward.Item);
                    break;
                case RewardType.Fate:
                    run.Fate += reward.Fate;
                    break;
            }
            UpdateDeckResonance(run);
        }

        public bool RemoveCard(RunState run, CardInstance card, int fateCost = 120)
        {
            var discount = CharmStacks(run, CharmEffectType.RemoveDiscount) * .15f;
            fateCost = Math.Max(20, (int)Math.Round(fateCost * Math.Max(.35f, 1f - discount)));
            if (run.DeuterRule == DeuterRule.Bookkeeper) fateCost *= 2;
            if (run.Fate < fateCost || run.Deck.Count <= GameCatalog.MinimumDeckSize
                || !run.Deck.Contains(card)) return false;
            run.Fate -= fateCost;
            run.Deck.Remove(card);
            run.RemovedCards.Add(card);
            run.MaxHp += CharmStacks(run, CharmEffectType.RemoveMaxHp);
            run.Hp = Math.Min(run.Hp, run.MaxHp);
            UpdateDeckResonance(run);
            return true;
        }

        public bool MirrorCard(RunState run, CardInstance card, int fateCost = 160)
        {
            if (run.Fate < fateCost || !run.Deck.Contains(card)) return false;
            if (card.Definition.IsMajor && run.Deck.Count(c => c.Definition.Id == card.Definition.Id) >= 2) return false;
            run.Fate -= fateCost;
            var copy = new CardInstance(card.Definition, true)
            {
                Level = card.Level,
                Shimmer = card.Shimmer,
                Orientation = card.Orientation
            };
            run.Deck.Add(copy);
            UpdateDeckResonance(run);
            return true;
        }

        public bool FlipCard(RunState run, CardInstance card, int fateCost = 90)
        {
            if (run.Fate < fateCost || !run.Deck.Contains(card)) return false;
            run.Fate -= fateCost;
            card.Orientation = card.Orientation == Orientation.Upright ? Orientation.Reversed : Orientation.Upright;
            return true;
        }

        public bool EvolveCard(RunState run, CardInstance card, int fateCost = 220)
        {
            if (run.Fate < fateCost || !run.Deck.Contains(card)) return false;
            run.Fate -= fateCost;
            card.Level++;
            if (card.Shimmer < Shimmer.Gold) card.Shimmer = (Shimmer)((int)card.Shimmer + 1);
            else if (card.Shimmer == Shimmer.Gold) card.Shimmer = Shimmer.Blood;
            // Aufwerten hat immer auch einen dunklen Preis.
            run.AddDarkness(2);
            EventCatalog.NoteShimmer(run, card);
            return true;
        }

        public int ShopPrice(RunState run, int basePrice)
        {
            var discount = CharmStacks(run, CharmEffectType.ShopDiscount) * .05f;
            return Math.Max(1, (int)Math.Round(basePrice * Math.Max(.50f, 1f - discount)));
        }

        /// <summary>Ab dieser Deckgroesse gibt es keine Groessenpunkte mehr.</summary>
        public const int DeckSizeCeiling = 16;

        /// <summary>
        /// Wie stimmig der Build ist: kleines Deck, entwickelte Karten, viele
        /// Charms, Fortschritt. Geht als Multiplikator in jede Legung ein.
        /// </summary>
        public void UpdateDeckResonance(RunState run)
        {
            var score = 1;

            // Deckgroesse als Gradient statt zweier Sprungmarken: jede entfernte
            // Karte zahlt ein wenig. Vorher gab es nur bei 12 und bei 9 einen
            // Punkt - und weil ein Run praktisch nie unter 12 kam, war der
            // zentrale Hebel des Designs faktisch wirkungslos.
            score += Math.Max(0, DeckSizeCeiling - run.Deck.Count) / 2;

            if (run.Deck.Any(c => c.Shimmer >= Shimmer.Indigo)) score++;
            if (run.Deck.Count(c => c.Shimmer >= Shimmer.Gold) >= 2) score++;
            if (run.Charms.Values.Sum() >= 6) score++;
            if (run.Charms.Values.Sum() >= 12) score++;
            if (run.FightIndex >= 4) score++;
            if (run.FightIndex >= 7) score++;
            run.DeckResonance = Math.Min(10, score);
        }

        public void ApplyOracle(RunState run, string prophecy)
        {
            run.Prophecy = prophecy;
            if (prophecy == "BLUT")
            {
                foreach (var card in run.Deck.Where(c => c.Orientation == Orientation.Reversed).Take(2))
                    card.AddExperience(15);
            }
            else if (prophecy == "EINHEIT")
            {
                run.Fate += 60;
            }
            else if (prophecy == "XXI")
            {
                run.Luck++;
            }
        }

        public bool UseItem(RunState run, CombatState combat, string itemId, CardInstance target = null)
        {
            var item = GameCatalog.Items.FirstOrDefault(i => i.Id == itemId);
            if (item == null || !run.ConsumeItem(itemId)) return false;

            switch (item.Effect)
            {
                case ItemEffectType.MirrorCard:
                    if (target == null || !MirrorCardFree(run, target)) { run.AddItem(item); return false; }
                    break;
                case ItemEffectType.RemoveCard:
                    if (target == null || !RemoveCardFree(run, target)) { run.AddItem(item); return false; }
                    break;
                case ItemEffectType.FlipCard:
                    if (target == null) { run.AddItem(item); return false; }
                    target.Orientation = target.Orientation == Orientation.Upright ? Orientation.Reversed : Orientation.Upright;
                    break;
                case ItemEffectType.UpgradeCard:
                    if (target == null) { run.AddItem(item); return false; }
                    target.Level++;
                    break;
                case ItemEffectType.Heal:
                    run.Hp = Math.Min(run.MaxHp, run.Hp + item.Magnitude);
                    break;
                case ItemEffectType.GainGold:
                    run.Gold += item.Magnitude;
                    break;
                case ItemEffectType.GainLuck:
                    run.Luck += item.Magnitude;
                    if (combat != null) combat.TemporaryLuck += item.Magnitude;
                    break;
                case ItemEffectType.Revive:
                    run.ReviveCharges++;
                    break;
                case ItemEffectType.StartShieldBuff:
                    run.StartShieldBuff += item.Magnitude;
                    break;
                case ItemEffectType.SkipEnemyIntent:
                    if (combat == null) { run.AddItem(item); return false; }
                    combat.SkipEnemyIntent = true;
                    break;
                case ItemEffectType.TowerBlast:
                    if (combat == null) { run.AddItem(item); return false; }
                    combat.PlayerShield = 0;
                    combat.Enemy.Hp -= item.Magnitude;
                    break;
                case ItemEffectType.DevilsBargain:
                    run.FreeNextShopPurchase = true;
                    break;
                case ItemEffectType.RestoreRemovedCard:
                    if (run.RemovedCards.Count > 0)
                    {
                        var restored = run.RemovedCards[run.RemovedCards.Count - 1];
                        run.RemovedCards.RemoveAt(run.RemovedCards.Count - 1);
                        restored.Level++;
                        run.Deck.Add(restored);
                    }
                    break;
                default:
                    // Einige Utility-Items sind für spätere UI-Interaktionen reserviert.
                    run.Fate += 15;
                    break;
            }
            UpdateDeckResonance(run);
            return true;
        }

        private bool MirrorCardFree(RunState run, CardInstance card)
        {
            if (!run.Deck.Contains(card)) return false;
            if (card.Definition.IsMajor && run.Deck.Count(c => c.Definition.Id == card.Definition.Id) >= 2) return false;
            run.Deck.Add(new CardInstance(card.Definition, true)
            {
                Level = card.Level,
                Shimmer = card.Shimmer,
                Orientation = card.Orientation
            });
            return true;
        }

        private bool RemoveCardFree(RunState run, CardInstance card)
        {
            if (!run.Deck.Contains(card) || run.Deck.Count <= 5) return false;
            run.Deck.Remove(card);
            run.RemovedCards.Add(card);
            return true;
        }

        private CardDefinition RandomCardReward(RunState run, float rareChance)
        {
            var majors = GameCatalog.Cards.Where(c => c.IsMajor).ToList();
            var minors = GameCatalog.Cards.Where(c => !c.IsMajor).ToList();
            if (_rng.Chance(Math.Min(.30f, rareChance))) return _rng.Pick(majors);
            return _rng.Pick(minors);
        }

        private int CharmStacks(RunState run, CharmEffectType effect)
        {
            var charm = GameCatalog.Charms.FirstOrDefault(c => c.Effect == effect);
            return charm == null ? 0 : run.CharmStacks(charm.Id);
        }
    }
}
