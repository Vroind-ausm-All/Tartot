using System.Collections.Generic;
using Tartot.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Praesentationsschicht fuer die physische Bossbuehne.
    /// Liest Gegnerzustand, entscheidet aber keine Kampfregel.
    /// </summary>
    public sealed class BossStageView
    {
        private readonly VisualElement _combatRoot;
        private readonly VisualElement _stageRoot;
        private readonly VisualElement _backdrop;
        private readonly VisualElement _figureArt;
        private readonly VisualElement _phaseGlow;
        private readonly VisualElement _lightning;
        private readonly VisualElement _dust;
        private readonly EnemyStage _spriteStage;

        private string _enemyId = string.Empty;
        private bool _isTower;
        private bool _phaseTwoRequested;
        private bool _phaseTransitionDeferred;
        private int _introToken;
        private int _stanceToken;
        private int _phaseToken;
        private int _towerStrikeToken;

        private static readonly Dictionary<string, Texture2D> Textures =
            new Dictionary<string, Texture2D>();

        public BossStageView(VisualElement documentRoot, VisualElement combatRoot, EnemyStage spriteStage)
        {
            _combatRoot = combatRoot;
            _spriteStage = spriteStage;
            _stageRoot = documentRoot.Q<VisualElement>("gegner");
            _backdrop = documentRoot.Q<VisualElement>("gegner-buehnenbild");
            _figureArt = documentRoot.Q<VisualElement>("gegner-figurkunst");
            _phaseGlow = documentRoot.Q<VisualElement>("gegner-phaseglut");
            _lightning = documentRoot.Q<VisualElement>("gegner-blitz");
            _dust = documentRoot.Q<VisualElement>("gegner-staub");
        }

        /// <summary>
        /// Aktualisiert nur Darstellung. Rueckgabe true bedeutet: neuer Boss,
        /// daher darf die Regelkarte ihren Intro-Cue spielen.
        /// </summary>
        public bool Refresh(EnemyState enemy)
        {
            if (enemy == null || enemy.Definition == null) return false;

            _spriteStage?.Show(enemy.Definition);
            _isTower = enemy.Definition.Id == "boss_turm";
            _phaseTwoRequested = enemy.Phase >= 1;

            var boss = enemy.Definition.IsBoss;
            _stageRoot?.EnableInClassList("bossbuehne--boss", boss);
            _stageRoot?.EnableInClassList("bossbuehne--turm", _isTower);
            _combatRoot?.EnableInClassList("kampf--turm", _isTower);

            SetTexture(_backdrop, _isTower ? "Tartot/Stage/turm_hintergrund" : null);
            SetTexture(_figureArt, _isTower ? "Tartot/Stage/turm_figur" : null);
            ApplyPhaseLook(_phaseTwoRequested && !_phaseTransitionDeferred);

            var changed = _enemyId != enemy.Definition.Id;
            _enemyId = enemy.Definition.Id;
            if (changed && boss) PlayIntroCue();
            return changed && boss;
        }

        /// <summary>
        /// Muss vor dem Refresh nach einem Core-Phasenwechsel aufgerufen werden.
        /// So erscheint Phase 2 erst im Cue und nicht schon beim Zustands-Refresh.
        /// </summary>
        public void PreparePhaseChange()
        {
            _phaseTransitionDeferred = true;
        }

        public void PlayStanceBreakCue()
        {
            if (_stageRoot == null) return;
            var token = ++_stanceToken;
            _stageRoot.EnableInClassList("bossbuehne--haltung-bruch", true);
            _dust?.EnableInClassList("gegner__staub--haltung", true);

            _stageRoot.schedule.Execute(() =>
            {
                if (token != _stanceToken) return;
                _stageRoot.EnableInClassList("bossbuehne--haltung-bruch", false);
                _dust?.EnableInClassList("gegner__staub--haltung", false);
            }).StartingIn(280);
        }

        public void PlayPhaseTwoCue()
        {
            if (_stageRoot == null) return;

            _phaseTransitionDeferred = false;
            ApplyPhaseLook(_phaseTwoRequested);

            var token = ++_phaseToken;
            _stageRoot.EnableInClassList("bossbuehne--phase-cue", true);
            _phaseGlow?.EnableInClassList("gegner__phaseglut--cue", true);
            _dust?.EnableInClassList("gegner__staub--phase", true);
            if (_isTower) _lightning?.EnableInClassList("gegner__blitz--aktiv", true);

            _stageRoot.schedule.Execute(() =>
            {
                if (token != _phaseToken) return;
                _stageRoot.EnableInClassList("bossbuehne--phase-cue", false);
                _phaseGlow?.EnableInClassList("gegner__phaseglut--cue", false);
                _dust?.EnableInClassList("gegner__staub--phase", false);
                _lightning?.EnableInClassList("gegner__blitz--aktiv", false);
            }).StartingIn(460);
        }

        public void PlayTowerStrikeCue()
        {
            if (!_isTower || _stageRoot == null) return;

            var token = ++_towerStrikeToken;
            _stageRoot.EnableInClassList("bossbuehne--turm-schlag", true);
            _lightning?.EnableInClassList("gegner__blitz--turm-schlag", true);
            _dust?.EnableInClassList("gegner__staub--turm-schlag", true);

            _stageRoot.schedule.Execute(() =>
            {
                if (token != _towerStrikeToken) return;
                _stageRoot.EnableInClassList("bossbuehne--turm-schlag", false);
                _lightning?.EnableInClassList("gegner__blitz--turm-schlag", false);
                _dust?.EnableInClassList("gegner__staub--turm-schlag", false);
            }).StartingIn(360);
        }

        private void PlayIntroCue()
        {
            if (_stageRoot == null) return;
            var token = ++_introToken;

            _stageRoot.EnableInClassList("bossbuehne--intro-start", true);
            _dust?.EnableInClassList("gegner__staub--intro", true);
            if (_isTower) _lightning?.EnableInClassList("gegner__blitz--intro", true);

            _stageRoot.schedule.Execute(() =>
            {
                if (token != _introToken) return;
                _stageRoot.EnableInClassList("bossbuehne--intro-start", false);
                _stageRoot.EnableInClassList("bossbuehne--intro-settle", true);
            }).StartingIn(70);

            _stageRoot.schedule.Execute(() =>
            {
                if (token != _introToken) return;
                _stageRoot.EnableInClassList("bossbuehne--intro-settle", false);
                _dust?.EnableInClassList("gegner__staub--intro", false);
                _lightning?.EnableInClassList("gegner__blitz--intro", false);
            }).StartingIn(560);
        }

        private void ApplyPhaseLook(bool phaseTwo)
        {
            _stageRoot?.EnableInClassList("bossbuehne--phase2", _isTower && phaseTwo);
            _combatRoot?.EnableInClassList("kampf--phase2", _isTower && phaseTwo);
        }

        private static Texture2D Texture(string path)
        {
            if (string.IsNullOrEmpty(path)) return null;
            if (Textures.TryGetValue(path, out var cached)) return cached;
            var texture = Resources.Load<Texture2D>(path);
            Textures[path] = texture;
            return texture;
        }

        private static void SetTexture(VisualElement element, string path)
        {
            if (element == null) return;
            element.style.backgroundImage = new StyleBackground(Texture(path));
        }
    }
}
