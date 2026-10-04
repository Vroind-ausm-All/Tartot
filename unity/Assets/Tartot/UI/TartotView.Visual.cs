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
        private BossStageView _bossStageView;
        private BossRuleCardView _bossRuleCardView;
        private TowerSignatureView _towerSignatureView;
        private PreviewCascadeView _previewCascadeView;
        private ResolutionPulseView _resolutionPulseView;

        private readonly Dictionary<SlotPosition, VisualElement> _slotArts =
            new Dictionary<SlotPosition, VisualElement>();
        private readonly List<CardElement> _handVisuals = new List<CardElement>();

        private int _presentationToken;
        private int _impactToken;
        private bool _presentationLocked;
        private string _pendingSnapCardId = string.Empty;

        private static readonly Dictionary<string, Texture2D> VisualTextures =
            new Dictionary<string, Texture2D>();

        private void CacheVisualElements()
        {
            _bossStageView = new BossStageView(_root, _frame, _stage);
            _bossRuleCardView = new BossRuleCardView(_root);
            _towerSignatureView = new TowerSignatureView(_root, _slots, _slotHints);
            _previewCascadeView = new PreviewCascadeView(_root, _actButton);
            _resolutionPulseView = new ResolutionPulseView(_root);

            _slotArts[SlotPosition.Past] = _root.Q<VisualElement>("platz-past-art");
            _slotArts[SlotPosition.Present] = _root.Q<VisualElement>("platz-present-art");
            _slotArts[SlotPosition.Future] = _root.Q<VisualElement>("platz-future-art");

            _root.RegisterCallback<GeometryChangedEvent>(evt =>
            {
                if (_frame == null) return;
                _frame.EnableInClassList("wurzel--desktop", evt.newRect.width > evt.newRect.height * 1.12f);
            });
        }

        private void RefreshEnemyVisual(EnemyState enemy, string activeRuleText)
        {
            if (enemy == null) return;

            var introduced = _bossStageView?.Refresh(enemy) ?? false;
            _bossRuleCardView?.Refresh(enemy, activeRuleText);
            if (introduced) _bossRuleCardView?.PlayIntroCue();

            // Die Turm-Platzkunst gehoert zum Tisch, nicht zur Bossbuehne.
            var tower = enemy.Definition.Id == "boss_turm";
            _towerSignatureView?.Refresh(tower, _game?.Combat?.BlockedSlot);
            SetVisualTexture(_slotArts[SlotPosition.Past], tower ? "Tartot/Stage/turm_platz_0" : null);
            SetVisualTexture(_slotArts[SlotPosition.Present], tower ? "Tartot/Stage/turm_platz_1" : null);
            SetVisualTexture(_slotArts[SlotPosition.Future], tower ? "Tartot/Stage/turm_platz_2" : null);
        }

        private bool DisplaySlotBlocked(SlotPosition slot, bool actualBlocked)
        {
            return _towerSignatureView?.DisplayBlocked(slot, actualBlocked) ?? actualBlocked;
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

        /// <summary>
        /// Setzt den reinen Presentation-Lock vor Refresh(), damit Reward-/BossLoot-
        /// Overlays einen finalen Treffer nicht verdecken.
        /// </summary>
        private void PrepareResolution(TurnResult turn, SlotPosition? blockedBefore)
        {
            if (turn == null || turn.Score == null) return;
            _towerSignatureView?.PrepareTransition(blockedBefore, _game?.Combat?.BlockedSlot);
            if (turn.PhaseChanged)
            {
                _bossStageView?.PreparePhaseChange();
                _bossRuleCardView?.PreparePhaseChange();
            }
            _presentationLocked = true;
            _frame?.EnableInClassList("kampf--aufloesung", true);
            _actButton?.SetEnabled(false);
        }

        private void ShowResolution(TurnResult turn, SlotPosition? blockedBefore)
        {
            var blockedAfter = _game?.Combat?.BlockedSlot;
            if (_resolutionPulseView == null)
            {
                ReleasePresentationLock();
                return;
            }

            _resolutionPulseView.Play(
                turn,
                blockedBefore,
                blockedAfter,
                PulseImpact,
                PulseStanceBreak,
                PulseSealBreak,
                PulseSlotCollapse,
                PulseSlotRestore,
                PulseWorld,
                ReleasePresentationLock);
        }

        private void PulseStanceBreak()
        {
            _bossStageView?.PlayStanceBreakCue();
            PulseImpact(2);
        }

        private void PulseSealBreak()
        {
            _bossRuleCardView?.PlaySealBreakCue();
            _bossStageView?.PlayPhaseTwoCue();
            _towerSignatureView?.PlaySealBreakShock();
            PulseImpact(3);
        }

        private void PulseSlotCollapse(SlotPosition slot)
        {
            _towerSignatureView?.PlayCollapse(slot);
            _bossStageView?.PlayTowerStrikeCue();
            PulseImpact(3);
        }

        private void PulseSlotRestore(SlotPosition slot)
        {
            _towerSignatureView?.PlayRecovery(slot);
            PulseImpact(1);
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
            _towerSignatureView?.Synchronize(_game?.Combat?.BlockedSlot);
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
