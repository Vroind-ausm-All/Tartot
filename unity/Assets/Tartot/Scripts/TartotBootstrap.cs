using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Baut das Spiel aus jeder beliebigen Szene auf, damit man zum
    /// Ausprobieren nichts konfigurieren muss: Play druecken genuegt.
    /// </summary>
    /// <remarks>
    /// Fuer den Produktionsbuild gehoert stattdessen eine richtige Szene mit
    /// einem vorbereiteten UIDocument angelegt - dann kann dieses Skript weg.
    /// </remarks>
    public static class TartotBootstrap
    {
        private const string UxmlPath = "Tartot/Tartot";      // Assets/Resources/...
        private const string PanelSettingsPath = "Tartot/TartotPanelSettings";

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Bootstrap()
        {
            if (Object.FindObjectOfType<TartotView>() != null) return;

            var tree = Resources.Load<VisualTreeAsset>(UxmlPath);
            var settings = Resources.Load<PanelSettings>(PanelSettingsPath);
            if (tree == null || settings == null)
            {
                Debug.LogWarning(
                    "Tartot: UXML oder PanelSettings nicht unter Assets/Resources/Tartot gefunden. " +
                    "Ruf im Editor einmal Tartot → Projekt einrichten auf, oder lege von Hand " +
                    "eine Szene mit UIDocument und TartotView an (siehe docs/UNITY.md).");
                return;
            }

            var host = new GameObject("Tartot");
            Object.DontDestroyOnLoad(host);

            var document = host.AddComponent<UIDocument>();
            document.panelSettings = settings;
            document.visualTreeAsset = tree;
            host.AddComponent<TartotView>();
        }
    }
}
