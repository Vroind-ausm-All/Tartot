// Minimale Nachbildungen der Unity-Typen, die das Frontend benutzt.
//
// Zweck: Der Unity-Code laesst sich in dieser Umgebung nicht bauen. Diese
// Stubs erlauben wenigstens eine Syntax- und Signaturpruefung - sie fangen
// Tippfehler und falsche Zugriffe auf Tartot.Core ab.
//
// Was sie NICHT leisten: sie beweisen nicht, dass der Code in Unity laeuft.
// Weicht eine echte Unity-Signatur hiervon ab, faellt das erst dort auf.
// Diese Dateien liegen ausserhalb von Assets, Unity sieht sie nie.
using System;

namespace UnityEngine
{
    public class Object
    {
        public static T FindObjectOfType<T>() where T : Object => null;
        public static void DontDestroyOnLoad(Object target) { }
    }

    public class Component : Object
    {
        public T GetComponent<T>() where T : Component => null;
    }

    public class Behaviour : Component { }
    public class MonoBehaviour : Behaviour { }

    public class GameObject : Object
    {
        public GameObject(string name) { }
        public T AddComponent<T>() where T : Component => null;
    }

    public sealed class TooltipAttribute : Attribute { public TooltipAttribute(string t) { } }
    public sealed class RequireComponent : Attribute { public RequireComponent(Type t) { } }

    public enum RuntimeInitializeLoadType { AfterSceneLoad }
    public sealed class RuntimeInitializeOnLoadMethodAttribute : Attribute
    {
        public RuntimeInitializeOnLoadMethodAttribute(RuntimeInitializeLoadType t) { }
    }

    public static class Debug
    {
        public static void Log(object m) { }
        public static void LogWarning(object m) { }
        public static void LogError(object m) { }
    }

    public static class PlayerPrefs
    {
        public static string GetString(string key, string fallback = "") => fallback;
        public static void SetString(string key, string value) { }
        public static void DeleteKey(string key) { }
        public static void Save() { }
    }

    public static class Mathf
    {
        public static int Max(int a, int b) => a > b ? a : b;
        public static float Max(float a, float b) => a > b ? a : b;
        public static float Clamp01(float v) => v < 0f ? 0f : (v > 1f ? 1f : v);
    }

    public enum FilterMode { Point, Bilinear, Trilinear }
    public class TextAsset : Object { public string text => string.Empty; }
    public class Texture2D : Object { }

    public struct Vector2
    {
        public float x;
        public float y;
        public Vector2(float x = 0f, float y = 0f) { this.x = x; this.y = y; }
        public float sqrMagnitude => x * x + y * y;
        public static Vector2 operator -(Vector2 a, Vector2 b) => new Vector2(a.x - b.x, a.y - b.y);
    }

    public struct Vector3
    {
        public float x;
        public float y;
        public float z;
        public Vector3(float x = 0f, float y = 0f, float z = 0f) { this.x = x; this.y = y; this.z = z; }
    }

    public struct Rect
    {
        public float x, y, width, height;
        public bool Contains(Vector2 point) => true;
    }

    public static class Resources
    {
        public static T Load<T>(string path) where T : Object => null;
    }

    public class PanelSettings : ScriptableObject
    {
        public UIElements.ThemeStyleSheet themeStyleSheet { get; set; }
        public UIElements.PanelScaleMode scaleMode { get; set; }
        public Vector2Int referenceResolution { get; set; }
        public UIElements.PanelScreenMatchMode screenMatchMode { get; set; }
        public float match { get; set; }
    }
}

namespace UnityEngine.UIElements
{
    public enum DisplayStyle { Flex, None }

    public struct Length
    {
        public static Length Percent(float value) => new Length();
    }

    public struct Rotate
    {
        public Rotate(float angle) { }
    }

    public struct StyleLength
    {
        public static implicit operator StyleLength(float v) => new StyleLength();
        public static implicit operator StyleLength(Length v) => new StyleLength();
    }

    public struct StyleBackground
    {
        public StyleBackground(UnityEngine.Texture2D texture) { }
    }

    public interface IStyle
    {
        DisplayStyle display { get; set; }
        StyleLength width { get; set; }
        StyleLength height { get; set; }
        StyleLength left { get; set; }
        StyleLength top { get; set; }
        StyleBackground backgroundImage { get; set; }
        Rotate rotate { get; set; }
    }

    internal sealed class StyleStub : IStyle
    {
        public DisplayStyle display { get; set; }
        public StyleLength width { get; set; }
        public StyleLength height { get; set; }
        public StyleLength left { get; set; }
        public StyleLength top { get; set; }
        public StyleBackground backgroundImage { get; set; }
        public Rotate rotate { get; set; }
    }

    public interface IVisualElementScheduledItem
    {
        IVisualElementScheduledItem Every(long intervalMs);
        IVisualElementScheduledItem StartingIn(long delayMs);
    }

    public interface IVisualElementScheduler
    {
        IVisualElementScheduledItem Execute(Action timerUpdateEvent);
    }

    internal sealed class SchedulerStub : IVisualElementScheduler, IVisualElementScheduledItem
    {
        public IVisualElementScheduledItem Execute(Action timerUpdateEvent) => this;
        public IVisualElementScheduledItem Every(long intervalMs) => this;
        public IVisualElementScheduledItem StartingIn(long delayMs) => this;
    }

