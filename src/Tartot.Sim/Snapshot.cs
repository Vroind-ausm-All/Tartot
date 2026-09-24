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

        // 2. Legung gefuellt: Vorschau sichtbar, bevor ausgefuehrt wird.
        PlaceBestThree(game);
        Save(directory, "02_legung", Combat(game, "Drei Karten liegen. Die Vorschau rechnet mit."));

        // 3. Nach ein paar Zuegen: Haltung angeschlagen, Status sichtbar.
        game.ResolveTurn();
        for (var i = 0; i < 2 && game.Phase == GamePhase.Combat; i++)
        {
            PlaceBestThree(game);
            game.ResolveTurn();
        }
        if (game.Phase == GamePhase.Combat)
        {
            PlaceBestThree(game);
            Save(directory, "03_kampf_spaet", Combat(game, "Spaeter im Kampf."));
        }

        // 4. Belohnung und 5. Haendler.
        var rewardGame = new GameController(4711);
        pilot.PlayCombat(rewardGame);
        if (rewardGame.Phase == GamePhase.Reward)
            Save(directory, "04_belohnung", Reward(rewardGame));

        var shopGame = new GameController(99);
        shopGame.Run.Gold = 240;
        shopGame.OpenShop();
        Save(directory, "05_haendler", Shop(shopGame));

        Console.WriteLine($"Zustaende geschrieben nach {directory}");
    }

    private static void PlaceBestThree(GameController game)
    {
        var slots = new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future };
        var hand = game.Combat.Hand.OrderByDescending(c => c.EffectiveRank).Take(3).ToList();
        for (var i = 0; i < hand.Count; i++)
            game.CombatSystem.PlaceCard(game.Combat, hand[i].InstanceId, slots[i]);
    }

    private static JsonValue Combat(GameController game, string caption)
    {
        var enemy = game.Combat.Enemy;
        var root = Screen("combat", caption);

        root.Set("enemy", JsonValue.Object()
            .Set("name", enemy.Definition.Name)
            .Set("hp", Math.Max(0, enemy.Hp))
            .Set("maxHp", enemy.Definition.MaxHp)
            .Set("stance", Math.Max(0, enemy.Stance))
            .Set("maxStance", enemy.Definition.MaxStance)
            .Set("sigils", enemy.Sigils)
            .Set("burn", enemy.Burn)
            .Set("intent", IntentText(enemy)));

        root.Set("player", JsonValue.Object()
            .Set("hp", game.Run.Hp)
            .Set("maxHp", game.Run.MaxHp)
            .Set("shield", game.Combat.PlayerShield)
            .Set("fate", game.Run.Fate)
            .Set("luck", game.Combat.TemporaryLuck)
            .Set("fight", game.Run.FightIndex + 1)
            .Set("turn", game.Combat.Turn)
            .Set("resonance", game.Run.DeckResonance));

        root.Set("charms", Charms(game));

        var slots = JsonValue.Object();
        foreach (var slot in new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future })
            slots.Set(slot.ToString(),
                game.Combat.Slots.TryGetValue(slot, out var card) ? Card(card) : JsonValue.Null());
        root.Set("slots", slots);

        var hand = JsonValue.Array();
        foreach (var card in game.Combat.Hand) hand.Add(Card(card));
        root.Set("hand", hand);

        var score = game.PreviewScore();
        root.Set("preview", score == null || game.Combat.Slots.Count == 0
            ? ""
            : $"{score.ComboName}: {score.Chips} × {score.Multiplier:0.00}"
              + (score.RepeatPenalty < 1f ? $" × Wdh. {score.RepeatPenalty:0.00}" : "")
              + $" = {score.FateDamage}");
        root.Set("log", game.Message ?? "");
        return root;
    }

    private static JsonValue Reward(GameController game)
    {
        var root = Screen("reward", "Nach dem Sieg: eine Karte, oder ein dünneres Deck.");
        root.Set("title", "WÄHLE EINE BELOHNUNG");
        root.Set("subtitle", game.Message ?? "");
        var options = JsonValue.Array();
        foreach (var reward in game.Rewards)
            options.Add(JsonValue.Object()
                .Set("title", reward.Title)
                .Set("text", reward.Description)
                .Set("kind", reward.Type.ToString()));
        root.Set("options", options);
        root.Set("charms", Charms(game));
        return root;
    }

    private static JsonValue Shop(GameController game)
    {
        var root = Screen("shop", "Der Händler — und das Vergessen als Goldsenke.");
        root.Set("title", "DER HÄNDLER");
        root.Set("subtitle", $"{game.Run.Gold} Gold");
        root.Set("removalPrice", game.RemovalPrice);
        var offers = JsonValue.Array();
        foreach (var offer in game.ShopOffers)
            offers.Add(JsonValue.Object()
                .Set("title", offer.Reward.Title)
                .Set("text", offer.Reward.Description)
                .Set("price", offer.Price));
        root.Set("offers", offers);
        var deck = JsonValue.Array();
        foreach (var card in game.Run.Deck) deck.Add(Card(card));
        root.Set("deck", deck);
        root.Set("charms", Charms(game));
        return root;
    }

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

    private static JsonValue Card(CardInstance card) => JsonValue.Object()
        .Set("head", Head(card))
        .Set("suit", card.Definition.Suit.ToString())
        .Set("name", card.Definition.Name)
        .Set("text", card.Definition.Description)
        .Set("shimmer", card.Shimmer.ToString())
        .Set("reversed", card.Orientation == Orientation.Reversed)
        .Set("rage", card.Rage)
        .Set("level", card.Level);

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
