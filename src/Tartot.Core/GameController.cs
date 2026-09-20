using System;
using System.Collections.Generic;
using System.Linq;

namespace Tartot.Core
{
    public sealed class ShopOffer
    {
        public RewardOption Reward;
        public int Price;
        public bool Sold;
    }

    public sealed class GameController
    {
        private readonly DeterministicRandom _rng;
        public readonly CombatSystem CombatSystem;
        public readonly ProgressionSystem Progression;

        /// <summary>Der Seed dieses Runs. Teilbar, reproduzierbar.</summary>
        public long Seed { get; }

        public RunState Run { get; private set; }
        public CombatState Combat { get; private set; }
        public GamePhase Phase { get; private set; }
        public List<RewardOption> Rewards { get; private set; } = new List<RewardOption>();
        public List<PathType> Paths { get; private set; } = new List<PathType>();
        public List<ShopOffer> ShopOffers { get; private set; } = new List<ShopOffer>();
        public VictorySummary LastVictory { get; private set; }
        public TurnResult LastTurn { get; private set; }
        public string Message { get; private set; } = string.Empty;

        public GameController(long seed = 1337)
        {
            Seed = seed;
            // Getrennte Stroeme: ein Reroll im Laden darf die Kartenzuege im
            // naechsten Kampf nicht verschieben, sonst ist der Seed wertlos.
            var root = new DeterministicRandom(seed);
            _rng = root.Stream("world");
            CombatSystem = new CombatSystem(root.Stream("combat"));
            Progression = new ProgressionSystem(root.Stream("progression"));
            NewRun();
        }

        /// <summary>Konstruktor fuer das Laden: baut nichts auf, uebernimmt alles.</summary>
        private GameController(long seed, DeterministicRandom world,
            DeterministicRandom combat, DeterministicRandom progression)
        {
            Seed = seed;
            _rng = world;
            CombatSystem = new CombatSystem(combat);
            Progression = new ProgressionSystem(progression);
        }

        public RandomSnapshot WorldRandomSnapshot => _rng.Snapshot();
        public RandomSnapshot CombatRandomSnapshot => CombatSystem.RandomSnapshot();
        public RandomSnapshot ProgressionRandomSnapshot => Progression.RandomSnapshot();

        /// <summary>
        /// Stellt einen gespeicherten Run wieder her - einschliesslich eines
        /// laufenden Kampfes, denn auf dem Handy wird die App jederzeit
        /// weggeraeumt.
        /// </summary>
        public static GameController Restore(SaveData save)
        {
            if (save == null) throw new ArgumentNullException(nameof(save));
            if (save.Run == null) throw new ArgumentException("Speicherstand ohne Run.", nameof(save));

            var game = new GameController(
                save.Seed,
                DeterministicRandom.Restore(save.WorldRandom),
                DeterministicRandom.Restore(save.CombatRandom),
                DeterministicRandom.Restore(save.ProgressionRandom))
            {
                Run = save.Run,
                Combat = save.Combat,
                Phase = save.Phase
            };

            // Phasen, deren Angebot nicht mitgespeichert wird, werden neu
            // aufgebaut. Das ist bewusst: ein Speicherstand soll den Fortschritt
            // sichern, nicht eine halb offene Auswahlliste.
            switch (game.Phase)
            {
                case GamePhase.Reward:
                    game.Rewards = game.Progression.GenerateRewards(game.Run);
                    break;
                case GamePhase.PathChoice:
                    game.GeneratePaths();
                    break;
                case GamePhase.Shop:
                    game.OpenShop();
                    break;
                case GamePhase.Combat when game.Combat == null:
                    // Kampfphase ohne Kampfzustand: neuen Kampf beginnen.
                    game.StartFight(false);
                    break;
            }

            game.Message = "Fortgesetzt.";
            return game;
        }

        /// <summary>Speichert den aktuellen Stand als JSON.</summary>
        public string Save(bool indented = false) => SaveSystem.Serialize(this, indented);

        public void NewRun()
        {
            Run = GameCatalog.CreateStarterRun();
            Combat = null;
            LastVictory = null;
            LastTurn = null;
            Rewards.Clear();
            Paths.Clear();
            ShopOffers.Clear();
            Run.FightIndex = 0;
            Phase = GamePhase.Combat;
            StartFight(false);
            Message = "Die erste Lesung beginnt.";
        }

