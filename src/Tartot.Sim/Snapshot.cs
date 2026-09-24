using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;

/// <summary>
/// Schreibt den Zustand einzelner Bildschirme als JSON heraus.
/// </summary>
/// <remarks>
/// Zweck: ein ehrlicher erster Eindruck, ohne Unity. Die Zahlen und Karten
/// stammen aus dem echten Regelkern; gezeichnet wird daraus anschliessend von
/// tools/screenshots/render.py. Das ersetzt keinen Unity-Build - Schriftart,
/// Abstaende und Theme koennen dort abweichen.
///
/// Alle Zustaende entstehen durch echtes Spielen (Autopilot), nicht durch
/// Zusammenbauen: gesucht wird ein Seed, bei dem der Moment natuerlich
/// eintritt.
/// </remarks>
public static class Snapshot
{
    public static void Write(string directory)
    {
        Directory.CreateDirectory(directory);
        var pilot = new Autopilot();

        // 1. Kampfbeginn: volle Hand, leere Legung.
        var game = new GameController(20260924);
        Save(directory, "01_kampf_start", Combat(game, "Der erste Blick in die Karten."));

        // 2. Legung gefuellt: Vorschau und Beinahe-Hinweis sichtbar.
        pilot.Arrange(game);
        Save(directory, "02_legung", Combat(game, "Drei Karten liegen. Die Vorschau rechnet mit."));

        // 3. Der Turm: eine Position ist eingestuerzt.
        var tower = FindBossMoment("boss_turm", g => g.Combat.BlockedSlot.HasValue, pilot);
        if (tower != null)
        {
            pilot.Arrange(tower);
            Save(directory, "03_boss_turm", Combat(tower, "Akt I, Boss: Der Turm nimmt dir eine Position."));
        }

        // 4. Der Tod hat eine Karte auf deiner Hand gezeichnet.
        var death = FindBossMoment("boss_tod", g => !string.IsNullOrEmpty(g.Combat.MarkedCardId)
                                                    && g.Combat.Hand.Any(c => c.InstanceId == g.Combat.MarkedCardId), pilot);
        if (death != null)
            Save(directory, "04_boss_tod", Combat(death, "Akt II, Boss: Der Tod zeichnet deine stärkste Karte."));

        // 5. Der Teufel verhandelt.
        var devil = FindBossMoment("boss_teufel", g => g.Combat.PactPending, pilot, answerPacts: false);
        if (devil != null)
            Save(directory, "05_pakt", Combat(devil, "Akt III, Boss: Der Teufel bietet einen Pakt an."));

        // 6. Eine Zwischensequenz: Der Kartenspieler am Kreuzweg.
        var scene = FindEvent("kartenspieler_1", pilot);
        if (scene != null) Save(directory, "06_ereignis", Event(scene));

        // 7. Omen-Beute nach dem ersten Boss.
        var loot = FindPhase(GamePhase.BossLoot, pilot, 300);
        if (loot != null) Save(directory, "07_omen_beute", BossLoot(loot));

        // 8. Spaet im Run: ein dunkles Deck in Akt III.
        var late = FindLateCombat(pilot);
        if (late != null)
        {
            pilot.Arrange(late);
            Save(directory, "08_spaetes_deck", Combat(late, "Akt III: das Deck ist dunkler geworden - und staerker."));
        }

        // 9. Wegwahl mit angekuendigtem Omen.
        var path = FindPhase(GamePhase.PathChoice, pilot, 700, g => ActCatalog.FightsUntilBoss(g.Run.FightIndex + 1) == 0);
        if (path != null) Save(directory, "09_wegwahl", Paths(path));

        // 10. Der Run-Bericht nach ein paar Runs - mit Beinahe-Liste.
        Save(directory, "10_bericht", Report(pilot));

        // 11. Titelschirm eines Spielers mit etwas Fortschritt.
        Save(directory, "11_titel", Title());

        // 12. Belohnung und 13. Haendler (wie bisher).
        var rewardGame = new GameController(4711);
        pilot.PlayCombat(rewardGame);
        if (rewardGame.Phase == GamePhase.Reward) Save(directory, "12_belohnung", Reward(rewardGame));

        var shopGame = new GameController(99);
        shopGame.Run.Gold = 240;
        shopGame.OpenShop();
        Save(directory, "13_haendler", Shop(shopGame));

        Console.WriteLine($"Zustaende geschrieben nach {directory}");
    }

