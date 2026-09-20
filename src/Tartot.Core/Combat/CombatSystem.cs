using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    public sealed class TurnResult
    {
        public readonly List<string> Log = new List<string>();
        public ScoreBreakdown Score;
        public int FateDamage;
        public int EnemyDamage;
        public int Healing;
        public int ShieldGained;
        public bool StanceBroken;
        public bool Victory;
        public bool Defeat;
    }

    public sealed class CombatSystem
    {
        /// <summary>Karten auf der Hand zu Beginn jedes Zuges.</summary>
        public const int HandSize = 5;

        private readonly DeterministicRandom _rng;

        /// <summary>
        /// Der Strom wird hereingegeben, nicht selbst erzeugt: nur so kann der
        /// GameController Kampf, Belohnung und Laden auf getrennten Stroemen
        /// halten. Sonst verschiebt ein Reroll im Laden die Kartenzuege.
        /// </summary>
        public CombatSystem(DeterministicRandom rng)
        {
            _rng = rng ?? throw new ArgumentNullException(nameof(rng));
        }

        /// <summary>Zustand des Kampfstroms fuer den Speicherstand.</summary>
        public RandomSnapshot RandomSnapshot() => _rng.Snapshot();

        public CombatState StartCombat(RunState run, EnemyDefinition enemyDefinition)
        {
            var combat = new CombatState
            {
                Enemy = new EnemyState(enemyDefinition),
                PlayerShield = run.StartShieldBuff + CharmStacks(run, CharmEffectType.StartShield) * 3,
                TemporaryLuck = run.Luck + CharmStacks(run, CharmEffectType.StartLuck)
            };

            combat.DrawPile.AddRange(run.Deck);
            Shuffle(combat.DrawPile);
            combat.TemporaryDrawBonus = Math.Min(2, CharmStacks(run, CharmEffectType.OpeningDraw));
            DrawToHand(run, combat, HandSize + combat.TemporaryDrawBonus);
            combat.TemporaryDrawBonus = 0;
            RollIntent(combat);
            return combat;
        }

        public bool PlaceCard(CombatState combat, string instanceId, SlotPosition slot)
        {
            var card = combat.Hand.FirstOrDefault(c => c.InstanceId == instanceId);
            if (card == null) return false;

            if (combat.Slots.TryGetValue(slot, out var previous))
            {
                combat.Hand.Add(previous);
            }

            foreach (var occupied in combat.Slots.Where(kv => kv.Value.InstanceId == instanceId).Select(kv => kv.Key).ToList())
                combat.Slots.Remove(occupied);

            combat.Hand.Remove(card);
            combat.Slots[slot] = card;
            return true;
        }

        public bool ReturnSlotToHand(CombatState combat, SlotPosition slot)
        {
            if (!combat.Slots.TryGetValue(slot, out var card)) return false;
            combat.Hand.Add(card);
            combat.Slots.Remove(slot);
            return true;
        }

        public bool LuckReroll(RunState run, CombatState combat, string instanceId)
        {
            if (combat.TemporaryLuck <= 0) return false;
            var card = combat.Hand.FirstOrDefault(c => c.InstanceId == instanceId);
            if (card == null) return false;
            combat.TemporaryLuck--;
            combat.Hand.Remove(card);
            combat.DiscardPile.Add(card);
            DrawToHand(run, combat, 1);
            return true;
        }

        /// <summary>
        /// Vorschau ohne jede Nebenwirkung. Die UI ruft das bei jeder Karte auf,
        /// die der Spieler anfasst - alles andere waere ein Exploit.
        /// </summary>
        public ScoreBreakdown PreviewScore(RunState run, CombatState combat)
        {
            return CalculateScore(run, combat, commit: false);
        }

        public TurnResult ResolveTurn(RunState run, CombatState combat)
        {
            var result = new TurnResult();
            if (combat.Slots.Count == 0 || combat.PlayerWon || combat.PlayerLost)
            {
                result.Log.Add("Lege mindestens eine Karte.");
                return result;
            }

            var ordered = OrderedSlots(combat).ToList();
            var score = CalculateScore(run, combat, true);
            combat.LastScore = score;
            combat.LastPlayedCards = ordered.Select(x => x.Card).ToList();
            result.Score = score;

            var preStance = combat.Enemy.Stance;
            var stanceDamage = Math.Max(1, score.Chips / 9 + ordered.Count(x => x.Card.Definition.Suit == Suit.Swords) * 2);
            combat.Enemy.Stance = Math.Max(0, combat.Enemy.Stance - stanceDamage);
            var justBroke = preStance > 0 && combat.Enemy.Stance == 0;
            result.StanceBroken = justBroke;
            if (justBroke) result.Log.Add("HALTUNG GEBROCHEN – Schadensfenster geöffnet.");

            var fateDamage = score.FateDamage;
            if (justBroke || combat.Enemy.BrokenThisRound) fateDamage = (int)Math.Round(fateDamage * 1.5f);
            if (preStance > 0 && !justBroke)
            {
                var cap = Math.Max(1, (int)Math.Round(combat.Enemy.Definition.MaxHp * 0.35f));
                fateDamage = Math.Min(fateDamage, cap);
            }

            fateDamage = DealEnemyDamage(run, combat, fateDamage, true);
            result.FateDamage = fateDamage;
            result.Log.Add($"{score.ComboName}: {score.Chips} Chips × {score.Multiplier:0.00} × Wiederholung {score.RepeatPenalty:0.00} = {fateDamage} Fate-Schaden.");

            DistributeFateContribution(combat, ordered, fateDamage, stanceDamage, score.Multiplier);

            var immediate = ordered.Where(x => x.Slot != SlotPosition.Future).ToList();
            var future = ordered.Where(x => x.Slot == SlotPosition.Future).ToList();

            foreach (var entry in immediate)
                ApplyCard(run, combat, entry.Card, entry.Slot, result);

            TickEnemyBurn(run, combat, result);
            CheckEnemyDeathOrSigil(run, combat, result);

            if (!combat.PlayerWon)
                ResolveEnemyIntent(run, combat, result);

            if (!combat.PlayerLost)
            {
                foreach (var entry in future)
                    ApplyCard(run, combat, entry.Card, entry.Slot, result);
                CheckEnemyDeathOrSigil(run, combat, result);
            }

            foreach (var entry in ordered)
                combat.DiscardPile.Add(entry.Card);
            combat.Slots.Clear();

            if (combat.PlayerWon)
            {
                AwardRageOnVictory(combat);
                result.Victory = true;
                return result;
            }

            if (combat.PlayerLost)
            {
                result.Defeat = true;
                return result;
            }

            combat.Turn++;
            if (combat.Enemy.Stance == 0)
            {
                if (combat.Enemy.BrokenThisRound)
                {
                    combat.Enemy.Stance = Math.Max(1, (int)Math.Round(combat.Enemy.Definition.MaxStance * 0.60f));
                    combat.Enemy.BrokenThisRound = false;
                    result.Log.Add("Der Gegner fängt sich und gewinnt Haltung zurück.");
                }
                else combat.Enemy.BrokenThisRound = true;
            }

            var retained = CharmStacks(run, CharmEffectType.ShieldRetention) * 0.10f;
            combat.PlayerShield = (int)Math.Floor(combat.PlayerShield * Math.Min(.5f, retained));
            // Der Zieh-Bonus (Der Gehaengte, Leere Karte) galt bisher nur beim
            // Kampfstart und verfiel danach ungenutzt.
            DrawToHand(run, combat, HandSize + combat.TemporaryDrawBonus);
            combat.TemporaryDrawBonus = 0;
            RollIntent(combat);
            return result;
        }

        public void DrawToHand(RunState run, CombatState combat, int targetCount)
        {
            targetCount = Math.Max(0, targetCount);
            while (combat.Hand.Count < targetCount)
            {
                if (combat.DrawPile.Count == 0)
                {
                    if (combat.DiscardPile.Count == 0) break;
                    combat.DrawPile.AddRange(combat.DiscardPile);
                    combat.DiscardPile.Clear();
                    Shuffle(combat.DrawPile);
                    combat.Reshuffles++;
                    var bonus = Math.Min(2, CharmStacks(run, CharmEffectType.ReshuffleDraw));
                    targetCount += bonus;
                }

                var top = combat.DrawPile[0];
                combat.DrawPile.RemoveAt(0);
                combat.Hand.Add(top);
            }
        }

        private ScoreBreakdown CalculateScore(RunState run, CombatState combat, bool commit)
        {
            var entries = OrderedSlots(combat).ToList();
            var cards = entries.Select(e => e.Card).ToList();
            var score = new ScoreBreakdown { Chips = 0, Multiplier = 1f, ComboName = "Offene Legung" };
            if (cards.Count == 0) return score;

            foreach (var card in cards)
            {
                var chips = card.EffectiveRank;
                if (card.Definition.Suit == Suit.Swords)
                    chips += CharmStacks(run, CharmEffectType.SwordsChips) * 2;
                if (card.IsCopy)
                    chips += CharmStacks(run, CharmEffectType.CopyBase);
                if (card.IsUpgraded)
                    score.Multiplier += CharmStacks(run, CharmEffectType.UpgradedPower) * .08f;
                if (card.IsCopy)
                    score.Multiplier += CharmStacks(run, CharmEffectType.CopyPower) * .10f;
                if (card.Orientation == Orientation.Reversed)
                {
                    score.Multiplier += .10f;
                    score.Multiplier += CharmStacks(run, CharmEffectType.SelfDamagePower) * .12f;
                }
                if (card.Rage >= 3)
                {
                    chips = (int)Math.Round(chips * 1.5f);
                    score.Notes.Add($"{card.Definition.Name} ist in Raserei (+50% Chips). ");
                }
                score.Chips += chips;
            }

            if (combat.Slots.ContainsKey(SlotPosition.Present)) score.Multiplier += .15f;
            if (combat.Slots.ContainsKey(SlotPosition.Future))
                score.Multiplier += .10f + CharmStacks(run, CharmEffectType.FuturePower) * .10f;

            var values = cards.Select(c => c.Definition.Rank).OrderBy(v => v).ToList();
            var sum = values.Sum();
            var sameSuit = cards.Count == 3 && cards.Select(c => c.Definition.Suit).Distinct().Count() == 1;
            var uniqueSuits = cards.Select(c => c.Definition.Suit).Distinct().Count();
            var straight = values.Count == 3 && values[1] == values[0] + 1 && values[2] == values[1] + 1;
            var groups = values.GroupBy(v => v).OrderByDescending(g => g.Count()).ToList();
            var majorCount = cards.Count(c => c.Definition.IsMajor);

            var comboParts = new List<string>();
            if (sum == 21)
            {
                score.Multiplier += 2.10f;
                score.Chips += 21;
                comboParts.Add("DIE WELT 21");
                // Nur beim echten Zug, nicht in der Vorschau: sonst haette der
                // Spieler durch blosses Hin- und Herschieben von Karten
                // unbegrenzt Rage aufgebaut.
                if (commit)
                    foreach (var card in cards) card.Rage = Math.Min(3, card.Rage + 1);
            }
            if (straight)
            {
                score.Multiplier += .75f;
                score.Chips += 8;
                comboParts.Add("Folge");
            }
            if (sameSuit)
            {
                score.Multiplier += .65f;
                score.Chips += 10;
                comboParts.Add("Resonanz");
            }
            if (groups.First().Count() == 3)
            {
                score.Multiplier += 1.0f;
                score.Chips += 12;
                comboParts.Add("Dreiklang");
            }
            else if (groups.First().Count() == 2)
            {
                score.Multiplier += .50f;
                score.Chips += 5;
                comboParts.Add("Paar");
            }
            if (cards.Count == 3 && uniqueSuits == 3)
            {
                score.Multiplier += .35f;
                comboParts.Add("Drei Pfade");
            }
            if (majorCount >= 2)
            {
                score.Multiplier += .60f + (majorCount - 2) * .25f;
                comboParts.Add("Großes Omen");
            }

            var wands = cards.Count(c => c.Definition.Suit == Suit.Wands);
            if (wands >= 2) score.Multiplier += wands * CharmStacks(run, CharmEffectType.WandCombo) * .08f;
            if (run.Hp <= run.MaxHp / 2) score.Multiplier += CharmStacks(run, CharmEffectType.SelfDamagePower) * .04f;
            score.Multiplier += Math.Max(0, run.Charms.Count - 1) / 5 * CharmStacks(run, CharmEffectType.WorldThread) * .02f;

            if (!string.IsNullOrEmpty(run.Prophecy) && run.Prophecy == "XXI" && run.Deck.Count <= 10)
                score.Multiplier += .30f;

            score.ComboName = comboParts.Count == 0 ? (cards.Count == 3 ? "Dreier-Legung" : "Offene Legung") : string.Join(" + ", comboParts);
            var signature = string.Join("-", cards.Select(c => c.Definition.Id).OrderBy(s => s)) + "|" + score.ComboName;
            var repeats = signature == combat.LastComboSignature ? combat.SameComboRepeats + 1 : 0;
            score.RepeatPenalty = repeats switch
            {
                0 => 1f,
                1 => .90f,
                2 => .75f,
                _ => .50f
            };

            if (commit)
            {
                if (signature == combat.LastComboSignature) combat.SameComboRepeats++;
                else
                {
                    combat.LastComboSignature = signature;
                    combat.SameComboRepeats = 0;
                }
            }

            score.FateDamage = Math.Max(1, (int)Math.Round(score.Chips * score.Multiplier * score.RepeatPenalty));
            return score;
        }

        private void ApplyCard(RunState run, CombatState combat, CardInstance card, SlotPosition slot, TurnResult result)
        {
            var slotFactor = slot == SlotPosition.Past ? .90f : slot == SlotPosition.Future ? 1.50f : 1f;
            var charmFactor = 1f;
            if (card.IsCopy) charmFactor += CharmStacks(run, CharmEffectType.CopyPower) * .10f;
            if (card.IsUpgraded) charmFactor += CharmStacks(run, CharmEffectType.UpgradedPower) * .08f;
            if (card.Orientation == Orientation.Reversed) charmFactor += CharmStacks(run, CharmEffectType.SelfDamagePower) * .12f;
            var rageFactor = card.Rage >= 3 ? 1.5f : 1f;
            if (card.Rage >= 3) card.Rage = 0;
            var factor = slotFactor * card.PowerMultiplier * charmFactor * rageFactor;

            if (card.Definition.IsMajor)
            {
                ApplyMajor(run, combat, card, slot, factor, result);
                return;
            }

            var power = Math.Max(1, (int)Math.Round(card.Definition.BasePower * factor));
            switch (card.Definition.Suit)
            {
                case Suit.Swords:
                {
                    var bonus = CharmStacks(run, CharmEffectType.FirstAttackBonus) * 4;
                    var damage = DealEnemyDamage(run, combat, power + bonus, false);
                    AddContribution(combat, card, damage: damage);
                    result.Log.Add($"{card.Definition.Name}: {damage} Klingenschaden.");
                    break;
                }
                case Suit.Wands:
                {
                    var burn = Math.Max(1, power / 3 + CharmStacks(run, CharmEffectType.WandsBurn));
                    combat.Enemy.Burn += burn;
                    var damage = DealEnemyDamage(run, combat, Math.Max(1, power / 2), false);
                    AddContribution(combat, card, damage: damage);
                    result.Log.Add($"{card.Definition.Name}: {damage} Schaden und +{burn} Brand.");
                    break;
                }
                case Suit.Cups:
                {
                    var heal = power + CharmStacks(run, CharmEffectType.CupAfterAttack) * 2;
                    heal = ApplyHeal(run, combat, card, heal, result);
                    AddContribution(combat, card, healing: heal);
                    break;
                }
                case Suit.Pentacles:
                {
                    var shield = power + CharmStacks(run, CharmEffectType.PentacleShield) * 2;
                    if (run.Hp <= run.MaxHp / 2) shield += CharmStacks(run, CharmEffectType.LowHpShield) * 2;
                    combat.PlayerShield += shield;
                    AddContribution(combat, card, shield: shield);
                    result.ShieldGained += shield;
                    result.Log.Add($"{card.Definition.Name}: +{shield} Schild.");
                    break;
                }
            }

            if (card.Orientation == Orientation.Reversed)
            {
                var selfDamage = Math.Max(1, card.Definition.Rank / 5);
                run.Hp = Math.Max(1, run.Hp - selfDamage);
                result.Log.Add($"Umkehrpreis: -{selfDamage} HP.");
            }

            ApplyGenericCharmTriggers(run, combat, card, result);
        }

        private void ApplyMajor(RunState run, CombatState combat, CardInstance card, SlotPosition slot, float factor, TurnResult result)
        {
            var major = card.Definition.Major.Value;
            var p = Math.Max(1, (int)Math.Round((card.Definition.BasePower + card.Level) * factor));
            switch (major)
            {
                case MajorArcana.Fool:
                    DrawToHand(run, combat, Math.Min(8, combat.Hand.Count + (card.Orientation == Orientation.Reversed ? 3 : 2)));
                    if (card.Orientation == Orientation.Reversed) combat.TemporaryLuck++;
                    result.Log.Add("Der Narr verwirft Gewissheit: zusätzliche Karten gezogen.");
                    break;
                case MajorArcana.Magician:
                    var echo = combat.LastPlayedCards.LastOrDefault();
                    if (echo != null)
                    {
                        var dmg = DealEnemyDamage(run, combat, Math.Max(2, echo.EffectiveRank + p), false);
                        AddContribution(combat, card, damage:dmg, mult:.15f);
                        result.Log.Add($"Der Magier spiegelt {echo.Definition.Name}: {dmg} Echo-Schaden.");
                    }
                    else
                    {
                        combat.TemporaryLuck++;
                        result.Log.Add("Der Magier findet noch kein Echo und erzeugt stattdessen 1 Luck.");
                    }
                    break;
                case MajorArcana.HighPriestess:
                    combat.TemporaryLuck += 1;
                    DrawToHand(run, combat, Math.Min(7, combat.Hand.Count + 1));
                    result.Log.Add("Die Hohepriesterin enthüllt Möglichkeiten: +1 Luck, +1 Karte.");
                    break;
                case MajorArcana.Empress:
                    ApplyHeal(run, combat, card, 6 + p, result);
                    break;
                case MajorArcana.Emperor:
                    combat.PlayerShield += 10 + p;
                    AddContribution(combat, card, shield:10+p);
                    result.Log.Add($"Der Herrscher errichtet {10+p} Schild.");
                    break;
                case MajorArcana.Hierophant:
                    card.AddExperience(10 + p);
                    result.Log.Add("Der Hierophant lehrt die Karte: zusätzliche Erfahrung.");
                    break;
                case MajorArcana.Lovers:
                    var loversDmg = DealEnemyDamage(run, combat, p * 2, false);
                    AddContribution(combat, card, damage:loversDmg, mult:.25f);
                    result.Log.Add("Die Liebenden verbinden zwei Schicksale und verdoppeln ihren Impuls.");
                    break;
                case MajorArcana.Chariot:
                    var chariot = DealEnemyDamage(run, combat, p + (slot == SlotPosition.Future ? p : 0), false);
                    AddContribution(combat, card, damage:chariot);
                    result.Log.Add($"Der Wagen rast voran: {chariot} Schaden.");
                    break;
                case MajorArcana.Strength:
                    var strength = DealEnemyDamage(run, combat, p * 2, false);
                    combat.PlayerShield += 4;
                    AddContribution(combat, card, damage:strength, shield:4);
                    result.Log.Add($"Kraft: {strength} Schaden und 4 Schild.");
                    break;
                case MajorArcana.Hermit:
                    if (combat.Hand.Count > 0)
                    {
                        var weakest = combat.Hand.OrderBy(c => c.EffectiveRank).First();
                        combat.Hand.Remove(weakest);
                        combat.DiscardPile.Add(weakest);
                        DrawToHand(run, combat, combat.Hand.Count + 2);
                    }
                    result.Log.Add("Der Eremit dünnt die aktuelle Hand aus und zieht tiefer.");
                    break;
                case MajorArcana.Wheel:
                    foreach (var h in combat.Hand.ToList()) combat.DiscardPile.Add(h);
                    combat.Hand.Clear();
                    DrawToHand(run, combat, 5);
                    result.Log.Add("Das Rad ersetzt die gesamte Hand.");
                    break;
                case MajorArcana.Justice:
                    var justice = DealEnemyDamage(run, combat, 6 + p, false);
                    AddContribution(combat, card, damage:justice);
                    result.Log.Add($"Gerechtigkeit richtet: {justice} Schaden.");
                    break;
                case MajorArcana.HangedMan:
                    combat.PlayerShield += p;
                    combat.TemporaryDrawBonus += 2;
                    result.Log.Add("Der Gehängte opfert Tempo: Schild jetzt, zusätzliche Karten im nächsten Zug.");
                    break;
                case MajorArcana.Death:
                    var death = DealEnemyDamage(run, combat, p * 2, false);
                    if (combat.DiscardPile.Count > 0) combat.DiscardPile.RemoveAt(_rng.Next(combat.DiscardPile.Count));
                    AddContribution(combat, card, damage:death);
                    result.Log.Add($"Der Tod vernichtet: {death} Schaden und eine Karte verlässt diesen Kampf.");
                    break;
                case MajorArcana.Temperance:
                    var temp = DealEnemyDamage(run, combat, p, false);
                    combat.PlayerShield += p;
                    ApplyHeal(run, combat, card, p / 2, result);
                    AddContribution(combat, card, damage:temp, shield:p, mult:.15f);
                    result.Log.Add("Mäßigkeit mischt Schaden, Schild und Heilung.");
                    break;
                case MajorArcana.Devil:
                    var devil = DealEnemyDamage(run, combat, p * 3, false);
                    run.Hp = Math.Max(1, run.Hp - 4);
                    AddContribution(combat, card, damage:devil, mult:.25f);
                    result.Log.Add($"Der Teufel gewährt {devil} Schaden gegen 4 HP.");
                    break;
                case MajorArcana.Tower:
                    combat.PlayerShield = 0;
                    combat.Enemy.Shield = 0;
                    var tower = DealEnemyDamage(run, combat, 18 + p, false);
                    AddContribution(combat, card, damage:tower);
                    result.Log.Add($"Der Turm zerbricht Schutz: {tower} Schaden.");
                    break;
                case MajorArcana.Star:
                    ApplyHeal(run, combat, card, 8 + p/2, result);
                    combat.TemporaryLuck++;
                    DrawToHand(run, combat, Math.Min(7, combat.Hand.Count + 1));
                    result.Log.Add("Der Stern schenkt Heilung, Luck und eine Karte.");
                    break;
                case MajorArcana.Moon:
                    combat.TemporaryLuck += card.Orientation == Orientation.Reversed ? 2 : 1;
                    var moon = DealEnemyDamage(run, combat, p, false);
                    AddContribution(combat, card, damage:moon, mult:.20f);
                    result.Log.Add("Der Mond verstärkt Unsicherheit und umgekehrte Wege.");
                    break;
                case MajorArcana.Sun:
                    var sun = DealEnemyDamage(run, combat, 10 + p, false);
                    ApplyHeal(run, combat, card, 6 + p/2, result);
                    DrawToHand(run, combat, Math.Min(7, combat.Hand.Count + 1));
                    AddContribution(combat, card, damage:sun);
                    result.Log.Add("Die Sonne vereint Schaden, Heilung und Ziehen.");
                    break;
                case MajorArcana.Judgement:
                    if (combat.DiscardPile.Count > 0)
                    {
                        var returned = combat.DiscardPile.OrderByDescending(c => c.EffectiveRank).First();
                        combat.DiscardPile.Remove(returned);
                        combat.Hand.Add(returned);
                        result.Log.Add($"Das Gericht ruft {returned.Definition.Name} zurück.");
                    }
                    break;
                case MajorArcana.World:
                    var worldBonus = combat.LastScore != null && combat.LastScore.ComboName.Contains("DIE WELT") ? 30 : 16;
                    var world = DealEnemyDamage(run, combat, worldBonus + p, false);
                    combat.PlayerShield += 10;
                    DrawToHand(run, combat, Math.Min(7, combat.Hand.Count + 2));
                    AddContribution(combat, card, damage:world, shield:10, mult:.35f);
                    result.Log.Add($"Die Welt schließt den Kreis: {world} Schaden, 10 Schild, Karten gezogen.");
                    break;
            }
        }

        private int ApplyHeal(RunState run, CombatState combat, CardInstance card, int amount, TurnResult result)
        {
            var glassStacks = CharmStacks(run, CharmEffectType.GlassHeart);
            if (glassStacks > 0) amount = (int)Math.Round(amount * (1f + glassStacks * .25f));
            var before = run.Hp;
            run.Hp = Math.Min(run.MaxHp, run.Hp + amount);
            var actual = run.Hp - before;
            var overheal = Math.Max(0, amount - actual);
            var convert = CharmStacks(run, CharmEffectType.OverhealToShield) * .20f;
            if (overheal > 0 && convert > 0) combat.PlayerShield += (int)Math.Round(overheal * Math.Min(1f, convert));
            var damagePercent = CharmStacks(run, CharmEffectType.HealDamage) * .20f;
            if (damagePercent > 0)
            {
                var damage = DealEnemyDamage(run, combat, Math.Max(1, (int)Math.Round(amount * Math.Min(1f, damagePercent))), false);
                AddContribution(combat, card, damage:damage);
            }
            result.Healing += actual;
            result.Log.Add($"{card.Definition.Name}: +{actual} HP.");
            return actual;
        }

        private void ApplyGenericCharmTriggers(RunState run, CombatState combat, CardInstance card, TurnResult result)
        {
            // Der Zaehler steigt hier, waehrend die Karte wirkt. Vorher stieg er
            // erst nach dem gesamten Zug, wodurch alle drei Karten denselben
            // Stand sahen und "jede dritte Karte" nie richtig ausloeste.
            combat.CardsPlayedThisCombat++;

            if (card.Orientation == Orientation.Reversed)
            {
                var shield = CharmStacks(run, CharmEffectType.ReversedShield);
                if (shield > 0)
                {
                    combat.PlayerShield += shield;
                    result.ShieldGained += shield;
                }
            }

            var everyThird = CharmStacks(run, CharmEffectType.EveryThirdCardDamage);
            if (everyThird > 0 && combat.CardsPlayedThisCombat % 3 == 0)
            {
                var dmg = DealEnemyDamage(run, combat, everyThird * 3, false);
                result.Log.Add($"Schwarzer Nagel: +{dmg} Schaden.");
            }

            var everyFifth = CharmStacks(run, CharmEffectType.EveryFifthHeal);
            if (everyFifth > 0 && combat.CardsPlayedThisCombat % 5 == 0)
            {
                var before = run.Hp;
                run.Hp = Math.Min(run.MaxHp, run.Hp + everyFifth);
                result.Healing += run.Hp - before;
            }
        }

        private void TickEnemyBurn(RunState run, CombatState combat, TurnResult result)
        {
            if (combat.Enemy.Burn <= 0 || combat.Enemy.IsDead) return;
            var extra = CharmStacks(run, CharmEffectType.BurnPower);
            var damage = combat.Enemy.Burn + extra;
            damage = DealEnemyDamage(run, combat, damage, false);
            combat.Enemy.Burn = Math.Max(0, combat.Enemy.Burn - 1);
            result.Log.Add($"Brand tickt für {damage}.");
        }

        private void ResolveEnemyIntent(RunState run, CombatState combat, TurnResult result)
        {
            if (combat.SkipEnemyIntent)
            {
                combat.SkipEnemyIntent = false;
                result.Log.Add("Die gegnerische Aktion wird übersprungen.");
                return;
            }

            switch (combat.Enemy.Intent)
            {
                case IntentType.Guard:
                    combat.Enemy.Shield += combat.Enemy.IntentValue;
                    result.Log.Add($"{combat.Enemy.Definition.Name} erhält {combat.Enemy.IntentValue} Schild.");
                    break;
                case IntentType.Hex:
                    combat.TemporaryLuck = Math.Max(0, combat.TemporaryLuck - 1);
                    TakePlayerDamage(run, combat, Math.Max(1, combat.Enemy.IntentValue / 2), result);
                    result.Log.Add("Ein Fluch frisst 1 Luck.");
                    break;
                case IntentType.Drain:
                {
                    var dealt = TakePlayerDamage(run, combat, combat.Enemy.IntentValue, result);
                    combat.Enemy.Hp = Math.Min(combat.Enemy.Definition.MaxHp, combat.Enemy.Hp + dealt / 2);
                    result.Log.Add($"Der Gegner heilt {dealt/2} HP durch Drain.");
                    break;
                }
                case IntentType.Frenzy:
                    TakePlayerDamage(run, combat, combat.Enemy.IntentValue, result);
                    if (!combat.PlayerLost) TakePlayerDamage(run, combat, combat.Enemy.IntentValue, result);
                    break;
                default:
                    TakePlayerDamage(run, combat, combat.Enemy.IntentValue, result);
                    break;
            }
        }

        private int TakePlayerDamage(RunState run, CombatState combat, int incoming, TurnResult result)
        {
            var blocked = Math.Min(combat.PlayerShield, incoming);
            combat.PlayerShield -= blocked;
            var damage = incoming - blocked;
            if (blocked > 0)
            {
                var thorns = CharmStacks(run, CharmEffectType.Thorns) * 2;
                if (thorns > 0) DealEnemyDamage(run, combat, Math.Min(blocked, thorns), false);
            }
            run.Hp -= damage;
            result.EnemyDamage += damage;
            result.Log.Add($"Gegner trifft für {damage} ({blocked} geblockt).");

            if (run.Hp <= 0)
            {
                if (run.ReviveCharges > 0)
                {
                    run.ReviveCharges--;
                    run.Hp = Math.Max(1, run.MaxHp / 4);
                    result.Log.Add("Aschephiole: Wiederbelebung.");
                }
                else if (CharmStacks(run, CharmEffectType.Phoenix) > 0)
                {
                    run.Hp = 1 + CharmStacks(run, CharmEffectType.Phoenix) * 5;
                    run.Charms[GameCatalog.Charms.First(c => c.Effect == CharmEffectType.Phoenix).Id] = 0;
                    result.Log.Add("Phönixfeder verhindert den Tod.");
                }
                else
                {
                    run.Hp = 0;
                    combat.PlayerLost = true;
                }
            }
            return damage;
        }

        private int DealEnemyDamage(RunState run, CombatState combat, int amount, bool fateDamage)
        {
            amount = Math.Max(0, amount);
            if (combat.Enemy.Shield > 0)
            {
                // Durchdringung senkt das wirksame Schild einmal. Vorher wurde
                // sie zusaetzlich vom Restschild abgezogen - doppelt gezaehlt.
                var pierce = fateDamage ? 0 : CharmStacks(run, CharmEffectType.ArmorPierce);
                var effectiveShield = Math.Max(0, combat.Enemy.Shield - pierce);
                var blocked = Math.Min(effectiveShield, amount);
                combat.Enemy.Shield = Math.Max(0, combat.Enemy.Shield - blocked);
                amount -= blocked;
            }
            combat.Enemy.Hp -= amount;
            return amount;
        }

        private void CheckEnemyDeathOrSigil(RunState run, CombatState combat, TurnResult result)
        {
            if (combat.Enemy.Hp > 0) return;
            if (combat.Enemy.Sigils > 0)
            {
                combat.Enemy.Sigils--;
                combat.Enemy.Hp = Math.Max(1, (int)Math.Round(combat.Enemy.Definition.MaxHp * .45f));
                combat.Enemy.Stance = combat.Enemy.Definition.MaxStance;
                combat.Enemy.AttackRamp += 3;
                result.Log.Add("SCHICKSALSSIEGEL BRICHT – der Gegner kehrt verändert zurück.");
                return;
            }
            combat.Enemy.Hp = 0;
            combat.PlayerWon = true;
            result.Log.Add("Gegner besiegt.");
        }

        private void RollIntent(CombatState combat)
        {
            var enemy = combat.Enemy;
            var lowHp = enemy.Hp <= enemy.Definition.MaxHp / 2;
            if (lowHp && combat.Turn % 4 == 0)
            {
                enemy.Intent = IntentType.Frenzy;
                enemy.IntentValue = Math.Max(1, (enemy.Definition.BaseAttack + enemy.AttackRamp) / 2);
                return;
            }
            // Der seltenere Zug wird zuerst geprueft. Vorher stand Guard (%3)
            // vor Hex (%5), wodurch Hex auf Zug 15 und 30 nie vorkam.
            if (combat.Turn % 5 == 0)
            {
                enemy.Intent = IntentType.Hex;
                enemy.IntentValue = enemy.Definition.BaseAttack + enemy.AttackRamp;
                return;
            }
            if (combat.Turn % 3 == 0)
            {
                enemy.Intent = IntentType.Guard;
                enemy.IntentValue = Math.Max(4, enemy.Definition.MaxStance / 2);
                return;
            }
            enemy.Intent = IntentType.Attack;
            enemy.IntentValue = enemy.Definition.BaseAttack + enemy.AttackRamp + (lowHp ? 2 : 0);
        }

        private void DistributeFateContribution(CombatState combat, List<(SlotPosition Slot, CardInstance Card)> entries, int damage, int stanceDamage, float mult)
        {
            var totalRanks = Math.Max(1, entries.Sum(e => e.Card.EffectiveRank));
            foreach (var e in entries)
            {
                var share = (float)e.Card.EffectiveRank / totalRanks;
                AddContribution(combat, e.Card,
                    damage: (int)Math.Round(damage * share),
                    stance: (int)Math.Round(stanceDamage * share),
                    mult: mult * share);
            }
        }

        private void AddContribution(CombatState combat, CardInstance card, int damage = 0, int shield = 0, int healing = 0, int stance = 0, float mult = 0)
        {
            if (!combat.Contributions.TryGetValue(card.InstanceId, out var contribution))
            {
                contribution = new PlayedCardContribution { Card = card };
                combat.Contributions[card.InstanceId] = contribution;
            }
            contribution.Damage += damage;
            contribution.Shield += shield;
            contribution.Healing += healing;
            contribution.StanceDamage += stance;
            contribution.MultContribution += mult;
        }

        private void AwardRageOnVictory(CombatState combat)
        {
            foreach (var card in combat.LastPlayedCards)
                card.Rage = Math.Min(3, card.Rage + 1);
        }

        private int CharmStacks(RunState run, CharmEffectType effect)
        {
            var charm = GameCatalog.Charms.FirstOrDefault(c => c.Effect == effect);
            return charm == null ? 0 : run.CharmStacks(charm.Id);
        }

        private IEnumerable<(SlotPosition Slot, CardInstance Card)> OrderedSlots(CombatState combat)
        {
            var order = new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future };
            foreach (var slot in order)
                if (combat.Slots.TryGetValue(slot, out var card)) yield return (slot, card);
        }

        private void Shuffle<T>(IList<T> list)
        {
            for (var i = list.Count - 1; i > 0; i--)
            {
                var j = _rng.Next(i + 1);
                (list[i], list[j]) = (list[j], list[i]);
            }
        }
    }
}
