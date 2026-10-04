using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Stellt die nebenwirkungsfreie Score-Vorschau dar. Berechnet keine Regeln:
    /// alle Werte stammen aus ScoreBreakdown.
    /// </summary>
    public sealed class PreviewCascadeView
    {
        private readonly VisualElement _panel;
        private readonly Label _status;
        private readonly Label _summary;
        private readonly Label _fate;
        private readonly Label _hint;
        private readonly VisualElement _cascade;
        private readonly Button _actButton;

        public PreviewCascadeView(VisualElement documentRoot, Button actButton)
        {
            _panel = documentRoot.Q<VisualElement>("vorschau-panel");
            _status = documentRoot.Q<Label>("vorschau-status");
            _summary = documentRoot.Q<Label>("vorschau");
            _fate = documentRoot.Q<Label>("vorschau-fate");
            _hint = documentRoot.Q<Label>("vorschau-hinweis");
            _cascade = documentRoot.Q<VisualElement>("vorschau-kaskade");
            _actButton = actButton;
        }

        public void Clear()
        {
            _cascade?.Clear();
            if (_summary != null) _summary.text = string.Empty;
            if (_status != null) _status.text = string.Empty;
            if (_fate != null) _fate.text = string.Empty;
            if (_hint != null) _hint.text = string.Empty;

            _panel?.EnableInClassList("vorschau-panel--aktiv", false);
            _panel?.EnableInClassList("vorschau-panel--toedlich", false);
            _panel?.EnableInClassList("vorschau-panel--bruch", false);
            _panel?.EnableInClassList("vorschau-panel--welt", false);
            _panel?.EnableInClassList("vorschau-panel--verschleiert", false);

            if (_actButton == null) return;
            _actButton.EnableInClassList("knopf--toedlich", false);
            _actButton.EnableInClassList("knopf--bruchbereit", false);
            _actButton.EnableInClassList("knopf--welt", false);
            _actButton.text = "SCHICKSAL AUSFÜHREN";
        }

        public void Show(ScoreBreakdown score)
        {
            Clear();
            if (score == null) return;

            _panel?.EnableInClassList("vorschau-panel--aktiv", true);

            if (score.Veiled)
            {
                if (_status != null) _status.text = "MONDLICHT";
                if (_summary != null) _summary.text = "Die Legung bleibt ungewiss.";
                if (_fate != null) _fate.text = "?";
                _panel?.EnableInClassList("vorschau-panel--verschleiert", true);
                return;
            }

            var penalty = score.RepeatPenalty < 1f
                ? " · Wiederholung ×" + score.RepeatPenalty.ToString("0.00")
                : string.Empty;
            var chain = score.Chain >= 2 ? " · Kette ×" + score.Chain : string.Empty;
            var cap = score.ExpectedHit < score.FateDamage
                ? " · Treffer " + score.ExpectedHit
                : string.Empty;

            if (_summary != null)
                _summary.text = score.ComboName + ": " + score.Chips + " × " +
                                score.Multiplier.ToString("0.00") + penalty + " = " +
                                score.FateDamage + cap + chain;

            if (_fate != null)
                _fate.text = (score.ExpectedHit < score.FateDamage ? score.ExpectedHit : score.FateDamage) +
                             (score.ExpectedHit < score.FateDamage ? " TREFFER" : " FATE");

            if (_hint != null) _hint.text = string.Join("   ·   ", score.Hints);

            if (_status != null)
            {
                if (score.Lethal) _status.text = "TÖDLICHE LEGUNG";
                else if (score.IsWorld) _status.text = "XXI · DIE WELT";
                else if (score.BreaksStance) _status.text = "HALTUNG BRICHT";
                else if (score.HasPattern) _status.text = score.ComboName.ToUpperInvariant();
                else _status.text = "PROPHEZEIUNG";
            }

            if (_cascade != null)
            {
                foreach (var step in score.Steps.Take(5))
                {
                    var line = new Label(FormatStep(step));
                    line.AddToClassList("kaskade__schritt");
                    if (string.IsNullOrEmpty(step.InstanceId))
                        line.AddToClassList("kaskade__schritt--muster");
                    _cascade.Add(line);
                }
            }

            _panel?.EnableInClassList("vorschau-panel--toedlich", score.Lethal);
            _panel?.EnableInClassList("vorschau-panel--bruch", score.BreaksStance && !score.Lethal);
            _panel?.EnableInClassList("vorschau-panel--welt", score.IsWorld);

            if (_actButton == null) return;
            _actButton.EnableInClassList("knopf--toedlich", score.Lethal);
            _actButton.EnableInClassList("knopf--bruchbereit", score.BreaksStance && !score.Lethal);
            _actButton.EnableInClassList("knopf--welt", score.IsWorld);

            if (score.Lethal) _actButton.text = "SCHICKSAL BESIEGELN";
            else if (score.IsWorld) _actButton.text = "DIE WELT AUSFÜHREN";
            else if (score.BreaksStance) _actButton.text = "HALTUNG BRECHEN";
        }

        private static string FormatStep(ScoreStep step)
        {
            var parts = new List<string>();
            if (step.Chips != 0) parts.Add((step.Chips > 0 ? "+" : "") + step.Chips + " Chips");
            if (Math.Abs(step.MultAdd) > .001f)
                parts.Add((step.MultAdd > 0 ? "+" : "") + step.MultAdd.ToString("0.00") + " Mult");
            if (Math.Abs(step.MultX - 1f) > .001f)
                parts.Add("×" + step.MultX.ToString("0.00"));
            return step.Label + (parts.Count > 0 ? "  ·  " + string.Join("  ", parts) : string.Empty);
        }
    }
}