    // ------------------------------------------------------------ Suche
    /// <summary>Spielt Runs, bis im Kampf gegen diesen Boss der Moment eintritt.</summary>
    private static GameController FindBossMoment(string bossId, Func<GameController, bool> moment,
        Autopilot pilot, bool answerPacts = true)
    {
        for (var seed = 1; seed < 400; seed++)
        {
            var game = new GameController(seed);
            if (!game.Run.ActBosses.Contains(bossId)) continue;
            for (var guard = 0; guard < 400 && game.Phase != GamePhase.GameOver; guard++)
            {
                if (game.Phase == GamePhase.Combat && game.Combat.Enemy.Definition.Id == bossId)
                {
                    for (var turn = 0; turn < 12 && game.Phase == GamePhase.Combat; turn++)
                    {
                        if (moment(game)) return game;
                        if (!answerPacts && game.Combat.PactPending) break;
                        pilot.PlayTurn(game);
                    }
                    break;
                }
                pilot.Step(game);
            }
        }
        return null;
    }

    private static GameController FindPhase(GamePhase phase, Autopilot pilot, int seed,
        Func<GameController, bool> extra = null)
    {
        for (var s = seed; s < seed + 200; s++)
        {
            var game = new GameController(s);
            for (var guard = 0; guard < 400 && game.Phase != GamePhase.GameOver; guard++)
            {
                if (game.Phase == phase && (extra == null || extra(game))) return game;
                pilot.Step(game);
            }
        }
        return null;
    }

    private static GameController FindEvent(string eventId, Autopilot pilot)
    {
        for (var seed = 1; seed < 600; seed++)
        {
            var game = new GameController(seed);
            for (var guard = 0; guard < 120 && game.Phase != GamePhase.GameOver; guard++)
            {
                if (game.Phase == GamePhase.Event && game.CurrentEvent?.Id == eventId) return game;
                if (game.Phase == GamePhase.PathChoice && game.Paths.Contains(PathType.Event))
                {
                    game.ChoosePath(PathType.Event);
                    continue;
                }
                pilot.Step(game);
            }
        }
        return null;
    }

    private static GameController FindLateCombat(Autopilot pilot)
    {
        for (var seed = 50; seed < 400; seed++)
        {
            var game = new GameController(seed);
            for (var guard = 0; guard < 600 && game.Phase != GamePhase.GameOver; guard++)
            {
                if (game.Phase == GamePhase.Combat && game.Run.FightIndex == 12 && game.Combat.Turn == 1
                    && game.Run.Deck.Count(c => c.Shimmer >= Shimmer.Blood) >= 2)
                    return game;
                if (game.Run.FightIndex > 12) break;
                pilot.Step(game);
            }
        }
        return null;
    }

