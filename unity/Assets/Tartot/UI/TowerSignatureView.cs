using System.Collections.Generic;
using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Inszeniert ausschliesslich die Turm-Regel, die der Core bereits als
    /// BlockedSlot berechnet hat. Keine Rundenzahl, kein Slot-Zyklus und keine
    /// Bossregel wird hier entschieden.
    /// </summary>
    public sealed class TowerSignatureView
    {
        private readonly VisualElement _table;
        private readonly VisualElement _strike;
        private readonly Dictionary<SlotPosition, VisualElement> _slots;
        private readonly Dictionary<SlotPosition, Label> _hints;
        private readonly Dictionary<SlotPosition, VisualElement> _dust =
            new Dictionary<SlotPosition, VisualElement>();
        private readonly Dictionary<SlotPosition, VisualElement> _shards =
            new Dictionary<SlotPosition, VisualElement>();

        private bool _isTower;
        private bool _deferred;
        private SlotPosition? _displayedBlocked;
        private SlotPosition? _pendingBlocked;
        private int _token;

        private static readonly Dictionary<SlotPosition, string> DefaultHints =
            new Dictionary<SlotPosition, string>
            {
                [SlotPosition.Past] = "90 % — Vorbereitung",
                [SlotPosition.Present] = "100 % — sicher",
                [SlotPosition.Future] = "150 % — nach dem Gegner"
            };

        public TowerSignatureView(
            VisualElement documentRoot,
            Dictionary<SlotPosition, VisualElement> slots,
            Dictionary<SlotPosition, Label> hints)
        {
            _table = documentRoot.Q<VisualElement>("tisch");
            _strike = documentRoot.Q<VisualElement>("turm-einschlag");
            _slots = slots;
            _hints = hints;

            _dust[SlotPosition.Past] = documentRoot.Q<VisualElement>("platz-past-staub");
            _dust[SlotPosition.Present] = documentRoot.Q<VisualElement>("platz-present-staub");
            _dust[SlotPosition.Future] = documentRoot.Q<VisualElement>("platz-future-staub");

            _shards[SlotPosition.Past] = documentRoot.Q<VisualElement>("platz-past-splitter");
            _shards[SlotPosition.Present] = documentRoot.Q<VisualElement>("platz-present-splitter");
            _shards[SlotPosition.Future] = documentRoot.Q<VisualElement>("platz-future-splitter");
        }

        public void Refresh(bool isTower, SlotPosition? actualBlocked)
        {
            _isTower = isTower;
            _table?.EnableInClassList("tisch--turm", isTower);

            if (!isTower)
            {
                _deferred = false;
                _displayedBlocked = null;
                _pendingBlocked = null;
                ClearTowerClasses();
                return;
            }

            if (_deferred) return;
            _displayedBlocked = actualBlocked;
            ApplyPersistentState(_displayedBlocked);
        }

        /// <summary>
        /// Friert den sichtbaren alten Zustand ein, bis die Resolve-Kaskade den
        /// eigentlichen Einsturz oder die Wiederkehr erreicht.
        /// </summary>
        public void PrepareTransition(SlotPosition? before, SlotPosition? after)
        {
            if (!_isTower || before == after)
            {
                _deferred = false;
                _displayedBlocked = after;
                _pendingBlocked = after;
                return;
            }

            _deferred = true;
            _displayedBlocked = before;
            _pendingBlocked = after;
            ApplyPersistentState(before);
        }

        public bool DisplayBlocked(SlotPosition slot, bool actualBlocked)
        {
            if (!_isTower) return actualBlocked;
            if (_deferred) return _displayedBlocked.HasValue && _displayedBlocked.Value == slot;
            return actualBlocked;
        }

        public void PlayCollapse(SlotPosition slot)
        {
            if (!_isTower) return;
            var token = ++_token;
            var previous = _displayedBlocked;

            _deferred = false;
            _pendingBlocked = slot;

            if (previous.HasValue && previous.Value != slot)
                AnimateRecovery(previous.Value, token);

            _displayedBlocked = slot;
            ApplyPersistentState(slot);

            _strike?.EnableInClassList("turm-einschlag--warnung", true);
            _table?.EnableInClassList("tisch--turm-warnung", true);

            if (_slots.TryGetValue(slot, out var target))
                target.EnableInClassList("platz--einsturz-vorwarnung", true);

            _table?.schedule.Execute(() =>
            {
                if (token != _token) return;
                _strike?.EnableInClassList("turm-einschlag--warnung", false);
                _strike?.EnableInClassList("turm-einschlag--schlag", true);
                _table?.EnableInClassList("tisch--turm-warnung", false);
                _table?.EnableInClassList("tisch--turm-schlag", true);

                if (_slots.TryGetValue(slot, out var hit))
                {
                    hit.EnableInClassList("platz--einsturz-vorwarnung", false);
                    hit.EnableInClassList("platz--einsturz-cue", true);
                }
                _dust[slot]?.EnableInClassList("platz__staub--aktiv", true);
                _shards[slot]?.EnableInClassList("platz__splitter--aktiv", true);
            }).StartingIn(95);

            _table?.schedule.Execute(() =>
            {
                if (token != _token) return;
                _strike?.EnableInClassList("turm-einschlag--schlag", false);
                _table?.EnableInClassList("tisch--turm-schlag", false);
                if (_slots.TryGetValue(slot, out var hit))
                {
                    hit.EnableInClassList("platz--einsturz-cue", false);
                    hit.EnableInClassList("platz--einsturz-nachhall", true);
                }
            }).StartingIn(270);

            _table?.schedule.Execute(() =>
            {
                if (token != _token) return;
                if (_slots.TryGetValue(slot, out var hit))
                    hit.EnableInClassList("platz--einsturz-nachhall", false);
                _dust[slot]?.EnableInClassList("platz__staub--aktiv", false);
                _shards[slot]?.EnableInClassList("platz__splitter--aktiv", false);
                _strike?.EnableInClassList("turm-einschlag--warnung", false);
                _strike?.EnableInClassList("turm-einschlag--schlag", false);
            }).StartingIn(620);
        }

        public void PlayRecovery(SlotPosition slot)
        {
            if (!_isTower) return;
            var token = ++_token;

            _deferred = false;
            _pendingBlocked = null;
            _displayedBlocked = null;
            ApplyPersistentState(null);
            AnimateRecovery(slot, token);
        }

        public void Synchronize(SlotPosition? actualBlocked)
        {
            if (!_isTower) return;
            _deferred = false;
            _pendingBlocked = actualBlocked;
            _displayedBlocked = actualBlocked;
            ApplyPersistentState(actualBlocked);
        }

        private void AnimateRecovery(SlotPosition slot, int token)
        {
            if (!_slots.TryGetValue(slot, out var element)) return;

            element.EnableInClassList("platz--rueckkehr", true);
            _dust[slot]?.EnableInClassList("platz__staub--rueckkehr", true);

            _table?.schedule.Execute(() =>
            {
                if (token != _token) return;
                element.EnableInClassList("platz--rueckkehr", false);
                _dust[slot]?.EnableInClassList("platz__staub--rueckkehr", false);
            }).StartingIn(360);
        }

        private void ApplyPersistentState(SlotPosition? blocked)
        {
            foreach (var pair in _slots)
            {
                var isBlocked = blocked.HasValue && blocked.Value == pair.Key;
                pair.Value.EnableInClassList("platz--eingestuerzt", isBlocked);
                pair.Value.EnableInClassList("platz--bruch", isBlocked);

                if (_hints.TryGetValue(pair.Key, out var hint))
                    hint.text = isBlocked ? "EINGESTÜRZT — der Turm" : DefaultHints[pair.Key];
            }
        }

        private void ClearTowerClasses()
        {
            _strike?.EnableInClassList("turm-einschlag--warnung", false);
            _strike?.EnableInClassList("turm-einschlag--schlag", false);
            _table?.EnableInClassList("tisch--turm-warnung", false);
            _table?.EnableInClassList("tisch--turm-schlag", false);

            foreach (var pair in _slots)
            {
                pair.Value.EnableInClassList("platz--einsturz-vorwarnung", false);
                pair.Value.EnableInClassList("platz--einsturz-cue", false);
                pair.Value.EnableInClassList("platz--einsturz-nachhall", false);
                pair.Value.EnableInClassList("platz--rueckkehr", false);
            }
        }
    }
}
