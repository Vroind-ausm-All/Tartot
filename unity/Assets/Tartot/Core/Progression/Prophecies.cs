using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>
    /// Ein Ziel ueber Runs hinweg, das etwas freischaltet.
    /// </summary>
    /// <remarks>
    /// Prophezeiungen sind der Grund, warum ein verlorener Run nicht verloren
    /// ist: fast jeder Run bringt mindestens eine von ihnen naeher. Der
    /// Run-Bericht zeigt die naechsten drei - "noch 1 Welt-Legung bis
    /// Weltenweber" ist der staerkste Satz, den ein Todesbildschirm sagen kann.
    ///
    /// Belohnt wird mit neuen Moeglichkeiten (Charms, Deuter), nie mit
    /// pauschaler Kraft. Ein Veteran ist nicht staerker als ein Neuling, er
    /// hat nur mehr Werkzeuge.
    /// </remarks>
    public sealed class ProphecyDefinition
    {
        public string Id;
        public string Title;
        public string Text;
        public int Target;
        /// <summary>Aktueller Stand, wahlweise mit einem laufenden Run (null = nur Meta).</summary>
        public Func<MetaProgress, RunState, int> Value;
        public string[] UnlockCharms = new string[0];
        public string UnlockDeuter = string.Empty;

        public float Progress(MetaProgress meta, RunState run) =>
            Target <= 0 ? 1f : Math.Min(1f, (float)Value(meta, run) / Target);

        public bool IsFulfilled(MetaProgress meta, RunState run) => Value(meta, run) >= Target;

        public string RewardText
        {
            get
            {
                var parts = new List<string>();
                if (!string.IsNullOrEmpty(UnlockDeuter))
                    parts.Add("Deuter: " + DeuterCatalog.Find(UnlockDeuter).Name);
                foreach (var id in UnlockCharms)
                {
                    var charm = GameCatalog.Charms.FirstOrDefault(c => c.Id == id);
                    if (charm != null) parts.Add("Charm: " + charm.Name);
                }
                return string.Join(" · ", parts);
            }
        }
    }

    public static class ProphecyCatalog
    {
        // Wert-Helfer: Lebenszeit-Summe und Bestwert je Run, jeweils mit dem
        // laufenden Run, falls einer mitgegeben wird.
        private static Func<MetaProgress, RunState, int> Sum(string key) =>
            (meta, run) => meta.Lifetime(key) + (run != null ? Stat(run, key) : 0);

        private static Func<MetaProgress, RunState, int> Best(string key) =>
            (meta, run) => Math.Max(meta.Best(key), run != null ? Stat(run, key) : 0);

        private static Func<MetaProgress, RunState, int> Flag(string flag) =>
            (meta, run) => meta.StoryFlags.Contains(flag) || (run != null && run.StoryFlags.Contains(flag)) ? 1 : 0;

        private static int Stat(RunState run, string key) =>
            run.Stats.ToDictionary().TryGetValue(key, out var value) ? value : 0;

        private static ProphecyDefinition P(string id, string title, string text, int target,
            Func<MetaProgress, RunState, int> value, string deuter = "", params string[] charms)
            => new ProphecyDefinition
            {
                Id = id, Title = title, Text = text, Target = target, Value = value,
                UnlockDeuter = deuter, UnlockCharms = charms
            };

        public static readonly List<ProphecyDefinition> All = new List<ProphecyDefinition>
        {
            // Die erste kommt garantiert - der erste Tod soll schon etwas oeffnen.
            P("erste_lesung", "Die erste Lesung", "Beende einen Run.", 1,
                (m, r) => m.RunsStarted, "", "star_dust"),
            P("welt_oeffnet", "Die Welt öffnet sich", "Lege insgesamt 30-mal DIE WELT.", 30,
                Sum("worldSpreads"), "", "world_thread"),
            P("weltenweber", "Weltenweber", "Lege 5-mal DIE WELT in einem einzigen Kampf.", 5,
                Best("mostWorldsInFight"), "", "cat_fang"),
            P("blutige_lesung", "Blutige Lesung", "Spiele insgesamt 40 umgekehrte Karten.", 40,
                Sum("reversedPlayed"), "aderleser", "blood_moon"),
            P("voller_tresor", "Der volle Tresor", "Gewinne einen Kampf mit 40 Schild.", 40,
                Best("mostShield"), "buchhalter", "emperor_seal"),
            P("leeres_blatt", "Das leere Blatt", "Besiege einen Boss mit höchstens 8 Karten im Deck.", 1,
                Best("thinBossKills"), "eremit"),
            P("ueberschuss", "Überschuss", "Triff 300 über das Leben eines Gegners hinaus.", 300,
                Best("bestOverkill"), "", "predator_fang"),
            P("kettenleser", "Kettenleser", "Halte eine Musterkette über 8 Züge.", 8,
                Best("longestChain"), "", "wand_weave"),
            P("teufel_im_detail", "Der Teufel im Detail", "Nimm insgesamt 3 Pakte an.", 3,
                Sum("pactsAccepted"), "", "greed_moth"),
            P("tintenherz", "Tintenherz", "Erreiche in einem Run Verdunkelung 60.", 60,
                Best("peakDarkness"), "", "silver_mirror"),
            P("schwarzer_spiegel", "Schwarzer Spiegel", "Besitze drei schwarze Karten zugleich.", 3,
                Best("mostBlackCards"), "", "twin_coin"),
            P("weg_ist_ziel", "Der Weg ist das Ziel", "Erlebe insgesamt 12 Ereignisse.", 12,
                Sum("eventsSeen"), "", "oracle_eye"),
            P("grosser_schlag", "Der große Schlag", "Lege eine Legung im Wert von 500.", 500,
                Best("bestHit"), "", "black_nail"),
            P("welt_nicht_ende", "Die Welt ist nicht das Ende", "Gewinne einen Run.", 1,
                (m, r) => m.RunsWon + (r != null && r.Won ? 1 : 0), "", "phoenix_feather"),
            P("schleierlaeufer", "Schleierläufer", "Gewinne auf Schleier 3 oder höher.", 3,
                (m, r) => Math.Max(m.HighestVeilWon, r != null && r.Won ? r.Veil : -1), "", "black_cup"),
            P("spiralgaenger", "Spiralgänger", "Erreiche Tiefe 8 in der Schwarzen Spirale.", 8,
                (m, r) => Math.Max(m.BestSpiralDepth, r != null ? ActCatalog.SpiralDepth(r.FightIndex) : 0), "", "broken_crown"),
            P("letztes_blatt", "Das letzte Blatt", "Beende die Geschichte des Kartenspielers.", 1,
                Flag("spieler_3"), "", "gold_die"),
            P("schwarzes_blatt", "Das Schwarze Blatt", "Beende die Geschichte der Tinte.", 1,
                Flag("tinte_3"), "", "empty_frame"),
            P("sammler", "Sammler", "Sieh 40 verschiedene Karten in deinen Decks.", 40,
                (m, r) => m.SeenCards.Count + (r == null ? 0 : r.Deck.Select(c => c.Definition.Id)
                    .Distinct().Count(id => !m.SeenCards.Contains(id))), "", "luck_bell")
        };

        /// <summary>Charms, die erst eine Prophezeiung freigibt.</summary>
        public static readonly HashSet<string> LockedCharmIds =
            new HashSet<string>(All.SelectMany(p => p.UnlockCharms));

        public static ProphecyDefinition Find(string id) => All.FirstOrDefault(p => p.Id == id);
    }

    /// <summary>Ein Ziel, das knapp verfehlt wurde - der Grund fuer den naechsten Run.</summary>
    public sealed class NearMiss
    {
        public string Title = string.Empty;
        public string Detail = string.Empty;
        public string Reward = string.Empty;
        public float Progress;
    }

    /// <summary>
    /// Was am Ende eines Runs gezeigt wird.
    /// </summary>
    /// <remarks>
    /// Die Reihenfolge ist Absicht: erst was du erreicht hast, dann was neu
    /// ist, dann was fast geklappt haette. Der letzte Blick vor dem Knopf
    /// "Noch einmal" faellt auf das Beinahe.
    /// </remarks>
    public sealed class RunReport
    {
        public bool Won;
        public string Headline = string.Empty;
        public int FightsCleared;
        public int Act;
        public int SpiralDepth;
        public int FateTotal;
        public int BestHit;
        public string BestHitCombo = string.Empty;
        public string KilledBy = string.Empty;
        public int Darkness;
        public readonly List<string> Records = new List<string>();
        public readonly List<string> Unlocked = new List<string>();
        public readonly List<NearMiss> NearMisses = new List<NearMiss>();
    }
}