        public void StartFight(bool advance)
        {
            if (advance) Run.FightIndex++;
            var enemy = BuildEnemyForFight(Run.FightIndex);
            Combat = CombatSystem.StartCombat(Run, enemy);
            Phase = GamePhase.Combat;
            Message = $"{enemy.Name} tritt aus dem Schatten.";
        }

        public TurnResult ResolveTurn()
        {
            if (Phase != GamePhase.Combat) return null;
            LastTurn = CombatSystem.ResolveTurn(Run, Combat);
            Message = string.Join("\n", LastTurn.Log.Skip(Math.Max(0, LastTurn.Log.Count - 4)));

            if (LastTurn.Victory)
            {
                LastVictory = Progression.ResolveVictory(Run, Combat);
                Rewards = Progression.GenerateRewards(Run);
                Phase = GamePhase.Reward;
                Message = $"Sieg. +{LastVictory.FateEarned} Fate, +{LastVictory.GoldEarned} Gold. " +
                          (LastVictory.Champion != null ? $"{LastVictory.Champion.Definition.Name} wurde vom Schicksal berührt." : string.Empty);
            }
            else if (LastTurn.Defeat)
            {
                Phase = GamePhase.GameOver;
                Message = $"Der Run endet nach Kampf {Run.FightIndex + 1}. Gesamt-Fate: {Run.FateScoreTotal}.";
            }
            return LastTurn;
        }

        public void ChooseReward(int index)
        {
            if (Phase != GamePhase.Reward || index < 0 || index >= Rewards.Count) return;
            var reward = Rewards[index];
            Progression.TakeReward(Run, reward);
            Message = $"Belohnung erhalten: {reward.Title}.";
            GeneratePaths();
            Phase = GamePhase.PathChoice;
        }

        public void SkipRewardForFate()
        {
            if (Phase != GamePhase.Reward) return;
            var fate = 40 + Run.FightIndex * 8;
            Run.Fate += fate;
            Message = $"Belohnung übersprungen: +{fate} Fate. Dein Deck bleibt dünn.";
            GeneratePaths();
            Phase = GamePhase.PathChoice;
        }

        public void ChoosePath(PathType path)
        {
            if (Phase != GamePhase.PathChoice) return;
            switch (path)
            {
                case PathType.Fight:
                    StartFight(true);
                    break;
                case PathType.Shop:
                    OpenShop();
                    break;
                case PathType.Ritual:
                    Phase = GamePhase.Ritual;
                    Message = "Ritual: Wähle eine Karte aus deinem Deck und verändere ihr Schicksal.";
                    break;
                case PathType.Oracle:
                    Phase = GamePhase.Oracle;
                    Message = "Das Orakel bietet drei Prophezeiungen.";
                    break;
            }
        }

        public void ContinueFromOffgame()
        {
            if (Phase != GamePhase.Shop && Phase != GamePhase.Ritual && Phase != GamePhase.Oracle) return;
            StartFight(true);
        }

        public void OpenShop()
        {
            Phase = GamePhase.Shop;
            ShopOffers.Clear();
            var card = RandomCard();
            ShopOffers.Add(MakeShopOffer(new RewardOption { Type=RewardType.Card, Card=card, Title=card.Name, Description=card.Description }, 38));

            for (var i = 0; i < 2; i++)
            {
                var charm = _rng.Pick(GameCatalog.Charms);
                ShopOffers.Add(MakeShopOffer(new RewardOption { Type=RewardType.Charm, Charm=charm, Title=charm.Name, Description=charm.Description }, 58 + i * 7));
            }
            var item = _rng.Pick(GameCatalog.Items);
            ShopOffers.Add(MakeShopOffer(new RewardOption { Type=RewardType.Item, Item=item, Title=item.Name, Description=item.Description }, 46));
            Message = "Der Händler öffnet seinen Mantel.";
        }

        public bool BuyShopOffer(int index)
        {
            if (Phase != GamePhase.Shop || index < 0 || index >= ShopOffers.Count) return false;
            var offer = ShopOffers[index];
            if (offer.Sold) return false;
            if (!Run.FreeNextShopPurchase && Run.Gold < offer.Price)
            {
                Message = "Nicht genug Gold.";
                return false;
            }
            if (Run.FreeNextShopPurchase) Run.FreeNextShopPurchase = false;
            else Run.Gold -= offer.Price;
            Progression.TakeReward(Run, offer.Reward);
            offer.Sold = true;
            Message = $"Gekauft: {offer.Reward.Title}.";
            return true;
        }

