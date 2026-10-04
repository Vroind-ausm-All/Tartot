#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity.EditorTools
{
    public static class TartotBuild
    {
        public static void ValidateProject()
        {
            TartotSetup.EnsureProject();
            EditorSceneManager.OpenScene(TartotSetup.ScenePath);
            var view = UnityEngine.Object.FindAnyObjectByType<TartotView>();
            if (view == null || !view.TowerDemo || view.AutoSave)
                throw new InvalidOperationException("Start scene must contain a non-saving Tower demo.");
            var document = view.GetComponent<UIDocument>();
            if (document.panelSettings == null || document.panelSettings.themeStyleSheet == null || document.visualTreeAsset == null)
                throw new InvalidOperationException("UIDocument / panel / theme is not wired.");
            foreach (var path in new[] { "Tartot/Stage/turm_hintergrund", "Tartot/Stage/turm_figur" })
                if (Resources.Load<Texture2D>(path) == null) throw new InvalidOperationException("Missing texture: " + path);
            foreach (var path in new[] { "auftritt", "landen", "phase", "angriff_blitz", "sieg" })
                if (Resources.Load<AudioClip>("Tartot/Audio/" + path) == null) throw new InvalidOperationException("Missing audio: " + path);
            if (TowerDemoSession.Create().Combat.Enemy.Definition.Id != "boss_turm")
                throw new InvalidOperationException("Demo did not start the Tower.");
            Debug.Log("TARTOT_PROJECT_VALIDATION_PASS");
        }

        [MenuItem("Tartot/Windows-Demo bauen", priority = 30)]
        public static void BuildWindows()
        {
            ValidateProject();
            Directory.CreateDirectory("Build/Windows");
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { TartotSetup.ScenePath },
                locationPathName = "Build/Windows/Tartot.exe",
                target = BuildTarget.StandaloneWindows64,
                options = BuildOptions.Development
            });
            if (report.summary.result != BuildResult.Succeeded)
                throw new InvalidOperationException("Tartot build failed: " + report.summary.result);
            Debug.Log("TARTOT_WINDOWS_BUILD_PASS");
        }
    }
}
#endif
