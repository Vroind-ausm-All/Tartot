using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace Tartot.Core
{
    /// <summary>
    /// Minimaler JSON-Baustein ohne Fremdpakete.
    /// </summary>
    /// <remarks>
    /// Warum nicht Newtonsoft oder System.Text.Json? Der Kern soll in Unity
    /// ohne zusaetzliches Paket kompilieren, und Unitys eigenes JsonUtility
    /// kann weder Dictionaries noch Polymorphie. Ein eigener, kleiner
    /// Serialisierer garantiert ausserdem, dass ein Speicherstand in Unity und
    /// in den Tests Byte fuer Byte gleich gelesen wird.
    ///
    /// Bewusst nicht enthalten: Reflexion, Attribute, Zyklen. Die
    /// Speicherstaende werden von Hand aufgebaut - das ist mehr Tipparbeit,
    /// aber das Format bleibt dadurch stabil und ueberschaubar.
    /// </remarks>
    public static class Json
    {
        // ------------------------------------------------------------ Schreiben
        public static string Write(JsonValue value, bool indented = false)
        {
            var builder = new StringBuilder();
            WriteValue(builder, value, indented, 0);
            return builder.ToString();
        }

        private static void WriteValue(StringBuilder sb, JsonValue value, bool indented, int depth)
        {
            if (value == null || value.Kind == JsonKind.Null) { sb.Append("null"); return; }
            switch (value.Kind)
            {
                case JsonKind.Bool:
                    sb.Append(value.BoolValue ? "true" : "false");
                    break;
                case JsonKind.Number:
                    sb.Append(value.NumberValue.ToString("R", CultureInfo.InvariantCulture));
                    break;
                case JsonKind.String:
                    WriteString(sb, value.StringValue);
                    break;
                case JsonKind.Array:
                    WriteArray(sb, value, indented, depth);
                    break;
                case JsonKind.Object:
                    WriteObject(sb, value, indented, depth);
                    break;
            }
        }

        private static void WriteArray(StringBuilder sb, JsonValue value, bool indented, int depth)
        {
            if (value.Items.Count == 0) { sb.Append("[]"); return; }
            sb.Append('[');
            for (var i = 0; i < value.Items.Count; i++)
            {
                if (i > 0) sb.Append(',');
                NewLine(sb, indented, depth + 1);
                WriteValue(sb, value.Items[i], indented, depth + 1);
            }
            NewLine(sb, indented, depth);
            sb.Append(']');
        }

        private static void WriteObject(StringBuilder sb, JsonValue value, bool indented, int depth)
        {
            if (value.Members.Count == 0) { sb.Append("{}"); return; }
            sb.Append('{');
            var first = true;
            foreach (var pair in value.Members)
            {
                if (!first) sb.Append(',');
                first = false;
                NewLine(sb, indented, depth + 1);
                WriteString(sb, pair.Key);
                sb.Append(':');
                if (indented) sb.Append(' ');
                WriteValue(sb, pair.Value, indented, depth + 1);
            }
            NewLine(sb, indented, depth);
            sb.Append('}');
        }

        private static void NewLine(StringBuilder sb, bool indented, int depth)
        {
            if (!indented) return;
            sb.Append('\n');
            sb.Append(' ', depth * 2);
        }

        private static void WriteString(StringBuilder sb, string text)
        {
            sb.Append('"');
            if (text != null)
            {
                foreach (var c in text)
                {
                    switch (c)
                    {
                        case '"': sb.Append("\\\""); break;
                        case '\\': sb.Append("\\\\"); break;
                        case '\n': sb.Append("\\n"); break;
                        case '\r': sb.Append("\\r"); break;
                        case '\t': sb.Append("\\t"); break;
                        case '\b': sb.Append("\\b"); break;
                        case '\f': sb.Append("\\f"); break;
                        default:
                            if (c < ' ') sb.Append("\\u").Append(((int)c).ToString("x4", CultureInfo.InvariantCulture));
                            else sb.Append(c);
                            break;
                    }
                }
            }
            sb.Append('"');
        }

        // --------------------------------------------------------------- Lesen
        public static JsonValue Parse(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) throw new FormatException("Leerer JSON-Text.");
            var index = 0;
            var value = ParseValue(text, ref index);
            SkipWhitespace(text, ref index);
            if (index != text.Length) throw new FormatException($"Unerwartetes Zeichen an Position {index}.");
            return value;
        }

        public static bool TryParse(string text, out JsonValue value)
        {
            try { value = Parse(text); return true; }
            catch (FormatException) { value = null; return false; }
        }

        private static JsonValue ParseValue(string s, ref int i)
        {
            SkipWhitespace(s, ref i);
            if (i >= s.Length) throw new FormatException("Unerwartetes Ende.");
            switch (s[i])
            {
                case '{': return ParseObject(s, ref i);
                case '[': return ParseArray(s, ref i);
                case '"': return JsonValue.Of(ParseString(s, ref i));
                case 't': Expect(s, ref i, "true"); return JsonValue.Of(true);
                case 'f': Expect(s, ref i, "false"); return JsonValue.Of(false);
                case 'n': Expect(s, ref i, "null"); return JsonValue.Null();
                default: return JsonValue.Of(ParseNumber(s, ref i));
            }
        }

        private static JsonValue ParseObject(string s, ref int i)
        {
            var result = JsonValue.Object();
            i++; // {
            SkipWhitespace(s, ref i);
            if (i < s.Length && s[i] == '}') { i++; return result; }
            while (true)
            {
                SkipWhitespace(s, ref i);
                var key = ParseString(s, ref i);
                SkipWhitespace(s, ref i);
                if (i >= s.Length || s[i] != ':') throw new FormatException($"':' erwartet an Position {i}.");
                i++;
                result.Members[key] = ParseValue(s, ref i);
                SkipWhitespace(s, ref i);
                if (i >= s.Length) throw new FormatException("Objekt nicht geschlossen.");
                if (s[i] == ',') { i++; continue; }
                if (s[i] == '}') { i++; return result; }
                throw new FormatException($"',' oder '}}' erwartet an Position {i}.");
            }
        }

        private static JsonValue ParseArray(string s, ref int i)
        {
            var result = JsonValue.Array();
            i++; // [
            SkipWhitespace(s, ref i);
            if (i < s.Length && s[i] == ']') { i++; return result; }
            while (true)
            {
                result.Items.Add(ParseValue(s, ref i));
                SkipWhitespace(s, ref i);
                if (i >= s.Length) throw new FormatException("Array nicht geschlossen.");
                if (s[i] == ',') { i++; continue; }
                if (s[i] == ']') { i++; return result; }
                throw new FormatException($"',' oder ']' erwartet an Position {i}.");
            }
        }

        private static string ParseString(string s, ref int i)
        {
            if (i >= s.Length || s[i] != '"') throw new FormatException($"Zeichenkette erwartet an Position {i}.");
            i++;
            var sb = new StringBuilder();
            while (i < s.Length)
            {
                var c = s[i++];
                if (c == '"') return sb.ToString();
                if (c != '\\') { sb.Append(c); continue; }
                if (i >= s.Length) break;
                var escape = s[i++];
                switch (escape)
                {
                    case '"': sb.Append('"'); break;
                    case '\\': sb.Append('\\'); break;
                    case '/': sb.Append('/'); break;
                    case 'n': sb.Append('\n'); break;
                    case 'r': sb.Append('\r'); break;
                    case 't': sb.Append('\t'); break;
                    case 'b': sb.Append('\b'); break;
                    case 'f': sb.Append('\f'); break;
                    case 'u':
                        if (i + 4 > s.Length) throw new FormatException("Unvollstaendige \\u-Folge.");
                        sb.Append((char)Convert.ToInt32(s.Substring(i, 4), 16));
                        i += 4;
                        break;
                    default: throw new FormatException($"Unbekannte Escape-Folge \\{escape}.");
                }
            }
            throw new FormatException("Zeichenkette nicht geschlossen.");
        }

        private static double ParseNumber(string s, ref int i)
        {
            var start = i;
            if (i < s.Length && (s[i] == '-' || s[i] == '+')) i++;
            while (i < s.Length && (char.IsDigit(s[i]) || s[i] == '.' || s[i] == 'e' || s[i] == 'E'
                                    || s[i] == '-' || s[i] == '+')) i++;
            var slice = s.Substring(start, i - start);
            if (!double.TryParse(slice, NumberStyles.Float, CultureInfo.InvariantCulture, out var value))
                throw new FormatException($"Keine gueltige Zahl: '{slice}'.");
            return value;
        }

        private static void Expect(string s, ref int i, string literal)
        {
            if (i + literal.Length > s.Length || string.CompareOrdinal(s, i, literal, 0, literal.Length) != 0)
                throw new FormatException($"'{literal}' erwartet an Position {i}.");
            i += literal.Length;
        }

        private static void SkipWhitespace(string s, ref int i)
        {
            while (i < s.Length && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
        }
    }

    public enum JsonKind { Null, Bool, Number, String, Array, Object }

    /// <summary>Ein JSON-Knoten. Bewusst schlicht: keine Reflexion, keine Zyklen.</summary>
    public sealed class JsonValue
    {
        public JsonKind Kind { get; private set; }
        public bool BoolValue { get; private set; }
        public double NumberValue { get; private set; }
        public string StringValue { get; private set; }
        public List<JsonValue> Items { get; private set; }
        public Dictionary<string, JsonValue> Members { get; private set; }

        public static JsonValue Null() => new JsonValue { Kind = JsonKind.Null };
        public static JsonValue Of(bool v) => new JsonValue { Kind = JsonKind.Bool, BoolValue = v };
        public static JsonValue Of(double v) => new JsonValue { Kind = JsonKind.Number, NumberValue = v };
        public static JsonValue Of(long v) => new JsonValue { Kind = JsonKind.Number, NumberValue = v };
        public static JsonValue Of(int v) => new JsonValue { Kind = JsonKind.Number, NumberValue = v };
        public static JsonValue Of(string v) =>
            v == null ? Null() : new JsonValue { Kind = JsonKind.String, StringValue = v };

        public static JsonValue Array() =>
            new JsonValue { Kind = JsonKind.Array, Items = new List<JsonValue>() };

        public static JsonValue Object() =>
            new JsonValue { Kind = JsonKind.Object, Members = new Dictionary<string, JsonValue>() };

        // -------------------------------------------------------- Bequemlichkeit
        public JsonValue Set(string key, JsonValue value) { Members[key] = value; return this; }
        public JsonValue Set(string key, string value) => Set(key, Of(value));
        public JsonValue Set(string key, int value) => Set(key, Of(value));
        public JsonValue Set(string key, long value) => Set(key, Of(value));
        public JsonValue Set(string key, double value) => Set(key, Of(value));
        public JsonValue Set(string key, bool value) => Set(key, Of(value));
        public JsonValue Add(JsonValue value) { Items.Add(value); return this; }

        public bool Has(string key) => Kind == JsonKind.Object && Members.ContainsKey(key);

        public JsonValue Get(string key) =>
            Kind == JsonKind.Object && Members.TryGetValue(key, out var value) ? value : null;

        /// <summary>Lesen mit Vorgabewert - fehlende Felder sind kein Fehler,
        /// damit aeltere Speicherstaende weiter laden.</summary>
        public int GetInt(string key, int fallback = 0)
        {
            var v = Get(key);
            return v != null && v.Kind == JsonKind.Number ? (int)Math.Round(v.NumberValue) : fallback;
        }

        public long GetLong(string key, long fallback = 0)
        {
            var v = Get(key);
            return v != null && v.Kind == JsonKind.Number ? (long)Math.Round(v.NumberValue) : fallback;
        }

        public ulong GetULong(string key, ulong fallback = 0)
        {
            var v = Get(key);
            if (v == null || v.Kind != JsonKind.String) return fallback;
            return ulong.TryParse(v.StringValue, NumberStyles.None, CultureInfo.InvariantCulture, out var parsed)
                ? parsed : fallback;
        }

        public float GetFloat(string key, float fallback = 0f)
        {
            var v = Get(key);
            return v != null && v.Kind == JsonKind.Number ? (float)v.NumberValue : fallback;
        }

        public bool GetBool(string key, bool fallback = false)
        {
            var v = Get(key);
            return v != null && v.Kind == JsonKind.Bool ? v.BoolValue : fallback;
        }

        public string GetString(string key, string fallback = "")
        {
            var v = Get(key);
            return v != null && v.Kind == JsonKind.String ? v.StringValue : fallback;
        }

        public List<JsonValue> GetArray(string key)
        {
            var v = Get(key);
            return v != null && v.Kind == JsonKind.Array ? v.Items : new List<JsonValue>();
        }

        public TEnum GetEnum<TEnum>(string key, TEnum fallback) where TEnum : struct
        {
            var v = Get(key);
            if (v == null) return fallback;
            if (v.Kind == JsonKind.String && Enum.TryParse<TEnum>(v.StringValue, out var parsed)) return parsed;
            if (v.Kind == JsonKind.Number)
            {
                var number = (int)Math.Round(v.NumberValue);
                if (Enum.IsDefined(typeof(TEnum), number)) return (TEnum)Enum.ToObject(typeof(TEnum), number);
            }
            return fallback;
        }
    }
}
