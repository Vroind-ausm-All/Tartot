// Seltenheit (wie selten eine Karte auftaucht) und Edition (wie eine
// einzelne Karte im Deck veredelt ist) - angelehnt an Balatro, aber in
// TARTOTs Palette und mit TARTOTs Zahlen.
using System.Collections.Generic;
using System.Globalization;

namespace Tartot.Core
{
    /// <summary>Wie selten eine Karte ist. Haengt nur an der Definition.</summary>
    public enum Rarity { Common, Uncommon, Rare, Legendary }

    /// <summary>
    /// Die Veredelung einer einzelnen Karte. Unabhaengig vom Schimmer
    /// (der Verdunkelungsachse Matt bis Schwarz): eine Karte kann blutig
    /// schimmern UND glaesern sein.
    /// </summary>
    public enum CardEdition { None, Shimmering, Glowing, Burning, Glass }

    public static class Rarities
    {
        /// <summary>Die drei Legendaeren: Anfang, Wendepunkt, Ende.</summary>
        public static readonly HashSet<int> LegendaryMajors = new HashSet<int> { 0, 10, 21 };

        public static Rarity Of(CardDefinition card)
        {
            if (card.IsMajor)
                return card.Major.HasValue && LegendaryMajors.Contains((int)card.Major.Value) ? Rarity.Legendary : Rarity.Rare;
            return card.Rank >= 11 ? Rarity.Uncommon : Rarity.Common;
        }

        public static string Name(Rarity rarity)
        {
            switch (rarity)
            {
                case Rarity.Uncommon: return "Ungewöhnlich";
                case Rarity.Rare: return "Selten";
                case Rarity.Legendary: return "Legendär";
                default: return "Gewöhnlich";
            }
        }

        /// <summary>Farbe der Plakette (Palette der Stilbibel).</summary>
        public static string Color(Rarity rarity)
        {
            switch (rarity)
            {
                case Rarity.Uncommon: return "#3B4A8C";
                case Rarity.Rare: return "#B3262B";
                case Rarity.Legendary: return "#E3A83B";
                default: return "#8F7A5A";
            }
        }
    }

    public static class CardEditions
    {
        public const int ShimmerChips = 6;
        public const float GlowMult = .4f;
        public const float BurnXMult = 1.4f;
        public const int BurnBrand = 3;
        public const int BurnSelfDamage = 2;
        public const float GlassXMult = 1.8f;
        public const float GlassShatterChance = .25f;

        public static readonly CardEdition[] All =
            { CardEdition.Shimmering, CardEdition.Glowing, CardEdition.Burning, CardEdition.Glass };

        public static string Name(CardEdition edition)
        {
            switch (edition)
            {
                case CardEdition.Shimmering: return "Schimmernd";
                case CardEdition.Glowing: return "Leuchtend";
                case CardEdition.Burning: return "Brennend";
                case CardEdition.Glass: return "Gläsern";
                default: return string.Empty;
            }
        }

        public static string Text(CardEdition edition)
        {
            switch (edition)
            {
                case CardEdition.Shimmering: return $"+{ShimmerChips} Chips";
                case CardEdition.Glowing: return $"+{De(GlowMult)} Mult";
                case CardEdition.Burning: return $"×{De(BurnXMult)} Mult, +{BurnBrand} Brand beim Gegner, kostet {BurnSelfDamage} LP";
                case CardEdition.Glass: return $"×{De(GlassXMult)} Mult, zerspringt zu {GlassShatterChance * 100:0} %";
                default: return string.Empty;
            }
        }

        /// <summary>Deutsches Komma, unabhaengig von der Geraetesprache.</summary>
        private static string De(float value) => value.ToString("0.0", CultureInfo.InvariantCulture).Replace('.', ',');

        public static int Chips(CardEdition edition) => edition == CardEdition.Shimmering ? ShimmerChips : 0;
        public static float MultAdd(CardEdition edition) => edition == CardEdition.Glowing ? GlowMult : 0f;

        public static float MultX(CardEdition edition) =>
            edition == CardEdition.Burning ? BurnXMult : edition == CardEdition.Glass ? GlassXMult : 1f;

        /// <summary>
        /// Editionschance einer Belohnungskarte in Promille, je Edition.
        /// Zusammen gut 5 %: selten genug, dass jede ein Ereignis ist.
        /// </summary>
        public static readonly Dictionary<CardEdition, int> RewardPermille = new Dictionary<CardEdition, int>
        {
            [CardEdition.Shimmering] = 25,
            [CardEdition.Glowing] = 15,
            [CardEdition.Burning] = 8,
            [CardEdition.Glass] = 7
        };
    }

    /// <summary>
    /// Ein Schritt der Wertung, fuer die Kaskade in der Oberflaeche: erst
    /// zaehlt jede Karte ihre Chips, dann kommen Muster und Editionen.
    /// </summary>
    public sealed class ScoreStep
    {
        /// <summary>Instanz-Id der Karte; leer fuer Schritte ohne Karte (Muster, Position).</summary>
        public string InstanceId = string.Empty;
        public string Label = string.Empty;
        public int Chips;
        public float MultAdd;
        /// <summary>Faktor auf den Multiplikator (1 = keiner).</summary>
        public float MultX = 1f;
        public CardEdition Edition;
    }
}
