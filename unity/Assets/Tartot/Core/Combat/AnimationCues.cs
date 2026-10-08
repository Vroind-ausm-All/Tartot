using System.Collections.Generic;

namespace Tartot.Core
{
    /// <summary>
    /// Welche Animation ein Zug ausloest. Die Namen sind die Zustaende der
    /// Sprite-Streifen (tools/blender/anim.py): idle, attack, attack1-3,
    /// summon, supernova, hit, phase2, death.
    /// </summary>
    /// <remarks>
    /// Liegt im Kern und nicht in der Oberflaeche, damit die Zuordnung ohne
    /// Unity getestet werden kann. Die Oberflaeche spielt die Folge ab und
    /// faellt auf "attack" oder "idle" zurueck, wenn ein Streifen fehlt.
    /// </remarks>
    public static class AnimationCues
    {
        public const string Idle = "idle";

        /// <summary>
        /// Die Folge fuer einen aufgeloesten Zug.
        /// <paramref name="intent"/> ist die Absicht, die der Gegner in diesem
        /// Zug ausgefuehrt hat (vor dem Wuerfeln der naechsten).
        /// </summary>
        public static List<string> ForTurn(TurnResult turn, EnemyState enemy, IntentType intent, int turnNumber)
        {
            var cues = new List<string>();
            if (turn == null || enemy == null) return cues;
            if (turn.FateDamage > 0 || turn.StanceBroken) cues.Add("hit");
            if (turn.Victory)
            {
                cues.Add("death");
                return cues;
            }
            if (turn.PhaseChanged) cues.Add("phase2");
            if (!turn.Defeat || turn.EnemyDamage > 0) cues.Add(EnemyAction(turn, enemy, intent, turnNumber));
            return cues;
        }

        /// <summary>Welcher Angriff des Blatts zur ausgefuehrten Absicht passt.</summary>
        public static string EnemyAction(TurnResult turn, EnemyState enemy, IntentType intent, int turnNumber)
        {
            var rules = enemy.Definition.Rules;
            if (turn.Supernova) return "supernova";
            if (rules.Contains(BossRule.Sun))
                return intent == IntentType.Guard ? "summon" : intent == IntentType.Frenzy ? "attack2" : "attack1";
            if (rules.Contains(BossRule.Temperance))
            {
                if (turn.Reflected > 0 || enemy.Phase >= 1) return "attack3";
                if (intent == IntentType.Guard) return "summon";
                // Wasserrunden sind ungerade, Feuerrunden gerade.
                return turnNumber % 2 == 0 ? "attack2" : "attack1";
            }
            if (rules.Contains(BossRule.Hierophant))
            {
                if (turn.Log.Exists(l => l.Contains("Akolythen.") || l.Contains("ruft einen Akolythen"))) return "attack2";
                return intent == IntentType.Guard ? "attack1" : "attack3";
            }
            if (rules.Contains(BossRule.Devil))
                return intent == IntentType.Guard ? "summon" : intent == IntentType.Frenzy ? "attack2" : "attack1";
            if (rules.Contains(BossRule.Moon))
            {
                switch (intent)
                {
                    case IntentType.Hex: return "attack3";
                    case IntentType.Drain: return "attack1";
                    case IntentType.Guard: return "summon";
                    default: return "attack2";
                }
            }
            if (rules.Contains(BossRule.Tower) && intent != IntentType.Guard) return "attack1";
            return intent == IntentType.Guard ? Idle : "attack";
        }

        /// <summary>Spiralgegner tragen die Id ihrer Vorlage mit Tiefe ("uhrenwurm_spirale_3").</summary>
        public static string SpriteId(EnemyDefinition definition)
        {
            var id = definition?.Id ?? string.Empty;
            var cut = id.IndexOf("_spirale_", System.StringComparison.Ordinal);
            return cut > 0 ? id.Substring(0, cut) : id;
        }
    }
}
