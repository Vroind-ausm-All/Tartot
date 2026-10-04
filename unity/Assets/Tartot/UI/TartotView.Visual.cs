using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Game-Feel fuer den Kampftisch. Diese Schicht interpretiert ausschliesslich
    /// bereits berechnete Core-Zustaende und TurnResults.
    /// </summary>
    public sealed partial class TartotView
    {
        private VisualElement _enemyRoot, _enemyBackdrop, _enemyFigureArt, _ruleCard, _ruleSeal;
        private VisualElement _previewPanel, _previewCascade, _resolution;
        private Label _ruleSealLabel;

        private readonly Dictionary<SlotPosition, VisualElement> _slotArts =
            new Dictionary<SlotPosition, VisualElement>();
        private readonly List<CardElement> _handVisuals = new List<CardElement>();

        private int _resolutionToken;
        private int _presentationToken;
        private int _impactToken;
        private int _introToken;
        private bool _presentationLocked;
        private string _pendingSnapCardId = string.Empty;
        private string _stagedEnemyId = string.Empty;

        private static readonly Dictionary<string, Texture2D> VisualTextures =
            new Dictionary<string, Texture2D>();

        private void CacheVisualElements()
        {
            _enemyRoot = _root.Q<VisualElement>("gegner");
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

            if (tower && _stagedEnemyId != enemy.Definition.Id)
            {
                _stagedEnemyId = enemy.Definition.Id;
                PlayTowerEntrance();
            }
        }

        private void PlayTowerEntrance()
        {
            var token = ++_introToken;
            _enemyRoot?.EnableInClassList("gegner--eintritt", true);
            _ruleCard?.EnableInClassList("regelkarte--einflug", true);

            _enemyRoot?.schedule.Execute(() =>
            {
                if (token != _introToken) return;
                _enemyRoot.EnableInClassList("gegner--eintritt", false);
                _ruleCard?.EnableInClassList("regelkarte--einflug", false);
            }).StartingIn(80);
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
                if (!string.IsNullOrEmpty(_pendingSnapCardId) &&
                    element.Card.InstanceId == _pendingSnapCardId)
                {
                    _pendingSnapCardId = string.Empty;
                    PulseSnap(element);
                }
                return element;
            }

            ConfigureCombatCardInput(element, onClick);
            return element;
        }

        private void MarkCardForSnap(string instanceId)
        {
            _pendingSnapCardId = instanceId ?? string.Empty;
        }

        private static void PulseSnap(CardElement element)
        {
            element.AddToClassList("karte--einrasten");
            element.schedule.Execute(() => element.RemoveFromClassList("karte--einrasten"))
                .StartingIn(150);
        }

        private void ApplyHandFan(CardElement element, int index, int count)
        {
            if (element == null) return;

            if (count > 1)
            {
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

            element.RegisterCallback<PointerEnterEvent>(_ =>
            {
                if (_presentationLocked) return;
                SetHandFocus(element);
            });
            element.RegisterCallback<PointerLeaveEvent>(_ =>
            {
                if (_presentationLocked) return;
                if (_selected != null) SetHandFocus(_selected);
                else ClearHandFocus();
            });
        }

        private void SetHandFocus(CardElement focus)
        {
            ClearHandFocus();
            if (focus == null) return;
            var index = _handVisuals.IndexOf(focus);
            if (index < 0) return;

            focus.AddToClassList("karte--fokus");
            if (index > 0) _handVisuals[index - 1].AddToClassList("karte--nachbar-links");
            if (index + 1 < _handVisuals.Count) _handVisuals[index + 1].AddToClassList("karte--nachbar-rechts");
        }

        private void ClearHandFocus()
        {
            foreach (var card in _handVisuals)
            {
                card.EnableInClassList("karte--fokus", false);
                card.EnableInClassList("karte--nachbar-links", false);
                card.EnableInClassList("karte--nachbar-rechts", false);
            }
        }

        private void ConfigureCombatCardInput(CardElement element, Action<CardElement> onClick)
        {
            var pressed = false;
            var dragging = false;
            var suppressClick = false;
            var press = new Vector2();

            element.RegisterCallback<PointerDownEvent>(evt =>
            {
                if (_presentationLocked || _game == null || _game.Phase != GamePhase.Combat) return;
                pressed = true;
                dragging = false;
                press = new Vector2(evt.position.x, evt.position.y);
                element.CapturePointer(evt.pointerId);
            });

            element.RegisterCallback<PointerMoveEvent>(evt =>
            {
                if (!pressed || _presentationLocked) return;
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
                UpdateDragTarget(current);
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
                if (_presentationLocked) return;
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
            SetHandFocus(element);
            RefreshDropTargets();
        }

        private void UpdateDragTarget(Vector2 pointer)
        {
            if (_game == null || _game.Combat == null) return;

            foreach (var pair in _slots)
            {
                var inside = pair.Value.worldBound.Contains(pointer);
                var blocked = _game.Combat.BlockedSlot.HasValue &&
                              _game.Combat.BlockedSlot.Value == pair.Key;
                pair.Value.EnableInClassList("platz--ziel-aktiv", inside && !blocked);
                pair.Value.EnableInClassList("platz--ziel-gesperrt-aktiv", inside && blocked);
            }
        }

        private void OnCombatCardDropped(CardElement element, Vector2 pointer)
        {
            if (_presentationLocked || _game == null || _game.Combat == null)
            {
                ClearDropTargets();
                return;
            }

            SlotPosition? target = null;
            foreach (var pair in _slots)
            {
                if (pair.Value.worldBound.Contains(pointer))
                {
                    target = pair.Key;
                    break;
                }
            }

            if (!target.HasValue)
            {
                PulseCardReject(element);
                _log.text = "Die Karte kehrt in deine Hand zurück.";
                ClearDropTargets();
                return;
            }

            if (!_game.CombatSystem.PlaceCard(_game.Combat, element.Card.InstanceId, target.Value))
            {
                RejectPlacement(target.Value, element);
                ClearDropTargets();
                return;
            }

            MarkCardForSnap(element.Card.InstanceId);
            _selected = null;
            ClearDropTargets();
            Refresh();
        }

        private void RejectPlacement(SlotPosition slot, CardElement card)
        {
            _log.text = "Dieser Schicksalsplatz nimmt die Karte nicht an.";
            PulseCardReject(card);
            if (_slots.TryGetValue(slot, out var target))
            {
                target.AddToClassList("platz--reject");
                target.schedule.Execute(() => target.RemoveFromClassList("platz--reject"))
                    .StartingIn(220);
            }
        }

        private static void PulseCardReject(CardElement card)
        {
            if (card == null) return;
            card.AddToClassList("karte--abgewiesen-a");
            card.schedule.Execute(() =>
            {
                card.RemoveFromClassList("karte--abgewiesen-a");
                card.AddToClassList("karte--abgewiesen-b");
            }).StartingIn(70);
            card.schedule.Execute(() => card.RemoveFromClassList("karte--abgewiesen-b"))
                .StartingIn(150);
        }

        private void RefreshDropTargets()
        {
            ClearDropTargets();
            if (_game == null || _game.Combat == null) return;

            if (_selected != null) SetHandFocus(_selected);

            foreach (var pair in _slots)
            {
                var blocked = _game.Combat.BlockedSlot.HasValue &&
                              _game.Combat.BlockedSlot.Value == pair.Key;
                pair.Value.EnableInClassList("platz--ziel", _selected != null && !blocked);
                pair.Value.EnableInClassList("platz--ziel-gesperrt", _selected != null && blocked);
            }
        }

        private void ClearDropTargets()
        {
            foreach (var element in _slots.Values)
            {
                element.EnableInClassList("platz--ziel", false);
                element.EnableInClassList("platz--ziel-gesperrt", false);
                element.EnableInClassList("platz--ziel-aktiv", false);
                element.EnableInClassList("platz--ziel-gesperrt-aktiv", false);
            }
        }

        private void ClearPreviewVisual()
        {
            _previewCascade?.Clear();
            _previewPanel?.EnableInClassList("vorschau-panel--toedlich", false);
            _previewPanel?.EnableInClassList("vorschau-panel--bruch", false);
            _previewPanel?.EnableInClassList("vorschau-panel--welt", false);

            if (_actButton != null)
            {
                _actButton.EnableInClassList("knopf--toedlich", false);
                _actButton.EnableInClassList("knopf--bruchbereit", false);
                _actButton.EnableInClassList("knopf--welt", false);
                _actButton.text = "SCHICKSAL AUSFÜHREN";
            }
        }

        private void RefreshPreviewVisual(ScoreBreakdown score)
        {
            ClearPreviewVisual();
            if (score == null || score.Veiled || _previewCascade == null) return;

            foreach (var step in score.Steps.Take(5))
            {
                var line = new Label(ScoreStepText(step));
                line.AddToClassList("kaskade__schritt");
                if (string.IsNullOrEmpty(step.InstanceId))
                    line.AddToClassList("kaskade__schritt--muster");
                _previewCascade.Add(line);
            }

            _previewPanel?.EnableInClassList("vorschau-panel--toedlich", score.Lethal);
            _previewPanel?.EnableInClassList("vorschau-panel--bruch", score.BreaksStance);
            _previewPanel?.EnableInClassList("vorschau-panel--welt", score.IsWorld);

            if (_actButton == null) return;
            _actButton.EnableInClassList("knopf--toedlich", score.Lethal);
            _actButton.EnableInClassList("knopf--bruchbereit", score.BreaksStance && !score.Lethal);
            _actButton.EnableInClassList("knopf--welt", score.IsWorld);

            if (score.Lethal) _actButton.text = "SCHICKSAL BESIEGELN";
            else if (score.IsWorld) _actButton.text = "DIE WELT AUSFÜHREN";
            else if (score.BreaksStance) _actButton.text = "HALTUNG BRECHEN";
        }

        private static string ScoreStepText(ScoreStep step)
        {
            var parts = new List<string>();
            if (step.Chips != 0) parts.Add((step.Chips > 0 ? "+" : "") + step.Chips + " Chips");
            if (Math.Abs(step.MultAdd) > .001f)
                parts.Add((step.MultAdd > 0 ? "+" : "") + step.MultAdd.ToString("0.00") + " Mult");
            if (Math.Abs(step.MultX - 1f) > .001f)
                parts.Add("×" + step.MultX.ToString("0.00"));
            return step.Label + (parts.Count > 0 ? "  ·  " + string.Join("  ", parts) : string.Empty);
        }

        /// <summary>
        /// Setzt den reinen Presentation-Lock vor Refresh(), damit Reward-/BossLoot-
        /// Overlays einen finalen Treffer nicht verdecken.
        /// </summary>
        private void PrepareResolution(TurnResult turn)
        {
            if (turn == null || turn.Score == null) return;
            _presentationLocked = true;
            _frame?.EnableInClassList("kampf--aufloesung", true);
            _actButton?.SetEnabled(false);
        }

        private void ShowResolution(TurnResult turn, SlotPosition? blockedBefore)
        {
            if (_resolution == null || turn == null || turn.Score == null)
            {
                ReleasePresentationLock();
                return;
            }

            var token = ++_resolutionToken;
            _resolution.Clear();
            _resolution.EnableInClassList("auflosung--toedlich", turn.Score.Lethal);
            _resolution.EnableInClassList("auflosung--welt", turn.Score.IsWorld);
            _resolution.style.display = DisplayStyle.Flex;

            var delay = 30;
            foreach (var step in turn.Score.Steps.Take(4))
            {
                var captured = step;
                var when = delay;
                _resolution.schedule.Execute(() =>
                {
                    if (token != _resolutionToken) return;
                    var line = new Label(ScoreStepText(captured));
                    line.AddToClassList("auflosung__schritt");
                    if (string.IsNullOrEmpty(captured.InstanceId))
                        line.AddToClassList("auflosung__schritt--muster");
                    _resolution.Add(line);
                }).StartingIn(when);
                delay += 85;
            }

            if (turn.Score.IsWorld)
            {
                var when = delay;
                _resolution.schedule.Execute(() =>
                {
                    if (token != _resolutionToken) return;
                    var world = new Label("XXI  ·  DIE WELT");
                    world.AddToClassList("auflosung__welt");
                    _resolution.Add(world);
                    PulseWorld();
                }).StartingIn(when);
                delay += 120;
            }

            var fateDelay = delay;
            _resolution.schedule.Execute(() =>
            {
                if (token != _resolutionToken) return;
                var fate = new Label(turn.Score.Chips + " × " + turn.Score.Multiplier.ToString("0.00") +
                                     "  =  " + turn.Score.FateDamage + " FATE");
                fate.AddToClassList("auflosung__fate");
                if (turn.Score.Lethal) fate.AddToClassList("auflosung__fate--toedlich");
                _resolution.Add(fate);
                PulseImpact(turn.Score.Lethal ? 2 : 1);
            }).StartingIn(fateDelay);
            delay += turn.Score.Lethal ? 145 : 95;

            if (turn.StanceBroken)
            {
                var when = delay;
                _resolution.schedule.Execute(() =>
                {
                    if (token != _resolutionToken) return;
                    var stance = new Label("✦  HALTUNG BRICHT");
                    stance.AddToClassList("auflosung__moment");
                    _resolution.Add(stance);
                    PulseStanceBreak();
                }).StartingIn(when);
                delay += 120;
            }

            if (turn.PhaseChanged)
            {
                var when = delay;
                _resolution.schedule.Execute(() =>
                {
                    if (token != _resolutionToken) return;
                    var phase = new Label("DAS SIEGEL REISST — DIE REGEL VERSCHAERFT SICH");
                    phase.AddToClassList("auflosung__moment");
                    phase.AddToClassList("auflosung__moment--blut");
                    _resolution.Add(phase);
                    PulseSealBreak();
                }).StartingIn(when);
                delay += 150;
            }

            var blockedAfter = _game?.Combat?.BlockedSlot;
            if (blockedAfter.HasValue && blockedAfter != blockedBefore)
            {
                var collapsed = blockedAfter.Value;
                var when = delay;
                _resolution.schedule.Execute(() =>
                {
                    if (token != _resolutionToken) return;
                    var collapse = new Label(CombatSystem.SlotName(collapsed).ToUpperInvariant() + " STUERZT EIN");
                    collapse.AddToClassList("auflosung__moment");
                    collapse.AddToClassList("auflosung__moment--blut");
                    _resolution.Add(collapse);
                    PulseSlotCollapse(collapsed);
                }).StartingIn(when);
                delay += 145;
            }

            var endDelay = Math.Max(720, delay + 230);
            _resolution.schedule.Execute(() =>
            {
                if (token != _resolutionToken) return;
                _resolution.style.display = DisplayStyle.None;
                _resolution.EnableInClassList("auflosung--toedlich", false);
                _resolution.EnableInClassList("auflosung--welt", false);
            }).StartingIn(endDelay);

            SchedulePresentationUnlock(endDelay + 20);
        }

        private void PulseStanceBreak()
        {
            if (_enemyRoot == null) return;
            _enemyRoot.AddToClassList("gegner--haltung-bruch");
            PulseImpact(2);
            _enemyRoot.schedule.Execute(() =>
                _enemyRoot.RemoveFromClassList("gegner--haltung-bruch")).StartingIn(260);
        }

        private void PulseSealBreak()
        {
            _ruleCard?.EnableInClassList("regelkarte--bricht", true);
            _ruleSeal?.EnableInClassList("regelkarte__siegel--bricht", true);
            PulseImpact(3);

            _ruleCard?.schedule.Execute(() =>
            {
                _ruleCard.EnableInClassList("regelkarte--bricht", false);
                _ruleSeal?.EnableInClassList("regelkarte__siegel--bricht", false);
            }).StartingIn(360);
        }

        private void PulseSlotCollapse(SlotPosition slot)
        {
            if (!_slots.TryGetValue(slot, out var element)) return;
            element.EnableInClassList("platz--einsturz-cue", true);
            PulseImpact(3);

            element.schedule.Execute(() =>
            {
                element.EnableInClassList("platz--einsturz-cue", false);
                element.EnableInClassList("platz--einsturz-nachhall", true);
            }).StartingIn(180);
            element.schedule.Execute(() =>
                element.EnableInClassList("platz--einsturz-nachhall", false)).StartingIn(520);
        }

        private void PulseWorld()
        {
            _frame?.EnableInClassList("kampf--welt", true);
            _frame?.schedule.Execute(() =>
                _frame.EnableInClassList("kampf--welt", false)).StartingIn(420);
        }

        private void PulseImpact(int strength)
        {
            if (_frame == null) return;
            var token = ++_impactToken;
            _frame.EnableInClassList("kampf--stoss-a", false);
            _frame.EnableInClassList("kampf--stoss-b", false);
            _frame.EnableInClassList("kampf--stoss-stark", strength >= 2);
            _frame.EnableInClassList("kampf--stoss-a", true);

            _frame.schedule.Execute(() =>
            {
                if (token != _impactToken) return;
                _frame.EnableInClassList("kampf--stoss-a", false);
                _frame.EnableInClassList("kampf--stoss-b", true);
            }).StartingIn(45);

            _frame.schedule.Execute(() =>
            {
                if (token != _impactToken) return;
                _frame.EnableInClassList("kampf--stoss-b", false);
                _frame.EnableInClassList("kampf--stoss-stark", false);
            }).StartingIn(95);
        }

        private void SchedulePresentationUnlock(int delayMs)
        {
            var token = ++_presentationToken;
            _root.schedule.Execute(() =>
            {
                if (token != _presentationToken) return;
                ReleasePresentationLock();
            }).StartingIn(delayMs);
        }

        private void ReleasePresentationLock()
        {
            _presentationLocked = false;
            _frame?.EnableInClassList("kampf--aufloesung", false);
            if (_actButton != null)
                _actButton.SetEnabled(_game != null && _game.Phase == GamePhase.Combat);
            RefreshOverlay();
            RefreshToast();
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
            if (element == null) return;
            element.style.backgroundImage = new StyleBackground(VisualTexture(path));
        }
    }
}
