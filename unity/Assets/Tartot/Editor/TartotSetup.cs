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
    /// Nimmt die Handgriffe ab, die zwischen "Projekt geoeffnet" und "Play"
    /// liegen: PanelSettings anlegen, Szene bauen, Hochformat einstellen.
    /// </summary>
    /// <remarks>
    /// Falls hier etwas schiefgeht, stehen dieselben Schritte von Hand in
    /// docs/UNITY.md. Dieses Skript ist Bequemlichkeit, keine Voraussetzung.
    /// </remarks>
    public static class TartotSetup
    {
        private const string SettingsFolder = "Assets/Settings";
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
            Debug.Log("Tartot: eingerichtet. Szene Assets/Scenes/Tartot.unity ist offen - Play druecken.");
        }

        [MenuItem("Tartot/Regelkern pruefen (ohne Play)", priority = 20)]
        public static void SelfCheck()
        {
            // Schneller Beweis, dass der Kern im Editor laeuft, ohne die
            // Oberflaeche anzufassen.
            var outcome = new Autopilot().PlayRun(seed: 1337, maxFights: 10);
            Debug.Log($"Tartot-Selbsttest: {outcome.FightsCleared} Kaempfe, Deck {outcome.DeckSize}, " +
                      $"Resonanz {outcome.DeckResonance}/10, gestorben gegen {outcome.DiedAgainst}. " +
                      $"Karten im Katalog: {GameCatalog.Cards.Count}, Charms: {GameCatalog.Charms.Count}.");
        }

        private static PanelSettings CreatePanelSettings()
        {
            var existing = AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath);
            if (existing != null) return existing;

            var theme = FindTheme();
            if (theme == null)
            {
                Debug.LogError(
                    "Tartot: Kein ThemeStyleSheet gefunden. Lege eines an ueber " +
                    "Assets → Create → UI Toolkit → TSS Theme File und rufe das Menue erneut auf. " +
                    "Ohne Theme zeichnet UI Toolkit zur Laufzeit nichts.");
                return null;
            }

            EnsureFolder("Assets/Resources");
            EnsureFolder("Assets/Resources/Tartot");

            var settings = ScriptableObject.CreateInstance<PanelSettings>();
            settings.themeStyleSheet = theme;
            settings.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            settings.referenceResolution = new Vector2Int(1080, 1920);
            settings.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
            settings.match = 1f;   // an der Hoehe ausrichten: Hochformat

            AssetDatabase.CreateAsset(settings, PanelSettingsPath);
            AssetDatabase.SaveAssets();
            return settings;
        }

        private static ThemeStyleSheet FindTheme()
        {
            var guid = AssetDatabase.FindAssets("t:ThemeStyleSheet").FirstOrDefault();
            return guid == null
                ? null
                : AssetDatabase.LoadAssetAtPath<ThemeStyleSheet>(AssetDatabase.GUIDToAssetPath(guid));
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
            var parent = Path.GetDirectoryName(path)?.Replace('\\', '/');
            var leaf = Path.GetFileName(path);
            if (!string.IsNullOrEmpty(parent) && !AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }
    }
}
