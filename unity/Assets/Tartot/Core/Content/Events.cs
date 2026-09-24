using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    /// <summary>Eine Wahl in einem Ereignis.</summary>
    public sealed class EventChoice
    {
        public string Label = string.Empty;
        /// <summary>
        /// Was die Wahl kostet und bringt - mit Wahrscheinlichkeiten. Ein
        /// Gluecksspiel, dessen Chancen man kennt, fuehlt sich nach eigener
        /// Entscheidung an; eines mit versteckten Chancen nach Betrug.
        /// </summary>
        public string Hint = string.Empty;
        public Func<RunState, bool> Available = _ => true;
        /// <summary>Fuehrt die Wahl aus und gibt den Schlusssatz der Szene zurueck.</summary>
        public Func<EventContext, string> Resolve = _ => string.Empty;
    }

    public sealed class EventContext
    {
        public RunState Run;
        public DeterministicRandom Rng;
    }

    /// <summary>
    /// Ein Ereignis auf dem Weg: eine kurze Zwischensequenz aus wenigen
    /// Saetzen ("Beats"), dann eine Entscheidung, dann ein Schlusssatz.
    /// </summary>
    /// <remarks>
    /// Die Beats werden in der Oberflaeche einzeln eingeblendet - die Szene
    /// soll sich wie ein Moment anfuehlen, nicht wie ein Menue. Manche
    /// Ereignisse erzaehlen ueber mehrere Runs weiter (Story-Flags), eines
    /// zeigt das Grab des letzten Runs.
    /// </remarks>
    public sealed class EventDefinition
    {
        public string Id = string.Empty;
        public string Title = string.Empty;
        public string Art = string.Empty;
        public int MinAct = 1;
        public int MaxAct = 4;
        public int MinDarkness;
        public string RequiresFlag = string.Empty;
        public string ExcludesFlag = string.Empty;
        public Func<RunState, bool> Condition = _ => true;
        public float Weight = 1f;
        public string[] Beats = new string[0];
        /// <summary>Variante ab Verdunkelung 40 - die Welt sieht dich anders an.</summary>
        public string[] DarkBeats = new string[0];
        /// <summary>Fuer Szenen, die sich aus dem Run speisen (das Grab).</summary>
        public Func<RunState, string[]> DynamicBeats;
        public List<EventChoice> Choices = new List<EventChoice>();

        /// <summary>Ob die Szene Teil einer Geschichte ueber mehrere Runs ist.</summary>
        public bool IsStory => !string.IsNullOrEmpty(RequiresFlag) || !string.IsNullOrEmpty(ExcludesFlag);

        public string[] BeatsFor(RunState run)
        {
            if (DynamicBeats != null) return DynamicBeats(run);
            return run.Darkness >= 40 && DarkBeats.Length > 0 ? DarkBeats : Beats;
        }

        public bool IsEligible(RunState run)
        {
            var act = Math.Min(4, run.Act);
            if (act < MinAct || act > MaxAct) return false;
            if (run.Darkness < MinDarkness) return false;
            if (!string.IsNullOrEmpty(RequiresFlag) && !run.StoryFlags.Contains(RequiresFlag)) return false;
            if (!string.IsNullOrEmpty(ExcludesFlag) && run.StoryFlags.Contains(ExcludesFlag)) return false;
            if (run.SeenEvents.Contains(Id)) return false;
            return Condition(run);
        }
    }

    public static class EventCatalog
    {
        // --------------------------------------------------------- Helfer
        private static float Strength(CardInstance card) =>
            (int)card.Shimmer * 6 + card.Level * 3 + card.Definition.Rank + (card.Definition.IsMajor ? 6 : 0);

        public static CardInstance Strongest(RunState run) =>
            run.Deck.OrderByDescending(Strength).FirstOrDefault();

        public static CardInstance Weakest(RunState run) =>
            run.Deck.OrderBy(Strength).FirstOrDefault();

        private static bool CanThin(RunState run, int count) =>
            run.Deck.Count - count >= GameCatalog.MinimumDeckSize;

        private static void Remove(RunState run, CardInstance card)
        {
            if (card == null || !run.Deck.Remove(card)) return;
            run.RemovedCards.Add(card);
        }

        private static CardInstance Add(RunState run, CardDefinition definition, int level = 1,
            Shimmer shimmer = Shimmer.Matte, Orientation orientation = Orientation.Upright, bool copy = false)
        {
            var card = new CardInstance(definition, copy)
            {
                Level = Math.Max(1, level),
                Shimmer = shimmer,
                Orientation = orientation
            };
            run.Deck.Add(card);
            NoteShimmer(run, card);
            return card;
        }

        /// <summary>Eine Stufe dunkler - auch ueber Gold hinaus, bis Schwarz.</summary>
        public static void Darken(RunState run, CardInstance card)
        {
            if (card == null) return;
            if (card.Shimmer < Shimmer.Black) card.Shimmer = (Shimmer)((int)card.Shimmer + 1);
            NoteShimmer(run, card);
        }

        public static void NoteShimmer(RunState run, CardInstance card)
        {
            if (card != null)
                run.Stats.DarkestShimmer = Math.Max(run.Stats.DarkestShimmer, (int)card.Shimmer);
            run.Stats.MostBlackCards = Math.Max(run.Stats.MostBlackCards,
                run.Deck.Count(c => c.Shimmer == Shimmer.Black));
        }

        private static void Hurt(RunState run, int amount) => run.Hp = Math.Max(1, run.Hp - amount);

        private static int Heal(RunState run, int amount)
        {
            var before = run.Hp;
            run.Hp = Math.Min(run.MaxHp, run.Hp + Math.Max(0, amount));
            return run.Hp - before;
        }

        private static CharmDefinition RandomCharm(EventContext ctx)
        {
            var options = GameCatalog.Charms
                .Where(c => ctx.Run.CharmAllowed(c.Id) && ctx.Run.CharmStacks(c.Id) < c.MaxStacks)
                .ToList();
            return options.Count == 0 ? null : ctx.Rng.Pick(options);
        }

        private static string GiveRandomCharm(EventContext ctx, string fallback)
        {
            var charm = RandomCharm(ctx);
            if (charm == null)
            {
                ctx.Run.Fate += 40;
                return fallback + " (+40 Fate)";
            }
            ctx.Run.AddCharm(charm);
            return $"Du erhältst {charm.Name}.";
        }

        private static string GiveRandomItem(EventContext ctx)
        {
            var item = ctx.Rng.Pick(GameCatalog.Items);
            ctx.Run.AddItem(item);
            return $"Du erhältst {item.Name}.";
        }

        private static CardDefinition RandomMajor(EventContext ctx) =>
            ctx.Rng.Pick(GameCatalog.Cards.Where(c => c.IsMajor).ToList());

        private static EventChoice Leave(string epilogue) => new EventChoice
        {
            Label = "Weitergehen",
            Hint = "Nichts geschieht.",
            Resolve = _ => epilogue
        };

        private static EventChoice Choice(string label, string hint, Func<EventContext, string> resolve,
            Func<RunState, bool> available = null) => new EventChoice
        {
            Label = label,
            Hint = hint,
            Resolve = resolve,
            Available = available ?? (_ => true)
        };

        // ------------------------------------------------------ Katalog
        public static readonly List<EventDefinition> All = Build();

        public static EventDefinition Find(string id) => All.FirstOrDefault(e => e.Id == id);

        private static List<EventDefinition> Build()
        {
            var list = new List<EventDefinition>();

            // ============ Geschichte I: Der Kartenspieler (ueber Runs) ============
            list.Add(new EventDefinition
            {
                Id = "kartenspieler_1", Title = "Der Kartenspieler am Kreuzweg", Art = "kartenspieler",
                MaxAct = 2, ExcludesFlag = "spieler_1", Weight = 2f,
                Beats = new[]
                {
                    "Mitten auf dem Weg steht ein Tisch. Ein Stuhl fehlt – deiner.",
                    "Der Mann dahinter mischt ein Deck, das deinem sehr ähnlich sieht.",
                    "„Eine Karte“, sagt er. „Die höhere gewinnt.“"
                },
                Choices =
                {
                    Choice("Setze 30 Gold", "Hälfte-Hälfte: +50 Gold oder −30 Gold.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_1");
                        if (ctx.Rng.Chance(.5f)) { ctx.Run.Gold += 50; return "Er zahlt, ohne hinzusehen. „Glück ist auch eine Fähigkeit.“"; }
                        ctx.Run.Gold -= 30;
                        return "Er lächelt, als hätte er es vorher gewusst.";
                    }, run => run.Gold >= 30),
                    Choice("Setze deine schwächste Karte", "Hälfte-Hälfte: ein Großes Arkanum – oder die Karte ist fort.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_1");
                        if (ctx.Rng.Chance(.5f))
                        {
                            var major = RandomMajor(ctx);
                            Add(ctx.Run, major);
                            return $"Er schiebt dir {major.Name} über den Tisch. Die Karte ist noch warm.";
                        }
                        var lost = Weakest(ctx.Run);
                        Remove(ctx.Run, lost);
                        return $"{lost?.Definition.Name} verschwindet in seinem Deck. Es sah aus, als gehöre sie dorthin.";
                    }, run => CanThin(run, 1)),
                    Choice("Geh vorbei", "Nichts geschieht. Vorerst.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_1");
                        return "Er ruft dir nach: „Wir sehen uns wieder. Das tun wir immer.“";
                    })
                }
            });

            list.Add(new EventDefinition
            {
                Id = "kartenspieler_2", Title = "Der Kartenspieler erinnert sich", Art = "kartenspieler",
                MinAct = 2, MaxAct = 3, RequiresFlag = "spieler_1", ExcludesFlag = "spieler_2", Weight = 3f,
                Beats = new[]
                {
                    "Derselbe Tisch. Diesmal steht ein zweiter Stuhl da.",
                    "„Du hast letztes Mal gezögert“, sagt er. Er hat recht, und das beunruhigt dich.",
                    "Er legt drei Karten verdeckt hin. Eine davon trägt dein Gesicht."
                },
                Choices =
                {
                    Choice("Zieh die mittlere", "Ein Drittel: deine stärkste Karte steigt 2 Stufen. Sonst −12 HP.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_2");
                        if (ctx.Rng.Chance(1f / 3f))
                        {
                            var best = Strongest(ctx.Run);
                            if (best != null) best.Level += 2;
                            return $"Dein Gesicht. {best?.Definition.Name} fühlt sich schwerer an.";
                        }
                        Hurt(ctx.Run, 12);
                        return "Eine leere Karte. Sie schneidet dir in den Finger, als du sie zurücklegst.";
                    }),
                    Choice("Zieh alle drei", "Sicher: +1 Luck für den Run, +8 Verdunkelung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_2");
                        ctx.Run.Luck++;
                        ctx.Run.AddDarkness(8);
                        return "„Gier ist auch eine Antwort“, sagt er und schreibt etwas auf.";
                    }),
                    Choice("Steh auf und geh", "+25 Fate.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_2");
                        ctx.Run.Fate += 25;
                        return "Er nickt, als hättest du richtig gewählt.";
                    })
                }
            });

            list.Add(new EventDefinition
            {
                Id = "kartenspieler_3", Title = "Der Kartenspieler zeigt sein Blatt", Art = "kartenspieler",
                MinAct = 3, MaxAct = 3, RequiresFlag = "spieler_2", ExcludesFlag = "spieler_3", Weight = 4f,
                Beats = new[]
                {
                    "Der Tisch steht jetzt in einem leeren Saal. Der Mann trägt deinen Mantel.",
                    "Er dreht seine Karten um. Es sind deine – mit jedem Schimmer, den du ihnen gegeben hast.",
                    "„Ich bin, was bleibt, wenn du aufhörst zu spielen.“"
                },
                Choices =
                {
                    Choice("Fordere ihn heraus", "Der nächste Kampf gilt ihm. Sieg: eine Charm-Belohnung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_3");
                        ctx.Run.PendingEnemyId = "kartenspieler";
                        ctx.Run.NextFightElite = true;
                        return "Er mischt. Zum ersten Mal sieht er dir in die Augen.";
                    }, run => !ActCatalog.IsBossFight(run.FightIndex + 1) && !ActCatalog.IsFinale(run.FightIndex + 1)),
                    Choice("Lass ihn gewinnen", "Radmarke und 60 Fate.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("spieler_3");
                        ctx.Run.AddItem(GameCatalog.Item("wheel_token"));
                        ctx.Run.Fate += 60;
                        return "Er steckt das Deck ein. „Bis zum nächsten Mal. Es gibt immer ein nächstes Mal.“";
                    })
                }
            });

            // ============ Geschichte II: Die Tinte (ueber Runs) ============
            list.Add(new EventDefinition
            {
                Id = "tinte_1", Title = "Das Tintenfass", Art = "tintenfass",
                MinDarkness = 20, ExcludesFlag = "tinte_1", Weight = 2f,
                Beats = new[]
                {
                    "Ein Tintenfass am Wegrand, randvoll, obwohl es regnet.",
                    "Etwas darin atmet. Die Oberfläche hebt und senkt sich."
                },
                Choices =
                {
                    Choice("Tauche deine stärkste Karte ein", "Sie springt auf Blutschimmer. +8 Verdunkelung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("tinte_1");
                        var best = Strongest(ctx.Run);
                        if (best != null && best.Shimmer < Shimmer.Blood) best.Shimmer = Shimmer.Blood;
                        NoteShimmer(ctx.Run, best);
                        ctx.Run.AddDarkness(8);
                        return $"{best?.Definition.Name} kommt rot heraus. Die Tinte im Fass ist ein wenig weniger geworden.";
                    }),
                    Choice("Verschließe es", "+40 Fate.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("tinte_1");
                        ctx.Run.Fate += 40;
                        return "Der Deckel klemmt. Von innen klopft es, zweimal.";
                    })
                }
            });

            list.Add(new EventDefinition
            {
                Id = "tinte_2", Title = "Die Schreiber", Art = "schreiber",
                MinAct = 2, MinDarkness = 30, RequiresFlag = "tinte_1", ExcludesFlag = "tinte_2", Weight = 3f,
                Beats = new[]
                {
                    "In einem Saal ohne Fenster sitzen Schreiber und kopieren dein Deck.",
                    "Jede Karte, die sie abschreiben, verblasst ein wenig in deiner Hand.",
                    "Die Abschriften sind schwärzer als die Originale."
                },
                Choices =
                {
                    Choice("Lass sie schreiben", "Zwei zufällige Karten werden kopiert – mit Blutschimmer. +10 Verdunkelung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("tinte_2");
                        var picks = ctx.Rng.PickDistinct(ctx.Run.Deck, 2);
                        foreach (var card in picks)
                            Add(ctx.Run, card.Definition, card.Level, Shimmer.Blood, card.Orientation, copy: true);
                        ctx.Run.AddDarkness(10);
                        return "Sie reichen dir die Abschriften, ohne aufzusehen. Die Tinte ist noch nass.";
                    }, run => run.Deck.Count >= 2),
                    Choice("Verbrenne die Abschriften", "Glutknoten, −5 Verdunkelung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("tinte_2");
                        var ember = GameCatalog.Charm("ember_knot");
                        if (ctx.Run.CharmStacks(ember.Id) < ember.MaxStacks) ctx.Run.AddCharm(ember);
                        ctx.Run.AddDarkness(-5);
                        return "Das Papier brennt grün. Die Schreiber schreiben einfach weiter, jetzt auf den Tischen.";
                    })
                }
            });

            list.Add(new EventDefinition
            {
                Id = "tinte_3", Title = "Das Schwarze Blatt", Art = "schwarzes_blatt",
                MinAct = 3, MinDarkness = 40, RequiresFlag = "tinte_2", ExcludesFlag = "tinte_3", Weight = 4f,
                Beats = new[]
                {
                    "Am Ende des Saals liegt ein einzelnes Blatt, schwärzer als die Nacht hinter dir.",
                    "Es kennt deinen Namen. Es hat ihn schon unterschrieben.",
                    "Nur eine Zeile ist noch frei."
                },
                Choices =
                {
                    Choice("Unterschreibe", "Deine stärkste Karte wird schwarz. +15 Verdunkelung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("tinte_3");
                        var best = Strongest(ctx.Run);
                        if (best != null) best.Shimmer = Shimmer.Black;
                        NoteShimmer(ctx.Run, best);
                        ctx.Run.AddDarkness(15);
                        return $"Die Tinte kriecht in {best?.Definition.Name}. Du hörst sie denken.";
                    }),
                    Choice("Zerreiße es", "Heile vollständig, −10 Verdunkelung.", ctx =>
                    {
                        ctx.Run.SetStoryFlag("tinte_3");
                        ctx.Run.Hp = ctx.Run.MaxHp;
                        ctx.Run.AddDarkness(-10);
                        return "Es reißt wie Haut. Danach ist es sehr still, und du bist sehr wach.";
                    })
                }
            });

            // ============ Das Grab: der letzte Run liegt hier ============
            list.Add(new EventDefinition
            {
                Id = "grab", Title = "Das Grab mit deinem Namen", Art = "grab", Weight = 2f,
                Condition = run => !string.IsNullOrEmpty(run.GraveCardId)
                                   && GameCatalog.Cards.Any(c => c.Id == run.GraveCardId),
                DynamicBeats = run => new[]
                {
                    $"Ein frisches Grab. Der Stein trägt deinen Namen und die Zahl {run.GraveFight}.",
                    "Darunter liegt ein Deck. Es riecht nach deinem letzten Run.",
                    $"Obenauf: {GameCatalog.Card(run.GraveCardId).Name}."
                },
                Choices =
                {
                    Choice("Grab es aus", "Die Karte kehrt zurück – Stufe 3, Indigo. +6 Verdunkelung.", ctx =>
                    {
                        var definition = GameCatalog.Card(ctx.Run.GraveCardId);
                        Add(ctx.Run, definition, 3, Shimmer.Indigo);
                        ctx.Run.GraveCardId = string.Empty;
                        ctx.Run.AddDarkness(6);
                        return $"{definition.Name} ist kalt, aber sie erinnert sich an dich.";
                    }),
                    Choice("Leg Blumen nieder", "Heile 15 HP, −6 Verdunkelung.", ctx =>
                    {
                        Heal(ctx.Run, 15);
                        ctx.Run.AddDarkness(-6);
                        ctx.Run.GraveCardId = string.Empty;
                        return "Die Blumen welken sofort. Trotzdem fühlst du dich leichter.";
                    })
                }
            });

            // ============ Einzelne Szenen ============
            list.Add(new EventDefinition
            {
                Id = "naeherin", Title = "Die Näherin", Art = "naeherin",
                Beats = new[]
                {
                    "Eine Frau sitzt auf einem Stapel Karten und näht sie aneinander.",
                    "Ihre Finger sind aus Faden. Sie sieht nicht auf."
                },
                DarkBeats = new[]
                {
                    "Eine Frau näht Karten aneinander. Diesmal näht sie mit deinem Haar.",
                    "„Du bist dunkler geworden“, sagt sie, ohne aufzusehen. „Das hält besser.“"
                },
                Choices =
                {
                    Choice("Lass zwei Karten vernähen", "Deine zwei schwächsten Karten verschwinden, die stärkste steigt eine Stufe.", ctx =>
                    {
                        Remove(ctx.Run, Weakest(ctx.Run));
                        Remove(ctx.Run, Weakest(ctx.Run));
                        var best = Strongest(ctx.Run);
                        if (best != null) best.Level++;
                        return $"Die Naht hält. {best?.Definition.Name} trägt jetzt zwei fremde Ränder.";
                    }, run => CanThin(run, 2)),
                    Choice("Bitte um einen Faden", "Weißer Faden (+3 Schild zu Kampfbeginn).", ctx =>
                    {
                        var thread = GameCatalog.Charm("white_thread");
                        if (ctx.Run.CharmStacks(thread.Id) >= thread.MaxStacks) { ctx.Run.Fate += 30; return "Sie hat keinen mehr für dich. (+30 Fate)"; }
                        ctx.Run.AddCharm(thread);
                        return "Sie beißt ihn ab und legt ihn dir in die Hand. Er ist warm.";
                    }),
                    Leave("Die Nadel hält kurz inne, als du gehst.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "spiegelkabinett", Title = "Das Spiegelkabinett", Art = "spiegel",
                Beats = new[]
                {
                    "Hundert Spiegel. In neunundneunzig bewegst du dich mit.",
                    "In einem stehst du still und lächelst."
                },
                Choices =
                {
                    Choice("Tritt in den stillen Spiegel", "Eine zufällige Karte deines Decks wird kopiert. +4 Verdunkelung.", ctx =>
                    {
                        var card = ctx.Rng.Pick(ctx.Run.Deck);
                        Add(ctx.Run, card.Definition, card.Level, card.Shimmer, card.Orientation, copy: true);
                        ctx.Run.AddDarkness(4);
                        return $"Du kommst mit zwei {card.Definition.Name} heraus. Eine davon ist spiegelverkehrt signiert.";
                    }, run => run.Deck.Count > 0),
                    Choice("Zerschlag ihn", "+45 Gold, −8 HP.", ctx =>
                    {
                        ctx.Run.Gold += 45;
                        Hurt(ctx.Run, 8);
                        return "Hinter dem Glas liegen Münzen. Und ein Zahn.";
                    }),
                    Leave("Hinter dir drehen sich neunundneunzig Spiegelbilder um.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "leichenschmaus", Title = "Der Leichenschmaus", Art = "tafel",
                Beats = new[]
                {
                    "Eine lange Tafel im Nebel. Die Gäste sind satt, aber sie essen weiter.",
                    "Ein Platz ist gedeckt. Die Serviette trägt deine Initialen."
                },
                Choices =
                {
                    Choice("Iss mit", "Heile 40 % – eine zufällige aufrechte Karte kippt um.", ctx =>
                    {
                        var healed = Heal(ctx.Run, (int)Math.Round(ctx.Run.MaxHp * .40f));
                        var upright = ctx.Run.Deck.Where(c => c.Orientation == Orientation.Upright).ToList();
                        if (upright.Count == 0) return $"+{healed} HP. Es schmeckt nach nichts.";
                        var flipped = ctx.Rng.Pick(upright);
                        flipped.Orientation = Orientation.Reversed;
                        return $"+{healed} HP. Als du aufstehst, liegt {flipped.Definition.Name} verkehrt herum.";
                    }),
                    Choice("Gib ihnen eine Karte", "Deine schwächste Karte geht, +4 Max-HP.", ctx =>
                    {
                        var weakest = Weakest(ctx.Run);
                        Remove(ctx.Run, weakest);
                        ctx.Run.MaxHp += 4;
                        ctx.Run.Hp += 4;
                        return $"Sie essen {weakest?.Definition.Name} mit Messer und Gabel. Höflich.";
                    }, run => CanThin(run, 1)),
                    Leave("Niemand bemerkt, dass du gehst. Dein Teller bleibt voll.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "kinder_im_nebel", Title = "Die Kinder im Nebel", Art = "kinder", MinDarkness = 15,
                Beats = new[]
                {
                    "Sie spielen Tarot mit flachen Steinen. Keines der Kinder hat einen Schatten.",
                    "„Spielst du mit?“, fragen sie alle gleichzeitig."
                },
                Choices =
                {
                    Choice("Spiel mit", "+1 Luck für den Run, +5 Verdunkelung.", ctx =>
                    {
                        ctx.Run.Luck++;
                        ctx.Run.AddDarkness(5);
                        return "Du gewinnst. Sie freuen sich mehr als du.";
                    }),
                    Choice("Gib ihnen 20 Gold", "Ein zufälliges Item.", ctx =>
                    {
                        ctx.Run.Gold -= 20;
                        return "Sie geben dir etwas zurück, das sie gefunden haben. " + GiveRandomItem(ctx);
                    }, run => run.Gold >= 20),
                    Leave("Sie spielen weiter. Einer der Steine trägt jetzt dein Gesicht.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "uhrmacher", Title = "Der Uhrmacher ohne Zeiger", Art = "uhrmacher", MinAct = 2,
                Beats = new[]
                {
                    "„Ich kann dir Zeit geben“, sagt er. „Nicht viel. Deine.“",
                    "Auf dem Tresen tickt eine Uhr ohne Zeiger."
                },
                Choices =
                {
                    Choice("Tausche 8 Max-HP gegen Reife", "Deine stärkste Karte steigt eine Stufe und dunkelt nach. +5 Verdunkelung.", ctx =>
                    {
                        ctx.Run.MaxHp -= 8;
                        ctx.Run.Hp = Math.Min(ctx.Run.Hp, ctx.Run.MaxHp);
                        var best = Strongest(ctx.Run);
                        if (best != null) { best.Level++; Darken(ctx.Run, best); }
                        ctx.Run.AddDarkness(5);
                        return $"{best?.Definition.Name} altert in deiner Hand. Du auch, ein wenig.";
                    }, run => run.MaxHp > 30),
                    Choice("Kaufe Ruhe", "35 Gold: heile 30 %.", ctx =>
                    {
                        ctx.Run.Gold -= 35;
                        var healed = Heal(ctx.Run, (int)Math.Round(ctx.Run.MaxHp * .30f));
                        return $"+{healed} HP. Die Uhr bleibt stehen, solange du schläfst.";
                    }, run => run.Gold >= 35),
                    Leave("Die Uhr tickt lauter, als du gehst.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "beichtstuhl", Title = "Der Beichtstuhl", Art = "beichtstuhl",
                Beats = new[]
                {
                    "Ein Beichtstuhl mitten auf einer Wiese. Die Tür steht offen.",
                    "Durch das Gitter flüstert jemand deinen Namen – falsch betont."
                },
                DarkBeats = new[]
                {
                    "Ein Beichtstuhl mitten auf einer Wiese. Das Gras um ihn ist schwarz.",
                    "Durch das Gitter flüstert jemand: „Du schon wieder.“"
                },
                Choices =
                {
                    Choice("Beichte", "−12 Verdunkelung, −25 Gold.", ctx =>
                    {
                        ctx.Run.Gold -= 25;
                        ctx.Run.AddDarkness(-12);
                        return "Du erzählst alles. Er klingt enttäuscht, dass es so wenig war.";
                    }, run => run.Gold >= 25),
                    Choice("Lüge", "+60 Fate, +10 Verdunkelung.", ctx =>
                    {
                        ctx.Run.Fate += 60;
                        ctx.Run.AddDarkness(10);
                        return "Er glaubt dir jedes Wort. Das ist das Schlimmste daran.";
                    }),
                    Leave("Das Flüstern hört auf. Du bist nicht sicher, ob das besser ist.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "brunnen", Title = "Das Orakel im Brunnen", Art = "brunnen",
                Beats = new[]
                {
                    "Tief unten spiegelt sich ein Gesicht, das nicht deins ist.",
                    "Es bewegt die Lippen, sobald du dich vorbeugst."
                },
                Choices =
                {
                    Choice("Hör zu", "Die nächsten zwei Belohnungen bieten eine Wahl mehr.", ctx =>
                    {
                        ctx.Run.BonusRewardChoices += 2;
                        return "Es flüstert Möglichkeiten. Zu viele, um sie alle zu behalten.";
                    }),
                    Choice("Wirf eine Münze", "10 Gold: ein Drittel für einen zufälligen Charm.", ctx =>
                    {
                        ctx.Run.Gold -= 10;
                        if (!ctx.Rng.Chance(1f / 3f)) return "Die Münze fällt lange. Du hörst sie nie aufschlagen.";
                        return "Etwas fliegt zurück nach oben. " + GiveRandomCharm(ctx, "Nichts kommt zurück.");
                    }, run => run.Gold >= 10),
                    Leave("Das Gesicht sieht dir nach, bis du hinter dem Hügel bist.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "wanderzirkus", Title = "Der Wanderzirkus", Art = "zirkus",
                Beats = new[]
                {
                    "Ein Zelt, das von innen größer ist als von außen.",
                    "Der Direktor hat keinen Kopf, nur einen Hut. Der Hut lächelt."
                },
                Choices =
                {
                    Choice("Kaufe ein Los", "25 Gold: 40 % Charm, 35 % Item, 25 % nichts.", ctx =>
                    {
                        ctx.Run.Gold -= 25;
                        var roll = ctx.Rng.NextFloat();
                        if (roll < .40f) return "Ein Gewinn! " + GiveRandomCharm(ctx, "Der Preis ist ausverkauft.");
                        if (roll < .75f) return "Ein Trostpreis. " + GiveRandomItem(ctx);
                        return "Eine Niete. Der Hut lacht, und alle lachen mit.";
                    }, run => run.Gold >= 25),
                    Choice("Tritt als Attraktion auf", "+50 Gold, −10 HP.", ctx =>
                    {
                        ctx.Run.Gold += 50;
                        Hurt(ctx.Run, 10);
                        return "Sie werfen Messer. Die Menge jubelt bei jedem, der trifft.";
                    }),
                    Leave("Die Musik folgt dir noch eine Weile.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "hebamme", Title = "Die Hebamme der Omen", Art = "hebamme", MinAct = 2,
                Beats = new[]
                {
                    "Sie wiegt etwas im Arm, das in ein Tarottuch gewickelt ist.",
                    "Es greift nach dir. Es hat deine Hände."
                },
                Choices =
                {
                    Choice("Nimm es an dich", "Ein zufälliges Großes Arkanum, umgekehrt. +8 Verdunkelung.", ctx =>
                    {
                        var major = RandomMajor(ctx);
                        Add(ctx.Run, major, orientation: Orientation.Reversed);
                        ctx.Run.AddDarkness(8);
                        return $"Unter dem Tuch liegt {major.Name}, kopfüber. Es hört auf zu weinen.";
                    }),
                    Choice("Segne es", "Eine zufällige Karte deines Decks steigt 2 Stufen.", ctx =>
                    {
                        var card = ctx.Rng.Pick(ctx.Run.Deck);
                        card.Level += 2;
                        return $"Sie nickt. Irgendwo in deinem Deck wird {card.Definition.Name} schwerer.";
                    }, run => run.Deck.Count > 0),
                    Leave("Sie singt ihm etwas vor. Es ist dein Name.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "hungriger_haendler", Title = "Der Händler hat Hunger", Art = "haendler", MinAct = 2,
                Beats = new[]
                {
                    "Der Händler sitzt am Wegrand und kaut. Sein Mantel ist leer.",
                    "„Nur ein Happen“, sagt er. „Dann öffne ich wieder.“"
                },
                Choices =
                {
                    Choice("Füttere ihn mit einer Karte", "Deine schwächste Karte geht; dein nächster Kauf ist umsonst.", ctx =>
                    {
                        var weakest = Weakest(ctx.Run);
                        Remove(ctx.Run, weakest);
                        ctx.Run.FreeNextShopPurchase = true;
                        return $"Er kaut {weakest?.Definition.Name} sehr gründlich. „Beim nächsten Mal geht's aufs Haus.“";
                    }, run => CanThin(run, 1)),
                    Choice("Füttere ihn mit Gold", "40 Gold: ein zufälliger Charm.", ctx =>
                    {
                        ctx.Run.Gold -= 40;
                        return "Er spuckt etwas aus und wischt es an seinem Ärmel ab. " + GiveRandomCharm(ctx, "Er hat nichts mehr.");
                    }, run => run.Gold >= 40),
                    Leave("Er kaut weiter. Du hörst es noch lange.")
                }
            });

            list.Add(new EventDefinition
            {
                Id = "waage", Title = "Die Waage", Art = "waage",
                Beats = new[]
                {
                    "Eine Waage ohne Richter. In der einen Schale liegt ein Herz.",
                    "Die andere Schale ist leer und wartet."
                },
                Choices =
                {
                    Choice("Leg eine Karte hinein", "Deine schwächste Kleine Arkana wird gegen eine andere derselben Farbe getauscht – eine Stufe höher.", ctx =>
                    {
                        var weakest = ctx.Run.Deck.Where(c => !c.Definition.IsMajor).OrderBy(Strength).FirstOrDefault();
                        if (weakest == null) return "Die Waage rührt sich nicht.";
                        var options = GameCatalog.Cards.Where(c => c.Suit == weakest.Definition.Suit && c.Id != weakest.Definition.Id).ToList();
                        var replacement = ctx.Rng.Pick(options);
                        Remove(ctx.Run, weakest);
                        Add(ctx.Run, replacement, weakest.Level + 1, weakest.Shimmer, weakest.Orientation);
                        return $"{weakest.Definition.Name} wiegt zu wenig. Die Waage gibt dir {replacement.Name}.";
                    }, run => run.Deck.Any(c => !c.Definition.IsMajor)),
                    Choice("Leg dein ganzes Gold hinein", "Ab 80 Gold wird ein Charm, den du trägst, stärker. Das Gold ist fort.", ctx =>
                    {
                        var gold = ctx.Run.Gold;
                        ctx.Run.Gold = 0;
                        var owned = GameCatalog.Charms
                            .Where(c => ctx.Run.CharmStacks(c.Id) > 0 && ctx.Run.CharmStacks(c.Id) < c.MaxStacks)
                            .ToList();
                        if (gold < 80 || owned.Count == 0) return "Die Waage rührt sich nicht. Das Gold ist trotzdem fort.";
                        var charm = ctx.Rng.Pick(owned);
                        ctx.Run.AddCharm(charm);
                        return $"Die Schale sinkt. {charm.Name} wird schwerer an deinem Hals.";
                    }, run => run.Gold > 0),
                    Leave("Das Herz in der Schale schlägt einmal, als du gehst.")
                }
            });

            return list;
        }
    }
}
