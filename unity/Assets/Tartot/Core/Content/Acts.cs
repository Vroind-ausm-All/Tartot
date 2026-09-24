using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>
    /// Der Bogen eines Runs: drei Akte, je vier Kaempfe und ein Boss, dann das
    /// Finale. Danach beginnt die Schwarze Spirale.
    /// </summary>
    /// <remarks>
    /// Vorher gab es acht Gegner in fester Reihenfolge, und 96 % der Runs
    /// schlugen sie alle - die Schwierigkeit lag vollstaendig in der
    /// Endlos-Skalierung. Ein Run braucht aber einen Spannungsbogen: frueh
    /// lernen, in der Mitte zweifeln, am Ende knapp scheitern oder knapp
    /// siegen. Deshalb Akte mit eigenen Gegnerpools, angekuendigte Bosse, die
    /// eine Regel brechen, und ein Finale, das sich aus den Bossen des Runs
    /// zusammensetzt.
    ///
    /// Kampfindex:  0-3 Akt I, 4 Boss I · 5-8 Akt II, 9 Boss II ·
    ///              10-13 Akt III, 14 Boss III · 15 Finale · ab 16 Spirale
    /// </remarks>
    public static class ActCatalog
    {
        public const int ActCount = 3;
        public const int FightsBeforeBoss = 4;
        public const int FightsPerAct = FightsBeforeBoss + 1;
        public const int FinaleIndex = ActCount * FightsPerAct;

        /// <summary>Jeder wievielte Spiralkampf ein Boss ist.</summary>
        public const int SpiralBossInterval = 4;

        public static readonly string[] ActNames =
        {
            string.Empty,
            "Der Jahrmarkt der Omen",
            "Das Haus der Spiegel",
            "Die Schwarze Messe",
            "Das Ende der Welt",
            "Die Schwarze Spirale"
        };

        /// <summary>1-3 fuer die Akte, 4 fuer das Finale, 5 fuer die Spirale.</summary>
        public static int ActOf(int fightIndex)
        {
            if (fightIndex > FinaleIndex) return 5;
            if (fightIndex == FinaleIndex) return 4;
            return Math.Max(0, fightIndex) / FightsPerAct + 1;
        }

        public static bool IsBossFight(int fightIndex) =>
            fightIndex >= 0 && fightIndex < FinaleIndex && fightIndex % FightsPerAct == FightsBeforeBoss;

        public static bool IsFinale(int fightIndex) => fightIndex == FinaleIndex;
        public static bool IsSpiral(int fightIndex) => fightIndex > FinaleIndex;
        public static int SpiralDepth(int fightIndex) => Math.Max(0, fightIndex - FinaleIndex);

        public static bool IsSpiralBoss(int fightIndex) =>
            IsSpiral(fightIndex) && SpiralDepth(fightIndex) % SpiralBossInterval == 0;

        /// <summary>Wie viele Kaempfe bis zum naechsten Boss (0 = der naechste ist einer).</summary>
        public static int FightsUntilBoss(int nextFightIndex)
        {
            if (nextFightIndex >= FinaleIndex) return 0;
            return FightsBeforeBoss - nextFightIndex % FightsPerAct;
        }

        public static readonly List<EnemyDefinition> Normals = BuildNormals();
        public static readonly List<EnemyDefinition> Elites = BuildElites();
        public static readonly List<EnemyDefinition> Bosses = BuildBosses();
        public static readonly EnemyDefinition Finale = BuildFinale();
        public static readonly EnemyDefinition SpiralBoss = BuildSpiralBoss();
        /// <summary>Gegner, die nur ein Ereignis herbeiruft.</summary>
        public static readonly List<EnemyDefinition> Specials = BuildSpecials();

        public static IEnumerable<EnemyDefinition> All =>
            Normals.Concat(Elites).Concat(Bosses).Concat(new[] { Finale, SpiralBoss }).Concat(Specials);

        public static EnemyDefinition Find(string id) =>
            string.IsNullOrEmpty(id) ? null : All.FirstOrDefault(e => e.Id == id);

        public static List<EnemyDefinition> NormalsOf(int act) => Normals.Where(e => e.Act == act).ToList();
        public static List<EnemyDefinition> ElitesOf(int act) => Elites.Where(e => e.Act == act).ToList();
        public static List<EnemyDefinition> BossesOf(int act) => Bosses.Where(e => e.Act == act).ToList();

        // ------------------------------------------------------ Regeltexte
        /// <summary>Kurzbeschreibung einer Bossregel fuer die aktuelle Phase.</summary>
        public static string RuleText(BossRule rule, int phase, bool weakened)
        {
            switch (rule)
            {
                case BossRule.Tower:
                    return weakened ? "Der Turm: alle 4 Runden stürzt eine Position ein."
                        : phase >= 1 ? "Der Turm: jede 2. Runde stürzt eine Position ein."
                        : "Der Turm: jede 3. Runde stürzt eine Position ein.";
                case BossRule.Moon:
                    return weakened ? "Der Mond: jede 3. Runde verbirgt er Absicht und eine Handkarte."
                        : phase >= 1 ? "Der Mond: Absicht immer verborgen, zwei Handkarten verdeckt."
                        : "Der Mond: jede 2. Runde verbirgt er Absicht und eine Handkarte.";
                case BossRule.Death:
                    return weakened ? "Der Tod zeichnet eine Karte. Nach 4 Runden gehört sie ihm."
                        : phase >= 1 ? "Der Tod zeichnet eine Karte. Nach 2 Runden gehört sie ihm."
                        : "Der Tod zeichnet eine Karte. Nach 3 Runden gehört sie ihm. Leg sie in die Zukunft, um sie zu retten.";
                case BossRule.Wheel:
                    return weakened ? "Das Rad: jede 2. Runde rücken deine Positionen weiter."
                        : phase >= 1 ? "Das Rad: deine Positionen drehen sich rückwärts."
                        : "Das Rad: deine Positionen rücken jede Runde eins weiter.";
                case BossRule.Devil:
                    return weakened ? "Der Teufel bietet einmal einen Pakt an."
                        : "Der Teufel verhandelt: mehr Schaden gegen deine Lebenskraft.";
                case BossRule.HangedMan:
                    return weakened ? "Der Gehängte: jede 2. Runde ist die Legung gespiegelt."
                        : phase >= 1 ? "Der Gehängte: Legung gespiegelt, eine Handkarte weniger."
                        : "Der Gehängte: Vergangenheit und Zukunft tauschen die Rollen.";
                default:
                    return string.Empty;
            }
        }

        // ------------------------------------------------------ Gegner
        // Absichten: A = Angriff, G = Schild, H = Fluch, D = Aussaugen, F = Raserei
        private static IntentType[] P(string code) => code.Select(c =>
        {
            switch (c)
            {
                case 'G': return IntentType.Guard;
                case 'H': return IntentType.Hex;
                case 'D': return IntentType.Drain;
                case 'F': return IntentType.Frenzy;
                default: return IntentType.Attack;
            }
        }).ToArray();

        private static EnemyDefinition E(string id, string name, EnemyTier tier, int act, int hp, int stance,
            int attack, int sigils, string pattern, string flavor, string art = null)
            => new EnemyDefinition
            {
                Id = id, Name = name, Tier = tier, Act = act, MaxHp = hp, MaxStance = stance,
                BaseAttack = attack, Sigils = sigils, Pattern = P(pattern), Flavor = flavor, Art = art ?? id
            };

        private static List<EnemyDefinition> BuildNormals() => new List<EnemyDefinition>
        {
            // Akt I - Der Jahrmarkt der Omen. Jeder Gegner lehrt eine Absicht.
            E("lachender_henker", "Der lachende Henker", EnemyTier.Normal, 1, 148, 29, 19, 0, "AAF",
                "Ein viel zu langer Hals, ein viel zu breites Grinsen. Der Strick hängt lose."),
            E("zahnmuenze", "Die Münze mit Zähnen", EnemyTier.Normal, 1, 133, 34, 17, 0, "GAA",
                "Sie rollt. Sie klappert. Wenn sie sich öffnet, sieht man das Gebiss."),
            E("kelchtrinker", "Der Kelchtrinker", EnemyTier.Normal, 1, 160, 24, 17, 0, "ADA",
                "Er trinkt aus einem Kelch, in dem ein Auge schwimmt. Das Auge sieht dich."),
            E("schreiende_klinge", "Die schreiende Klinge", EnemyTier.Normal, 1, 110, 19, 25, 0, "AH",
                "Ein Schwert mit einem Mund in der Schneide. Es schreit den eigenen Namen."),
            E("zwillingsschatten", "Die Zwillingsschatten", EnemyTier.Normal, 1, 125, 29, 17, 0, "FGA",
                "Zwei Schatten einer Figur, die es nicht gibt. Sie tun nicht dasselbe."),
            E("kleiner_mond", "Der kleine grinsende Mond", EnemyTier.Normal, 1, 144, 29, 19, 0, "HAA",
                "Er hängt zu niedrig und grinst zu breit. Manchmal blinzelt er nicht."),

            // Akt II - Das Haus der Spiegel
            E("hutmann", "Der Hutmann", EnemyTier.Normal, 2, 289, 44, 19, 0, "GAAH",
                "Unter dem Hut ist noch ein Hut. Und darunter wieder einer."),
            E("augensammlerin", "Die Augensammlerin", EnemyTier.Normal, 2, 255, 40, 20, 0, "HAF",
                "Sie trägt die Augen anderer an einer Schnur. Keines davon ist ihres."),
            E("blutorgel", "Die Blutorgel", EnemyTier.Normal, 2, 323, 48, 17, 0, "DADG",
                "Jede Pfeife ein Finger. Sie spielt sich selbst und trifft nie denselben Ton."),
            E("wachsbote", "Der Wachsbote", EnemyTier.Normal, 2, 238, 35, 23, 0, "AAG",
                "Er bringt eine Nachricht, die schmilzt, bevor man sie lesen kann."),
            E("mondfresser", "Der Mondfresser", EnemyTier.Normal, 2, 306, 44, 19, 0, "AHF",
                "Unter halben HP wird er aggressiver und verbirgt, was er vorhat."),
            E("nadelwitwe", "Die Nadelwitwe", EnemyTier.Normal, 2, 280, 53, 19, 0, "GAGA",
                "Sie näht zwischen den Stichen. Was sie näht, trägt dein Gesicht."),

            // Akt III - Die Schwarze Messe
            E("uhrenwurm", "Der Uhrenwurm", EnemyTier.Normal, 3, 420, 68, 20, 0, "AGAH",
                "Er frisst Minuten. In seinem Bauch schlägt es immer eins."),
            E("sieben_finger", "Die Sieben Finger", EnemyTier.Normal, 3, 378, 60, 22, 0, "FAA",
                "Sieben Finger ohne Hand. Sie zählen mit, wie oft du getroffen hast."),
            E("laecheln_ohne_gesicht", "Das Lächeln ohne Gesicht", EnemyTier.Normal, 3, 448, 68, 19, 0, "DAHA",
                "Nur ein Mund, frei schwebend. Er wird breiter, je länger der Kampf dauert."),
            E("gerichtsdiener", "Der lächelnde Gerichtsdiener", EnemyTier.Normal, 3, 406, 64, 21, 0, "AAG",
                "Er stellt dir deine eigene Vorladung zu. Er hat sie selbst geschrieben.")
        };

        private static List<EnemyDefinition> BuildElites()
        {
            var list = new List<EnemyDefinition>
            {
                E("papierpriester", "Der Papierpriester", EnemyTier.Elite, 1, 228, 40, 20, 1, "GAHA",
                    "Sein Gewand ist aus Verträgen. Er liest laut, aber niemand hört Worte."),
                E("fette_ratte", "Die fette Ratte des Händlers", EnemyTier.Elite, 1, 262, 35, 18, 0, "ADG",
                    "Sie hat Münzen gefressen. Man hört sie klimpern, wenn sie atmet."),
                E("spiegelschwester", "Die Spiegelschwester", EnemyTier.Elite, 2, 448, 56, 22, 1, "AFGH",
                    "Sie ahmt dich nach, aber immer eine Sekunde zu spät - und etwas zu genau."),
                E("muenzmaul", "Das Münzmaul", EnemyTier.Elite, 2, 480, 60, 21, 0, "GAD",
                    "Es bestraft lange Kämpfe und spuckt am Ende alles aus, was es gefressen hat."),
                E("henker_verkehrt", "Der Henker (umgekehrt)", EnemyTier.Elite, 3, 598, 72, 24, 1, "FAGA",
                    "Derselbe Hals, dasselbe Grinsen - aber der Strick hält jetzt ihn."),
                E("rote_sonne", "Die rote Sonne", EnemyTier.Elite, 3, 624, 72, 23, 1, "ADFH",
                    "Sie geht nicht unter. Sie wartet nur, bis du müde wirst.")
            };
            // Die Ratte und das Maul tragen, was sie gefressen haben.
            list.First(e => e.Id == "fette_ratte").GoldFactor = 2.5f;
            list.First(e => e.Id == "muenzmaul").GoldFactor = 2.5f;
            return list;
        }

        private static EnemyDefinition Boss(string id, string name, int act, int hp, int stance, int attack,
            int sigils, string pattern, BossRule rule, int omen, string flavor)
        {
            var boss = E(id, name, EnemyTier.Boss, act, hp, stance, attack, sigils, pattern, flavor);
            boss.Rules.Add(rule);
            boss.OmenCardId = $"major_{omen}";
            return boss;
        }

        private static List<EnemyDefinition> BuildBosses() => new List<EnemyDefinition>
        {
            Boss("boss_turm", "XVI · Der Turm", 1, 323, 44, 20, 1, "AAGF", BossRule.Tower, 16,
                "Er wächst hinter dir hoch. Jeder Blitz nimmt dir eine Möglichkeit."),
            Boss("boss_mond", "XVIII · Der Mond", 1, 360, 44, 21, 1, "HADA", BossRule.Moon, 18,
                "Du siehst sein Grinsen. Sonst siehst du nichts - nicht einmal deine eigenen Karten."),
            Boss("boss_tod", "XIII · Der Tod", 2, 510, 64, 22, 1, "AHAD", BossRule.Death, 13,
                "Ein weißes Gesicht, ein roter Schnitt. Er nimmt nicht dich - er nimmt deine Karten."),
            Boss("boss_rad", "X · Rad des Schicksals", 2, 495, 60, 22, 1, "AFGA", BossRule.Wheel, 10,
                "Es dreht. Deine Positionen bleiben nicht, wo du sie gelegt hast."),
            Boss("boss_teufel", "XV · Der Teufel", 3, 640, 72, 20, 1, "ADAF", BossRule.Devil, 15,
                "Er kämpft nicht gern. Er verhandelt. Und er gewinnt fast immer."),
            Boss("boss_gehaengter", "XII · Der Gehängte", 3, 650, 79, 22, 1, "GAAH", BossRule.HangedMan, 12,
                "Er hängt verkehrt. Von seiner Seite aus liegt deine Zukunft links.")
        };

        private static EnemyDefinition BuildFinale()
        {
            var finale = E("boss_welt", "XXI · Die Welt", EnemyTier.Finale, 4, 504, 65, 24, 2, "AHFGD",
                "Alles, was du besiegt hast, ist noch da. Es sieht nur jetzt zusammen aus.");
            finale.OmenCardId = "major_21";
            // Die Regeln setzt der Run ein: die der Bosse, die du geschlagen hast.
            finale.RulesWeakened = true;
            return finale;
        }

        private static List<EnemyDefinition> BuildSpecials() => new List<EnemyDefinition>
        {
            E("kartenspieler", "Der Kartenspieler", EnemyTier.Elite, 3, 546, 68, 22, 1, "AHGF",
                "Er spielt deine Karten. Besser als du.")
        };

        private static EnemyDefinition BuildSpiralBoss()
        {
            var worm = E("weltenwurm", "Der Weltenwurm", EnemyTier.Boss, 5, 620, 46, 24, 2, "AFDHA",
                "Die Welt ist nicht das Ende. Er frisst sie von hinten und wächst mit jeder Schleife.");
            worm.OmenCardId = "major_21";
            return worm;
        }
    }
}
