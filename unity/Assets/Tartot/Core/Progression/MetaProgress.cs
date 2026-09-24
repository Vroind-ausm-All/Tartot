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
        /// <summary>Die staerkste Karte des Runs - sie wartet spaeter im Grab.</summary>
        public string CardId = string.Empty;
        public string DeuterId = string.Empty;
    }

    /// <summary>Wie ein neuer Run beginnt: Figur, Schleier, Tageskarte.</summary>
    public sealed class RunSetup
    {
        public string DeuterId = DeuterCatalog.DefaultId;
        public int Veil;
        public bool IsDaily;

        /// <summary>
        /// Die Tageskarte: fuer alle am selben Tag derselbe Seed, dieselbe Figur
        /// und derselbe Schleier. Auch gesperrte Deuter kommen dran - wer sie
        /// einmal gespielt hat, will sie freischalten.
        /// </summary>
        public static RunSetup Daily(DateTime? utcNow = null)
        {
            var seed = MetaProgress.DailySeed(utcNow);
            var deuters = DeuterCatalog.All;
            return new RunSetup
            {
                DeuterId = deuters[(int)(seed % deuters.Count)].Id,
                Veil = 2,
                IsDaily = true
            };
        }
    }

    /// <summary>
    /// Fortschritt ueber Runs hinweg.
    /// </summary>
    /// <remarks>
    /// Bewusst kein "+5 % Schaden". Was waechst, ist das Verstaendnis (Lesarten
    /// der Grossen Arkana), die Auswahl (Prophezeiungen schalten Charms und
    /// Deuter frei), die Herausforderung (Schleier) und die Geschichte
    /// (Story-Flags, Totenkarten).
    /// </remarks>
    public sealed class MetaProgress
    {
        public const int CurrentVersion = 2;

        public int RunsStarted;
        public int RunsWon;
        public int Deaths;
        public int BestFightsCleared;
        public int BestFateTotal;
        public int SmallestDeck = int.MaxValue;
        /// <summary>Hoechster freigeschalteter Schleier (0-8).</summary>
        public int Veil;
        /// <summary>Hoechster Schleier, auf dem ein Run gewonnen wurde (-1 = noch nie).</summary>
        public int HighestVeilWon = -1;
        public int BestSpiralDepth;
        public int DailiesPlayed;
        public int BestDailyFate;
        public long LastDailySeed;

        public readonly Dictionary<string, int> ArcanaEncounters = new Dictionary<string, int>();
        public readonly Dictionary<string, List<string>> Interpretations = new Dictionary<string, List<string>>();
        public readonly HashSet<string> SeenCards = new HashSet<string>();
        public readonly List<DeathCard> DeathCards = new List<DeathCard>();

        /// <summary>Summe ueber alle Runs (Welt-Legungen, Ereignisse ...).</summary>
        public readonly Dictionary<string, int> LifetimeStats = new Dictionary<string, int>();
        /// <summary>Bestwert eines einzelnen Runs (hoechster Treffer, laengste Kette ...).</summary>
        public readonly Dictionary<string, int> BestStats = new Dictionary<string, int>();
        public readonly HashSet<string> CompletedProphecies = new HashSet<string>();
        public readonly HashSet<string> StoryFlags = new HashSet<string>();

        /// <summary>Ab wie vielen Begegnungen ein Arkanum eine neue Lesart zeigt.</summary>
        public static readonly int[] InterpretationThresholds = { 1, 5, 12 };
        public static readonly string[] InterpretationNames = { "Erste Lesart", "Transformation", "Verkehrte Lesart" };

        public const int MaxDeathCards = 30;

        public int Lifetime(string key) => LifetimeStats.TryGetValue(key, out var v) ? v : 0;
        public int Best(string key) => BestStats.TryGetValue(key, out var v) ? v : 0;

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

        // ------------------------------------------------- Freischaltungen
        public IEnumerable<string> UnlockedCharmIds =>
            ProphecyCatalog.All.Where(p => CompletedProphecies.Contains(p.Id)).SelectMany(p => p.UnlockCharms);

        /// <summary>Was in einem Run mit diesem Fortschritt angeboten werden darf.</summary>
        public HashSet<string> CharmPool()
        {
            var pool = new HashSet<string>(GameCatalog.StarterCharmIds);
            foreach (var id in UnlockedCharmIds) pool.Add(id);
            return pool;
        }

        public bool IsDeuterUnlocked(string deuterId)
        {
            var deuter = DeuterCatalog.All.FirstOrDefault(d => d.Id == deuterId);
            if (deuter == null) return false;
            return string.IsNullOrEmpty(deuter.UnlockedBy) || CompletedProphecies.Contains(deuter.UnlockedBy);
        }

        public IEnumerable<DeuterDefinition> UnlockedDeuters =>
            DeuterCatalog.All.Where(d => IsDeuterUnlocked(d.Id));

        /// <summary>
        /// Prophezeiungen, die mit dem laufenden Run gerade erfuellt waeren,
        /// aber noch nicht verbucht sind. Die Oberflaeche ruft das nach jedem
        /// Zug auf und zeigt den Moment sofort - nicht erst nach dem Tod.
        /// </summary>
        public List<ProphecyDefinition> PendingFulfilled(RunState run) =>
            ProphecyCatalog.All
                .Where(p => !CompletedProphecies.Contains(p.Id) && p.IsFulfilled(this, run))
                .ToList();

        // ---------------------------------------------------------- Runs
        /// <summary>Verbucht einen beendeten Run (Kurzform, ohne Bericht).</summary>
        public void RegisterRun(GameController game, bool won, string killedBy = "")
        {
            CompleteRun(game, won, killedBy);
        }

        /// <summary>
        /// Verbucht einen beendeten Run und erstellt den Bericht.
        /// </summary>
        /// <param name="won">Null: aus dem Run lesen (Finale geschlagen).</param>
        public RunReport CompleteRun(GameController game, bool? won = null, string killedBy = "")
        {
            var report = new RunReport();
            if (game == null) return report;

            var run = game.Run;
            var hasWon = won ?? run.Won;
            var previousBestFights = BestFightsCleared;
            var previousBestFate = BestFateTotal;
            var previousBestHit = Best("bestHit");

            RunsStarted++;
            if (hasWon) RunsWon++; else Deaths++;

            BestFightsCleared = Math.Max(BestFightsCleared, run.FightIndex);
            BestFateTotal = Math.Max(BestFateTotal, run.FateScoreTotal);
            if (run.Deck.Count > 0) SmallestDeck = Math.Min(SmallestDeck, run.Deck.Count);

            foreach (var pair in run.Stats.ToDictionary())
            {
                LifetimeStats[pair.Key] = Lifetime(pair.Key) + pair.Value;
                BestStats[pair.Key] = Math.Max(Best(pair.Key), pair.Value);
            }

            foreach (var card in run.Deck)
            {
                SeenCards.Add(card.Definition.Id);
                if (card.Definition.IsMajor) EncounterArcanum(card.Definition.Id);
            }
            foreach (var flag in run.NewStoryFlags) StoryFlags.Add(flag);

            if (hasWon)
            {
                HighestVeilWon = Math.Max(HighestVeilWon, run.Veil);
                Veil = Math.Min(VeilCatalog.MaxVeil, Math.Max(Veil, run.Veil + 1));
                BestSpiralDepth = Math.Max(BestSpiralDepth, ActCatalog.SpiralDepth(run.FightIndex));
            }

            if (run.IsDaily)
            {
                if (LastDailySeed != game.Seed) DailiesPlayed++;
                LastDailySeed = game.Seed;
                BestDailyFate = Math.Max(BestDailyFate, run.FateScoreTotal);
            }

            if (!hasWon)
            {
                var best = run.Deck
                    .OrderByDescending(c => (int)c.Shimmer * 10 + c.Level)
                    .FirstOrDefault();
                DeathCards.Add(new DeathCard
                {
                    Title = $"Gefallen nach Kampf {run.FightIndex}",
                    Fight = run.FightIndex,
                    DeckSize = run.Deck.Count,
                    FateTotal = run.FateScoreTotal,
                    KilledBy = killedBy ?? string.Empty,
                    Seed = game.Seed,
                    CardId = best?.Definition.Id ?? string.Empty,
                    DeuterId = run.DeuterId
                });
                if (DeathCards.Count > MaxDeathCards) DeathCards.RemoveAt(0);
            }

            // Prophezeiungen: jetzt ist der Run verbucht, also ohne ihn auswerten.
            foreach (var prophecy in ProphecyCatalog.All)
            {
                if (CompletedProphecies.Contains(prophecy.Id) || !prophecy.IsFulfilled(this, null)) continue;
                CompletedProphecies.Add(prophecy.Id);
                var reward = prophecy.RewardText;
                report.Unlocked.Add(string.IsNullOrEmpty(reward)
                    ? $"Prophezeiung erfüllt: {prophecy.Title}"
                    : $"Prophezeiung erfüllt: {prophecy.Title} — {reward}");
            }

            FillReport(report, game, hasWon, killedBy, previousBestFights, previousBestFate, previousBestHit);
            return report;
        }

        private void FillReport(RunReport report, GameController game, bool won, string killedBy,
            int previousBestFights, int previousBestFate, int previousBestHit)
        {
            var run = game.Run;
            report.Won = won;
            report.FightsCleared = run.FightIndex;
            report.Act = Math.Min(4, run.Act);
            report.SpiralDepth = ActCatalog.SpiralDepth(run.FightIndex);
            report.FateTotal = run.FateScoreTotal;
            report.BestHit = run.Stats.BestHit;
            report.BestHitCombo = run.Stats.BestHitCombo;
            report.KilledBy = killedBy ?? string.Empty;
            report.Darkness = run.Darkness;

            if (won)
                report.Headline = report.SpiralDepth > 0
                    ? $"DIE WELT FIEL · Spirale Tiefe {report.SpiralDepth}"
                    : "DIE WELT FIEL";
            else
                report.Headline = run.Act <= ActCatalog.ActCount
                    ? $"GEFALLEN IN AKT {Roman(run.Act)}"
                    : "GEFALLEN VOR DER WELT";

            if (run.FightIndex > previousBestFights && previousBestFights > 0)
                report.Records.Add($"Neuer Tiefenrekord: Kampf {run.FightIndex + 1}.");
            if (run.FateScoreTotal > previousBestFate && previousBestFate > 0)
                report.Records.Add($"Neuer Fate-Rekord: {run.FateScoreTotal}.");
            if (run.Stats.BestHit > previousBestHit && previousBestHit > 0)
                report.Records.Add($"Härtester Treffer aller Zeiten: {run.Stats.BestHit} ({run.Stats.BestHitCombo}).");

            // --- Beinahe: was knapp verfehlt wurde ---------------------
            var near = new List<NearMiss>();
            foreach (var prophecy in ProphecyCatalog.All)
            {
                if (CompletedProphecies.Contains(prophecy.Id)) continue;
                var progress = prophecy.Progress(this, null);
                if (progress < .25f) continue;
                near.Add(new NearMiss
                {
                    Title = prophecy.Title,
                    Detail = $"{prophecy.Text} ({prophecy.Value(this, null)} / {prophecy.Target})",
                    Reward = prophecy.RewardText,
                    Progress = progress
                });
            }

            if (!won)
            {
                var gap = previousBestFights - run.FightIndex;
                if (gap >= 0 && gap <= 2 && previousBestFights > 0)
                    near.Add(new NearMiss
                    {
                        Title = gap == 0 ? "Genau dein Rekord" : $"{gap} {(gap == 1 ? "Kampf" : "Kämpfe")} unter deinem Rekord",
                        Detail = $"Dein tiefster Run endete in Kampf {previousBestFights + 1}.",
                        Progress = 1f - gap * .05f
                    });

                // Am Boss gestorben: wie viel fehlte? Das ist der staerkste
                // Satz, den ein Todesbildschirm sagen kann.
                var enemy = game.Combat?.Enemy;
                var share = enemy == null ? 1f : (float)enemy.Hp / Math.Max(1, enemy.Definition.MaxHp);
                // Nur wenn wirklich wenig fehlte - ein Boss mit vollem Leben ist kein Beinahe.
                var close = enemy != null && enemy.Hp > 0 && (enemy.Sigils == 0 ? share <= .5f : share <= .25f);
                if (enemy != null && enemy.Definition.IsBoss && close)
                {
                    var finale = enemy.Definition.Tier == EnemyTier.Finale;
                    near.Add(new NearMiss
                    {
                        Title = $"{enemy.Definition.Name} hatte noch {enemy.Hp} HP" +
                                (enemy.Sigils > 0 ? $" und {enemy.Sigils} Siegel" : string.Empty),
                        Detail = enemy.Sigils > 0 ? "Ein Siegel stand noch." : "Ein, zwei Legungen mehr.",
                        Reward = finale
                            ? $"Der Sieg hätte Schleier {Math.Min(VeilCatalog.MaxVeil, run.Veil + 1)} geöffnet"
                            : $"Dahinter wartete Akt {Roman(Math.Min(ActCatalog.ActCount, run.Act + 1))}",
                        Progress = enemy.Sigils > 0 ? .5f * (1f - share) : 1f - share
                    });
                }
                else if (run.Act == ActCatalog.ActCount)
                {
                    var left = ActCatalog.FinaleIndex - run.FightIndex;
                    near.Add(new NearMiss
                    {
                        Title = "Das Finale war nah",
                        Detail = $"Noch {left} {(left == 1 ? "Kampf" : "Kämpfe")} bis zur Welt.",
                        Reward = $"Schleier {Math.Min(VeilCatalog.MaxVeil, run.Veil + 1)} öffnet sich mit dem Sieg",
                        Progress = .8f
                    });
                }
            }

            // Lesarten, die eine einzige Begegnung entfernt sind.
            foreach (var card in run.Deck.Where(c => c.Definition.IsMajor).Select(c => c.Definition).Distinct())
            {
                ArcanaEncounters.TryGetValue(card.Id, out var count);
                for (var i = 0; i < InterpretationThresholds.Length; i++)
                {
                    if (InterpretationThresholds[i] != count + 1) continue;
                    near.Add(new NearMiss
                    {
                        Title = $"{card.Name}: noch 1 Begegnung",
                        Detail = $"bis zur Lesart „{InterpretationNames[i]}“.",
                        Reward = $"+{CombatSystem.InterpretationPowerPerReading * 100:0} % Wirkung für dieses Arkanum",
                        Progress = .95f
                    });
                }
            }

            report.NearMisses.AddRange(near.OrderByDescending(n => n.Progress).Take(3));
        }

        public static string Roman(int value)
        {
            var numerals = new[] { "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" };
            return value >= 0 && value < numerals.Length ? numerals[value] : value.ToString();
        }

        /// <summary>Tageskarte: derselbe Seed fuer alle Spieler an einem Tag (UTC).</summary>
        public static long DailySeed(DateTime? utcNow = null)
        {
            var now = utcNow ?? DateTime.UtcNow;
            return now.Year * 10000L + now.Month * 100L + now.Day;
        }

        // ------------------------------------------------------- Speichern
        private static JsonValue WriteCounts(Dictionary<string, int> counts)
        {
            var node = JsonValue.Object();
            foreach (var pair in counts.OrderBy(p => p.Key, StringComparer.Ordinal)) node.Set(pair.Key, pair.Value);
            return node;
        }

        private static JsonValue WriteSet(IEnumerable<string> values)
        {
            var node = JsonValue.Array();
            foreach (var value in values.OrderBy(x => x, StringComparer.Ordinal)) node.Add(JsonValue.Of(value));
            return node;
        }

        private static void ReadCounts(JsonValue node, Dictionary<string, int> target)
        {
            if (node == null || node.Kind != JsonKind.Object) return;
            foreach (var pair in node.Members)
                target[pair.Key] = (int)Math.Round(pair.Value.NumberValue);
        }

        private static void ReadSet(JsonValue root, string key, HashSet<string> target)
        {
            foreach (var entry in root.GetArray(key))
                if (entry.Kind == JsonKind.String) target.Add(entry.StringValue);
        }

        public string Serialize(bool indented = false)
        {
            var interpretations = JsonValue.Object();
            foreach (var pair in Interpretations)
            {
                var list = JsonValue.Array();
                foreach (var name in pair.Value) list.Add(JsonValue.Of(name));
                interpretations.Set(pair.Key, list);
            }

            var deaths = JsonValue.Array();
            foreach (var card in DeathCards)
                deaths.Add(JsonValue.Object()
                    .Set("title", card.Title)
                    .Set("fight", card.Fight)
                    .Set("deck", card.DeckSize)
                    .Set("fate", card.FateTotal)
                    .Set("by", card.KilledBy)
                    .Set("seed", card.Seed)
                    .Set("card", card.CardId)
                    .Set("deuter", card.DeuterId));

            return Json.Write(JsonValue.Object()
                .Set("version", CurrentVersion)
                .Set("runsStarted", RunsStarted)
                .Set("runsWon", RunsWon)
                .Set("deaths", Deaths)
                .Set("bestFights", BestFightsCleared)
                .Set("bestFate", BestFateTotal)
                .Set("smallestDeck", SmallestDeck == int.MaxValue ? 0 : SmallestDeck)
                .Set("veil", Veil)
                .Set("highestVeilWon", HighestVeilWon)
                .Set("bestSpiral", BestSpiralDepth)
                .Set("dailies", DailiesPlayed)
                .Set("bestDaily", BestDailyFate)
                .Set("lastDaily", LastDailySeed)
                .Set("arcana", WriteCounts(ArcanaEncounters))
                .Set("interpretations", interpretations)
                .Set("seen", WriteSet(SeenCards))
                .Set("deathCards", deaths)
                .Set("lifetime", WriteCounts(LifetimeStats))
                .Set("best", WriteCounts(BestStats))
                .Set("prophecies", WriteSet(CompletedProphecies))
                .Set("flags", WriteSet(StoryFlags)), indented);
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
            meta.HighestVeilWon = root.GetInt("highestVeilWon", -1);
            meta.BestSpiralDepth = root.GetInt("bestSpiral");
            meta.DailiesPlayed = root.GetInt("dailies");
            meta.BestDailyFate = root.GetInt("bestDaily");
            meta.LastDailySeed = root.GetLong("lastDaily");

            ReadCounts(root.Get("arcana"), meta.ArcanaEncounters);

            var interpretations = root.Get("interpretations");
            if (interpretations != null && interpretations.Kind == JsonKind.Object)
                foreach (var pair in interpretations.Members)
                    meta.Interpretations[pair.Key] = pair.Value.Items
                        .Where(v => v.Kind == JsonKind.String)
                        .Select(v => v.StringValue).ToList();

            ReadSet(root, "seen", meta.SeenCards);

            foreach (var entry in root.GetArray("deathCards"))
                meta.DeathCards.Add(new DeathCard
                {
                    Title = entry.GetString("title"),
                    Fight = entry.GetInt("fight"),
                    DeckSize = entry.GetInt("deck"),
                    FateTotal = entry.GetInt("fate"),
                    KilledBy = entry.GetString("by"),
                    Seed = entry.GetLong("seed"),
                    CardId = entry.GetString("card"),
                    DeuterId = entry.GetString("deuter")
                });

            ReadCounts(root.Get("lifetime"), meta.LifetimeStats);
            ReadCounts(root.Get("best"), meta.BestStats);
            ReadSet(root, "prophecies", meta.CompletedProphecies);
            ReadSet(root, "flags", meta.StoryFlags);
            return meta;
        }
    }
}
