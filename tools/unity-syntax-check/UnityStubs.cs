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

    public static class Resources
    {
        public static T Load<T>(string path) where T : Object => null;
    }

    public class PanelSettings : Object { }
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

    public interface IStyle
    {
        DisplayStyle display { get; set; }
        Length width { get; set; }
        Rotate rotate { get; set; }
    }

    internal sealed class StyleStub : IStyle
    {
        public DisplayStyle display { get; set; }
        public Length width { get; set; }
        public Rotate rotate { get; set; }
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
