using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Startet TARTOT aus jeder Szene. Fuer den Prototypen ist deshalb keine
    /// von Hand verdrahtete Startszene und kein PanelSettings-Asset noetig.
    /// </summary>
    public static class TartotBootstrap
    {
        private const string UxmlPath = "Tartot/Tartot";
        private const string PanelSettingsPath = "Tartot/TartotPanelSettings";

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Bootstrap()
        {
            if (Object.FindObjectOfType<TartotView>() != null) return;

            var tree = Resources.Load<VisualTreeAsset>(UxmlPath);
            if (tree == null)
            {
                Debug.LogError("Tartot: Assets/Resources/Tartot/Tartot.uxml fehlt.");
                return;
            }

            var settings = Resources.Load<PanelSettings>(PanelSettingsPath);
            if (settings == null)
            {
                settings = ScriptableObject.CreateInstance<PanelSettings>();
                settings.scaleMode = PanelScaleMode.ScaleWithScreenSize;
                settings.referenceResolution = new Vector2Int(270, 480);
                settings.screenMatchMode = PanelScreenMatchMode.MatchWidthOrHeight;
                settings.match = 1f;
                Debug.Log("Tartot: PanelSettings zur Laufzeit erzeugt (270x480, Point-Art-Prototyp).");
            }

            var host = new GameObject("Tartot");
            Object.DontDestroyOnLoad(host);

            var document = host.AddComponent<UIDocument>();
            document.panelSettings = settings;
            document.visualTreeAsset = tree;
            host.AddComponent<TartotView>();
            host.AddComponent<TartotPresentation>();
        }
    }
}
