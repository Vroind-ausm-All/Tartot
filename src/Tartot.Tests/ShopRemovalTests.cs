using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Vergessen beim Haendler: die Goldsenke. Gold war ab der Deckmitte eine
    /// tote Ressource, und gleichzeitig gab es zu wenige Gelegenheiten, das
    /// Deck auszuduennen. Beides loest derselbe Dienst.
    /// </summary>
    public class ShopRemovalTests
    {
        private static GameController InShop(int seed = 4242, int gold = 500)
        {
            var game = new GameController(seed);
            game.OpenShop();
            game.Run.Gold = gold;
            return game;
        }

        [Fact]
        public void RemovingACard_CostsGoldAndShrinksTheDeck()
        {
            var game = InShop();
            var card = game.Run.Deck[0];
            var deckBefore = game.Run.Deck.Count;
            var goldBefore = game.Run.Gold;
            var price = game.RemovalPrice;

            Assert.True(game.RemoveCardAtShop(card));

            Assert.Equal(deckBefore - 1, game.Run.Deck.Count);
            Assert.Equal(goldBefore - price, game.Run.Gold);
            Assert.DoesNotContain(card, game.Run.Deck);
            Assert.Contains(card, game.Run.RemovedCards);
        }

        [Fact]
        public void ThePriceRisesWithEachRemoval()
        {
            var game = InShop();
            var first = game.RemovalPrice;
            game.RemoveCardAtShop(game.Run.Deck[0]);
            var second = game.RemovalPrice;
            game.RemoveCardAtShop(game.Run.Deck[0]);
            var third = game.RemovalPrice;

            Assert.True(second > first, $"{second} muss ueber {first} liegen.");
            Assert.True(third > second, $"{third} muss ueber {second} liegen.");
            Assert.Equal(GameController.RemovalPriceStep, second - first);
        }

        [Fact]
        public void WithoutEnoughGold_NothingHappens()
        {
            var game = InShop(gold: 0);
            var deckBefore = game.Run.Deck.Count;

            Assert.False(game.RemoveCardAtShop(game.Run.Deck[0]));

            Assert.Equal(deckBefore, game.Run.Deck.Count);
            Assert.Equal(0, game.Run.Gold);
        }

        [Fact]
        public void TheDeckCannotShrinkBelowTheMinimum()
        {
            var game = InShop();
            while (game.Run.Deck.Count > GameCatalog.MinimumDeckSize)
                Assert.True(game.RemoveCardAtShop(game.Run.Deck[0]));

            Assert.Equal(GameCatalog.MinimumDeckSize, game.Run.Deck.Count);
            Assert.False(game.RemoveCardAtShop(game.Run.Deck[0]));
        }

        [Fact]
        public void OnlyAvailableInTheShop()
        {
            var game = new GameController(7);   // Phase: Kampf
            Assert.False(game.CanRemoveAtShop(game.Run.Deck[0]));
            Assert.False(game.RemoveCardAtShop(game.Run.Deck[0]));
        }

        [Fact]
        public void ForeignCardsAreRejected()
        {
            var game = InShop();
            var stranger = new CardInstance(GameCatalog.Card("swords_7"));
            Assert.False(game.CanRemoveAtShop(stranger));
            Assert.False(game.RemoveCardAtShop(stranger));
        }

        [Fact]
        public void TheShopDiscountCharmApplies()
        {
            var full = InShop();
            var fullPrice = full.RemovalPrice;

            var discounted = InShop();
            var charm = TestWorld.CharmWith(CharmEffectType.ShopDiscount);
            discounted.Run.AddCharm(charm, charm.MaxStacks);

            Assert.True(discounted.RemovalPrice < fullPrice,
                $"Rabatt muss greifen ({discounted.RemovalPrice} gegen {fullPrice}).");
        }

        [Fact]
        public void RemovingRaisesDeckResonance()
        {
            // Der Dienst staerkt den Ausduenn-Hebel, nicht nur die Goldbilanz.
            var game = InShop();
            var before = game.Run.DeckResonance;
            for (var i = 0; i < 3; i++) game.RemoveCardAtShop(game.Run.Deck[0]);
            Assert.True(game.Run.DeckResonance > before,
                $"Resonanz muss steigen ({game.Run.DeckResonance} gegen {before}).");
        }

        [Fact]
        public void TheRemovalSurvivesSaveAndLoad()
        {
            var game = InShop();
            game.RemoveCardAtShop(game.Run.Deck[0]);
            game.RemoveCardAtShop(game.Run.Deck[0]);
            var deckSize = game.Run.Deck.Count;
            var price = game.RemovalPrice;

            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            Assert.Equal(deckSize, restored.Run.Deck.Count);
            Assert.Equal(2, restored.Run.ShopRemovals);
            Assert.Equal(price, restored.RemovalPrice);
        }
    }
}
