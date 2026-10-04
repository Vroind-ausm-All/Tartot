using System;
using System.IO;
using System.Linq;
using Tartot.Core.Simulation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity.EditorTools
{
    [InitializeOnLoad]
    public static class TartotSetup
    {
        public const string PanelSettingsPath = "Assets/Resources/Tartot/TartotPanelSettings.asset";
        public const string UxmlPath = "Assets/Resources/Tartot/Tartot.uxml";
        public const string ScenePath = "Assets/Scenes/Tartot.unity";
        private const string ThemePath = "Assets/Resources/Tartot/TartotTheme.tss";

        static TartotSetup() { EditorApplication.delayCall += AutoSetup; }

        private static void AutoSetup()
        {
            if (Application.isBatchMode || EditorApplication.isPlayingOrWillChangePlaymode) return;
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
            {
                EditorApplication.delayCall += AutoSetup;
                return;
            }
            var active = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            if (!File.Exists(ScenePath) && string.IsNullOrEmpty(active.path) && active.isDirty)
            {
                Debug.LogWarning("Tartot: Ungespeicherte Szene bitte zuerst speichern; danach Tartot > Projekt einrichten.");
                return;
            }
            EnsureProject();
            EditorSceneManager.playModeStartScene = AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath);
        }

        [MenuItem("Tartot/Projekt einrichten", priority = 0)]
        public static void SetupProject()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) return;
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo()) return;
            EnsureProject();
            EditorSceneManager.OpenScene(ScenePath);
            RepairOpenScene();
            EditorSceneManager.playModeStartScene = AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath);
            Debug.Log("Tartot: Turm-Slice bereit. Play druecken.");
        }

        // Also callable via -executeMethod. Safe to run repeatedly.
        public static void EnsureProject()
        {
            var tree = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(UxmlPath);
            if (tree == null) throw new InvalidOperationException("Tartot: UXML fehlt: " + UxmlPath);
            var theme = AssetDatabase.LoadAssetAtPath<ThemeStyleSheet>(ThemePath);
            if (theme == null) throw new InvalidOperationException("Tartot: Theme fehlt: " + ThemePath);
            var panel = AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath);
            if (panel == null)
            {
                panel = ScriptableObject.CreateInstance<PanelSettings>();
                AssetDatabase.CreateAsset(panel, PanelSettingsPath);
            }
            panel.themeStyleSheet = theme;
            panel.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            panel.referenceResolution = new Vector2Int(720, 1280);
            panel.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
            panel.match = .5f;
            EditorUtility.SetDirty(panel);
            AssetDatabase.SaveAssets();
            if (!File.Exists(ScenePath)) CreateScene();
            var scenes = EditorBuildSettings.scenes.Where(s => s.path != ScenePath).ToList();
            scenes.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
            EditorBuildSettings.scenes = scenes.ToArray();
            PlayerSettings.companyName = "Tartot";
            PlayerSettings.productName = "Tartot - Der Turm";
            PlayerSettings.defaultScreenWidth = 540;
            PlayerSettings.defaultScreenHeight = 960;
            PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = true;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
        }

        public static void RepairOpenScene()
        {
            var view = UnityEngine.Object.FindAnyObjectByType<TartotView>();
            if (view == null) throw new InvalidOperationException("Tartot: Startszene enthaelt keine TartotView.");
            var document = view.GetComponent<UIDocument>();
            document.visualTreeAsset = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(UxmlPath);
            document.panelSettings = AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath);
            ConfigureBackground(view.gameObject);
            EditorUtility.SetDirty(document);
            EditorSceneManager.SaveScene(view.gameObject.scene, ScenePath);
        }

        private static void ConfigureBackground(GameObject host)
        {
            var camera = host.GetComponent<Camera>();
            if (camera == null) camera = host.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = Color.black;
            camera.cullingMask = 0;
            if (host.GetComponent<AudioListener>() == null) host.AddComponent<AudioListener>();
        }

        private static void CreateScene()
        {
            if (!AssetDatabase.IsValidFolder("Assets/Scenes")) AssetDatabase.CreateFolder("Assets", "Scenes");
            var previous = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            var replaceEmpty = string.IsNullOrEmpty(previous.path) && !previous.isDirty;
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene,
                replaceEmpty ? NewSceneMode.Single : NewSceneMode.Additive);
            try
            {
                var host = new GameObject("Tartot");
                UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(host, scene);
                host.SetActive(false);
                var document = host.AddComponent<UIDocument>();
                document.visualTreeAsset = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(UxmlPath);
                var view = host.AddComponent<TartotView>();
                view.TowerDemo = true;
                view.AutoSave = false;
                view.Seed = 1337;
                ConfigureBackground(host);
                host.SetActive(true);
                // NewScene(Single) unloads unused ScriptableObjects. Load the panel
                // AFTER that scene switch, never retain the pre-switch native object.
                document.panelSettings = AssetDatabase.LoadAssetAtPath<PanelSettings>(PanelSettingsPath);
                if (document.panelSettings == null)
                    throw new InvalidOperationException("Tartot: PanelSettings-Import fehlgeschlagen.");
                EditorUtility.SetDirty(document);
                if (!EditorSceneManager.SaveScene(scene, ScenePath))
                    throw new InvalidOperationException("Tartot: Startszene konnte nicht gespeichert werden.");
            }
            finally
            {
                if (!replaceEmpty) EditorSceneManager.CloseScene(scene, true);
                if (previous.IsValid()) UnityEngine.SceneManagement.SceneManager.SetActiveScene(previous);
            }
        }

        [MenuItem("Tartot/Regelkern pruefen (ohne Play)", priority = 20)]
        public static void SelfCheck()
        {
            var outcome = new Autopilot().PlayRun(seed: 1337, maxFights: 40);
            Debug.Log($"Tartot-Selbsttest: {outcome.FightsCleared} Kaempfe, Akt {outcome.ActReached}.");
        }
    }
}
