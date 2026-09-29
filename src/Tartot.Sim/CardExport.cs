using System;
using System.IO;
using System.Linq;
using Tartot.Core;

/// <summary>
/// Schreibt den Kartenkatalog als JSON fuer andere Oberflaechen (Godot-Addon
/// tartot_karten). Die Regeln bleiben im Kern - die Oberflaeche liest nur,
/// was auf der Karte steht, wie selten sie ist und was Editionen bewirken.
/// </summary>
public static class CardExport
{
    public static void Write(string path)
    {
        var cards = JsonValue.Array();
        foreach (var card in GameCatalog.Cards)
        {
            cards.Add(JsonValue.Object()
                .Set("id", card.Id)
                .Set("name", card.Name)
                .Set("suit", card.Suit.ToString())
                .Set("rank", card.Rank)
                .Set("number", card.IsMajor ? MetaProgress.Roman(card.DisplayNumber) : card.DisplayNumber.ToString())
                .Set("rarity", card.Rarity.ToString())
                .Set("power", card.BasePower)
                .Set("text", card.Description ?? string.Empty));
        }

        var rarities = JsonValue.Object();
        foreach (Rarity r in Enum.GetValues(typeof(Rarity)))
            rarities.Set(r.ToString(), JsonValue.Object()
                .Set("name", Rarities.Name(r))
                .Set("color", Rarities.Color(r)));

        var editions = JsonValue.Object();
        foreach (var e in CardEditions.All)
            editions.Set(e.ToString(), JsonValue.Object()
                .Set("name", CardEditions.Name(e))
                .Set("text", CardEditions.Text(e))
                .Set("chips", CardEditions.Chips(e))
                .Set("mult", Math.Round((double)CardEditions.MultAdd(e), 3))
                .Set("xmult", Math.Round((double)CardEditions.MultX(e), 3)));

        var root = JsonValue.Object()
            .Set("quelle", "Tartot.Core - erzeugt mit: dotnet run --project src/Tartot.Sim -- --export-cards=<pfad>")
            .Set("cards", cards)
            .Set("rarities", rarities)
            .Set("editions", editions);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path)));
        File.WriteAllText(path, Json.Write(root, true));
        Console.WriteLine($"{GameCatalog.Cards.Count} Karten nach {path}");
    }
}
