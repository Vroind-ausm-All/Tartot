using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>
    /// Die Regelbrecher. Jeder Boss nimmt eine Selbstverstaendlichkeit weg -
    /// einen Platz, das Wissen um seine Absicht, eine Karte, die Ordnung der
    /// Legung, die eigene Lebenskraft. Bricht ein Siegel, verschaerft er die
    /// Regel: der Boss veraendert sich waehrend des Kampfes.
    /// </summary>
    /// <remarks>
    /// Alles hier ist angekuendigt und sichtbar, bevor es passiert. Ein Boss
    /// soll eine neue Frage stellen, keine Falle sein.
    /// </remarks>
    public sealed partial class CombatSystem
    {
        /// <summary>Reihenfolge, in der der Turm Positionen einstuerzen laesst.</summary>
        private static readonly SlotPosition[] TowerCycle =
            { SlotPosition.Future, SlotPosition.Present, SlotPosition.Past };

        public const float PactFateBonus = .5f;
        public const float WeakPactFateBonus = .3f;
        public const int PactMaxHpCost = 6;
        public const int SecondPactMaxHpCost = 10;
        public const int WeakPactMaxHpCost = 4;
        public const float PactDeclinePenalty = .20f;
        public const int PactDarkness = 6;

        public static bool HasRule(CombatState combat, BossRule rule) =>
            combat?.Enemy?.Definition?.Rules != null && combat.Enemy.Definition.Rules.Contains(rule);

        /// <summary>Der Gehaengte nimmt in der zweiten Phase eine Handkarte.</summary>
        public int HandSizeFor(CombatState combat)
        {
            var enemy = combat?.Enemy;
            if (enemy != null && HasRule(combat, BossRule.HangedMan)
                && enemy.Phase >= 1 && !enemy.Definition.RulesWeakened)
                return HandSize - 1;
            return HandSize;
        }

        /// <summary>Aktuelle Regeltexte des Gegners, fuer das Banner unter seinem Namen.</summary>
        public static IEnumerable<string> ActiveRuleTexts(CombatState combat)
        {
            var enemy = combat?.Enemy;
            if (enemy?.Definition?.Rules == null) yield break;
            foreach (var rule in enemy.Definition.Rules)
                yield return ActCatalog.RuleText(rule, enemy.Phase, enemy.Definition.RulesWeakened);
        }

        // ------------------------------------------------------ Teufel
        private static void OfferPact(CombatState combat)
        {
            var weak = combat.Enemy.Definition.RulesWeakened;
            if (weak && combat.PactsOffered > 0) return;
            combat.PactPending = true;
            combat.PactsOffered++;
        }

        /// <summary>Was ein Pakt jetzt kosten wuerde (Max-HP).</summary>
        public static int PactCost(CombatState combat)
        {
            if (combat.Enemy.Definition.RulesWeakened) return WeakPactMaxHpCost;
            return combat.PactsOffered >= 2 ? SecondPactMaxHpCost : PactMaxHpCost;
        }

        public static float PactBonus(CombatState combat) =>
            combat.Enemy.Definition.RulesWeakened ? WeakPactFateBonus : PactFateBonus;

        /// <summary>
        /// Der Teufel verhandelt: mehr Fate-Schaden fuer den Rest des Kampfes
        /// gegen dauerhafte Max-HP und Verdunkelung. Wer ablehnt, bekommt
        /// seinen Zorn zu spueren.
        /// </summary>
        public bool AnswerPact(RunState run, CombatState combat, bool accept)
        {
            if (!combat.PactPending) return false;
            combat.PactPending = false;
            var weak = combat.Enemy.Definition.RulesWeakened;

            if (accept)
            {
                combat.FateBonus += PactBonus(combat);
                run.MaxHp = Math.Max(10, run.MaxHp - PactCost(combat));
                run.Hp = Math.Min(run.Hp, run.MaxHp);
                run.AddDarkness(PactDarkness);
                run.Stats.PactsAccepted++;
            }
            else if (!weak)
            {
                combat.EnemyAttackBonus += PactDeclinePenalty;
            }

            // Die angezeigte Absicht muss den neuen Zorn schon zeigen.
            RollIntent(combat);
            return true;
        }

        // ------------------------------------------------- Rundenbeginn
        /// <summary>
        /// Setzt die Regeln fuer den kommenden Zug: eingestuerzte Position,
        /// verborgene Absicht, verdeckte Karten, gezeichnete Karte.
        /// </summary>
        private void PrepareRules(RunState run, CombatState combat, TurnResult result)
        {
            var enemy = combat.Enemy;
            var weak = enemy.Definition.RulesWeakened;
            var phase = enemy.Phase;

            combat.BlockedSlot = null;
            combat.VeiledCards.Clear();
            enemy.IntentHidden = false;

            if (HasRule(combat, BossRule.Tower))
            {
                var interval = weak ? 4 : phase >= 1 ? 2 : 3;
                if (combat.Turn >= interval && combat.Turn % interval == 0)
                {
                    var slot = TowerCycle[combat.TowerCollapses % TowerCycle.Length];
                    combat.TowerCollapses++;
                    combat.BlockedSlot = slot;
                    result?.Log.Add($"Der Turm wirft seinen Schatten: die {SlotName(slot)} stürzt ein.");
                }
            }

            if (HasRule(combat, BossRule.Moon))
            {
                var hidden = weak ? combat.Turn % 3 == 0 : phase >= 1 || combat.Turn % 2 == 0;
                if (hidden)
                {
                    enemy.IntentHidden = true;
                    var count = phase >= 1 && !weak ? 2 : 1;
                    foreach (var card in _rng.PickDistinct(combat.Hand, Math.Min(count, combat.Hand.Count)))
                        combat.VeiledCards.Add(card.InstanceId);
                    result?.Log.Add("Der Mond verhüllt, was kommt.");
                }
            }

            if (HasRule(combat, BossRule.Death) && string.IsNullOrEmpty(combat.MarkedCardId)
                && combat.Turn >= combat.NextMarkTurn && run.Deck.Count > GameCatalog.MinimumDeckSize)
            {
                // Der Tod liebt, was du liebst: er zeichnet deine staerkste Karte.
                var target = run.Deck
                    .OrderByDescending(c => (int)c.Shimmer * 6 + c.Level * 3 + c.Definition.Rank)
                    .First();
                combat.MarkedCardId = target.InstanceId;
                combat.MarkTurnsLeft = weak ? 4 : phase >= 1 ? 2 : 3;
                result?.Log.Add($"Der Tod zeichnet {target.Definition.Name}. Noch {combat.MarkTurnsLeft} Runden.");
            }
        }

        /// <summary>Die gezeichnete Karte, falls es eine gibt.</summary>
        public static CardInstance MarkedCard(RunState run, CombatState combat) =>
            string.IsNullOrEmpty(combat?.MarkedCardId) ? null
                : run.Deck.FirstOrDefault(c => c.InstanceId == combat.MarkedCardId);

        /// <summary>
        /// Wer die gezeichnete Karte in die Zukunft legt und den Zug
        /// ueberlebt, rettet sie - die Zukunft gehoert nicht dem Tod.
        /// </summary>
        private static void LiftMarkIfFaced(CombatState combat, List<SlotEntry> future, TurnResult result)
        {
            if (string.IsNullOrEmpty(combat.MarkedCardId)) return;
            var faced = future.FirstOrDefault(e => e.Card.InstanceId == combat.MarkedCardId);
            if (faced.Card == null) return;
            combat.MarkedCardId = string.Empty;
            combat.NextMarkTurn = combat.Turn + 3;
            result.Log.Add($"{faced.Card.Definition.Name} hat dem Tod in die Augen gesehen. Das Zeichen verblasst.");
        }

        private static void TickDeathMark(RunState run, CombatState combat, TurnResult result)
        {
            if (string.IsNullOrEmpty(combat.MarkedCardId)) return;
            combat.MarkTurnsLeft--;
            if (combat.MarkTurnsLeft > 0) return;

            var card = MarkedCard(run, combat);
            combat.MarkedCardId = string.Empty;
            combat.NextMarkTurn = combat.Turn + 2;
            if (card == null || run.Deck.Count <= GameCatalog.MinimumDeckSize) return;

            run.Deck.Remove(card);
            run.RemovedCards.Add(card);
            combat.Hand.Remove(card);
            combat.DrawPile.Remove(card);
            combat.DiscardPile.Remove(card);
            run.Stats.CardsLostToDeath++;
            result.CardLost = card.Definition.Name;
            result.Log.Add($"DER TOD NIMMT {card.Definition.Name.ToUpperInvariant()}.");
        }

        // --------------------------------------------------- Phasenwechsel
        private static void OnPhaseChange(RunState run, CombatState combat, TurnResult result)
        {
            var enemy = combat.Enemy;
            enemy.Phase++;
            result.PhaseChanged = true;
            foreach (var text in ActiveRuleTexts(combat))
                if (!string.IsNullOrEmpty(text)) result.Log.Add("Neue Phase – " + text);
            if (HasRule(combat, BossRule.Devil)) OfferPact(combat);
        }
    }
}
