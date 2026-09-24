using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    public static class GameCatalog
    {
        /// <summary>
        /// Unter diese Groesse kann ein Deck nicht schrumpfen. Ein noch
        /// duenneres Deck zieht dieselben Karten so verlaesslich, dass jede
        /// Entscheidung im Kampf entfaellt.
        /// </summary>
        public const int MinimumDeckSize = 5;

        public static readonly List<CardDefinition> Cards = BuildCards();
        public static readonly List<CharmDefinition> Charms = BuildCharms();
        public static readonly List<ItemDefinition> Items = BuildItems();
        public static readonly List<EnemyDefinition> Enemies = BuildEnemies();

        public static CardDefinition Card(string id) => Cards.First(c => c.Id == id);
        public static CharmDefinition Charm(string id) => Charms.First(c => c.Id == id);
        public static ItemDefinition Item(string id) => Items.First(c => c.Id == id);

        public static RunState CreateStarterRun()
        {
            var run = new RunState();
            var starterIds = new[]
            {
                "pentacles_4", "swords_7", "wands_10", "cups_6",
                "swords_3", "pentacles_6", "wands_4", "cups_8",
                "major_1", "major_0"
            };
            foreach (var id in starterIds) run.Deck.Add(new CardInstance(Card(id)));
            run.AddCharm(Charm("white_thread"));
            run.AddCharm(Charm("lucky_clover"));
            run.AddItem(Item("mirror_shard"));
            return run;
        }

        private static List<CardDefinition> BuildCards()
        {
            var list = new List<CardDefinition>();
            AddMinorSuit(list, Suit.Swords, "Schwerter", 3, "Direkter Schaden. Höhere Werte brechen Haltung schneller.");
            AddMinorSuit(list, Suit.Wands, "Stäbe", 2, "Brand und Combo. Aufeinanderfolgende Stäbe verstärken sich.");
            AddMinorSuit(list, Suit.Cups, "Kelche", 2, "Heilung und Traum. Umgekehrt wird Heilung riskanter, aber stärker.");
            AddMinorSuit(list, Suit.Pentacles, "Münzen", 2, "Schild, Gold und Vorbereitung. Zukunftseffekte sind besonders stark.");

            var names = new[]
            {
                "Der Narr", "Der Magier", "Die Hohepriesterin", "Die Herrscherin", "Der Herrscher", "Der Hierophant",
                "Die Liebenden", "Der Wagen", "Kraft", "Der Eremit", "Rad des Schicksals", "Gerechtigkeit",
                "Der Gehängte", "Der Tod", "Mäßigkeit", "Der Teufel", "Der Turm", "Der Stern", "Der Mond",
                "Die Sonne", "Das Gericht", "Die Welt"
            };

            var desc = new[]
            {
                "Ziehe zusätzliche Karten; umgekehrt riskanter, aber mit Luck.",
                "Wiederholt die letzte Karte oder erzeugt eine temporäre Kopie.",
                "Ordnet kommende Karten und enthüllt Gegnerabsichten.",
                "Heilt und verstärkt die nächsten Karten; umgekehrt gegen Lebensopfer.",
                "Erzeugt starken Schild, der nicht sofort verfällt.",
                "Verbessert eine Karte im Kampf oder erschöpft sie für stärkere Wirkung.",
                "Verbindet zwei Karten, sodass Effekte gemeinsam ausgelöst werden.",
                "Belohnt die dritte Karte einer Legung mit Wiederholung.",
                "Verdoppelt die nächste Angriffskraft; umgekehrt mit Selbstschaden.",
                "Entfernt Karten temporär aus dem Kampf und verdünnt den Draw-Pile.",
                "Ersetzt oder wählt Karten neu; starker Luck-Effekt.",
                "Entfernt Debuffs oder überträgt sie auf den Gegner.",
                "Opfert Aktionen für einen explosiven Folgeturn.",
                "Vernichtet Karten temporär; kann nach dem Kampf permanentes Löschen auslösen.",
                "Mischt die Wirkung zweier Karten und belohnt hybride Builds.",
                "Verdoppelt Macht gegen einen Fluch oder stärkt umgekehrte Karten.",
                "Zerstört Schild und verursacht massiven Burst.",
                "Heilt, zieht und erzeugt Luck.",
                "Verstärkt umgekehrte Karten, verbirgt aber Informationen.",
                "Schaden, Heilung und Kartenziehen in einem Zug.",
                "Holt bereits gespielte oder erschöpfte Karten zurück.",
                "Belohnt alle vier Farben und Summe 21 mit einem massiven Fate-Schub."
            };

            for (var i = 0; i <= 21; i++)
            {
                list.Add(new CardDefinition
                {
                    Id = $"major_{i}",
                    Name = names[i],
                    Suit = Suit.Major,
                    // Der Narr traegt die Arkana-Nummer 0, im Spiel aber Rang 1:
                    // Muster wie Summe 21, Paar und Dreiklang rechnen mit Rank,
                    // und eine Karte mit Wert 0 waere dort tot. Die Anzeige
                    // nimmt dagegen die Arkana-Nummer - siehe CardDefinition.DisplayNumber.
                    Rank = i == 0 ? 1 : i,
                    BasePower = 4 + i / 3,
                    Major = (MajorArcana)i,
                    Description = desc[i]
                });
            }

            return list;
        }

        private static void AddMinorSuit(List<CardDefinition> list, Suit suit, string germanSuit, int basePower, string description)
        {
            for (var rank = 1; rank <= 14; rank++)
            {
                var label = rank switch
                {
                    1 => "Ass",
                    11 => "Bube",
                    12 => "Ritter",
                    13 => "Königin",
                    14 => "König",
                    _ => rank.ToString()
                };
                list.Add(new CardDefinition
                {
                    Id = $"{suit.ToString().ToLowerInvariant()}_{rank}",
                    Name = $"{label} der {germanSuit}",
                    Suit = suit,
                    Rank = rank,
                    BasePower = basePower + rank,
                    Description = description
                });
            }
        }

        private static List<CharmDefinition> BuildCharms()
        {
            return new List<CharmDefinition>
            {
                C("blade_pendant","Klingenanhänger",CharmEffectType.SwordsChips,2,8,"Schwerter erhalten +2 Chips pro Stack."),
                C("ember_knot","Glutknoten",CharmEffectType.WandsBurn,1,8,"Stäbe erzeugen +1 Brand pro Stack."),
                C("blood_moon","Blutmondsplitter",CharmEffectType.SelfDamagePower,.12f,8,"Riskante/umgekehrte Karten erhalten +12% Wirkung pro Stack."),
                C("predator_fang","Raubzahn",CharmEffectType.DebuffedLifesteal,1,5,"Angriffe gegen debuffte Gegner heilen 1 HP pro Stack."),
                C("hunt_bell","Jagdglocke",CharmEffectType.FirstAttackBonus,4,5,"Erster Angriff pro Kampf erhält +4 Schaden pro Stack."),
                C("black_nail","Schwarzer Nagel",CharmEffectType.EveryThirdCardDamage,3,5,"Jede dritte gespielte Karte verursacht +3 Schaden pro Stack."),
                C("falcon_eye","Falkenauge",CharmEffectType.AttackVsAttacker,2,5,"Greift der Gegner an, erhalten Angriffe +2 Chips pro Stack."),
                C("ash_wreath","Aschekranz",CharmEffectType.KillRamp,1,5,"Kills erhöhen Angriffschips für den Kampf."),
                C("thorn_ring","Dornenring",CharmEffectType.Thorns,2,5,"Reflektiert geblockten Schaden."),
                C("hangman_chain","Henkerkette",CharmEffectType.FuturePower,.10f,5,"Zukunftseffekte +10% pro Stack."),
                C("iron_coin","Eiserne Münze",CharmEffectType.PentacleShield,2,8,"Münzen geben +2 Schild pro Stack."),
                C("cup_rim","Kelchrand",CharmEffectType.OverhealToShield,.20f,5,"Überheilung wird teilweise zu Schild."),
                C("white_thread","Weißer Faden",CharmEffectType.StartShield,3,5,"Beginne Kämpfe mit +3 Schild pro Stack."),
                C("salt_seal","Salzsiegel",CharmEffectType.DebuffWard,1,3,"Negiert frühe Debuffs."),
                C("bone_pearl","Knochenperle",CharmEffectType.LowHpShield,2,5,"Unter 50% HP geben Schildkarten +2 Schild pro Stack."),
                C("moon_brooch","Mondbrosche",CharmEffectType.ReversedShield,1,5,"Umgekehrte Karten geben +1 Schild pro Stack."),
                C("emperor_seal","Siegel des Herrschers",CharmEffectType.ShieldRetention,.10f,5,"Ein Teil des Schilds bleibt zwischen Runden."),
                C("saint_needle","Heiligennadel",CharmEffectType.EveryFifthHeal,1,5,"Jede fünfte Karte heilt 1 HP pro Stack."),
                C("phoenix_feather","Phönixfeder",CharmEffectType.Phoenix,5,3,"Verhindert einmal pro Abschnitt den Tod; weitere Stacks heilen stärker."),
                C("glass_heart","Glasherz",CharmEffectType.GlassHeart,.25f,4,"Weniger Max-HP, aber stärkere Heilung."),
                C("silver_mirror","Silberspiegel",CharmEffectType.CopyPower,.10f,8,"Kopierte Karten +10% Wirkung pro Stack."),
                C("razor_charm","Rasieramulett",CharmEffectType.RemoveDiscount,.15f,5,"Kartenlöschen wird günstiger."),
                C("blank_card","Leere Karte",CharmEffectType.OpeningDraw,1,2,"Ziehe zu Kampfbeginn +1 Karte pro Stack."),
                C("thread_spool","Fadenspule",CharmEffectType.DiscardBoost,1,5,"Abwerfen stärkt die nächste Karte."),
                C("wax_seal","Wachssiegel",CharmEffectType.UpgradedPower,.08f,8,"Verbesserte Karten +8% Wirkung pro Stack."),
                C("crow_feather","Krähenfeder",CharmEffectType.ReshuffleDraw,1,2,"Beim Mischen +1 Karte ziehen."),
                C("memory_shard","Erinnerungssplitter",CharmEffectType.MemoryReturn,1,5,"Frühe Karten kehren in Folgerunden zurück."),
                C("twin_coin","Zwillingsmünze",CharmEffectType.CopyBase,1,5,"Kopien erhalten +1 Basiswert pro Stack."),
                C("empty_frame","Leerer Rahmen",CharmEffectType.RemoveMaxHp,1,5,"Gelöschte Karten können Max-HP erhöhen."),
                C("oracle_eye","Auge des Orakels",CharmEffectType.OracleSight,1,3,"Zeigt zusätzliche kommende Karten."),
                C("blade_rose","Klingenrose",CharmEffectType.SwordBridge,2,5,"Nach zwei Schwertern wird die nächste Nicht-Schwert-Karte stärker."),
                C("wand_weave","Stabgeflecht",CharmEffectType.WandCombo,.08f,8,"Stabketten erhöhen den Multiplikator."),
                C("cup_pearl","Kelchperle",CharmEffectType.CupAfterAttack,2,8,"Kelche nach Angriffen heilen mehr."),
                C("pentacle_chain","Pentakelkette",CharmEffectType.PentacleGold,2,5,"Hoher Schild am Kampfende erzeugt Gold."),
                C("fourfold_knot","Vierfachknoten",CharmEffectType.FourSuitBonus,.12f,8,"Vier Farben in einer Runde erhöhen den Mult."),
                C("black_cup","Schwarzer Kelch",CharmEffectType.HealDamage,.20f,5,"Heilung schädigt Gegner anteilig."),
                C("brass_wand","Messingstab",CharmEffectType.BurnPower,1,8,"Brandticks verursachen +1 Schaden pro Stack."),
                C("silver_blade","Silberklinge",CharmEffectType.ArmorPierce,1,5,"Schwerter ignorieren gegnerischen Schild."),
                C("gold_pentacle","Goldenes Pentakel",CharmEffectType.PentacleLuck,1,5,"Münzserien erzeugen temporäres Luck."),
                C("blue_ribbon","Blaues Band",CharmEffectType.CupCleanse,1,3,"Kelchserien entfernen Debuffs."),
                C("lucky_clover","Narrenklee",CharmEffectType.StartLuck,1,3,"Beginne Abschnitte mit +1 Luck pro Stack."),
                C("merchant_eye","Auge des Händlers",CharmEffectType.ShopDiscount,.05f,5,"Händlerpreise -5% pro Stack."),
                C("bent_coin","Gebogene Münze",CharmEffectType.RewardReroll,1,3,"+1 Reward-Reroll pro Abschnitt."),
                C("cat_fang","Katzenzahn",CharmEffectType.RareChance,.04f,5,"Seltene Karten erscheinen häufiger."),
                C("luck_bell","Glücksglocke",CharmEffectType.PositiveEvent,.06f,5,"Positive Ereignisse werden wahrscheinlicher."),
                C("greed_moth","Giermotte",CharmEffectType.Greed,.10f,5,"Mehr Gold, aber stärkere Gegner."),
                C("gold_die","Goldener Würfel",CharmEffectType.ExtraRewardChoice,1,4,"Jeder zweite Stack erweitert Reward-Auswahlen."),
                C("star_dust","Sternenstaub",CharmEffectType.UpgradedRewardChance,.08f,5,"Belohnungskarten sind häufiger verbessert."),
                C("broken_crown","Gebrochene Krone",CharmEffectType.EliteCharmChance,.20f,5,"Elitegegner geben häufiger zusätzliche Charms."),
                C("world_thread","Weltenfaden",CharmEffectType.WorldThread,.02f,8,"Für je fünf verschiedene Charms +2% Kartenwirkung pro Stack.")
            };
        }

        private static CharmDefinition C(string id, string name, CharmEffectType effect, float mag, int max, string desc)
            => new CharmDefinition(id, name, effect, mag, max, desc);

        private static List<ItemDefinition> BuildItems()
        {
            return new List<ItemDefinition>
            {
                I("mirror_shard","Spiegelscherbe",ItemEffectType.MirrorCard,1,"Kopiere permanent eine normale Karte."),
                I("fate_scissors","Schere des Schicksals",ItemEffectType.RemoveCard,1,"Lösche permanent eine Karte."),
                I("black_wax","Schwarzes Wachs",ItemEffectType.FlipCard,1,"Drehe eine Karte permanent um."),
                I("gold_needle","Goldene Nadel",ItemEffectType.UpgradeCard,1,"Erhöhe das Level einer Karte."),
                I("oracle_lens","Orakellinse",ItemEffectType.ReorderDeck,5,"Ordne die nächsten fünf Karten neu."),
                I("sun_vial","Sonnenphiole",ItemEffectType.Heal,15,"Heile 15 HP."),
                I("moon_salt","Mondsalz",ItemEffectType.CleanseReveal,3,"Entferne Debuffs und enthülle Absichten."),
                I("tower_powder","Turmpulver",ItemEffectType.TowerBlast,20,"20 Schaden an allen Gegnern, eigener Schild fällt."),
                I("devil_pact","Teufelspakt",ItemEffectType.DevilsBargain,1,"Nächster Händlerkauf kostet 0; dafür Fluch-Risiko."),
                I("lovers_band","Band der Liebenden",ItemEffectType.LinkCards,3,"Verbindet zwei Karten für drei Kämpfe."),
                I("hangman_rope","Strick des Gehängten",ItemEffectType.SkipEnemyIntent,1,"Überspringe eine Gegneraktion."),
                I("pentacle_pouch","Pentakelbeutel",ItemEffectType.GainGold,40,"Erhalte 40 Gold."),
                I("bone_key","Knochenschlüssel",ItemEffectType.Unlock,1,"Öffnet verschlossene Wege."),
                I("merchant_mark","Händlermarke",ItemEffectType.RerollShop,1,"Erneuere das Händlerangebot kostenlos."),
                I("ash_vial","Aschephiole",ItemEffectType.Revive,25,"Automatische Wiederbelebung mit 25% HP."),
                I("star_water","Sternenwasser",ItemEffectType.GainLuck,1,"+1 Luck für den Abschnitt."),
                I("emperor_token","Siegel des Kaisers",ItemEffectType.StartShieldBuff,12,"Die nächsten Kämpfe starten mit zusätzlichem Schild."),
                I("priestess_ink","Tinte der Priesterin",ItemEffectType.TransformCard,1,"Transformiert eine Karte derselben Farbe/Seltenheit."),
                I("wheel_token","Radmarke",ItemEffectType.RerollReward,1,"Würfle eine Belohnung komplett neu."),
                I("world_compass","Weltenkompass",ItemEffectType.RevealPath,1,"Zeigt kommende Räume und erleichtert die Wegwahl."),
                I("hermit_lantern","Laterne des Eremiten",ItemEffectType.RemoveCurse,1,"Entfernt eine Fluchkarte."),
                I("judgement_bell","Glocke des Gerichts",ItemEffectType.RestoreRemovedCard,1,"Hole eine gelöschte Karte verbessert zurück.")
            };
        }

        private static ItemDefinition I(string id, string name, ItemEffectType effect, int mag, string desc)
            => new ItemDefinition(id, name, effect, mag, desc);

        private static List<EnemyDefinition> BuildEnemies()
        {
            return new List<EnemyDefinition>
            {
                E("smiling_bailiff","Der lächelnde Gerichtsdiener",74,12,9,0,"Er schlägt regelmäßig zu und belohnt sauberes Haltungsspiel."),
                E("moon_eater","Der Mondfresser",96,16,11,0,"Unter halben HP wird er aggressiver und verbirgt seine Absicht."),
                E("needle_widow","Die Nadelwitwe",118,19,12,0,"Wechselt zwischen Angriff und Schild."),
                E("coin_mouth","Das Münzmaul",142,22,13,0,"Bestraft lange Kämpfe mit immer stärkerem Angriff."),
                E("laughing_hangman","Der lachende Henker",170,26,15,1,"Ein Siegel zwingt dich, ihn zweimal zu brechen."),
                E("tower_host","Der Wirt im Turm",210,30,17,1,"Boss: hoher Haltungsschutz und eskalierende Phasen."),
                E("red_sun","Die rote Sonne",260,34,19,2,"Boss: zwei Schicksalssiegel und massiver Druck."),
                E("world_worm","Der Weltenwurm",330,40,22,2,"Endlosgegner: wächst mit jedem Abschnitt weiter.")
            };
        }

        private static EnemyDefinition E(string id, string name, int hp, int stance, int attack, int sigils, string flavor)
            => new EnemyDefinition { Id=id, Name=name, MaxHp=hp, MaxStance=stance, BaseAttack=attack, Sigils=sigils, Flavor=flavor };
    }
}