    public class EventBase { public void StopPropagation() { } }
    public class ClickEvent : EventBase { }
    public class PointerDownEvent : EventBase { public UnityEngine.Vector3 position; public int pointerId; }
    public class PointerMoveEvent : EventBase { public UnityEngine.Vector3 position; public int pointerId; }
    public class PointerUpEvent : EventBase { public UnityEngine.Vector3 position; public int pointerId; }
    public class GeometryChangedEvent : EventBase { public UnityEngine.Rect newRect; }

    public class VisualElement
    {
        public IStyle style { get; } = new StyleStub();
        public IVisualElementScheduler schedule { get; } = new SchedulerStub();
        public UnityEngine.Rect worldBound => new UnityEngine.Rect();
        public void Add(VisualElement child) { }
        public void Clear() { }
        public void AddToClassList(string className) { }
        public void RemoveFromClassList(string className) { }
        public void EnableInClassList(string className, bool enable) { }
        public void SetEnabled(bool value) { }
        public void CapturePointer(int pointerId) { }
        public void ReleasePointer(int pointerId) { }
        public void RegisterCallback<TEvent>(Action<TEvent> callback) where TEvent : EventBase { }
        public T Q<T>(string name = null) where T : VisualElement => null;
    }

    public class Label : VisualElement
    {
        public Label() { }
        public Label(string text) { }
        public string text { get; set; }
    }

    public class Button : VisualElement
    {
        public Button() { }
        public Button(Action clickHandler) { }
        public string text { get; set; }
        public event Action clicked { add { } remove { } }
    }

    public class VisualTreeAsset : Object { }

    public class UIDocument : MonoBehaviour
    {
        public VisualElement rootVisualElement { get; } = new VisualElement();
        public PanelSettings panelSettings { get; set; }
        public VisualTreeAsset visualTreeAsset { get; set; }
    }
}

// ---------------------------------------------------------------------------
// Nachtrag: Typen fuer den Editor-Code (Assets/Tartot/Editor).
// Gleiche Einschraenkung wie oben - Syntax- und Signaturpruefung, kein Beweis.
// ---------------------------------------------------------------------------

namespace UnityEngine
{
    public struct Vector2Int
    {
        public Vector2Int(int x, int y) { }
    }

    public class ScriptableObject : Object
    {
        public static T CreateInstance<T>() where T : ScriptableObject => null;
    }
}

namespace UnityEngine.SceneManagement
{
    public struct Scene { }
}

namespace UnityEngine.UIElements
{
    public class ThemeStyleSheet : Object { }

    public enum PanelScaleMode { ConstantPixelSize, ScaleWithScreenSize, ConstantPhysicalSize }
    public enum PanelScreenMatchMode { MatchWidthOrHeight, Shrink, Expand }
}

namespace UnityEditor
{
    using System;

    public class AssetImporter : UnityEngine.Object { }
    public enum TextureImporterType { Default, Sprite }
    public enum TextureImporterCompression { Uncompressed, Compressed }
    public enum TextureImporterNPOTScale { None, ToNearest }
    public class TextureImporter : AssetImporter
    {
        public TextureImporterType textureType { get; set; }
        public UnityEngine.FilterMode filterMode { get; set; }
        public TextureImporterCompression textureCompression { get; set; }
        public bool mipmapEnabled { get; set; }
        public TextureImporterNPOTScale npotScale { get; set; }
        public bool alphaIsTransparency { get; set; }
    }
    public class AssetPostprocessor
    {
        public string assetPath => string.Empty;
        public AssetImporter assetImporter => null;
    }

    public sealed class MenuItem : Attribute
    {
        public MenuItem(string itemName) { }
        public MenuItem(string itemName, bool isValidateFunction) { }
        public MenuItem(string itemName, bool isValidateFunction, int priority) { }
        public int priority;
    }

    public static class AssetDatabase
    {
        public static T LoadAssetAtPath<T>(string path) where T : UnityEngine.Object => null;
        public static void CreateAsset(UnityEngine.Object asset, string path) { }
        public static void SaveAssets() { }
        public static string[] FindAssets(string filter) => new string[0];
        public static string GUIDToAssetPath(string guid) => string.Empty;
        public static bool IsValidFolder(string path) => false;
        public static string CreateFolder(string parent, string newFolderName) => string.Empty;
    }

    public enum UIOrientation { Portrait, PortraitUpsideDown, LandscapeRight, LandscapeLeft, AutoRotation }

    public static class PlayerSettings
    {
        public static UIOrientation defaultInterfaceOrientation { get; set; }
        public static bool allowedAutorotateToPortrait { get; set; }
        public static bool allowedAutorotateToPortraitUpsideDown { get; set; }
        public static bool allowedAutorotateToLandscapeLeft { get; set; }
        public static bool allowedAutorotateToLandscapeRight { get; set; }
    }
}

namespace UnityEditor.SceneManagement
{
    using UnityEngine.SceneManagement;

    public enum NewSceneSetup { EmptyScene, DefaultGameObjects }
    public enum NewSceneMode { Single, Additive }

    public static class EditorSceneManager
    {
        public static Scene NewScene(NewSceneSetup setup, NewSceneMode mode) => new Scene();
        public static bool SaveScene(Scene scene, string path) => true;
    }
}
