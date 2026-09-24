using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Der Bogen eines Runs: Akte, angekuendigte Bosse, Wegwahl mit Garantien,
    /// Omen-Beute, Finale, Spirale - und Schleier und Deuter, die ihn formen.
    /// </summary>
    public class RunArcTests
    {
        // ------------------------------------------------------------ Akte
        [Fact]
        public void FightIndices_MapToActs()
        {
            Assert.Equal(1, ActCatalog.ActOf(0));
            Assert.Equal(1, ActCatalog.ActOf(4));
            Assert.Equal(2, ActCatalog.ActOf(5));
            Assert.Equal(3, ActCatalog.ActOf(14));
            Assert.Equal(4, ActCatalog.ActOf(ActCatalog.FinaleIndex));
            Assert.Equal(5, ActCatalog.ActOf(ActCatalog.FinaleIndex + 1));

            Assert.True(ActCatalog.IsBossFight(4));
            Assert.True(ActCatalog.IsBossFight(9));
            Assert.True(ActCatalog.IsBossFight(14));
            Assert.False(ActCatalog.IsBossFight(ActCatalog.FinaleIndex));
            Assert.True(ActCatalog.IsFinale(15));
        }

        [Fact]
        public void NewRun_AnnouncesOneBossPerAct()
        {
            var game = new GameController(3);
            Assert.Equal(ActCatalog.ActCount, game.Run.ActBosses.Count);
            for (var act = 1; act <= ActCatalog.ActCount; act++)
                Assert.Contains(ActCatalog.BossesOf(act), b => b.Id == game.Run.ActBosses[act - 1]);
            Assert.Equal(game.Run.ActBosses[0], game.UpcomingBoss().Id);
            Assert.Contains(game.UpcomingBoss().Name, game.Message);
        }

        [Fact]
        public void TheFifthFight_IsTheAnnouncedBoss()
        {
            var game = new GameController(3);
            TestTools.JumpToFight(game, 4);
            Assert.Equal(game.Run.ActBosses[0], game.Combat.Enemy.Definition.Id);
            Assert.True(game.Combat.Enemy.Definition.IsBoss);
        }

        [Fact]
        public void NormalFights_DoNotRepeatWithinAnAct()
        {
            var game = new GameController(5);
            var seen = new[] { game.Combat.Enemy.Definition.Id }.ToList();
            for (var i = 1; i < ActCatalog.FightsBeforeBoss; i++)
            {
                TestTools.JumpToFight(game, i);
                seen.Add(game.Combat.Enemy.Definition.Id);
            }
            Assert.Equal(seen.Count, seen.Distinct().Count());
        }

        [Fact]
        public void TheFinale_CarriesTheRulesOfTheBeatenBosses()
        {
            var game = new GameController(3);
            game.Run.DefeatedBosses.Add("boss_turm");
            game.Run.DefeatedBosses.Add("boss_tod");
            TestTools.JumpToFight(game, ActCatalog.FinaleIndex);

            var finale = game.Combat.Enemy.Definition;
            Assert.Equal(EnemyTier.Finale, finale.Tier);
            Assert.True(finale.RulesWeakened);
            Assert.Contains(BossRule.Tower, finale.Rules);
            Assert.Contains(BossRule.Death, finale.Rules);
            Assert.DoesNotContain(BossRule.Wheel, finale.Rules);
            // Der Katalog bleibt unberuehrt.
            Assert.Empty(ActCatalog.Finale.Rules);
        }

        // -------------------------------------------------------- Wegwahl
        private static GameController AfterFight(int index, long seed = 21)
        {
            var game = new GameController(seed);
            if (index > 0) TestTools.JumpToFight(game, index);
            TestTools.WinFight(game);
            Assert.Equal(GamePhase.Reward, game.Phase);
            game.SkipRewardForFate();
            Assert.Equal(GamePhase.PathChoice, game.Phase);
            return game;
        }

        [Fact]
        public void BeforeABoss_ARestIsAlwaysOffered()
        {
            for (var seed = 0; seed < 12; seed++)
            {
                var game = AfterFight(ActCatalog.FightsBeforeBoss - 1, seed);
                Assert.Contains(PathType.Rest, game.Paths);
                Assert.DoesNotContain(PathType.Elite, game.Paths);
            }
        }

        [Fact]
        public void EveryPathChoice_OffersThreeDistinctWaysIncludingTheDirectOne()
        {
            for (var seed = 0; seed < 12; seed++)
            {
                var game = AfterFight(0, seed);
                Assert.Equal(3, game.Paths.Count);
                Assert.Equal(3, game.Paths.Distinct().Count());
                Assert.Contains(PathType.Fight, game.Paths);
            }
        }

        [Fact]
        public void AShopIsForcedAfterFourStepsWithout()
        {
            var game = new GameController(8);
            game.Run.StepsSinceShop = 4;
            TestTools.WinFight(game);
            game.SkipRewardForFate();
            Assert.Contains(PathType.Shop, game.Paths);
        }

        [Fact]
        public void TheDirectPath_PaysGold()
        {
            var game = AfterFight(0);
            var gold = game.Run.Gold;
            game.ChoosePath(PathType.Fight);
            Assert.Equal(gold + GameController.DirectPathGold, game.Run.Gold);
            Assert.Equal(GamePhase.Combat, game.Phase);
        }

        [Fact]
        public void TheElitePath_LeadsToAnEliteWithCharmRewards()
        {
            var game = AfterFight(0);
            game.Run.LastPath = PathType.Fight;
            // Den Weg direkt waehlen - ob er gerade angeboten wird, spielt fuer die Regel keine Rolle.
            ForcePaths(game, PathType.Elite);
            game.ChoosePath(PathType.Elite);

            Assert.Equal(EnemyTier.Elite, game.Combat.Enemy.Definition.Tier);
            TestTools.WinFight(game);
            Assert.Equal(GamePhase.Reward, game.Phase);
            Assert.True(game.Rewards.Take(2).All(r => r.Type == RewardType.Charm),
                "Elites geben verlaesslich Charms.");
        }

        private static void ForcePaths(GameController game, params PathType[] paths)
        {
            game.Paths.Clear();
            game.Paths.AddRange(paths);
        }

        // ----------------------------------------------------------- Rast
        [Fact]
        public void Rest_HealsAndMovesOn()
        {
            var game = AfterFight(0);
            game.Run.Hp = 10;
            ForcePaths(game, PathType.Rest);
            game.ChoosePath(PathType.Rest);
            Assert.Equal(GamePhase.Rest, game.Phase);
            var expected = System.Math.Min(game.Run.MaxHp, 10 + game.RestHealAmount);

            Assert.True(game.RestHeal());
            Assert.Equal(expected, game.Run.Hp);
            Assert.Equal(GamePhase.Combat, game.Phase);
            Assert.Equal(1, game.Run.FightIndex);
        }

        [Fact]
        public void Rest_StudyRaisesACard()
        {
            var game = AfterFight(0);
            ForcePaths(game, PathType.Rest);
            game.ChoosePath(PathType.Rest);
            var card = game.Run.Deck[0];
            var level = card.Level;
            Assert.True(game.RestStudy(card));
            Assert.Equal(level + 1, card.Level);
        }

        // ------------------------------------------------------ Ereignis
        [Fact]
        public void TheEventPath_PlaysAScene()
        {
            var game = AfterFight(0);
            ForcePaths(game, PathType.Event);
            game.ChoosePath(PathType.Event);

            Assert.Equal(GamePhase.Event, game.Phase);
            Assert.NotNull(game.CurrentEvent);
            Assert.Contains(game.CurrentEvent.Id, game.Run.SeenEvents);
            Assert.Equal(1, game.Run.Stats.EventsSeen);

            var index = Enumerable.Range(0, game.CurrentEvent.Choices.Count).First(game.CanChooseEventOption);
            Assert.True(game.ChooseEventOption(index));
            Assert.True(game.EventResolved);
            Assert.False(game.ChooseEventOption(index), "Eine Szene wird nur einmal entschieden.");

            game.ContinueFromOffgame();
            Assert.Equal(GamePhase.Combat, game.Phase);
        }

        [Fact]
        public void AnEventNeverReplacesABoss()
        {
            var game = new GameController(3);
            game.Run.PendingEnemyId = "kartenspieler";
            TestTools.JumpToFight(game, 4);
            Assert.Equal(game.Run.ActBosses[0], game.Combat.Enemy.Definition.Id);
            Assert.Equal("kartenspieler", game.Run.PendingEnemyId);

            TestTools.JumpToFight(game, 5);
            Assert.Equal("kartenspieler", game.Combat.Enemy.Definition.Id);
            Assert.True(string.IsNullOrEmpty(game.Run.PendingEnemyId));
        }

        // ---------------------------------------------------- Omen-Beute
        private static GameController AfterBoss(long seed = 17)
        {
            var game = new GameController(seed);
            TestTools.JumpToFight(game, 4);
            TestTools.WinFight(game);
            Assert.Equal(GamePhase.BossLoot, game.Phase);
            return game;
        }

        [Fact]
        public void BeatingABoss_DarkensTheRunAndOpensTheLoot()
        {
            var game = AfterBoss();
            Assert.Equal(6, game.Run.Darkness);
            Assert.Equal(1, game.Run.Stats.BossesDefeated);
            Assert.Contains(game.Run.ActBosses[0], game.Run.DefeatedBosses);
        }

        [Fact]
        public void Soak_DarkensTheThreeCardsThatFought()
        {
            var game = AfterBoss();
            var targets = game.SoakTargets();
            Assert.Equal(3, targets.Count);
            var before = targets.Select(c => (c.Level, c.Shimmer)).ToList();

            Assert.True(game.ChooseBossLoot(BossLootChoice.Soak));

            for (var i = 0; i < 3; i++)
            {
                Assert.Equal(before[i].Level + 1, targets[i].Level);
                Assert.True(targets[i].Shimmer > before[i].Shimmer || before[i].Shimmer == Shimmer.Black);
            }
            Assert.Equal(6 + GameController.SoakDarkness, game.Run.Darkness);
            Assert.Equal(GamePhase.PathChoice, game.Phase);
        }

        [Fact]
        public void Bind_TakesTheOmenIntoTheDeck()
        {
            var game = AfterBoss();
            var omen = game.OmenCard();
            Assert.NotNull(omen);
            var deck = game.Run.Deck.Count;

            Assert.True(game.ChooseBossLoot(BossLootChoice.Bind));

            Assert.Equal(deck + 1, game.Run.Deck.Count);
            var bound = game.Run.Deck.Last();
            Assert.Equal(omen.Id, bound.Definition.Id);
            Assert.Equal(Orientation.Reversed, bound.Orientation);
            Assert.Equal(Shimmer.Blood, bound.Shimmer);
            Assert.Equal(6 + GameController.BindDarkness, game.Run.Darkness);
        }

        [Fact]
        public void Banish_PaysAndLightens()
        {
            var game = AfterBoss();
            var gold = game.Run.Gold;
            Assert.True(game.ChooseBossLoot(BossLootChoice.Banish));
            Assert.Equal(gold + GameController.BanishGold, game.Run.Gold);
            Assert.Equal(0, game.Run.Darkness);
        }

        [Fact]
        public void BetweenActs_YouCatchYourBreath()
        {
            var game = AfterBoss();
            game.Run.Hp = 10;
            game.ChooseBossLoot(BossLootChoice.Soak);
            var expected = 10 + (int)System.Math.Round(game.Run.MaxHp * GameController.ActTransitionHeal);
            Assert.Equal(System.Math.Min(game.Run.MaxHp, expected), game.Run.Hp);
        }

        // ----------------------------------------------- Finale, Spirale
        [Fact]
        public void BeatingTheFinale_WinsTheRun()
        {
            var game = new GameController(3);
            TestTools.JumpToFight(game, ActCatalog.FinaleIndex);
            TestTools.WinFight(game);
            Assert.Equal(GamePhase.Victory, game.Phase);
            Assert.True(game.Run.Won);
        }

        [Fact]
        public void TheSpiral_FollowsTheWorldAndGrows()
        {
            var game = new GameController(3);
            TestTools.JumpToFight(game, ActCatalog.FinaleIndex);
            TestTools.WinFight(game);
            game.ContinueIntoSpiral();
            Assert.Equal(GamePhase.PathChoice, game.Phase);

            game.ChoosePath(PathType.Fight);
            var first = game.Combat.Enemy.Definition;
            Assert.Equal(5, game.Run.Act);
            Assert.Contains("Spirale 1", first.Name);

            TestTools.JumpToFight(game, ActCatalog.FinaleIndex + ActCatalog.SpiralBossInterval);
            var worm = game.Combat.Enemy.Definition;
            Assert.StartsWith(ActCatalog.SpiralBoss.Id, worm.Id);
            Assert.True(worm.Rules.Count >= 2);
            Assert.True(worm.MaxHp > ActCatalog.SpiralBoss.MaxHp);
        }

        // --------------------------------------------------------- Schleier
        [Fact]
        public void Veil4_ThinsYourSkin()
        {
            var game = new GameController(3, setup: new RunSetup { Veil = 4 });
            Assert.Equal(DeuterCatalog.Default.MaxHp - GameController.VeilHpCost, game.Run.MaxHp);
            Assert.Equal(game.Run.MaxHp, game.Run.Hp);
        }

        [Fact]
        public void Veil6_MakesEveryEnemyHitHarderFromActTwo()
        {
            var plain = new GameController(3);
            var veiled = new GameController(3, setup: new RunSetup { Veil = 6 });
            Assert.Equal(plain.Combat.Enemy.Definition.Id, veiled.Combat.Enemy.Definition.Id);
            // Akt I bleibt unberuehrt - der erste Boss soll keine Mauer werden.
            Assert.Equal(plain.Combat.Enemy.Definition.BaseAttack, veiled.Combat.Enemy.Definition.BaseAttack);

            TestTools.JumpToFight(plain, 5);
            TestTools.JumpToFight(veiled, 5);
            Assert.Equal(plain.Combat.Enemy.Definition.Id, veiled.Combat.Enemy.Definition.Id);
            Assert.Equal(plain.Combat.Enemy.Definition.BaseAttack + 1, veiled.Combat.Enemy.Definition.BaseAttack);
        }

        [Fact]
        public void Veil2_HardensOnlyElitesAndBosses()
        {
            var plain = new GameController(3);
            var veiled = new GameController(3, setup: new RunSetup { Veil = 2 });
            Assert.Equal(plain.Combat.Enemy.Definition.MaxHp, veiled.Combat.Enemy.Definition.MaxHp);
            TestTools.JumpToFight(plain, 4);
            TestTools.JumpToFight(veiled, 4);
            Assert.Equal((int)System.Math.Round(plain.Combat.Enemy.Definition.MaxHp * 1.2f),
                veiled.Combat.Enemy.Definition.MaxHp);
        }

        [Fact]
        public void Veil3_OffersOneChoiceLess()
        {
            var plain = new GameController(3);
            TestTools.WinFight(plain);
            var veiled = new GameController(3, setup: new RunSetup { Veil = 3 });
            TestTools.WinFight(veiled);
            Assert.Equal(plain.Rewards.Count - 1, veiled.Rewards.Count);
        }

        [Fact]
        public void Veil8_SealsTheWorldOnceMore()
        {
            var game = new GameController(3, setup: new RunSetup { Veil = 8 });
            TestTools.JumpToFight(game, ActCatalog.FinaleIndex);
            Assert.Equal(ActCatalog.Finale.Sigils + 1, game.Combat.Enemy.Definition.Sigils);
        }

        [Fact]
        public void Darkness_HardensEnemies()
        {
            var game = new GameController(3);
            game.Run.Darkness = 50;
            TestTools.JumpToFight(game, 1);
            var enemy = game.Combat.Enemy.Definition;
            Assert.Equal(ActCatalog.Find(enemy.Id).BaseAttack + 2, enemy.BaseAttack);
        }

        // ---------------------------------------------------------- Deuter
        [Fact]
        public void EveryDeuter_StartsAPlayableRun()
        {
            foreach (var deuter in DeuterCatalog.All)
            {
                var game = new GameController(9, setup: new RunSetup { DeuterId = deuter.Id });
                Assert.Equal(deuter.Id, game.Run.DeuterId);
                Assert.Equal(deuter.Rule, game.Run.DeuterRule);
                Assert.Equal(deuter.Deck.Length, game.Run.Deck.Count);
                Assert.Equal(deuter.ReversedCards.Length, game.Run.Deck.Count(c => c.Orientation == Orientation.Reversed));
                Assert.Equal(GamePhase.Combat, game.Phase);

                var outcome = new Autopilot { Setup = new RunSetup { DeuterId = deuter.Id } }.PlayRun(40 + deuter.Id.Length, 16);
                Assert.True(outcome.FightsCleared >= 0);
            }
        }

        [Fact]
        public void BloodReader_ReadsReversedCardsHarder()
        {
            float MultOf(DeuterRule rule)
            {
                var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_7");
                run.DeuterRule = rule;
                combat.Hand.Single().Orientation = Orientation.Reversed;
                TestWorld.Place(sys, combat, "swords_7", SlotPosition.Past);
                return sys.PreviewScore(run, combat).Multiplier;
            }
            Assert.Equal(MultOf(DeuterRule.None) + .05f, MultOf(DeuterRule.BloodReader), 3);
        }

        [Fact]
        public void Bookkeeper_KeepsShieldButPaysDoubleToForget()
        {
            var game = new GameController(3, setup: new RunSetup { DeuterId = "buchhalter" });
            var plain = new GameController(3);
            game.OpenShop();
            plain.OpenShop();
            Assert.Equal(plain.RemovalPrice * 2, game.RemovalPrice);

            var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "pentacles_10", "pentacles_9");
            run.DeuterRule = DeuterRule.Bookkeeper;
            TestWorld.Place(sys, combat, "pentacles_10", SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            Assert.True(combat.PlayerShield > 0, "Ein Fuenftel des Schilds bleibt.");
        }

        [Fact]
        public void Hermit_ReadsResonanceTwice()
        {
            float MultOf(DeuterRule rule)
            {
                var (run, combat, sys) = TestWorld.Fight(TestWorld.Dummy(), 1, "swords_7");
                run.DeuterRule = rule;
                run.DeckResonance = 6;
                TestWorld.Place(sys, combat, "swords_7", SlotPosition.Past);
                return sys.PreviewScore(run, combat).Multiplier;
            }
            Assert.Equal(MultOf(DeuterRule.None) + 5 * CombatSystem.DeckResonancePerStep,
                MultOf(DeuterRule.Hermit), 3);
        }

        // ------------------------------------------------------ Veredeln
        [Fact]
        public void Refining_RaisesADarkensAndGetsDearer()
        {
            var game = new GameController(3);
            game.OpenShop();
            game.Run.Gold = 1000;
            var card = game.Run.Deck[0];
            var first = game.RefinePrice;

            Assert.True(game.RefineAtShop(card));

            Assert.Equal(2, card.Level);
            Assert.Equal(Shimmer.White, card.Shimmer);
            Assert.Equal(1000 - first, game.Run.Gold);
            Assert.Equal(first + GameController.RefinePriceStep, game.RefinePrice);
            Assert.True(game.Run.Darkness > 0);
        }

        // --------------------------------------------------- Determinismus
        [Fact]
        public void AFullArc_IsDeterministic()
        {
            var pilot = new Autopilot { ContinueIntoSpiral = true };
            var a = pilot.PlayRun(777, 24);
            var b = pilot.PlayRun(777, 24);
            Assert.Equal(a.Signature, b.Signature);
            Assert.Equal(a.EventsSeen, b.EventsSeen);
            Assert.Equal(a.Darkness, b.Darkness);
        }
    }
}
