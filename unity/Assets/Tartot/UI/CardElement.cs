using System;
using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>Eine Karte als Filmkader: Rang, Motivsymbol, kurze Wirkung und Perforationsrand.</summary>
    public sealed class CardElement : VisualElement
    {
        public CardInstance Card { get; }

        private readonly Label _head;
        private readonly VisualElement _symbol;
        private readonly Label _text;
        private readonly Label _rage;

        public CardElement(CardInstance card, Action<CardElement> onClick = null,
            bool veiled = false, int deathMark = 0)
        {
            Card = card;
            AddToClassList("karte");
            AddPerforation();

            if (veiled)
            {
                AddToClassList("karte--verdeckt");
                _head = new Label { text = "?" }; _head.AddToClassList("karte__kopf"); Add(_head);
                _symbol = new VisualElement(); _symbol.AddToClassList("karte__symbol"); _symbol.style.backgroundImage = new StyleBackground(TartotPixelArt.SuitIcon("moon")); Add(_symbol);
                _rage = new Label { text = string.Empty }; _rage.AddToClassList("karte__rage"); Add(_rage);
                _text = new Label { text = "IM MONDLICHT" }; _text.AddToClassList("karte__text"); Add(_text);
                if (onClick != null) RegisterCallback<ClickEvent>(_ => onClick(this));
                return;
            }

            AddToClassList(SuitClass(card.Definition.Suit));
            AddToClassList(ShimmerClass(card.Shimmer));
            if (IsDark(card)) AddToClassList("karte--dunkel");
            if (deathMark > 0) AddToClassList("karte--gezeichnet");

            _head = new Label { text = HeadText(card) }; _head.AddToClassList("karte__kopf"); Add(_head);

            _symbol = new VisualElement();
            _symbol.AddToClassList("karte__symbol");
            _symbol.style.backgroundImage = new StyleBackground(TartotPixelArt.SuitIcon(SuitIcon(card.Definition.Suit)));
            if (card.Orientation == Orientation.Reversed) _symbol.style.rotate = new Rotate(180f);
            Add(_symbol);

            if (deathMark > 0)
            {
                var mark = new Label { text = $"TOD {deathMark}" }; mark.AddToClassList("karte__zeichen"); Add(mark);
            }

            _rage = new Label { text = card.Rage > 0 ? $"RAGE {card.Rage}/3" : string.Empty }; _rage.AddToClassList("karte__rage"); Add(_rage);
            _text = new Label { text = ShortText(card.Definition.Description) }; _text.AddToClassList("karte__text"); Add(_text);

            if (onClick != null) RegisterCallback<ClickEvent>(_ => onClick(this));
        }

        public void SetSelected(bool selected) => EnableInClassList("karte--gewaehlt", selected);

        private void AddPerforation()
        {
            var left = new VisualElement(); left.AddToClassList("karte__perf"); left.AddToClassList("karte__perf--links"); Add(left);
            var right = new VisualElement(); right.AddToClassList("karte__perf"); right.AddToClassList("karte__perf--rechts"); Add(right);
        }

        private static string ShortText(string text)
        {
            if (string.IsNullOrEmpty(text)) return string.Empty;
            var stop = text.IndexOf('.');
            var shortText = stop > 0 ? text.Substring(0, stop) : text;
            return shortText.Length <= 34 ? shortText.ToUpperInvariant() : shortText.Substring(0, 31).ToUpperInvariant() + "…";
        }

        private static string HeadText(CardInstance card)
        {
            var name = card.Definition.IsMajor ? Roman(card.Definition.DisplayNumber) : card.Definition.Rank.ToString();
            var level = card.Level > 1 ? new string('+', Math.Min(3, card.Level - 1)) : string.Empty;
            return name + level;
        }

        private static string SuitIcon(Suit suit)
        {
            switch (suit)
            {
                case Suit.Swords: return "swords";
                case Suit.Wands: return "wands";
                case Suit.Cups: return "cups";
                case Suit.Pentacles: return "pentacles";
                default: return "major";
            }
        }

        private static string SuitClass(Suit suit)
        {
            switch (suit)
            {
                case Suit.Swords: return "karte--schwerter";
                case Suit.Wands: return "karte--staebe";
                case Suit.Cups: return "karte--kelche";
                case Suit.Pentacles: return "karte--muenzen";
                default: return "karte--arkana";
            }
        }

        private static string ShimmerClass(Shimmer shimmer)
        {
            switch (shimmer)
            {
                case Shimmer.White: return "karte--weiss";
                case Shimmer.Indigo: return "karte--indigoschimmer";
                case Shimmer.Gold: return "karte--gold";
                case Shimmer.Blood: return "karte--blut";
                case Shimmer.Black: return "karte--schwarz";
                default: return "karte--matt";
            }
        }

        private static bool IsDark(CardInstance card) => card.Shimmer >= Shimmer.Gold || card.Definition.IsMajor;

        private static readonly string[] RomanNumerals =
        {
            "0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"
        };

        private static string Roman(int value) => value >= 0 && value < RomanNumerals.Length ? RomanNumerals[value] : value.ToString();
    }
}
