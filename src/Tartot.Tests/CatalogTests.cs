using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Der Katalog ist reine Daten - genau deshalb lohnt sich die Pruefung.
    /// Ein doppelter Bezeichner faellt sonst erst im Spiel auf.
    /// </summary>
    public class CatalogTests
    {
        [Fact]
        public void Deck_HasAllSeventyEightTarotCards()
        {
            Assert.Equal(78, GameCatalog.Cards.Count);
            Assert.Equal(22, GameCatalog.Cards.Count(c => c.IsMajor));
            Assert.Equal(56, GameCatalog.Cards.Count(c => !c.IsMajor));
        }

        [Fact]
        public void EachSuit_HasFourteenCards()
        {
            foreach (var suit in new[] { Suit.Swords, Suit.Wands, Suit.Cups, Suit.Pentacles })
                Assert.Equal(14, GameCatalog.Cards.Count(c => c.Suit == suit));
        }

        [Fact]
        public void MinorRanks_RunFromAceToKing()
        {
            foreach (var suit in new[] { Suit.Swords, Suit.Wands, Suit.Cups, Suit.Pentacles })
            {
                var ranks = GameCatalog.Cards.Where(c => c.Suit == suit).Select(c => c.Rank).OrderBy(r => r);
                Assert.Equal(Enumerable.Range(1, 14), ranks);
            }
        }

        [Fact]
        public void CardIds_AreUnique()
        {
            var duplicates = GameCatalog.Cards.GroupBy(c => c.Id).Where(g => g.Count() > 1).Select(g => g.Key);
            Assert.Empty(duplicates);
        }

        [Fact]
        public void Charms_AreFiftyAndUnique()
        {
            Assert.Equal(50, GameCatalog.Charms.Count);
            Assert.Empty(GameCatalog.Charms.GroupBy(c => c.Id).Where(g => g.Count() > 1).Select(g => g.Key));
        }

        [Fact]
        public void EachCharmEffect_AppearsExactlyOnce()
        {
            // Der Kern sucht Charms ueber ihre Wirkung. Gaebe es zwei Charms mit
            // derselben Wirkung, wuerde der zweite still ignoriert.
            var duplicates = GameCatalog.Charms
                .GroupBy(c => c.Effect)
                .Where(g => g.Count() > 1)
                .Select(g => g.Key.ToString());
            Assert.Empty(duplicates);
        }

        [Fact]
        public void EveryCharmEffect_HasACharm()
        {
            var defined = System.Enum.GetValues(typeof(CharmEffectType)).Cast<CharmEffectType>();
            var used = GameCatalog.Charms.Select(c => c.Effect).ToHashSet();
            Assert.Empty(defined.Where(e => !used.Contains(e)).Select(e => e.ToString()));
        }

        [Fact]
        public void Charms_HaveSaneStackLimits()
        {
            // Der Regelfall sind 5 Stacks; einige lineare Charms gehen bewusst
            // bis 8. Hoeher waere keine Designentscheidung mehr, sondern ein
            // Tippfehler - und genau davor schuetzt diese Grenze.
            foreach (var charm in GameCatalog.Charms)
            {
                Assert.True(charm.MaxStacks >= 1, $"{charm.Id} hat kein Stapelmaximum.");
                Assert.True(charm.MaxStacks <= 8, $"{charm.Id} erlaubt zu viele Stacks ({charm.MaxStacks}).");
                Assert.False(string.IsNullOrWhiteSpace(charm.Description), $"{charm.Id} hat keinen Text.");
            }
        }

        [Fact]
        public void MostCharms_StayAtTheStandardCap()
        {
            // Wenn die Ausnahme zur Regel wird, stimmt das Stapelkonzept nicht mehr.
            var standard = GameCatalog.Charms.Count(c => c.MaxStacks <= 5);
            Assert.True(standard >= GameCatalog.Charms.Count * 2 / 3,
                $"Nur {standard} von {GameCatalog.Charms.Count} Charms halten das Standardmaximum.");
        }

        [Fact]
        public void Items_AreTwentyTwoAndUnique()
        {
            Assert.Equal(22, GameCatalog.Items.Count);
            Assert.Empty(GameCatalog.Items.GroupBy(i => i.Id).Where(g => g.Count() > 1).Select(g => g.Key));
        }

        [Fact]
        public void EveryItemEffect_HasAnItem()
        {
            var defined = System.Enum.GetValues(typeof(ItemEffectType)).Cast<ItemEffectType>();
            var used = GameCatalog.Items.Select(i => i.Effect).ToHashSet();
            Assert.Empty(defined.Where(e => !used.Contains(e)).Select(e => e.ToString()));
        }

        [Fact]
        public void Acts_GrowInDifficulty()
        {
            // Frueher eine feste Achterreihe mit steigenden HP. Jetzt hat jeder
            // Akt einen eigenen Pool - wachsen muss er im Schnitt, und innerhalb
            // eines Akts muss ein Boss mehr aushalten als seine Elites und die
            // Elites mehr als die normalen Gegner.
            double AverageHp(IEnumerable<EnemyDefinition> list) => list.Average(e => e.MaxHp);
            for (var act = 2; act <= ActCatalog.ActCount; act++)
                Assert.True(AverageHp(ActCatalog.NormalsOf(act)) > AverageHp(ActCatalog.NormalsOf(act - 1)),
                    $"Akt {act} ist nicht staerker als Akt {act - 1}.");

            for (var act = 1; act <= ActCatalog.ActCount; act++)
            {
                var normal = AverageHp(ActCatalog.NormalsOf(act));
                var elite = AverageHp(ActCatalog.ElitesOf(act));
                var boss = AverageHp(ActCatalog.BossesOf(act));
                Assert.True(elite > normal, $"Akt {act}: Elites ({elite}) muessen mehr aushalten als Normale ({normal}).");
                Assert.True(boss > elite, $"Akt {act}: Bosse ({boss}) muessen mehr aushalten als Elites ({elite}).");
            }
        }

        [Fact]
        public void EveryActHasEnoughEnemiesForItsFights()
        {
            // Vier normale Kaempfe je Akt, ohne Wiederholung: also mindestens vier Normale.
            for (var act = 1; act <= ActCatalog.ActCount; act++)
            {
                Assert.True(ActCatalog.NormalsOf(act).Count >= ActCatalog.FightsBeforeBoss);
                Assert.True(ActCatalog.ElitesOf(act).Count >= 1);
                Assert.True(ActCatalog.BossesOf(act).Count >= 2, $"Akt {act} braucht zwei moegliche Omen.");
            }
        }

        [Fact]
        public void EveryBossBreaksARuleAndCarriesAnOmen()
        {
            foreach (var boss in ActCatalog.Bosses)
            {
                Assert.NotEmpty(boss.Rules);
                Assert.DoesNotContain(BossRule.None, boss.Rules);
                Assert.Contains(GameCatalog.Cards, c => c.Id == boss.OmenCardId);
            }
            // Jede Regel kommt bei genau einem Akt-Boss vor.
            var rules = ActCatalog.Bosses.SelectMany(b => b.Rules).ToList();
            Assert.Equal(rules.Count, rules.Distinct().Count());
        }

        [Fact]
        public void EnemyIdsAreUnique()
        {
            var ids = GameCatalog.Enemies.Select(e => e.Id).ToList();
            Assert.Equal(ids.Count, ids.Distinct().Count());
        }

        [Fact]
        public void EveryEnemyHasAPattern()
        {
            foreach (var enemy in GameCatalog.Enemies)
                Assert.True(enemy.Pattern.Length > 0, $"{enemy.Id} hat kein Absichtsmuster.");
        }

        [Fact]
        public void DeutersReferenceRealContent()
        {
            foreach (var deuter in DeuterCatalog.All)
            {
                Assert.True(deuter.Deck.Length >= GameCatalog.MinimumDeckSize, $"{deuter.Id}: Deck zu klein.");
                Assert.All(deuter.Deck, id => Assert.Contains(GameCatalog.Cards, c => c.Id == id));
                Assert.All(deuter.ReversedCards, id => Assert.Contains(id, deuter.Deck));
                Assert.All(deuter.Charms, id => Assert.Contains(GameCatalog.Charms, c => c.Id == id));
                Assert.All(deuter.Items, id => Assert.Contains(GameCatalog.Items, i => i.Id == id));
                if (!string.IsNullOrEmpty(deuter.UnlockedBy))
                    Assert.NotNull(ProphecyCatalog.Find(deuter.UnlockedBy));
            }
        }

        [Fact]
        public void EveryVeilLevelIsDescribed()
        {
            Assert.Equal(VeilCatalog.MaxVeil + 1, VeilCatalog.All.Count);
            for (var i = 0; i <= VeilCatalog.MaxVeil; i++)
                Assert.Equal(i, VeilCatalog.All[i].Level);
        }

        [Fact]
        public void TheFoolShowsZeroButPlaysAsOne()
        {
            // Der Narr traegt die Arkana-Nummer 0. Im Spiel rechnet er mit Rang 1,
            // sonst waere er in Summe 21, Paar und Dreiklang eine tote Karte.
            // Beschriftet wird er trotzdem mit 0 - vorher stand dort faelschlich I.
            var fool = GameCatalog.Cards.First(c => c.Major == MajorArcana.Fool);
            Assert.Equal(0, fool.DisplayNumber);
            Assert.Equal(1, fool.Rank);
        }

        [Fact]
        public void EveryOtherMajorShowsItsOwnNumber()
        {
            foreach (var card in GameCatalog.Cards.Where(c => c.IsMajor))
                Assert.Equal((int)card.Major.Value, card.DisplayNumber);
        }

        [Fact]
        public void MinorCardsShowTheirRank()
        {
            foreach (var card in GameCatalog.Cards.Where(c => !c.IsMajor))
                Assert.Equal(card.Rank, card.DisplayNumber);
        }

        [Fact]
        public void StarterRun_IsPlayable()
        {
            var run = GameCatalog.CreateStarterRun();
            Assert.Equal(10, run.Deck.Count);
            Assert.True(run.Hp > 0 && run.Hp <= run.MaxHp);
            Assert.All(run.Deck, c => Assert.NotNull(c.Definition));
            // Eindeutige Instanz-Ids, sonst kollidieren Beitraege und Auswahl.
            Assert.Equal(run.Deck.Count, run.Deck.Select(c => c.InstanceId).Distinct().Count());
        }
    }
}
