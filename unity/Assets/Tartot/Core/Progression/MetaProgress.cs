using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>Was ein gescheiterter Run hinterlaesst.</summary>
    public sealed class DeathCard
    {
        public string Title = string.Empty;
        public int Fight;
        public int DeckSize;
        public int FateTotal;
        public string KilledBy = string.Empty;
        public long Seed;
    }

    /// <summary>
    /// Fortschritt ueber Runs hinweg.
    /// </summary>
    /// <remarks>
    /// Bewusst kein "+5 % Schaden". Was waechst, ist das Verstaendnis: jede
    /// Begegnung mit einem Grossen Arkanum schaltet nach genug Begegnungen eine
    /// neue Lesart frei, und jeder Tod hinterlaesst eine Totenkarte aus den
    /// Eckdaten des Runs.
    ///
    /// Die Lesarten werden hier gesammelt und gespeichert; sie in die
    /// Kartenwirkung einzuspeisen steht noch aus (siehe docs/ROADMAP.md).
    /// </remarks>
    public sealed class MetaProgress
    {
        public const int CurrentVersion = 1;

        public int RunsStarted;
        public int RunsWon;
        public int Deaths;
        public int BestFightsCleared;
        public int BestFateTotal;
        public int SmallestDeck = int.MaxValue;
        public int Veil;                       // Schwierigkeitsstufe 0-8

        public readonly Dictionary<string, int> ArcanaEncounters = new Dictionary<string, int>();
        public readonly Dictionary<string, List<string>> Interpretations = new Dictionary<string, List<string>>();
        public readonly HashSet<string> SeenCards = new HashSet<string>();
        public readonly List<DeathCard> DeathCards = new List<DeathCard>();

        /// <summary>Ab wie vielen Begegnungen ein Arkanum eine neue Lesart zeigt.</summary>
        public static readonly int[] InterpretationThresholds = { 1, 5, 12 };
        public static readonly string[] InterpretationNames = { "Erste Lesart", "Transformation", "Verkehrte Lesart" };

        public const int MaxDeathCards = 30;

        /// <summary>
        /// Zaehlt eine Begegnung und gibt die dadurch freigeschaltete Lesart
        /// zurueck, sonst null.
        /// </summary>
        public string EncounterArcanum(string cardId)
        {
            if (string.IsNullOrEmpty(cardId)) return null;
            ArcanaEncounters.TryGetValue(cardId, out var count);
            count++;
            ArcanaEncounters[cardId] = count;

            var index = Array.IndexOf(InterpretationThresholds, count);
            if (index < 0) return null;

            if (!Interpretations.TryGetValue(cardId, out var list))
            {
                list = new List<string>();
                Interpretations[cardId] = list;
            }
            var name = InterpretationNames[index];
            if (list.Contains(name)) return null;
            list.Add(name);
            return name;
        }

        public bool HasInterpretation(string cardId, string name) =>
            Interpretations.TryGetValue(cardId, out var list) && list.Contains(name);

        public int InterpretationCount =>
            Interpretations.Values.Sum(list => list.Count);

        /// <summary>Verbucht einen beendeten Run.</summary>
        public void RegisterRun(GameController game, bool won, string killedBy = "")
        {
            if (game == null) return;
            RunsStarted++;
            if (won) RunsWon++; else Deaths++;

            var run = game.Run;
            BestFightsCleared = Math.Max(BestFightsCleared, run.FightIndex);
            BestFateTotal = Math.Max(BestFateTotal, run.FateScoreTotal);
            if (run.Deck.Count > 0) SmallestDeck = Math.Min(SmallestDeck, run.Deck.Count);

            foreach (var card in run.Deck)
            {
                SeenCards.Add(card.Definition.Id);
                if (card.Definition.IsMajor) EncounterArcanum(card.Definition.Id);
            }

            if (!won)
            {
                DeathCards.Add(new DeathCard
                {
                    Title = $"Gefallen nach Kampf {run.FightIndex}",
                    Fight = run.FightIndex,
                    DeckSize = run.Deck.Count,
                    FateTotal = run.FateScoreTotal,
                    KilledBy = killedBy,
                    Seed = game.Seed
                });
                if (DeathCards.Count > MaxDeathCards) DeathCards.RemoveAt(0);
            }
        }

        /// <summary>Tageskarte: derselbe Seed fuer alle Spieler an einem Tag (UTC).</summary>
        public static long DailySeed(DateTime? utcNow = null)
        {
            var now = utcNow ?? DateTime.UtcNow;
            return now.Year * 10000L + now.Month * 100L + now.Day;
        }

        // ------------------------------------------------------- Speichern
        public string Serialize(bool indented = false)
        {
            var encounters = JsonValue.Object();
            foreach (var pair in ArcanaEncounters) encounters.Set(pair.Key, pair.Value);

            var interpretations = JsonValue.Object();
            foreach (var pair in Interpretations)
            {
                var list = JsonValue.Array();
                foreach (var name in pair.Value) list.Add(JsonValue.Of(name));
                interpretations.Set(pair.Key, list);
            }

            var seen = JsonValue.Array();
            foreach (var id in SeenCards.OrderBy(x => x, StringComparer.Ordinal))
                seen.Add(JsonValue.Of(id));

            var deaths = JsonValue.Array();
            foreach (var card in DeathCards)
                deaths.Add(JsonValue.Object()
                    .Set("title", card.Title)
                    .Set("fight", card.Fight)
                    .Set("deck", card.DeckSize)
                    .Set("fate", card.FateTotal)
                    .Set("by", card.KilledBy)
                    .Set("seed", card.Seed));

            return Json.Write(JsonValue.Object()
                .Set("version", CurrentVersion)
                .Set("runsStarted", RunsStarted)
                .Set("runsWon", RunsWon)
                .Set("deaths", Deaths)
                .Set("bestFights", BestFightsCleared)
                .Set("bestFate", BestFateTotal)
                .Set("smallestDeck", SmallestDeck == int.MaxValue ? 0 : SmallestDeck)
                .Set("veil", Veil)
                .Set("arcana", encounters)
                .Set("interpretations", interpretations)
                .Set("seen", seen)
                .Set("deathCards", deaths), indented);
        }

        public static MetaProgress Deserialize(string text)
        {
            var meta = new MetaProgress();
            if (string.IsNullOrWhiteSpace(text) || !Json.TryParse(text, out var root)) return meta;

            meta.RunsStarted = root.GetInt("runsStarted");
            meta.RunsWon = root.GetInt("runsWon");
            meta.Deaths = root.GetInt("deaths");
            meta.BestFightsCleared = root.GetInt("bestFights");
            meta.BestFateTotal = root.GetInt("bestFate");
            var smallest = root.GetInt("smallestDeck");
            meta.SmallestDeck = smallest <= 0 ? int.MaxValue : smallest;
            meta.Veil = root.GetInt("veil");

            var arcana = root.Get("arcana");
            if (arcana != null && arcana.Kind == JsonKind.Object)
                foreach (var pair in arcana.Members)
                    meta.ArcanaEncounters[pair.Key] = (int)Math.Round(pair.Value.NumberValue);

            var interpretations = root.Get("interpretations");
            if (interpretations != null && interpretations.Kind == JsonKind.Object)
                foreach (var pair in interpretations.Members)
                    meta.Interpretations[pair.Key] = pair.Value.Items
                        .Where(v => v.Kind == JsonKind.String)
                        .Select(v => v.StringValue).ToList();

            foreach (var entry in root.GetArray("seen"))
                if (entry.Kind == JsonKind.String) meta.SeenCards.Add(entry.StringValue);

            foreach (var entry in root.GetArray("deathCards"))
                meta.DeathCards.Add(new DeathCard
                {
                    Title = entry.GetString("title"),
                    Fight = entry.GetInt("fight"),
                    DeckSize = entry.GetInt("deck"),
                    FateTotal = entry.GetInt("fate"),
                    KilledBy = entry.GetString("by"),
                    Seed = entry.GetLong("seed")
                });

            return meta;
        }
    }
}