    // ------------------------------------------------------ Bildschirme
    private static JsonValue Combat(GameController game, string caption)
    {
        var combat = game.Combat;
        var enemy = combat.Enemy;
        var root = Screen("combat", caption);
        root.Set("darkness", game.Run.DarknessStage);

        var moon = CombatSystem.HasRule(combat, BossRule.Moon);
        root.Set("enemy", JsonValue.Object()
            .Set("name", enemy.Definition.Name)
            .Set("rule", string.Join("  ·  ", CombatSystem.ActiveRuleTexts(combat)))
            .Set("hp", Math.Max(0, enemy.Hp))
            .Set("hpText", moon ? $"≈ {(Math.Max(0, enemy.Hp) + 9) / 10 * 10}" : Math.Max(0, enemy.Hp).ToString())
            .Set("maxHp", enemy.Definition.MaxHp)
            .Set("stance", Math.Max(0, enemy.Stance))
            .Set("maxStance", enemy.Definition.MaxStance)
            .Set("sigils", enemy.Sigils)
            .Set("burn", enemy.Burn)
            .Set("intent", enemy.IntentHidden ? "??? — der Mond verbirgt es" : IntentText(enemy)));

        var run = game.Run;
        var where = ActCatalog.IsFinale(run.FightIndex) ? "FINALE"
            : ActCatalog.IsSpiral(run.FightIndex) ? $"Spirale {ActCatalog.SpiralDepth(run.FightIndex)}"
            : $"Akt {MetaProgress.Roman(run.Act)} · Kampf {run.FightIndex % ActCatalog.FightsPerAct + 1}/{ActCatalog.FightsPerAct}";
        root.Set("player", JsonValue.Object()
            .Set("hp", run.Hp)
            .Set("maxHp", run.MaxHp)
            .Set("shield", combat.PlayerShield)
            .Set("fate", run.Fate)
            .Set("gold", run.Gold)
            .Set("luck", combat.TemporaryLuck)
            .Set("darkness", run.Darkness)
            .Set("where", where)
            .Set("turn", combat.Turn));

        root.Set("charms", Charms(game));

        var slots = JsonValue.Object();
        foreach (var slot in new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future })
        {
            var effective = game.CombatSystem.EffectiveSlot(combat, slot);
            var blocked = combat.BlockedSlot.HasValue && combat.BlockedSlot.Value == slot;
            slots.Set(slot.ToString(), JsonValue.Object()
                .Set("card", combat.Slots.TryGetValue(slot, out var card) ? Card(card, combat) : JsonValue.Null())
                .Set("blocked", blocked)
                .Set("hint", blocked ? "EINGESTÜRZT — der Turm"
                    : effective != slot ? $"wirkt als {CombatSystem.SlotName(effective)}" : string.Empty));
        }
        root.Set("slots", slots);

        var hand = JsonValue.Array();
        foreach (var card in combat.Hand) hand.Add(Card(card, combat));
        root.Set("hand", hand);

        var score = game.PreviewScore();
        var preview = string.Empty;
        var hints = string.Empty;
        var lethal = false;
        if (score != null && combat.Slots.Count > 0)
        {
            if (score.Veiled) preview = "Die Legung liegt im Mondlicht — ungewiss.";
            else
            {
                var landing = score.BreaksStance ? $" → HALTUNG BRICHT: {score.ExpectedHit}"
                    : score.ExpectedHit < score.FateDamage ? $" → Haltung deckelt: {score.ExpectedHit}" : string.Empty;
                preview = $"{score.ComboName}: {score.Chips} × {score.Multiplier:0.00}"
                          + (score.RepeatPenalty < 1f ? $" × Wdh. {score.RepeatPenalty:0.00}" : "")
                          + $" = {score.FateDamage}{landing}"
                          + (score.Chain >= 2 ? $" · Kette ×{score.Chain}" : string.Empty);
                hints = string.Join("   ·   ", score.Hints);
                lethal = score.Lethal;
            }
        }
        root.Set("preview", preview);
        root.Set("hints", hints);
        root.Set("lethal", lethal);

