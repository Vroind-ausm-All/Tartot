#if UNITY_EDITOR || DEVELOPMENT_BUILD
using System;
using System.Collections;
using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    public sealed partial class TartotView
    {
        private bool _smokeError;

        private void Start()
        {
            Application.runInBackground = true;
            if (Environment.GetCommandLineArgs().Contains("-tartot-smoke-test")) StartCoroutine(RunSmokeTest());
            else if (Environment.GetCommandLineArgs().Contains("-tartot-capture")) StartCoroutine(CapturePresentation());
        }

        private IEnumerator CapturePresentation()
        {
            yield return new WaitForSecondsRealtime(2);
            if (Environment.GetCommandLineArgs().Contains("-tartot-capture-layout"))
            {
                foreach (var (id, slot) in new Autopilot().SuggestLayout(_game))
                {
                    OnCardClicked(_handVisuals.First(c => c.Card.InstanceId == id));
                    OnSlotClicked(slot);
                }
                yield return new WaitForSecondsRealtime(.5f);
            }
            yield return new WaitForEndOfFrame();
            var args = Environment.GetCommandLineArgs();
            var path = args[Array.IndexOf(args, "-tartot-capture") + 1];
            var image = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
            image.ReadPixels(new Rect(0, 0, Screen.width, Screen.height), 0, 0);
            image.Apply();
            System.IO.File.WriteAllBytes(path, image.EncodeToPNG());
            Destroy(image);
            Debug.Log("TARTOT_CAPTURE_PASS");
            Application.Quit(0);
        }

        private void CaptureSmokeError(string message, string stack, LogType type)
        {
            if (type == LogType.Error || type == LogType.Exception || type == LogType.Assert) _smokeError = true;
        }

        private IEnumerator RunSmokeTest()
        {
            Application.logMessageReceived += CaptureSmokeError;
            var test = SmokeSteps();
            while (true)
            {
                object next;
                try
                {
                    if (!test.MoveNext()) break;
                    next = test.Current;
                }
                catch (Exception ex)
                {
                    Debug.LogException(ex);
                    Application.Quit(1);
                    yield break;
                }
                yield return next;
            }
            Application.logMessageReceived -= CaptureSmokeError;
            Debug.Log(_smokeError ? "TARTOT_SMOKE_FAIL" : "TARTOT_SMOKE_PASS");
            Application.Quit(_smokeError ? 1 : 0);
        }

        private IEnumerator SmokeSteps()
        {
            yield return new WaitForSecondsRealtime(1);
            Require(_game != null && _game.Combat.Enemy.Definition.Id == "boss_turm", "Tower start");
            Require(_handVisuals.Count > 0 && _actButton.panel != null, "Attached UI with hand");
            Require(_actButton.worldBound.width > 0 && _actButton.worldBound.height > 0, "Visible action button");
            Require(_actButton.worldBound.yMax <= _root.worldBound.yMax + 1, "Action button fits viewport");
            Require(_root.Q<VisualElement>("gegner-kulisse").worldBound.width > 200, "Boss stage does not collapse to sprite width");
            var picked = _root.panel.Pick(_actButton.worldBound.center);
            Require(picked == _actButton || _actButton.Contains(picked), "Action button is not covered by FX");
            var saveBefore = PlayerPrefs.GetString(SaveKey, "");
            var metaBefore = PlayerPrefs.GetString(MetaKey, "");
            var pilot = new Autopilot();
            var turns = 0;
            var collapse = false;
            var phaseChanged = false;
            while (_game.Phase == GamePhase.Combat && turns++ < 100)
            {
                var layout = pilot.SuggestLayout(_game);
                foreach (var (id, slot) in layout)
                {
                    var card = _handVisuals.First(c => c.Card.InstanceId == id);
                    OnCardClicked(card);
                    OnSlotClicked(slot);
                }
                Require(_game.Combat.Slots.Count > 0, "Cards placed through view handlers");
                yield return null;
                Require(_root.Q<Label>("vorschau-fate").worldBound.yMax <=
                    _root.Q<VisualElement>("vorschau-panel").worldBound.yMax, "Damage preview is not clipped");
                using (var submit = NavigationSubmitEvent.GetPooled())
                {
                    submit.target = _actButton;
                    _actButton.SendEvent(submit);
                }
                // UI Toolkit's keyboard submit simulates a click after its press animation.
                yield return new WaitForSecondsRealtime(.2f);
                Require(_presentationLocked, "Action button started resolution");
                collapse |= _game.Combat.BlockedSlot.HasValue;
                phaseChanged |= _game.LastTurn.PhaseChanged;
                var deadline = Time.realtimeSinceStartup + 15;
                while (_presentationLocked && Time.realtimeSinceStartup < deadline) yield return null;
                Require(!_presentationLocked, "Resolve finishes without a stuck lock");
                yield return null;
            }
            Require(_game.Phase != GamePhase.Combat, "Fight reaches end overlay");
            Require(collapse && phaseChanged, "Tower collapse and seal break exercised");
            Require(_overlay.resolvedStyle.display == DisplayStyle.Flex, "End overlay visible");
            Debug.Log("TARTOT_SMOKE_FIGHT: " + _game.Phase + ", turns=" + turns);
            var retry = _overlayButtons.Q<Button>();
            using (var submit = NavigationSubmitEvent.GetPooled())
            {
                submit.target = retry;
                retry.SendEvent(submit);
            }
            yield return new WaitForSecondsRealtime(.2f);
            Require(_game.Phase == GamePhase.Combat && _game.Combat.Turn == 1, "Retry starts fresh Tower");
            // Exercise the same UIDocument lifecycle used by editor re-enable.
            enabled = false;
            yield return null;
            enabled = true;
            yield return null;
            Require(_game.Combat.Enemy.Definition.Id == "boss_turm" && _handVisuals.Count > 0, "Re-enable binds UI");
            Require(GetComponents<AudioSource>().Length == 10, "No accumulated audio sources");
            Require(PlayerPrefs.GetString(SaveKey, "") == saveBefore && PlayerPrefs.GetString(MetaKey, "") == metaBefore,
                "Demo leaves normal saves untouched");
        }

        private static void Require(bool condition, string message)
        {
            if (!condition) throw new InvalidOperationException("Tartot smoke: " + message);
        }
    }
}
#endif