        public bool RitualRemove(CardInstance card)
        {
            var ok = Progression.RemoveCard(Run, card);
            Message = ok ? $"{card.Definition.Name} wurde vergessen." : "Das Ritual kann diese Karte nicht löschen.";
            return ok;
        }

        public bool RitualMirror(CardInstance card)
        {
            var ok = Progression.MirrorCard(Run, card);
            Message = ok ? $"{card.Definition.Name} wurde gespiegelt." : "Spiegelung nicht möglich.";
            return ok;
        }

        public bool RitualFlip(CardInstance card)
        {
            var ok = Progression.FlipCard(Run, card);
            Message = ok ? $"{card.Definition.Name} wurde umgekehrt." : "Umkehrung nicht möglich.";
            return ok;
        }

        public bool RitualEvolve(CardInstance card)
        {
            var ok = Progression.EvolveCard(Run, card);
            Message = ok ? $"{card.Definition.Name} entwickelt sich zu {card.Shimmer} L{card.Level}." : "Nicht genug Fate für die Entwicklung.";
            return ok;
        }

        public void ChooseOracle(string prophecy)
        {
            if (Phase != GamePhase.Oracle) return;
            Progression.ApplyOracle(Run, prophecy);
            Message = prophecy switch
            {
                "XXI" => "Prophezeiung XXI: Kleine Decks und 21er-Legungen werden belohnt.",
                "BLUT" => "Prophezeiung BLUT: Umgekehrte Karten wachsen schneller.",
                _ => "Prophezeiung EINHEIT: Ein fokussiertes Deck wird belohnt."
            };
        }

        public bool UseItem(string itemId, CardInstance target = null)
        {
            var ok = Progression.UseItem(Run, Phase == GamePhase.Combat ? Combat : null, itemId, target);
            Message = ok ? $"Item verwendet: {GameCatalog.Item(itemId).Name}." : "Dieses Item braucht ein gültiges Ziel oder einen anderen Zeitpunkt.";
            return ok;
        }

        public ScoreBreakdown PreviewScore()
        {
            return Phase == GamePhase.Combat ? CombatSystem.PreviewScore(Run, Combat) : null;
        }

        private void GeneratePaths()
        {
            Paths = new List<PathType> { PathType.Fight };
            var specials = new List<PathType> { PathType.Shop, PathType.Ritual, PathType.Oracle };
            while (Paths.Count < 3)
            {
                var p = _rng.Pick(specials);
                if (!Paths.Contains(p)) Paths.Add(p);
            }
            _rng.Shuffle(Paths);
        }

        private ShopOffer MakeShopOffer(RewardOption reward, int basePrice)
        {
            return new ShopOffer { Reward=reward, Price=Progression.ShopPrice(Run, basePrice) };
        }

        private CardDefinition RandomCard() => _rng.Pick(GameCatalog.Cards);
        private CardDefinition RandomMinor()
        {
            var minors = GameCatalog.Cards.Where(c => !c.IsMajor).ToList();
            return _rng.Pick(minors);
        }

        private EnemyDefinition BuildEnemyForFight(int index)
        {
            var baseEnemy = GameCatalog.Enemies[Math.Min(index, GameCatalog.Enemies.Count - 1)];
            if (index < GameCatalog.Enemies.Count) return baseEnemy;

            var tier = index - GameCatalog.Enemies.Count + 1;
            Run.EndlessTier = tier;
            return new EnemyDefinition
            {
                Id = baseEnemy.Id + "_endless_" + tier,
                Name = baseEnemy.Name + $" · Schleife {tier}",
                MaxHp = (int)Math.Round(baseEnemy.MaxHp * (1f + tier * .18f)),
                MaxStance = (int)Math.Round(baseEnemy.MaxStance * (1f + tier * .12f)),
                BaseAttack = baseEnemy.BaseAttack + tier * 2,
                Sigils = Math.Min(4, baseEnemy.Sigils + tier / 3),
                Flavor = "Das Ende hat gelernt, dich zu lesen."
            };
        }
    }
}
