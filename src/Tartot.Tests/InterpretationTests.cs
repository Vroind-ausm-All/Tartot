using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Xunit;

namespace Tartot.Tests
{
    /// <summary>
    /// Lesarten sind die Meta-Progression: kein "+5 % Schaden" auf alles,
    /// sondern ein besseres Verstaendnis einzelner Karten. Sie wurden bisher
    /// gesammelt, haben aber nichts bewirkt.
    /// </summary>
    public class InterpretationTests
    {
        private static CardDefinition Tower =>
            GameCatalog.Cards.First(c => c.IsMajor && c.Major == MajorArcana.Tower);

        private static int TowerDamage(int readings)
        {
            var run = TestWorld.Run();
            if (readings > 0) run.Interpretations[Tower.Id] = readings;
            run.Deck.Add(new CardInstance(Tower));
            var sys = TestWorld.System(1);
            var combat = sys.StartCombat(run, TestWorld.Dummy(hp: 100000));
            var before = combat.Enemy.Hp;
            sys.PlaceCard(combat, combat.Hand.Single().InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);
            return before - combat.Enemy.Hp;
        }

        [Fact]
        public void ReadingsStrengthenTheArcanum()
        {
            var none = TowerDamage(0);
            var three = TowerDamage(3);
            Assert.True(three > none,
                $"Drei Lesarten muessen wirken ({three} gegen {none}).");
        }

        [Fact]
        public void MoreReadingsMeanMoreEffect()
        {
            var one = TowerDamage(1);
            var three = TowerDamage(3);
            Assert.True(three > one, $"{three} muss ueber {one} liegen.");
        }

        [Fact]
        public void ReadingsOnlyAffectTheirOwnArcanum()
        {
            var run = TestWorld.Run();
            run.Interpretations["major_18"] = 3;   // Der Mond, nicht der Turm
            run.Deck.Add(new CardInstance(Tower));
            var sys = TestWorld.System(1);
            var combat = sys.StartCombat(run, TestWorld.Dummy(hp: 100000));
            var before = combat.Enemy.Hp;
            sys.PlaceCard(combat, combat.Hand.Single().InstanceId, SlotPosition.Present);
            sys.ResolveTurn(run, combat);

            Assert.Equal(TowerDamage(0), before - combat.Enemy.Hp);
        }

        [Fact]
        public void AFreshRunTakesTheReadingsFromMetaProgress()
        {
            var meta = new MetaProgress();
            for (var i = 0; i < 5; i++) meta.EncounterArcanum("major_16");   // 2 Lesarten

            var game = new GameController(9, meta);

            Assert.Equal(2, game.Run.InterpretationCount("major_16"));
        }

        [Fact]
        public void WithoutMetaProgress_ARunHasNoReadings()
        {
            var game = new GameController(9);
            Assert.Equal(0, game.Run.InterpretationCount("major_16"));
        }

        [Fact]
        public void ARunningGameIsNotChangedByLaterUnlocks()
        {
            // Ein Run muss in sich geschlossen sein: sonst liefe ein
            // Speicherstand anders weiter, nur weil zwischendurch eine Lesart
            // dazukam - und der Seed waere wertlos.
            var meta = new MetaProgress();
            meta.EncounterArcanum("major_16");
            var game = new GameController(9, meta);
            Assert.Equal(1, game.Run.InterpretationCount("major_16"));

            for (var i = 0; i < 20; i++) meta.EncounterArcanum("major_16");

            Assert.Equal(1, game.Run.InterpretationCount("major_16"));
        }

        [Fact]
        public void ReadingsSurviveSaveAndLoad()
        {
            var meta = new MetaProgress();
            for (var i = 0; i < 12; i++) meta.EncounterArcanum("major_13");   // alle drei
            var game = new GameController(10, meta);

            var restored = GameController.Restore(SaveSystem.Deserialize(game.Save()));

            Assert.Equal(3, restored.Run.InterpretationCount("major_13"));
        }

        // Bewusst KEIN Test auf "mit Lesarten kommt man weiter": der Effekt
        // liegt bei rund +2 % Reichweite, das Rauschen zwischen zwei
        // Stichproben von 20 Runs bei +-4 %. Ein solcher Test schlaegt
        // zufaellig fehl und sagt nichts. Die Aussage gehoert in eine
        // Messreihe, nicht in die Testsuite:
        //
        //   dotnet run --project src/Tartot.Sim -c Release -- --runs=400 --readings=1
        //
        // Gemessen ueber je 400 Runs: 9,9 ohne gegen 10,1 mit allen Lesarten.
        // Siehe docs/BALANCING.md.

    }
}
