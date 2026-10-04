using System;
using System.Collections.Generic;
using Tartot.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>Eine Karte als physischer Papier-Gegenstand.</summary>
    public sealed class CardElement : VisualElement
    {
        public CardInstance Card { get; }

        private readonly Label _head;
        private readonly Label _symbol;
        private readonly Label _name;
        private readonly Label _text;
        private readonly Label _rage;
        private readonly VisualElement _art;
        private readonly VisualElement _frame;

        private static readonly Dictionary<string, Texture2D> ArtCache =
            new Dictionary<string, Texture2D>();

        public CardElement(CardInstance card, Action<CardElement> onClick = null,
            bool veiled = false, int deathMark = 0)
        {
            Card = card;
            AddToClassList("karte");

            if (veiled)
            {
                AddToClassList("karte--verdeckt");
                _head = new Label { text = "?" };
                _head.AddToClassList("karte__kopf");
                Add(_head);

                _art = new VisualElement();
                _art.AddToClassList("karte__motiv");
                _art.AddToClassList("karte__rueckseite");
                SetTexture(_art, Load("Tartot/CardArt/rueckseite"));
                Add(_art);

                _symbol = new Label { text = "☾" };
                _symbol.AddToClassList("karte__symbol");
                Add(_symbol);

                _name = new Label { text = "IM MONDLICHT" };
                _name.AddToClassList("karte__name");
                Add(_name);

                _rage = new Label { text = string.Empty };
                _rage.AddToClassList("karte__rage");
                Add(_rage);

                _text = new Label { text = "Verborgen." };
                _text.AddToClassList("karte__text");
                Add(_text);

                _frame = Frame();
                Add(_frame);
                RegisterClick(onClick);
                return;
            }

            AddToClassList(SuitClass(card.Definition.Suit));
            AddToClassList(ShimmerClass(card.Shimmer));
            if (IsDark(card)) AddToClassList("karte--dunkel");
            if (deathMark > 0) AddToClassList("karte--gezeichnet");
            if (card.Orientation == Orientation.Reversed) AddToClassList("karte--verkehrt");
            AddToClassList("karte--selten-" + card.Definition.Rarity.ToString().ToLowerInvariant());
            if (card.Edition != CardEdition.None)
                AddToClassList("karte--edition-" + card.Edition.ToString().ToLowerInvariant());

            _head = new Label { text = HeadText(card) };
            _head.AddToClassList("karte__kopf");
            Add(_head);

            _art = new VisualElement();
            _art.AddToClassList("karte__motiv");
            var art = ArtFor(card.Definition);
            if (art != null)
            {
                SetTexture(_art, art);
                AddToClassList("karte--mit-motiv");
            }
            else AddToClassList("karte--ohne-motiv");
            Add(_art);

            _symbol = new Label { text = SuitSymbol(card.Definition.Suit) };
            _symbol.AddToClassList("karte__symbol");
            Add(_symbol);

            _name = new Label { text = card.Definition.Name.ToUpperInvariant() };
            _name.AddToClassList("karte__name");
            Add(_name);

            if (deathMark > 0)
            {
                var mark = new Label { text = "☠ " + deathMark };
                mark.AddToClassList("karte__zeichen");
                Add(mark);
            }

            _rage = new Label { text = card.Rage > 0 ? "RAGE " + card.Rage + "/3" : string.Empty };
            _rage.AddToClassList("karte__rage");
            Add(_rage);

            var badge = new Label
            {
                text = Rarities.Name(card.Definition.Rarity)
                    + (card.Edition != CardEdition.None ? " · " + CardEditions.Name(card.Edition) : string.Empty)
            };
            badge.AddToClassList("karte__plakette");
            Add(badge);

            _text = new Label
            {
                text = card.Definition.Description
                    + (card.Edition != CardEdition.None ? "\n" + CardEditions.Text(card.Edition) : string.Empty)
            };
            _text.AddToClassList("karte__text");
            Add(_text);

            _frame = Frame();
            Add(_frame);
            RegisterClick(onClick);
        }

        public void SetSelected(bool selected) => EnableInClassList("karte--gewaehlt", selected);

        private void RegisterClick(Action<CardElement> onClick)
        {
            if (onClick != null) RegisterCallback<ClickEvent>(_ => onClick(this));
        }

        private static VisualElement Frame()
        {
            var frame = new VisualElement();
            frame.AddToClassList("karte__rahmen");
            SetTexture(frame, Load("Tartot/CardArt/rahmen"));
            return frame;
        }

        private static Texture2D ArtFor(CardDefinition definition)
        {
            var exact = Load("Tartot/CardArt/" + definition.Id);
            if (exact != null) return exact;
            if (definition.IsMajor) return null;

            var prefix = definition.Suit.ToString().ToLowerInvariant();
            for (var distance = 1; distance <= 13; distance++)
            {
                var low = definition.Rank - distance;
                if (low >= 1)
                {
                    var image = Load("Tartot/CardArt/" + prefix + "_" + low);
                    if (image != null) return image;
                }

                var high = definition.Rank + distance;
                if (high <= 14)
                {
                    var image = Load("Tartot/CardArt/" + prefix + "_" + high);
                    if (image != null) return image;
                }
            }
            return null;
        }

        private static Texture2D Load(string path)
        {
            if (ArtCache.TryGetValue(path, out var cached)) return cached;
            var texture = Resources.Load<Texture2D>(path);
            ArtCache[path] = texture;
            return texture;
        }

        private static void SetTexture(VisualElement element, Texture2D texture)
        {
            if (element != null) element.style.backgroundImage = new StyleBackground(texture);
        }

        private static string HeadText(CardInstance card)
        {
            var name = card.Definition.IsMajor ? Roman(card.Definition.DisplayNumber) : card.Definition.Rank.ToString();
            var level = card.Level > 1 ? new string('+', Math.Min(3, card.Level - 1)) : string.Empty;
            return name + level;
        }

        private static string SuitSymbol(Suit suit)
        {
            switch (suit)
            {
                case Suit.Swords: return "⚔";
                case Suit.Wands: return "✸";
                case Suit.Cups: return "♥";
                case Suit.Pentacles: return "◆";
                default: return "★";
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
