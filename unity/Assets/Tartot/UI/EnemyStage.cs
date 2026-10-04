using System.Collections.Generic;
using Tartot.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Die Buehne des Gegners: spielt die Sprite-Streifen aus
    /// Resources/Tartot/Anim mit 12 Bildern pro Sekunde ab.
    /// </summary>
    /// <remarks>
    /// Ein Streifen liegt als ein Bild nebeneinander vor. Ein Fenster in
    /// Bildgroesse (overflow: hidden) zeigt davon immer genau eins - das
    /// innere Element wird pro Bild um eine Bildbreite nach links geschoben.
    /// So braucht es weder Sprite-Atlanten noch Import-Einstellungen ausser
    /// Filter Mode: Point. Folgen ("hit", "phase2", "attack1") laufen einmal
    /// durch, danach kehrt die Figur ins Wippen (idle) zurueck.
    /// </remarks>
    public sealed class EnemyStage
    {
        private const string AnimPath = "Tartot/Anim/";
        private readonly VisualElement _window;
        private readonly VisualElement _strip;
        private readonly Dictionary<string, int> _frames = new Dictionary<string, int>();
        private readonly Queue<string> _queue = new Queue<string>();
        private JsonValue _manifest;
        private string _enemyId = string.Empty;
        private string _state = AnimationCues.Idle;
        private int _frame;
        private int _size = 160;
        private int _displaySize = 212;
        private int _fps = 12;
        private int _tick;

        public EnemyStage(VisualElement window)
        {
            _window = window;
            _window.AddToClassList("gegner__buehne");
            _strip = new VisualElement();
            _strip.AddToClassList("gegner__streifen");
            _window.Add(_strip);
            var manifest = Resources.Load<TextAsset>(AnimPath + "anim");
            if (manifest != null) Json.TryParse(manifest.text, out _manifest);
            // Die Animationen sind "on twos" gezeichnet: 12 fps, jedes Bild zweimal.
            _window.schedule.Execute(Step).Every(1000 / 24);
        }

        /// <summary>Neuer Gegner: Streifen laden und ins Wippen gehen.</summary>
        public void Show(EnemyDefinition enemy)
        {
            if (enemy.Id == "boss_turm")
            {
                _window.style.display = DisplayStyle.None;
                return;
            }
            var id = AnimationCues.SpriteId(enemy);
            if (id == _enemyId) return;
            _enemyId = id;
            _frames.Clear();
            _queue.Clear();
            var entry = _manifest?.Get(id);
            if (entry != null)
            {
                _size = entry.GetInt("size", 160);
                _displaySize = _size + _size / 3;
                _fps = entry.GetInt("fps", 12);
                var states = entry.Get("states");
                if (states?.Members != null)
                    foreach (var pair in states.Members) _frames[pair.Key] = (int)pair.Value.NumberValue;
            }
            _window.style.width = _displaySize;
            _window.style.height = _displaySize;
            _window.style.display = _frames.Count > 0 ? DisplayStyle.Flex : DisplayStyle.None;
            Play(AnimationCues.Idle);
        }

        /// <summary>Eine Folge einreihen, etwa Treffer - Phase 2 - Angriff.</summary>
        public void Queue(IEnumerable<string> cues)
        {
            foreach (var cue in cues) _queue.Enqueue(cue);
            if (_state == AnimationCues.Idle) Next();
        }

        private void Next()
        {
            while (_queue.Count > 0)
            {
                var cue = Resolve(_queue.Dequeue());
                if (cue != null)
                {
                    Play(cue);
                    return;
                }
            }
            if (_state != "death") Play(AnimationCues.Idle);
        }

        /// <summary>Fehlt ein Streifen, springt die allgemeine Fassung ein.</summary>
        private string Resolve(string cue)
        {
            if (_frames.ContainsKey(cue)) return cue;
            if (cue.StartsWith("attack") || cue == "summon" || cue == "supernova")
                return _frames.ContainsKey("attack") ? "attack" : null;
            return null;
        }

        private void Play(string state)
        {
            if (!_frames.ContainsKey(state)) return;
            _state = state;
            _frame = 0;
            _tick = 0;
            var texture = Resources.Load<Texture2D>(AnimPath + _enemyId + "_" + state);
            _strip.style.backgroundImage = new StyleBackground(texture);
            _strip.style.width = _displaySize * _frames[state];
            _strip.style.height = _displaySize;
            _strip.style.left = 0;
        }

        private void Step()
        {
            if (!_frames.TryGetValue(_state, out var count)) return;
            // 24 Schritte je Sekunde, ein neues Bild alle 24 / fps Schritte.
            if (++_tick < 24 / Mathf.Max(1, _fps)) return;
            _tick = 0;
            _frame++;
            if (_frame >= count)
            {
                if (_state == AnimationCues.Idle) _frame = 0;
                else if (_state == "death") _frame = count - 1;
                else
                {
                    Next();
                    return;
                }
            }
            _strip.style.left = -_frame * _displaySize;
        }
    }
}
