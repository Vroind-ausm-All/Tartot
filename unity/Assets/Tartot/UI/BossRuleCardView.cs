using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Physische Boss-Regelkarte. Der Core liefert Regeltext, Phase und Siegel;
    /// diese Klasse entscheidet nur, wie diese Fakten auf dem Tisch erscheinen.
    /// </summary>
    public sealed class BossRuleCardView
    {
        private readonly VisualElement _card;
        private readonly Label _ruleText;
        private readonly Label _phaseLabel;
        private readonly VisualElement _seal;
        private readonly Label _sealText;
        private readonly VisualElement _sealCrack;
        private readonly VisualElement _waxA;
        private readonly VisualElement _waxB;
        private readonly VisualElement _waxC;

        private bool _phaseTwoRequested;
        private bool _phaseTransitionDeferred;
        private int _introToken;
        private int _breakToken;

        public BossRuleCardView(VisualElement documentRoot)
        {
            _card = documentRoot.Q<VisualElement>("gegner-regelkarte");
            _ruleText = documentRoot.Q<Label>("gegner-regel");
            _phaseLabel = documentRoot.Q<Label>("gegner-regelphase");
            _seal = documentRoot.Q<VisualElement>("gegner-regelsiegel");
            _sealText = documentRoot.Q<Label>("gegner-regelsiegel-text");
            _sealCrack = documentRoot.Q<VisualElement>("gegner-regelsiegel-riss");
            _waxA = documentRoot.Q<VisualElement>("gegner-wachssplitter-a");
            _waxB = documentRoot.Q<VisualElement>("gegner-wachssplitter-b");
            _waxC = documentRoot.Q<VisualElement>("gegner-wachssplitter-c");
        }

        public void Refresh(EnemyState enemy, string activeRuleText)
        {
            if (_card == null || enemy == null || enemy.Definition == null) return;

            var hasRules = enemy.Definition.Rules != null && enemy.Definition.Rules.Count > 0;
            _card.style.display = hasRules ? DisplayStyle.Flex : DisplayStyle.None;
            if (!hasRules) return;

            if (_ruleText != null) _ruleText.text = activeRuleText ?? string.Empty;
            if (_sealText != null)
                _sealText.text = enemy.Definition.Id == "boss_turm" ? "XVI" : "✦";

            _phaseTwoRequested = enemy.Phase >= 1;
            ApplyPhaseLook(_phaseTwoRequested && !_phaseTransitionDeferred,
                enemy.Sigils <= 0 && !_phaseTransitionDeferred);
        }

        public void PreparePhaseChange()
        {
            _phaseTransitionDeferred = true;
        }

        public void PlayIntroCue()
        {
            if (_card == null) return;
            var token = ++_introToken;

            _card.EnableInClassList("regelkarte--intro-start", true);
            _card.schedule.Execute(() =>
            {
                if (token != _introToken) return;
                _card.EnableInClassList("regelkarte--intro-start", false);
                _card.EnableInClassList("regelkarte--intro-settle", true);
            }).StartingIn(150);

            _card.schedule.Execute(() =>
            {
                if (token != _introToken) return;
                _card.EnableInClassList("regelkarte--intro-settle", false);
            }).StartingIn(560);
        }

        public void PlaySealBreakCue()
        {
            if (_card == null) return;

            _phaseTransitionDeferred = false;
            ApplyPhaseLook(_phaseTwoRequested, true);

            var token = ++_breakToken;
            _card.EnableInClassList("regelkarte--bricht", true);
            _seal?.EnableInClassList("regelkarte__siegel--bricht", true);
            _sealCrack?.EnableInClassList("regelkarte__siegelriss--aktiv", true);
            _waxA?.EnableInClassList("regelkarte__wachssplitter--fliegt-a", true);
            _waxB?.EnableInClassList("regelkarte__wachssplitter--fliegt-b", true);
            _waxC?.EnableInClassList("regelkarte__wachssplitter--fliegt-c", true);
            _phaseLabel?.EnableInClassList("regelkarte__phase--cue", true);

            _card.schedule.Execute(() =>
            {
                if (token != _breakToken) return;
                _card.EnableInClassList("regelkarte--bricht", false);
                _seal?.EnableInClassList("regelkarte__siegel--bricht", false);
                _waxA?.EnableInClassList("regelkarte__wachssplitter--fliegt-a", false);
                _waxB?.EnableInClassList("regelkarte__wachssplitter--fliegt-b", false);
                _waxC?.EnableInClassList("regelkarte__wachssplitter--fliegt-c", false);
                _phaseLabel?.EnableInClassList("regelkarte__phase--cue", false);
            }).StartingIn(380);
        }

        private void ApplyPhaseLook(bool phaseTwo, bool broken)
        {
            _card?.EnableInClassList("regelkarte--phase2", phaseTwo);
            _seal?.EnableInClassList("regelkarte__siegel--gebrochen", broken || phaseTwo);
            _sealCrack?.EnableInClassList("regelkarte__siegelriss--sichtbar", broken || phaseTwo);

            if (_phaseLabel != null)
            {
                _phaseLabel.text = phaseTwo ? "ZWEITE LESART" : "ERSTE LESART";
                _phaseLabel.style.display = phaseTwo ? DisplayStyle.Flex : DisplayStyle.None;
            }
        }
    }
}
