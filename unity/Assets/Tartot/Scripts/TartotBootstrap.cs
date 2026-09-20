using UnityEngine;
using Tartot.Core;

namespace Tartot.Unity
{
    public static class TartotBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Boot()
        {
            if (Object.FindObjectOfType<TartotGameUI>() != null) return;
            var go = new GameObject("Tartot Runtime");
            Object.DontDestroyOnLoad(go);
            var ui = go.AddComponent<TartotGameUI>();
            ui.Initialize(new GameController(System.Environment.TickCount));
        }
    }
}
