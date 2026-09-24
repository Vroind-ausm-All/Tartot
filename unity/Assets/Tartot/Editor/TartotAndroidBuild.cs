using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Tartot.Unity.EditorTools
{
    /// <summary>Ein-Klick-Build fuer den Android-Prototypen.</summary>
    public static class TartotAndroidBuild
    {
        private const string ScenePath = "Assets/Scenes/Tartot.unity";
        private const string OutputPath = "Build/Android/TARTOT-prototype.apk";

        [MenuItem("Tartot/Android-Prototyp bauen", priority = 5)]
        public static void Build()
        {
            TartotSetup.SetupProject();
            if (!File.Exists(ScenePath))
            {
                Debug.LogError("Tartot: Startszene konnte nicht erzeugt werden.");
                return;
            }

            PlayerSettings.companyName = "Tartot";
            PlayerSettings.productName = "TARTOT";
            PlayerSettings.bundleVersion = "0.1.0-prototype";
            PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "com.tartot.prototype");

            if (!EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
            {
                Debug.LogError("Tartot: Android Build Support ist in dieser Unity-Installation nicht verfuegbar.");
                return;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(OutputPath));
            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = OutputPath,
                target = BuildTarget.Android,
                options = BuildOptions.None
            });

            if (report.summary.result == BuildResult.Succeeded)
                Debug.Log($"Tartot: Android-Prototyp gebaut: {OutputPath} ({report.summary.totalSize} Bytes)");
            else
                Debug.LogError($"Tartot: Android-Build fehlgeschlagen: {report.summary.result}");
        }
    }
}
