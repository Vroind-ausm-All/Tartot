using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    public class JsonTests
    {
        [Fact]
        public void RoundTrip_PreservesValues()
        {
            var original = JsonValue.Object()
                .Set("text", "Hallo")
                .Set("zahl", 42)
                .Set("komma", 1.5)
                .Set("wahr", true)
                .Set("liste", JsonValue.Array().Add(JsonValue.Of(1)).Add(JsonValue.Of("zwei")));

            var parsed = Json.Parse(Json.Write(original));

            Assert.Equal("Hallo", parsed.GetString("text"));
            Assert.Equal(42, parsed.GetInt("zahl"));
            Assert.Equal(1.5f, parsed.GetFloat("komma"), 3);
            Assert.True(parsed.GetBool("wahr"));
            Assert.Equal(2, parsed.GetArray("liste").Count);
        }

        [Fact]
        public void Strings_SurviveEscapingAndUmlauts()
        {
            var tricky = "Zeile\nTab\t\"Anfuehrung\" \\Backslash\\ Umlaute: äöüß – Mond ☽";
            var parsed = Json.Parse(Json.Write(JsonValue.Object().Set("s", tricky)));
            Assert.Equal(tricky, parsed.GetString("s"));
        }

        [Fact]
        public void Numbers_UseInvariantCulture()
        {
            // Auf einem deutschen Geraet darf kein Komma im JSON landen.
            var text = Json.Write(JsonValue.Object().Set("x", 1.25));
            Assert.Contains("1.25", text);
            Assert.DoesNotContain("1,25", text);
        }

        [Fact]
        public void MissingFields_FallBackInsteadOfThrowing()
        {
            // Aeltere Speicherstaende muessen weiter laden.
            var parsed = Json.Parse("{\"a\":1}");
            Assert.Equal(7, parsed.GetInt("fehlt", 7));
            Assert.Equal("x", parsed.GetString("fehlt", "x"));
            Assert.Empty(parsed.GetArray("fehlt"));
        }

        [Theory]
        [InlineData("{")]
        [InlineData("{\"a\":}")]
        [InlineData("[1,2")]
        [InlineData("nicht json")]
        [InlineData("")]
        public void BrokenInput_IsRejectedCleanly(string text)
        {
            Assert.False(Json.TryParse(text, out _));
        }

        [Fact]
        public void IndentedOutput_IsStillValid()
        {
            var value = JsonValue.Object().Set("a", JsonValue.Array().Add(JsonValue.Of(1)));
            Assert.True(Json.TryParse(Json.Write(value, indented: true), out _));
        }
    }

    public class SaveGameTests
    {
        [Fact]
        public void Save_And_Restore_PreservesTheRun()
        {
            var game = new GameController(77);
            game.Run.Gold = 321;
            game.Run.Luck = 4;
            game.Run.Deck[0].Level = 5;
            game.Run.Deck[0].Shimmer = Shimmer.Gold;
            game.Run.Deck[1].Orientation = Orientation.Reversed;
            game.Run.Deck[2].Rage = 2;

            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            Assert.Equal(321, restored.Run.Gold);
            Assert.Equal(4, restored.Run.Luck);
            Assert.Equal(game.Run.Deck.Count, restored.Run.Deck.Count);
            Assert.Equal(5, restored.Run.Deck[0].Level);
            Assert.Equal(Shimmer.Gold, restored.Run.Deck[0].Shimmer);
            Assert.Equal(Orientation.Reversed, restored.Run.Deck[1].Orientation);
            Assert.Equal(2, restored.Run.Deck[2].Rage);
        }

        [Fact]
        public void Save_And_Restore_PreservesCharmsAndItems()
        {
            var game = new GameController(78);
            var charm = GameCatalog.Charms[3];
            game.Run.AddCharm(charm, 3);
            game.Run.AddItem(GameCatalog.Items[2], 2);

            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            Assert.Equal(3, restored.Run.CharmStacks(charm.Id));
            Assert.Equal(2, restored.Run.Items[GameCatalog.Items[2].Id]);
        }

        [Fact]
        public void Save_And_Restore_KeepsCardIdentity()
        {
            // Eine Karte, die zugleich im Deck und auf der Hand liegt, muss nach
            // dem Laden dasselbe Objekt sein - sonst laufen Level und Rage
            // auseinander.
            var game = new GameController(79);
            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            var handCard = restored.Combat.Hand.First();
            var deckCard = restored.Run.Deck.FirstOrDefault(c => c.InstanceId == handCard.InstanceId);

            Assert.NotNull(deckCard);
            Assert.Same(deckCard, handCard);
        }

        [Fact]
        public void Save_And_Restore_PreservesAnOngoingFight()
        {
            // Der realistische Fall auf dem Handy: die App wird mitten im Zug
            // weggeraeumt.
            var game = new GameController(80);
            new Autopilot().PlayCombat(new GameController(80));   // nur zum Aufwaermen
            game.CombatSystem.PlaceCard(game.Combat, game.Combat.Hand[0].InstanceId, SlotPosition.Present);
            game.ResolveTurn();

            var before = game.Combat;
            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            Assert.NotNull(restored.Combat);
            Assert.Equal(before.Turn, restored.Combat.Turn);
            Assert.Equal(before.Enemy.Hp, restored.Combat.Enemy.Hp);
            Assert.Equal(before.Enemy.Stance, restored.Combat.Enemy.Stance);
            Assert.Equal(before.Enemy.Intent, restored.Combat.Enemy.Intent);
            Assert.Equal(before.PlayerShield, restored.Combat.PlayerShield);
            Assert.Equal(before.Hand.Count, restored.Combat.Hand.Count);
            Assert.Equal(before.DrawPile.Count, restored.Combat.DrawPile.Count);
            Assert.Equal(before.DiscardPile.Count, restored.Combat.DiscardPile.Count);
            Assert.Equal(before.LastComboSignature, restored.Combat.LastComboSignature);
        }

        [Fact]
        public void Restore_ContinuesWithTheSameRandomSequence()
        {
            // Das eigentliche Versprechen: Laden aendert den weiteren Verlauf nicht.
            var original = new GameController(81);
            var json = original.Save();

            var continuedDirectly = ContinueAndDescribe(original);
            var continuedAfterLoad = ContinueAndDescribe(
                GameController.Restore(SaveSystem.Deserialize(json)));

            Assert.Equal(continuedDirectly, continuedAfterLoad);
        }

        private static string ContinueAndDescribe(GameController game)
        {
            var pilot = new Autopilot();
            for (var i = 0; i < 3 && game.Phase != GamePhase.GameOver; i++)
            {
                if (game.Phase == GamePhase.Combat) pilot.PlayCombat(game);
                else if (game.Phase == GamePhase.Reward) game.SkipRewardForFate();
                else if (game.Phase == GamePhase.PathChoice) game.ChoosePath(PathType.Fight);
                else break;
            }
            return $"{game.Run.FightIndex}|{game.Run.Hp}|{game.Run.Gold}|{game.Run.FateScoreTotal}|" +
                   string.Join(",", game.Run.Deck.Select(c => c.InstanceId + ":" + c.Level));
        }

        [Fact]
        public void SavedJson_IsParseable()
        {
            Assert.True(Json.TryParse(new GameController(82).Save(indented: true), out _));
        }

        [Fact]
        public void BrokenSave_IsRejectedWithoutThrowing()
        {
            Assert.False(SaveSystem.TryDeserialize("{\"version\":1", out _, out var error));
            Assert.False(string.IsNullOrEmpty(error));
        }

        [Fact]
        public void SaveWithUnknownCard_SkipsItInsteadOfCrashing()
        {
            // Eine Karte, die es in dieser Version nicht mehr gibt, darf den
            // Speicherstand nicht unbrauchbar machen.
            var game = new GameController(83);
            var json = game.Save().Replace("\"def\":\"swords_7\"", "\"def\":\"gibt_es_nicht\"");

            Assert.True(SaveSystem.TryDeserialize(json, out var save, out _));
            Assert.NotNull(save.Run);
            Assert.All(save.Run.Deck, c => Assert.NotNull(c.Definition));
        }

        [Fact]
        public void RestoreFromRewardPhase_RebuildsTheOffer()
        {
            var game = new GameController(84);
            new Autopilot().PlayCombat(game);
            if (game.Phase != GamePhase.Reward) return;   // Kampf verloren, nichts zu pruefen

            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            Assert.Equal(GamePhase.Reward, restored.Phase);
            Assert.NotEmpty(restored.Rewards);
        }
    }
}
