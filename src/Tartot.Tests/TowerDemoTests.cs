using System.Linq;
using Tartot.Core;
using Tartot.Core.Simulation;
using Tartot.Unity;
using Xunit;

namespace Tartot.Tests
{
    public class TowerDemoTests
    {
        [Fact]
        public void StartsTowerWithPlayableHandAndReproducibleDeal()
        {
            var game = TowerDemoSession.Create();
            var retry = TowerDemoSession.Create();
            Assert.Equal(GamePhase.Combat, game.Phase);
            Assert.Equal("boss_turm", game.Combat.Enemy.Definition.Id);
            Assert.NotEmpty(game.Combat.Hand);
            Assert.Equal(game.Combat.Hand.Select(c => c.Definition.Id), retry.Combat.Hand.Select(c => c.Definition.Id));
            Assert.True(new Autopilot().Arrange(game));
            Assert.NotNull(game.PreviewScore());
            Assert.NotNull(game.ResolveTurn());
            Assert.Equal(1, retry.Combat.Turn);
            Assert.Empty(retry.Combat.Slots);
        }

        [Fact]
        public void DefaultDemoReachesAnEndAndExercisesTowerCollapse()
        {
            var game = TowerDemoSession.Create();
            var pilot = new Autopilot();
            var collapse = false;
            for (var i = 0; i < 100 && game.Phase == GamePhase.Combat; i++)
            {
                Assert.True(pilot.PlayTurn(game));
                collapse |= game.Combat.BlockedSlot.HasValue;
            }
            Assert.NotEqual(GamePhase.Combat, game.Phase);
            Assert.True(collapse);
        }
    }
}
