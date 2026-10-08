using Tartot.Core;

namespace Tartot.Unity
{
    /// <summary>Demo composition only. Combat and boss rules remain in Tartot.Core.</summary>
    public static class TowerDemoSession
    {
        public static GameController Create(long seed = 1337)
        {
            var game = new GameController(seed);
            var tower = ActCatalog.Find("boss_turm");
            game.Run.FightIndex = (tower.Act - 1) * ActCatalog.FightsPerAct + ActCatalog.FightsBeforeBoss;
            game.Run.ActBosses[tower.Act - 1] = tower.Id;
            game.StartFight(false);
            return game;
        }
    }
}
