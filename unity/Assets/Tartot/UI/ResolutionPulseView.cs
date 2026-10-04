using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Spielt die bereits vom Core berechnete Zugauflösung als kurze visuelle
    /// Kaskade. Timing und Betonung sind Presentation, nicht Spielregel.
    /// </summary>
    public sealed class ResolutionPulseView
    {
        private readonly VisualElement _root;
        private readonly VisualElement _halo;
        private readonly Label _eyebrow;
        private readonly Label _stamp;
        private readonly VisualElement _steps;
        private readonly Label _fate;
        private readonly Label _moment;
        private int _token;

        public ResolutionPulseView(VisualElement documentRoot)
        {
            _root = documentRoot.Q<VisualElement>("auflosung");
            _halo = documentRoot.Q<VisualElement>("auflosung-halo");
            _eyebrow = documentRoot.Q<Label>("auflosung-kopf");
            _stamp = documentRoot.Q<Label>("auflosung-stempel");
            _steps = documentRoot.Q<VisualElement>("auflosung-schritte");
            _fate = documentRoot.Q<Label>("auflosung-fate");
            _moment = documentRoot.Q<Label>("auflosung-moment");
        }

        public void Play(
            TurnResult turn,
            SlotPosition? blockedBefore,
            SlotPosition? blockedAfter,
            Action<int> impact,
            Action stanceBreak,
            Action phaseChanged,
            Action<SlotPosition> slotCollapse,
            Action world,
            Action completed)
        {
            if (_root == null || turn == null || turn.Score == null)
            {
                completed?.Invoke();
                return;
            }

            var token = ++_token;
            ResetContent();

            var score = turn.Score;
            var lethal = score.Lethal || turn.Victory;
            var breakMoment = turn.StanceBroken;

            _root.EnableInClassList("auflosung--toedlich", lethal);
            _root.EnableInClassList("auflosung--welt", score.IsWorld);
            _root.EnableInClassList("auflosung--bruch", breakMoment && !lethal);
            _root.style.display = DisplayStyle.Flex;

            if (_eyebrow != null)
                _eyebrow.text = lethal ? "DAS URTEIL FÄLLT"
                    : score.IsWorld ? "DIE LEGUNG SCHLIESST SICH"
                    : breakMoment ? "DIE HALTUNG GIBT NACH"
                    : "DIE LEGUNG WIRD GEDEUTET";

            var delay = 35;
            foreach (var step in score.Steps.Take(5))
            {
                var captured = step;
                var when = delay;
                Schedule(token, when, () =>
                {
                    var line = new Label(FormatStep(captured));
                    line.AddToClassList("auflosung__schritt");
                    if (string.IsNullOrEmpty(captured.InstanceId))
                        line.AddToClassList("auflosung__schritt--muster");
                    _steps?.Add(line);
                    PulseClass("auflosung--schritt-puls", 70);
                });
                delay += 78;
            }

            if (score.IsWorld)
            {
                var when = delay;
                Schedule(token, when, () =>
                {
                    if (_stamp != null) _stamp.text = "XXI · DIE WELT";
                    _stamp?.EnableInClassList("auflosung__stempel--sichtbar", true);
                    _halo?.EnableInClassList("auflosung__halo--welt", true);
                    world?.Invoke();
                    impact?.Invoke(2);
                });
                delay += 135;
            }

            var fateDelay = delay;
            Schedule(token, fateDelay, () =>
            {
                var actual = turn.FateDamage;
                if (_fate != null)
                    _fate.text = score.Chips + " × " + score.Multiplier.ToString("0.00") +
                                 " = " + score.FateDamage + " FATE" +
                                 (actual != score.FateDamage ? "  →  " + actual + " TREFFER" : string.Empty);
                _fate?.EnableInClassList("auflosung__fate--aktiv", true);
                impact?.Invoke(lethal ? 3 : breakMoment ? 2 : 1);
            });
            delay += lethal ? 150 : 95;

            if (breakMoment)
            {
                var when = delay;
                Schedule(token, when, () =>
                {
                    if (_moment != null) _moment.text = "✦  HALTUNG BRICHT";
                    _moment?.EnableInClassList("auflosung__moment--sichtbar", true);
                    _halo?.EnableInClassList("auflosung__halo--bruch", true);
                    stanceBreak?.Invoke();
                });
                delay += 125;
            }

            if (turn.PhaseChanged)
            {
                var when = delay;
                Schedule(token, when, () =>
                {
                    if (_moment != null) _moment.text = "DAS SIEGEL REISST";
                    _moment?.EnableInClassList("auflosung__moment--sichtbar", true);
                    _moment?.EnableInClassList("auflosung__moment--blut", true);
                    phaseChanged?.Invoke();
                });
                delay += 150;
            }

            if (blockedAfter.HasValue && blockedAfter != blockedBefore)
            {
                var collapsed = blockedAfter.Value;
                var when = delay;
                Schedule(token, when, () =>
                {
                    if (_moment != null)
                        _moment.text = CombatSystem.SlotName(collapsed).ToUpperInvariant() + " STÜRZT EIN";
                    _moment?.EnableInClassList("auflosung__moment--sichtbar", true);
                    _moment?.EnableInClassList("auflosung__moment--blut", true);
                    slotCollapse?.Invoke(collapsed);
                });
                delay += 130;
            }

            if (lethal)
            {
                var when = delay;
                Schedule(token, when, () =>
                {
                    if (_stamp != null) _stamp.text = "SCHICKSAL BESIEGELT";
                    _stamp?.EnableInClassList("auflosung__stempel--sichtbar", true);
                    _stamp?.EnableInClassList("auflosung__stempel--toedlich", true);
                    _halo?.EnableInClassList("auflosung__halo--toedlich", true);
                    PulseClass("auflosung--urteil", 210);
                    impact?.Invoke(3);
                });
                delay += 185;
            }

            var endDelay = Math.Max(score.IsWorld || lethal ? 980 : 720, delay + 220);
            Schedule(token, endDelay, () =>
            {
                _root.style.display = DisplayStyle.None;
                ResetClasses();
                completed?.Invoke();
            });
        }

        private void ResetContent()
        {
            _steps?.Clear();
            if (_eyebrow != null) _eyebrow.text = string.Empty;
            if (_stamp != null) _stamp.text = string.Empty;
            if (_fate != null) _fate.text = string.Empty;
            if (_moment != null) _moment.text = string.Empty;
            ResetClasses();
        }

        private void ResetClasses()
        {
            _root?.EnableInClassList("auflosung--toedlich", false);
            _root?.EnableInClassList("auflosung--welt", false);
            _root?.EnableInClassList("auflosung--bruch", false);
            _root?.EnableInClassList("auflosung--schritt-puls", false);
            _root?.EnableInClassList("auflosung--urteil", false);
            _halo?.EnableInClassList("auflosung__halo--welt", false);
            _halo?.EnableInClassList("auflosung__halo--bruch", false);
            _halo?.EnableInClassList("auflosung__halo--toedlich", false);
            _stamp?.EnableInClassList("auflosung__stempel--sichtbar", false);
            _stamp?.EnableInClassList("auflosung__stempel--toedlich", false);
            _fate?.EnableInClassList("auflosung__fate--aktiv", false);
            _moment?.EnableInClassList("auflosung__moment--sichtbar", false);
            _moment?.EnableInClassList("auflosung__moment--blut", false);
        }

        private void PulseClass(string className, int duration)
        {
            if (_root == null) return;
            _root.EnableInClassList(className, true);
            var token = _token;
            _root.schedule.Execute(() =>
            {
                if (token == _token) _root.EnableInClassList(className, false);
            }).StartingIn(duration);
        }

        private void Schedule(int token, int delay, Action action)
        {
            _root.schedule.Execute(() =>
            {
                if (token == _token) action();
            }).StartingIn(delay);
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
