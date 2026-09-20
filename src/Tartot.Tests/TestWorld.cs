using System.Collections.Generic;
using System.Linq;
using Tartot.Core;

namespace Tartot.Tests
{
    /// <summary>
    /// Baut kontrollierte Kampfsituationen. Die Tests sollen eine Regel pruefen,
    /// nicht den Zufall: deshalb feste Decks, feste Gegner, fester Seed.
    /// </summary>
    internal static class TestWorld
    {
        /// <summary>Ein Gegner, der nicht stirbt und nicht stoert.</summary>
        public static EnemyDefinition Dummy(int hp = 100000, int stance = 0, int attack = 0, int sigils = 0) =>
            new EnemyDefinition
            {
                Id = "test_dummy",
                Name = "Puppe",
                MaxHp = hp,
                MaxStance = stance,
                BaseAttack = attack,
                Sigils = sigils,
                Flavor = "Steht nur da."
            };

        /// <summary>Run ohne Charms und ohne Items - nur das angegebene Deck.</summary>
        public static RunState Run(params string[] cardIds)
        {
            var run = new RunState();
            foreach (var id in cardIds) run.Deck.Add(new CardInstance(GameCatalog.Card(id)));
            return run;
        }

        public static CombatSystem System(int seed = 4711) =>
            new CombatSystem(new DeterministicRandom(seed));

        public static (RunState Run, CombatState Combat, CombatSystem Sys) Fight(
            EnemyDefinition enemy = null, int seed = 4711, params string[] cardIds)
        {
            var run = Run(cardIds);
            var sys = System(seed);
            var combat = sys.StartCombat(run, enemy ?? Dummy());
            return (run, combat, sys);
        }

        /// <summary>Legt die Karte mit dieser Vorlagen-Id aus der Hand auf den Platz.</summary>
        public static CardInstance Place(CombatSystem sys, CombatState combat, string cardId, SlotPosition slot)
        {
            var card = combat.Hand.First(c => c.Definition.Id == cardId);
            sys.PlaceCard(combat, card.InstanceId, slot);
            return card;
        }

        /// <summary>Gibt dem Run so viele Stacks eines Charms wie moeglich.</summary>
        public static void Charm(RunState run, string charmId, int stacks = 1)
        {
            run.AddCharm(GameCatalog.Charm(charmId), stacks);
        }

        /// <summary>Findet den ersten Charm mit dieser Wirkung.</summary>
        public static CharmDefinition CharmWith(CharmEffectType effect) =>
            GameCatalog.Charms.First(c => c.Effect == effect);

        public static int EnemyHp(CombatState combat) => combat.Enemy.Hp;
    }
}