        if (combat.PactPending)
            root.Set("pact", $"Der Teufel bietet einen Pakt: +{CombatSystem.PactBonus(combat) * 100:0} % Fate-Schaden für diesen Kampf. " +
                             $"Preis: {CombatSystem.PactCost(combat)} Max-HP für immer und +{CombatSystem.PactDarkness} Verdunkelung. " +
                             $"Lehnst du ab, schlägt er {CombatSystem.PactDeclinePenalty * 100:0} % härter zu.");
        root.Set("log", game.Message ?? "");
        return root;
    }

    private static JsonValue Event(GameController game)
    {
        var scene = game.CurrentEvent;
        var root = Screen("event", "Eine Zwischensequenz: Satz für Satz, dann die Entscheidung.");
        root.Set("title", scene.Title.ToUpperInvariant());
        root.Set("story", scene.IsStory);
        var beats = JsonValue.Array();
        foreach (var beat in scene.BeatsFor(game.Run)) beats.Add(JsonValue.Of(beat));
        root.Set("beats", beats);
        var choices = JsonValue.Array();
        for (var i = 0; i < scene.Choices.Count; i++)
            choices.Add(JsonValue.Object()
                .Set("label", scene.Choices[i].Label)
                .Set("hint", scene.Choices[i].Hint)
                .Set("enabled", game.CanChooseEventOption(i)));
        root.Set("choices", choices);
        return root;
    }

    private static JsonValue BossLoot(GameController game)
    {
        var root = Screen("options", "Nach dem Boss: was geschieht mit der Tinte des Omens?");
        root.Set("title", "DAS OMEN FÄLLT");
        root.Set("subtitle", (game.Message ?? string.Empty) + "\nWas geschieht mit seiner Tinte?");
        var omen = game.OmenCard();
        var options = JsonValue.Array();
        options.Add(Option($"TRÄNKEN — {string.Join(", ", game.SoakTargets().Select(c => c.Definition.Name))}",
            $"je eine Stufe höher und dunkler · +{GameController.SoakDarkness} Verdunkelung"));
        if (omen != null)
            options.Add(Option($"BINDEN — {omen.Name} kommt ins Deck",
                $"verkehrt und blutig · +{GameController.BindDarkness} Verdunkelung"));
        options.Add(Option($"BANNEN — +{GameController.BanishGold} Gold, Heilung",
            $"−{GameController.BanishLight} Verdunkelung"));
        root.Set("options", options);
        return root;
    }

    private static JsonValue Paths(GameController game)
    {
        var run = game.Run;
        var root = Screen("options", "Die Wegwahl kündigt das nächste Omen an.");
        root.Set("title", "WOHIN FÜHRT DEIN WEG?");
        root.Set("subtitle", $"{run.Deck.Count} Karten · {run.Gold} Gold · {run.Hp}/{run.MaxHp} HP · Resonanz {run.DeckResonance}/10");
        var next = run.FightIndex + 1;
        var boss = ActCatalog.IsFinale(next) ? ActCatalog.Finale : game.UpcomingBoss();
        if (boss != null)
        {
            root.Set("section", $"ALS NÄCHSTES: {boss.Name.ToUpperInvariant()}");
            root.Set("sectionText", string.Join(" ", boss.Rules.Select(r => ActCatalog.RuleText(r, 0, boss.RulesWeakened))));
        }
        var options = JsonValue.Array();
        foreach (var path in game.Paths)
        {
            var label = PathLabel(path);
            var split = label.IndexOf(" — ", StringComparison.Ordinal);
            options.Add(Option(split > 0 ? label.Substring(0, split) : label, split > 0 ? label.Substring(split + 3) : string.Empty));
        }
        root.Set("options", options);
        return root;
    }

    private static string PathLabel(PathType path)
    {
        switch (path)
        {
            case PathType.Shop: return "HÄNDLER — sein Mantel öffnet sich";
            case PathType.Ritual: return "RITUAL — forme dein Deck";
            case PathType.Oracle: return "ORAKEL — eine Prophezeiung";
            case PathType.Elite: return "ELITE — mehr Gefahr, sichere Charms";
            case PathType.Event: return "UNBEKANNT — etwas wartet am Wegrand";
            case PathType.Rest: return "RAST — heilen oder eine Karte neu lesen";
            default: return $"KAMPF — kein Umweg (+{GameController.DirectPathGold} Gold)";
        }
    }

    /// <summary>
    /// Ein Spieler nach einigen Runs: der letzte Tod erzeugt den Bericht.
    /// </summary>
    private static JsonValue Report(Autopilot pilot)
    {
        var meta = new MetaProgress();
        var withMeta = new Autopilot { Meta = meta };
        RunReport report = null;
        for (var i = 0; i < 7; i++)
        {
            var outcome = withMeta.PlayRun(3100 + i, 40);
            report = meta.CompleteRun(withMeta.LastGame, outcome.Won, outcome.DiedAgainst);
        }
        // Einen Run suchen, der knapp scheitert und etwas freischaltet.
        for (var seed = 3200; seed < 3400 && (report.Won || report.Unlocked.Count == 0); seed++)
        {
            var copy = MetaProgress.Deserialize(meta.Serialize());
            var probe = new Autopilot { Meta = copy };
            var outcome = probe.PlayRun(seed, 40);
            var candidate = copy.CompleteRun(probe.LastGame, outcome.Won, outcome.DiedAgainst);
            if (!candidate.Won && candidate.Unlocked.Count > 0) { report = candidate; break; }
        }

        var root = Screen("report", "Der Run-Bericht: erst das Erreichte, dann das Neue, zuletzt das Beinahe.");
        root.Set("title", report.Headline);
        root.Set("subtitle", (string.IsNullOrEmpty(report.KilledBy) ? string.Empty : report.KilledBy + " · ") +
                             $"Kampf {report.FightsCleared + 1} · {report.FateTotal} Fate · Verdunkelung {report.Darkness}");
        root.Set("best", report.BestHit > 0 ? $"Stärkste Legung: {report.BestHit} — {report.BestHitCombo}" : string.Empty);
        var records = JsonValue.Array();
        foreach (var r in report.Records) records.Add(JsonValue.Of(r));
        root.Set("records", records);
        var unlocked = JsonValue.Array();
        foreach (var u in report.Unlocked) unlocked.Add(JsonValue.Of(u));
        root.Set("unlocked", unlocked);
        var near = JsonValue.Array();
        foreach (var n in report.NearMisses)
            near.Add(JsonValue.Object()
                .Set("title", n.Title)
                .Set("detail", n.Detail)
                .Set("reward", n.Reward)
                .Set("progress", n.Progress));
        root.Set("near", near);
        return root;
    }

    private static JsonValue Title()
    {
        var meta = new MetaProgress();
        var pilot = new Autopilot { Meta = meta };
        for (var i = 0; i < 12; i++)
        {
            var outcome = pilot.PlayRun(5100 + i, 40);
            meta.CompleteRun(pilot.LastGame, outcome.Won, outcome.DiedAgainst);
        }

        var root = Screen("title", "Der Titelschirm: Figur, Schleier, Tageskarte.");
        root.Set("subtitle", $"{meta.RunsStarted} Runs · {meta.RunsWon} Siege · Prophezeiungen {meta.CompletedProphecies.Count}/{ProphecyCatalog.All.Count}");
        var deuters = JsonValue.Array();
        foreach (var deuter in DeuterCatalog.All)
        {
            var unlocked = meta.IsDeuterUnlocked(deuter.Id);
            deuters.Add(JsonValue.Object()
                .Set("name", deuter.Name)
                .Set("subtitle", deuter.Subtitle)
                .Set("text", unlocked ? deuter.RuleText : "Gesperrt — " + ProphecyCatalog.Find(deuter.UnlockedBy)?.Text)
                .Set("unlocked", unlocked)
                .Set("selected", deuter.Id == DeuterCatalog.DefaultId));
        }
        root.Set("deuters", deuters);
        var veil = VeilCatalog.Get(meta.Veil);
        root.Set("veil", $"SCHLEIER {veil.Level}: {veil.Name} — {veil.Text}");
        var daily = RunSetup.Daily(new DateTime(2026, 9, 24, 8, 0, 0, DateTimeKind.Utc));
        root.Set("daily", $"TAGESKARTE — {DeuterCatalog.Find(daily.DeuterId).Name}, Schleier {daily.Veil}");
        return root;
    }

    private static JsonValue Reward(GameController game)
    {
        var root = Screen("options", "Nach dem Sieg: eine Karte, oder ein dünneres Deck.");
        root.Set("title", "WÄHLE EINE BELOHNUNG");
        root.Set("subtitle", game.Message ?? "");
        var options = JsonValue.Array();
        foreach (var reward in game.Rewards) options.Add(Option(reward.Title, reward.Description));
        options.Add(Option("ÜBERSPRINGEN", "Fate statt Karte — dein Deck bleibt dünn."));
        root.Set("options", options);
        return root;
    }

    private static JsonValue Shop(GameController game)
    {
        var root = Screen("shop", "Der Händler — Vergessen und Veredeln als Goldsenken.");
        root.Set("title", "DER HÄNDLER");
        root.Set("subtitle", $"{game.Run.Gold} Gold");
        root.Set("removalPrice", game.RemovalPrice);
        root.Set("refinePrice", game.RefinePrice);
        var offers = JsonValue.Array();
        foreach (var offer in game.ShopOffers)
            offers.Add(JsonValue.Object()
                .Set("title", offer.Reward.Title)
                .Set("text", offer.Reward.Description)
                .Set("price", offer.Price));
        root.Set("offers", offers);
        var deck = JsonValue.Array();
        foreach (var card in game.Run.Deck) deck.Add(Card(card, null));
        root.Set("deck", deck);
        return root;
    }

    // ---------------------------------------------------------- Helfer
    private static JsonValue Option(string title, string text) =>
        JsonValue.Object().Set("title", title).Set("text", text ?? string.Empty);

    private static JsonValue Screen(string kind, string caption) =>
        JsonValue.Object().Set("screen", kind).Set("caption", caption);

    private static JsonValue Charms(GameController game)
    {
        var charms = JsonValue.Array();
        foreach (var pair in game.Run.Charms.Where(p => p.Value > 0))
        {
            var definition = GameCatalog.Charms.FirstOrDefault(c => c.Id == pair.Key);
            if (definition == null) continue;
            charms.Add(JsonValue.Object()
                .Set("name", definition.Name)
                .Set("count", pair.Value));
        }
        return charms;
    }

    private static JsonValue Card(CardInstance card, CombatState combat) => JsonValue.Object()
        .Set("head", Head(card))
        .Set("suit", card.Definition.Suit.ToString())
        .Set("name", card.Definition.Name)
        .Set("text", card.Definition.Description)
        .Set("shimmer", card.Shimmer.ToString())
        .Set("reversed", card.Orientation == Orientation.Reversed)
        .Set("rage", card.Rage)
        .Set("level", card.Level)
        .Set("veiled", combat != null && combat.VeiledCards.Contains(card.InstanceId))
        .Set("mark", combat != null && combat.MarkedCardId == card.InstanceId ? combat.MarkTurnsLeft : 0);

    private static string Head(CardInstance card)
    {
        var roman = new[] { "0","I","II","III","IV","V","VI","VII","VIII","IX","X",
                            "XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX","XXI" };
        var head = card.Definition.IsMajor && card.Definition.DisplayNumber < roman.Length
            ? roman[card.Definition.DisplayNumber]
            : card.Definition.Rank.ToString();
        return head + new string('+', Math.Max(0, Math.Min(3, card.Level - 1)));
    }

    private static string IntentText(EnemyState enemy)
    {
        switch (enemy.Intent)
        {
            case IntentType.Guard: return $"{enemy.IntentValue} Schild";
            case IntentType.Hex: return $"Fluch — {enemy.IntentValue / 2} Schaden, −1 Luck";
            case IntentType.Drain: return $"{enemy.IntentValue} Schaden, heilt sich";
            case IntentType.Frenzy: return $"2 × {enemy.IntentValue} Schaden";
            default: return $"{enemy.IntentValue} Schaden";
        }
    }

    private static void Save(string directory, string name, JsonValue value) =>
        File.WriteAllText(Path.Combine(directory, name + ".json"), Json.Write(value, indented: true));
}
