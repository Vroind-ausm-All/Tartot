using System;

namespace UnityEngine
{
    public class Object
    {
        public string name { get; set; }
        public static T FindObjectOfType<T>() where T : Object => null;
        public static void DontDestroyOnLoad(Object target) { }
    }
    public class Component : Object
    {
        public GameObject gameObject { get; } = new GameObject("stub");
        public T GetComponent<T>() where T : Component => null;
    }
    public class Behaviour : Component { }
    public class MonoBehaviour : Behaviour { }
    public class GameObject : Object
    {
        public GameObject(string name) { this.name = name; }
        public T AddComponent<T>() where T : Component => null;
    }
    public sealed class TooltipAttribute : Attribute { public TooltipAttribute(string t) { } }
    public sealed class RequireComponent : Attribute { public RequireComponent(Type t) { } }
    public enum RuntimeInitializeLoadType { AfterSceneLoad }
    public sealed class RuntimeInitializeOnLoadMethodAttribute : Attribute { public RuntimeInitializeOnLoadMethodAttribute(RuntimeInitializeLoadType t) { } }
    public static class Debug { public static void Log(object m) { } public static void LogWarning(object m) { } public static void LogError(object m) { } }
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
    public static class Resources { public static T Load<T>(string path) where T : Object => null; }
    public struct Vector2Int { public Vector2Int(int x, int y) { } }
    public struct Rect
    {
        public float x, y, width, height;
        public float xMin => x; public float yMin => y; public float xMax => x + width; public float yMax => y + height;
    }
    public static class Screen { public static int width => 1080; public static int height => 1920; public static Rect safeArea => new Rect { x = 0, y = 0, width = 1080, height = 1920 }; }
    public static class Time { public static float unscaledTime => 0f; }
    public static class Handheld { public static void Vibrate() { } }
    public struct Color32
    {
        public byte r, g, b, a;
        public Color32(byte r, byte g, byte b, byte a) { this.r = r; this.g = g; this.b = b; this.a = a; }
    }
    public enum TextureFormat { RGBA32 }
    public enum FilterMode { Point }
    public enum TextureWrapMode { Clamp, Repeat }
    public class Texture2D : Object
    {
        public Texture2D(int width, int height, TextureFormat format, bool mipChain) { }
        public FilterMode filterMode { get; set; }
        public TextureWrapMode wrapMode { get; set; }
        public void SetPixels32(Color32[] colors) { }
        public void Apply(bool updateMipmaps, bool makeNoLongerReadable) { }
    }
    public class AudioClip : Object
    {
        public static AudioClip Create(string name, int lengthSamples, int channels, int frequency, bool stream) => new AudioClip();
        public bool SetData(float[] data, int offsetSamples) => true;
    }
    public class AudioSource : Behaviour
    {
        public bool playOnAwake { get; set; }
        public bool loop { get; set; }
        public float volume { get; set; }
        public float pitch { get; set; }
        public AudioClip clip { get; set; }
        public void Play() { }
        public void PlayOneShot(AudioClip clip, float volumeScale = 1f) { }
    }
    public class ScriptableObject : Object { public static T CreateInstance<T>() where T : ScriptableObject => null; }
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
    public struct Length { public static Length Percent(float value) => new Length(); }
    public struct Rotate { public Rotate(float angle) { } }
    public struct StyleBackground { public StyleBackground(UnityEngine.Texture2D texture) { } }
    public interface IStyle
    {
        DisplayStyle display { get; set; }
        Length width { get; set; }
        Rotate rotate { get; set; }
        StyleBackground backgroundImage { get; set; }
        float paddingLeft { get; set; }
        float paddingRight { get; set; }
        float paddingTop { get; set; }
        float paddingBottom { get; set; }
    }
    internal sealed class StyleStub : IStyle
    {
        public DisplayStyle display { get; set; }
        public Length width { get; set; }
        public Rotate rotate { get; set; }
        public StyleBackground backgroundImage { get; set; }
        public float paddingLeft { get; set; }
        public float paddingRight { get; set; }
        public float paddingTop { get; set; }
        public float paddingBottom { get; set; }
    }
    public class EventBase { }
    public class ClickEvent : EventBase { }
    public class VisualElement
    {
        public IStyle style { get; } = new StyleStub();
        public void Add(VisualElement child) { }
        public void Clear() { }
        public void AddToClassList(string className) { }
        public void RemoveFromClassList(string className) { }
        public void EnableInClassList(string className, bool enable) { }
        public void SetEnabled(bool value) { }
        public void RegisterCallback<TEvent>(Action<TEvent> callback) where TEvent : EventBase { }
        public T Q<T>(string name = null) where T : VisualElement => null;
    }
    public class Label : VisualElement
    {
        public Label() { }
        public Label(string text) { this.text = text; }
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
    public class ThemeStyleSheet : Object { }
    public enum PanelScaleMode { ConstantPixelSize, ScaleWithScreenSize, ConstantPhysicalSize }
    public enum PanelScreenMatchMode { MatchWidthOrHeight, Shrink, Expand }
}

namespace UnityEngine.SceneManagement { public struct Scene { } }

namespace UnityEditor
{
    using System;
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
    public enum BuildTargetGroup { Android }
    public enum BuildTarget { Android }
    public enum BuildOptions { None }
    public static class PlayerSettings
    {
        public static UIOrientation defaultInterfaceOrientation { get; set; }
        public static bool allowedAutorotateToPortrait { get; set; }
        public static bool allowedAutorotateToPortraitUpsideDown { get; set; }
        public static bool allowedAutorotateToLandscapeLeft { get; set; }
        public static bool allowedAutorotateToLandscapeRight { get; set; }
        public static string companyName { get; set; }
        public static string productName { get; set; }
        public static string bundleVersion { get; set; }
        public static void SetApplicationIdentifier(BuildTargetGroup group, string identifier) { }
    }
    public static class EditorUserBuildSettings { public static bool SwitchActiveBuildTarget(BuildTargetGroup group, BuildTarget target) => true; }
    public struct BuildPlayerOptions
    {
        public string[] scenes;
        public string locationPathName;
        public BuildTarget target;
        public BuildOptions options;
    }
    public static class BuildPipeline { public static UnityEditor.Build.Reporting.BuildReport BuildPlayer(BuildPlayerOptions options) => new UnityEditor.Build.Reporting.BuildReport(); }
}

namespace UnityEditor.Build.Reporting
{
    public enum BuildResult { Unknown, Succeeded, Failed, Cancelled }
    public class BuildSummary { public BuildResult result { get; set; } public ulong totalSize { get; set; } }
    public class BuildReport { public BuildSummary summary { get; } = new BuildSummary(); }
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
