using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    public sealed partial class TartotView
    {
        private VisualElement _enemyBackdrop, _enemyFigureArt, _ruleCard, _ruleSeal;
        private VisualElement _previewPanel, _previewCascade, _resolution;
        private Label _ruleSealLabel;
        private readonly Dictionary<SlotPosition, VisualElement> _slotArts =
            new Dictionary<SlotPosition, VisualElement>();
        private int _resolutionToken;

        private static readonly Dictionary<string, Texture2D> VisualTextures =
            new Dictionary<string, Texture2D>();

        private void CacheVisualElements()
        {
            _enemyBackdrop = _root.Q<VisualElement>("gegner-kulisse");
            _enemyFigureArt = _root.Q<VisualElement>("gegner-figurkunst");
            _ruleCard = _root.Q<VisualElement>("gegner-regelkarte");
            _ruleSeal = _root.Q<VisualElement>("gegner-regelsiegel");
            _ruleSealLabel = _root.Q<Label>("gegner-regelsiegel-text");
            _previewPanel = _root.Q<VisualElement>("vorschau-panel");
            _previewCascade = _root.Q<VisualElement>("vorschau-kaskade");
            _resolution = _root.Q<VisualElement>("auflosung");

            _slotArts[SlotPosition.Past] = _root.Q<VisualElement>("platz-past-art");
            _slotArts[SlotPosition.Present] = _root.Q<VisualElement>("platz-present-art");
            _slotArts[SlotPosition.Future] = _root.Q<VisualElement>("platz-future-art");

            _root.RegisterCallback<GeometryChangedEvent>(evt =>
            {
                if (_frame == null) return;
                _frame.EnableInClassList("wurzel--desktop", evt.newRect.width > evt.newRect.height * 1.12f);
            });
        }

        private void RefreshEnemyVisual(EnemyState enemy)
        {
            if (enemy == null) return;
            var hasRules = enemy.Definition.Rules != null && enemy.Definition.Rules.Count > 0;
            var tower = _game != null && _game.Combat != null &&
                        CombatSystem.HasRule(_game.Combat, BossRule.Tower);
            var phaseTwo = enemy.Phase >= 1;

            if (_ruleCard != null)
            {
                _ruleCard.style.display = hasRules ? DisplayStyle.Flex : DisplayStyle.None;
                _ruleCard.EnableInClassList("regelkarte--phase2", phaseTwo);
            }
            _ruleSeal?.EnableInClassList("regelkarte__siegel--gebrochen", phaseTwo || enemy.Sigils <= 0);
            if (_ruleSealLabel != null) _ruleSealLabel.text = tower ? "XVI" : "✦";

            _frame?.EnableInClassList("kampf--turm", tower);
            _frame?.EnableInClassList("kampf--phase2", tower && phaseTwo);

            SetVisualTexture(_enemyBackdrop, tower ? "Tartot/Stage/turm_hintergrund" : null);
            SetVisualTexture(_enemyFigureArt, tower ? "Tartot/Stage/turm_figur" : null);
            SetVisualTexture(_slotArts[SlotPosition.Past], tower ? "Tartot/Stage/turm_platz_0" : null);
            SetVisualTexture(_slotArts[SlotPosition.Present], tower ? "Tartot/Stage/turm_platz_1" : null);
            SetVisualTexture(_slotArts[SlotPosition.Future], tower ? "Tartot/Stage/turm_platz_2" : null);
        }

        private void RefreshSlotVisual(SlotPosition slot, bool blocked, bool occupied)
        {
            if (!_slots.TryGetValue(slot, out var element)) return;
            element.EnableInClassList("platz--leer", !occupied);
            element.EnableInClassList("platz--bruch", blocked);
        }

        private CardElement DecorateCombatCard(CardElement element, Action<CardElement> onClick)
        {
            element.AddToClassList("karte--kampf");
            if (onClick == null)
            {
                element.AddToClassList("karte--auf-tisch");
                return element;
            }
            ConfigureCombatCardInput(element, onClick);
            return element;
        }

        private void ApplyHandFan(CardElement element, int index, int count)
        {
            if (element == null || count <= 1) return;
            var normalized = ((float)index / (count - 1)) * 2f - 1f;
            var bucket = normalized < -.72f ? "m3"
                : normalized < -.38f ? "m2"
                : normalized < -.12f ? "m1"
                : normalized > .72f ? "p3"
                : normalized > .38f ? "p2"
                : normalized > .12f ? "p1"
                : "c";
            element.AddToClassList("karte--faecher-" + bucket);
        }

        private void ConfigureCombatCardInput(CardElement element, Action<CardElement> onClick)
        {
            var pressed = false;
            var dragging = false;
            var suppressClick = false;
            var press = new Vector2();

            element.RegisterCallback<PointerDownEvent>(evt =>
            {
                if (_game == null || _game.Phase != GamePhase.Combat) return;
                pressed = true;
                dragging = false;
                press = new Vector2(evt.position.x, evt.position.y);
                element.CapturePointer(evt.pointerId);
            });

            element.RegisterCallback<PointerMoveEvent>(evt =>
            {
                if (!pressed) return;
                var current = new Vector2(evt.position.x, evt.position.y);
                var delta = current - press;
                if (!dragging && delta.sqrMagnitude > 144f)
                {
                    dragging = true;
                    suppressClick = true;
                    element.AddToClassList("karte--gezogen");
                    OnCombatCardDragStart(element);
                }
                if (!dragging) return;
                element.style.left = delta.x;
                element.style.top = delta.y;
                evt.StopPropagation();
            });

            element.RegisterCallback<PointerUpEvent>(evt =>
            {
                if (!pressed) return;
                pressed = false;
                element.ReleasePointer(evt.pointerId);
                element.style.left = 0;
                element.style.top = 0;
                element.RemoveFromClassList("karte--gezogen");
                if (!dragging) return;
                dragging = false;
                OnCombatCardDropped(element, new Vector2(evt.position.x, evt.position.y));
                evt.StopPropagation();
            });

            element.RegisterCallback<ClickEvent>(_ =>
            {
                if (suppressClick)
                {
                    suppressClick = false;
                    return;
                }
                onClick(element);
            });
        }

        private void OnCombatCardDragStart(CardElement element)
        {
            if (_game == null || _game.Combat == null) return;
            _selected?.SetSelected(false);
            _selected = null;
            foreach (var pair in _slots)
            {
                var blocked = _game.Combat.BlockedSlot.HasValue &&
                              _game.Combat.BlockedSlot.Value == pair.Key;
                pair.Value.EnableInClassList("platz--ziel", !blocked);
                pair.Value.EnableInClassList("platz--ziel-gesperrt", blocked);
            }
        }

        private void OnCombatCardDropped(CardElement element, Vector2 pointer)
        {
            if (_game == null || _game.Combat == null)
            {
                ClearDropTargets();
                return;
            }

            var found = false;
            foreach (var pair in _slots)
            {
                if (!pair.Value.worldBound.Contains(pointer)) continue;
                found = true;
                if (!_game.CombatSystem.PlaceCard(_game.Combat, element.Card.InstanceId, pair.Key))
                    _log.text = "Dieser Schicksalsplatz nimmt die Karte nicht an.";
                break;
            }

            var feedback = found ? string.Empty : "Die Karte kehrt in deine Hand zurück.";
            _selected = null;
            ClearDropTargets();
            Refresh();
            if (!string.IsNullOrEmpty(feedback)) _log.text = feedback;
        }

        private void RefreshDropTargets()
        {
            ClearDropTargets();
            if (_selected == null || _game == null || _game.Combat == null) return;
            foreach (var pair in _slots)
            {
                var blocked = _game.Combat.BlockedSlot.HasValue &&
                              _game.Combat.BlockedSlot.Value == pair.Key;
                pair.Value.EnableInClassList("platz--ziel", !blocked);
                pair.Value.EnableInClassList("platz--ziel-gesperrt", blocked);
            }
        }

        private void ClearDropTargets()
        {
            foreach (var element in _slots.Values)
            {
                element.EnableInClassList("platz--ziel", false);
                element.EnableInClassList("platz--ziel-gesperrt", false);
            }
        }

        private void ClearPreviewVisual()
        {
            _previewCascade?.Clear();
            _previewPanel?.EnableInClassList("vorschau-panel--toedlich", false);
            _previewPanel?.EnableInClassList("vorschau-panel--bruch", false);
        }

        private void RefreshPreviewVisual(ScoreBreakdown score)
        {
            ClearPreviewVisual();
            if (score == null || score.Veiled || _previewCascade == null) return;
            foreach (var step in score.Steps.Take(5))
            {
                var line = new Label(ScoreStepText(step));
                line.AddToClassList("kaskade__schritt");
                if (string.IsNullOrEmpty(step.InstanceId)) line.AddToClassList("kaskade__schritt--muster");
                _previewCascade.Add(line);
            }
            _previewPanel?.EnableInClassList("vorschau-panel--toedlich", score.Lethal);
            _previewPanel?.EnableInClassList("vorschau-panel--bruch", score.BreaksStance);
        }

        private static string ScoreStepText(ScoreStep step)
        {
            var parts = new List<string>();
            if (step.Chips != 0) parts.Add((step.Chips > 0 ? "+" : "") + step.Chips + " Chips");
            if (Math.Abs(step.MultAdd) > .001f)
                parts.Add((step.MultAdd > 0 ? "+" : "") + step.MultAdd.ToString("0.00") + " Mult");
            if (Math.Abs(step.MultX - 1f) > .001f) parts.Add("×" + step.MultX.ToString("0.00"));
            return step.Label + (parts.Count > 0 ? "  ·  " + string.Join("  ", parts) : string.Empty);
        }

        private void ShowResolution(TurnResult turn, SlotPosition? blockedBefore)
        {
            if (_resolution == null || turn == null || turn.Score == null) return;
            var token = ++_resolutionToken;
            _resolution.Clear();

            foreach (var step in turn.Score.Steps.Take(4))
            {
                var line = new Label(ScoreStepText(step));
                line.AddToClassList("auflosung__schritt");
                _resolution.Add(line);
            }

            var fate = new Label(turn.Score.Chips + " × " + turn.Score.Multiplier.ToString("0.00") +
                                 "  =  " + turn.Score.FateDamage + " FATE");
            fate.AddToClassList("auflosung__fate");
            if (turn.Score.Lethal) fate.AddToClassList("auflosung__fate--toedlich");
            _resolution.Add(fate);

            if (turn.StanceBroken)
            {
                var stance = new Label("✦  HALTUNG BRICHT");
                stance.AddToClassList("auflosung__moment");
                _resolution.Add(stance);
            }
            if (turn.PhaseChanged)
            {
                var phase = new Label("DAS SIEGEL REISST — DIE REGEL VERSCHAERFT SICH");
                phase.AddToClassList("auflosung__moment");
                phase.AddToClassList("auflosung__moment--blut");
                _resolution.Add(phase);
            }

            var blockedAfter = _game?.Combat?.BlockedSlot;
            if (blockedAfter.HasValue && blockedAfter != blockedBefore)
            {
                var collapse = new Label(CombatSystem.SlotName(blockedAfter.Value).ToUpperInvariant() + " STUERZT EIN");
                collapse.AddToClassList("auflosung__moment");
                collapse.AddToClassList("auflosung__moment--blut");
                _resolution.Add(collapse);
            }

            _resolution.style.display = DisplayStyle.Flex;
            _resolution.schedule.Execute(() =>
            {
                if (token == _resolutionToken) _resolution.style.display = DisplayStyle.None;
            }).StartingIn(1500);
        }

        private VisualElement OmenPreview(CardDefinition omen)
        {
            var preview = new VisualElement();
            preview.AddToClassList("omenkarte");
            var art = new VisualElement();
            art.AddToClassList("omenkarte__motiv");
            SetVisualTexture(art, "Tartot/CardArt/" + omen.Id);
            preview.Add(art);
            var number = new Label(MetaProgress.Roman(omen.DisplayNumber));
            number.AddToClassList("omenkarte__nummer");
            preview.Add(number);
            var name = new Label(omen.Name.ToUpperInvariant());
            name.AddToClassList("omenkarte__name");
            preview.Add(name);
            return preview;
        }

        private static void StyleOmenButton(Button button, string choice)
        {
            if (button == null) return;
            button.AddToClassList("omenwahl");
            button.AddToClassList("omenwahl--" + choice);
        }

        private static Texture2D VisualTexture(string path)
        {
            if (string.IsNullOrEmpty(path)) return null;
            if (VisualTextures.TryGetValue(path, out var cached)) return cached;
            var texture = Resources.Load<Texture2D>(path);
            VisualTextures[path] = texture;
            return texture;
        }

        private static void SetVisualTexture(VisualElement element, string path)
        {
            if (element != null) element.style.backgroundImage = new StyleBackground(VisualTexture(path));
        }
    }
}
