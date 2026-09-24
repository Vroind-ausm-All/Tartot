using System.IO;
using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity.EditorTools
{
    /// <summary>
    /// Richtet den 270x480-Mobile-Prototypen ein: PanelSettings, Startszene,
    /// Portrait und die Zelluloid-Praesentationsschicht.
    /// </summary>
    public static class TartotSetup
    {
        private const string PanelSettingsPath = "Assets/Resources/Tartot/TartotPanelSettings.asset";
        private const string UxmlPath = "Assets/Resources/Tartot/Tartot.uxml";
        private const string ScenePath = "Assets/Scenes/Tartot.unity";

        [MenuItem("Tartot/Projekt einrichten", priority = 0)]
        public static void SetupProject()
        {
            var panel = CreatePanelSettings();
            if (panel == null) return;
            CreateScene(panel);
            ApplyPortraitSettings();
            Debug.Log("Tartot: Zelluloid-Prototyp eingerichtet. Play druecken oder Tartot → Android-Prototyp bauen.");
        }

        [MenuItem("Tartot/Regelkern pruefen (ohne Play)", priority = 20)]
        public static void SelfCheck()
        {
            var outcome = new Autopilot().PlayRun(seed: 1337, maxFights: 40);
            var ende = outcome.Won ? "Finale geschlagen" : $"gestorben in Akt {outcome.ActReached} gegen {outcome.DiedAgainst}";
            Debug.Log($"Tartot-Selbsttest: {outcome.FightsCleared} Kaempfe, {ende}. Deck {outcome.DeckSize}, " +
                      $"Verdunkelung {outcome.Darkness}, {outcome.EventsSeen} Ereignisse. " +
                      $"Katalog: {GameCatalog.Cards.Count} Karten, {GameCatalog.Charms.Count} Charms, " +
                      $"{GameCatalog.Enemies.Count} Gegner, {EventCatalog.All.Count} Ereignisse.");
        }

        private static PanelSettings CreatePanelSettings()
        {
            var existing = AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath);
            if (existing != null)
            {
                Configure(existing);
                AssetDatabase.SaveAssets();
                return existing;
            }

            EnsureFolder("Assets/Resources");
            EnsureFolder("Assets/Resources/Tartot");
            var settings = ScriptableObject.CreateInstance<PanelSettings>();
            Configure(settings);

            var themeGuid = AssetDatabase.FindAssets("t:ThemeStyleSheet").FirstOrDefault();
            if (!string.IsNullOrEmpty(themeGuid))
                settings.themeStyleSheet = AssetDatabase.LoadAssetAtPath<ThemeStyleSheet>(AssetDatabase.GUIDToAssetPath(themeGuid));

            AssetDatabase.CreateAsset(settings, PanelSettingsPath);
            AssetDatabase.SaveAssets();
            return settings;
        }

        private static void Configure(PanelSettings settings)
        {
            settings.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            settings.referenceResolution = new Vector2Int(270, 480);
            settings.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
            settings.match = 1f;
        }

        private static void CreateScene(PanelSettings panel)
        {
            var tree = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(UxmlPath);
            if (tree == null)
            {
                Debug.LogError($"Tartot: {UxmlPath} nicht gefunden.");
                return;
            }

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var host = new GameObject("Tartot");
            var document = host.AddComponent<UIDocument>();
            document.panelSettings = panel;
            document.visualTreeAsset = tree;
            host.AddComponent<TartotView>();
            host.AddComponent<TartotPresentation>();

            EnsureFolder("Assets/Scenes");
            EditorSceneManager.SaveScene(scene, ScenePath);
        }

        private static void ApplyPortraitSettings()
        {
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = true;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
        }

        private static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            var parent = Path.GetDirectoryName(path)?.Replace('\', '/');
            var leaf = Path.GetFileName(path);
            if (!string.IsNullOrEmpty(parent) && !AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }
    }
}
