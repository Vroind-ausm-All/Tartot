using Tartot.Core;

namespace Tartot.Unity
{
    public sealed partial class TartotView
    {
        private void StartTowerDemo()
        {
            _game = TowerDemoSession.Create(Seed != 0 ? Seed : 1337);
            _showTitle = false;
            _report = null;
            _selected = null;
            _announced.Clear();
            _toast = string.Empty;
            _presentationLocked = false;
            _presentationToken++;
            _impactToken++;
            _pendingSnapCardId = string.Empty;
        }

        private void RestartTowerDemo()
        {
            // Detach the complete tree: its schedules and pointer captures stop,
            // including EnemyStage's idle loop and all outstanding boss cues.
            OnDisable();
            OnEnable();
        }

        private void OnDisable()
        {
            _presentationToken++;
            _impactToken++;
            _presentationLocked = false;
            _feedbackView?.Dispose();
            _feedbackView = null;
            _root?.RemoveFromHierarchy();
        }
    }
}
