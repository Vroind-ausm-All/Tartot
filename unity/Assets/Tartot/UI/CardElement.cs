using System;
using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Eine Karte auf dem Bildschirm.
    /// </summary>
    /// <remarks>
    /// Leitsatz der Artdirection: Man erkennt die Karte an ihrer Silhouette,
    /// der Text ist sekundaer. Deshalb dominiert das Symbol, die Zahl steht
    /// oben, der Effekttext klein darunter.
    ///
    /// Die Farbgebung kommt vollstaendig aus USS-Klassen - hier steht kein
    /// einziger Farbwert.
    /// </remarks>
    public sealed class CardElement : VisualElement
    {
        public CardInstance Card { get; }

        private readonly Label _head;
        private readonly Label _symbol;
        private readonly Label _text;
        private readonly Label _rage;

        /// <param name="veiled">Der Mond: nur die Rueckseite zeigen.</param>
        /// <param name="deathMark">Der Tod: verbleibende Runden, 0 = nicht gezeichnet.</param>
        public CardElement(CardInstance card, Action<CardElement> onClick = null,
            bool veiled = false, int deathMark = 0)
        {
            Card = card;
            AddToClassList("karte");

            if (veiled)
            {
                // Verdeckt verraet die Karte nichts - weder Farbe noch Wert
                // noch Orientierung. Man legt sie im Vertrauen.
                AddToClassList("karte--verdeckt");
                _head = new Label { text = "?" };
                _head.AddToClassList("karte__kopf");
                Add(_head);
                _symbol = new Label { text = "☾" };
                _symbol.AddToClassList("karte__symbol");
                Add(_symbol);
                _rage = new Label { text = string.Empty };
                _rage.AddToClassList("karte__rage");
                Add(_rage);
                _text = new Label { text = "Im Mondlicht verborgen." };
                _text.AddToClassList("karte__text");
                Add(_text);
                if (onClick != null)
                    RegisterCallback<ClickEvent>(_ => onClick(this));
                return;
            }

            AddToClassList(SuitClass(card.Definition.Suit));
            AddToClassList(ShimmerClass(card.Shimmer));
            if (IsDark(card)) AddToClassList("karte--dunkel");
            if (deathMark > 0) AddToClassList("karte--gezeichnet");

            _head = new Label { text = HeadText(card) };
            _head.AddToClassList("karte__kopf");
            Add(_head);

            _symbol = new Label { text = SuitSymbol(card.Definition.Suit) };
            _symbol.AddToClassList("karte__symbol");
            // Umgekehrt wird nicht durchgestrichen, sondern gedreht: es ist eine
            // andere Karte, keine schlechtere.
            if (card.Orientation == Orientation.Reversed)
                _symbol.style.rotate = new Rotate(180f);
            Add(_symbol);

            if (deathMark > 0)
            {
                var mark = new Label { text = $"☠ {deathMark}" };
                mark.AddToClassList("karte__zeichen");
                Add(mark);
            }

            _rage = new Label { text = card.Rage > 0 ? $"RAGE {card.Rage}/3" : string.Empty };
            _rage.AddToClassList("karte__rage");
            Add(_rage);

            _text = new Label { text = card.Definition.Description };
            _text.AddToClassList("karte__text");
            Add(_text);

            if (onClick != null)
                RegisterCallback<ClickEvent>(_ => onClick(this));
        }

        public void SetSelected(bool selected) => EnableInClassList("karte--gewaehlt", selected);

        private static string HeadText(CardInstance card)
        {
            var name = card.Definition.IsMajor
                ? Roman(card.Definition.DisplayNumber)
                : card.Definition.Rank.ToString();
            var level = card.Level > 1 ? new string('+', Math.Min(3, card.Level - 1)) : string.Empty;
            return name + level;
        }

        private static string SuitSymbol(Suit suit)
        {
            switch (suit)
            {
                case Suit.Swords: return "⚔";     // gekreuzte Schwerter
                case Suit.Wands: return "✸";      // Funke
                case Suit.Cups: return "♥";       // Herz
                case Suit.Pentacles: return "◆";  // Raute
                default: return "★";              // Stern
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

        /// <summary>Ab Gold ist die Karte zu dunkel fuer schwarze Schrift.</summary>
        private static bool IsDark(CardInstance card) =>
            card.Shimmer >= Shimmer.Gold || card.Definition.IsMajor;

        private static readonly string[] RomanNumerals =
        {
            "0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
            "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI"
        };

        private static string Roman(int value) =>
            value >= 0 && value < RomanNumerals.Length ? RomanNumerals[value] : value.ToString();
    }
}
