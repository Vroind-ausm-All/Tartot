using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>
    /// Die spielbaren Figuren. Jede liest dieselben Karten anders.
    /// </summary>
    /// <remarks>
    /// Freigeschaltet wird ueber Prophezeiungen (siehe ProphecyCatalog), nicht
    /// ueber Spielzeit. Wer das Spiel eines Deuters meistert, wird zum
    /// naechsten gefuehrt: der Aderleser kommt zu dem, der viel umgekehrt
    /// spielt; der Eremit zu dem, der duenn baut.
    /// </remarks>
    public static class DeuterCatalog
    {
        public const string DefaultId = "wahrsagerin";

        public static readonly List<DeuterDefinition> All = new List<DeuterDefinition>
        {
            new DeuterDefinition
            {
                Id = DefaultId,
                Name = "Die Wahrsagerin",
                Subtitle = "Sie liest, was ohnehin geschieht.",
                RuleText = "Keine Sonderregel. Der ehrliche Weg.",
                Rule = DeuterRule.None,
                MaxHp = 72, Gold = 90, Luck = 2,
                Deck = new[]
                {
                    "pentacles_4", "swords_7", "wands_10", "cups_6",
                    "swords_3", "pentacles_6", "wands_4", "cups_8",
                    "major_1", "major_0"
                },
                Charms = new[] { "white_thread", "lucky_clover" },
                Items = new[] { "mirror_shard" }
            },
            new DeuterDefinition
            {
                Id = "aderleser",
                Name = "Der Aderleser",
                Subtitle = "Er braucht dein Blut, nicht deine Zukunft.",
                RuleText = "Umgekehrte Karten geben +0,15 Multiplikator statt +0,10 - und kosten ein Viertel mehr.",
                Rule = DeuterRule.BloodReader,
                MaxHp = 70, Gold = 80, Luck = 1,
                Deck = new[]
                {
                    "swords_5", "swords_7", "swords_9", "wands_6",
                    "wands_8", "cups_5", "cups_7", "cups_9",
                    "pentacles_5", "major_8"
                },
                ReversedCards = new[] { "swords_7", "swords_9", "wands_8" },
                Charms = new[] { "blood_moon", "moon_brooch" },
                Items = new[] { "sun_vial" },
                UnlockedBy = "blutige_lesung"
            },
            new DeuterDefinition
            {
                Id = "buchhalter",
                Name = "Der Buchhalter",
                Subtitle = "Er notiert jeden Treffer. Auch deine.",
                RuleText = "15 % deines Schildes bleibt zwischen den Runden. Vergessen kostet doppelt.",
                Rule = DeuterRule.Bookkeeper,
                MaxHp = 64, Gold = 90, Luck = 2,
                Deck = new[]
                {
                    "pentacles_3", "pentacles_5", "pentacles_7", "pentacles_9",
                    "swords_4", "swords_6", "cups_4", "wands_5",
                    "major_4", "major_11"
                },
                Charms = new string[0],
                Items = new[] { "pentacle_pouch" },
                UnlockedBy = "voller_tresor"
            },
            new DeuterDefinition
            {
                Id = "eremit",
                Name = "Der Eremit",
                Subtitle = "Er trägt nur, was er braucht. Den Rest vergisst er.",
                RuleText = "Deck-Resonanz wirkt doppelt. Kartenbelohnungen erscheinen seltener.",
                Rule = DeuterRule.Hermit,
                MaxHp = 68, Gold = 80, Luck = 3,
                Deck = new[]
                {
                    "swords_8", "wands_7", "cups_6", "pentacles_7",
                    "swords_10", "major_9"
                },
                Charms = new[] { "lucky_clover" },
                Items = new[] { "fate_scissors" },
                UnlockedBy = "leeres_blatt"
            }
        };

        public static DeuterDefinition Default => All[0];

        public static DeuterDefinition Find(string id) =>
            All.FirstOrDefault(d => d.Id == id) ?? Default;
    }

    /// <summary>
    /// Schleier 0-8. Wer auf Stufe n gewinnt, oeffnet Stufe n+1.
    /// </summary>
    /// <remarks>
    /// Jede Stufe nimmt genau eine Sicherheit weg und stapelt sich mit den
    /// vorigen. Keine Stufe macht Gegner einfach nur zaeher - das waere
    /// dieselbe Frage mit groesseren Zahlen.
    /// </remarks>
    public static class VeilCatalog
    {
        public const int MaxVeil = 8;

        public static readonly List<VeilDefinition> All = new List<VeilDefinition>
        {
            new VeilDefinition { Level = 0, Name = "Ohne Schleier", Text = "Das Spiel, wie es gedacht ist." },
            new VeilDefinition { Level = 1, Name = "Geizige Hände", Text = "Kämpfe bringen ein Viertel weniger Gold." },
            new VeilDefinition { Level = 2, Name = "Wache Omen", Text = "Elites und Bosse haben 20 % mehr HP und Haltung." },
            new VeilDefinition { Level = 3, Name = "Stumpfe Lesung", Text = "Belohnungen bieten eine Wahl weniger." },
            new VeilDefinition { Level = 4, Name = "Dünne Haut", Text = "Du beginnst mit 4 Max-HP weniger." },
            new VeilDefinition { Level = 5, Name = "Scharfe Omen", Text = "Ab Akt II schlagen Elites und Bosse je Akt 1 härter zu." },
            new VeilDefinition { Level = 6, Name = "Hungrige Schatten", Text = "Ab Akt II schlagen alle Gegner 1 härter zu." },
            new VeilDefinition { Level = 7, Name = "Blutzoll", Text = "Umkehrpreis +50 %, Rast und Aktwechsel heilen weniger." },
            new VeilDefinition { Level = 8, Name = "Das letzte Siegel", Text = "Die Welt trägt ein weiteres Schicksalssiegel." }
        };

        public static VeilDefinition Get(int level) =>
            All[Math.Max(0, Math.Min(MaxVeil, level))];
    }
}
