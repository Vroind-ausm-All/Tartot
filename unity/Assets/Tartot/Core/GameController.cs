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

        private readonly MetaProgress _meta;
        private readonly RunSetup _setup;

        public RunState Run { get; private set; }
        public CombatState Combat { get; private set; }
        public GamePhase Phase { get; private set; }
        public List<RewardOption> Rewards { get; private set; } = new List<RewardOption>();
        public List<PathType> Paths { get; private set; } = new List<PathType>();
        public List<ShopOffer> ShopOffers { get; private set; } = new List<ShopOffer>();
        public VictorySummary LastVictory { get; private set; }
        public TurnResult LastTurn { get; private set; }
        public string Message { get; private set; } = string.Empty;

        /// <summary>Das laufende Ereignis (Phase Event).</summary>
        public EventDefinition CurrentEvent { get; private set; }
        public bool EventResolved { get; private set; }
        public string EventEpilogue { get; private set; } = string.Empty;

        /// <summary>Gold fuer den direkten Weg ohne Umweg.</summary>
        public const int DirectPathGold = 12;
        /// <summary>Anteil der Max-HP, den eine Rast heilt.</summary>
        public const float RestHealFraction = .30f;
        /// <summary>Anteil der Max-HP, der zwischen zwei Akten zurueckkommt.</summary>
        public const float ActTransitionHeal = .25f;
        /// <summary>Schleier 4: so viel Max-HP weniger.</summary>
        public const int VeilHpCost = 4;

        /// <param name="meta">
        /// Optionaler Meta-Fortschritt. Lesarten, Story-Flags, Charm-Pool und
        /// das Grab werden beim Start in den Run kopiert - danach ist der Run
        /// in sich geschlossen und reproduzierbar.
        /// </param>
        /// <param name="setup">Figur, Schleier, Tageskarte. Null = Wahrsagerin ohne Schleier.</param>
        public GameController(long seed = 1337, MetaProgress meta = null, RunSetup setup = null)
        {
            Seed = seed;
            _meta = meta;
            _setup = setup ?? new RunSetup();
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
            _setup = new RunSetup();
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
                case GamePhase.Event:
                    // Das Ereignis selbst wird gespeichert: ein neu gezogenes
                    // waere ein Reroll durch App-Neustart.
                    game.CurrentEvent = EventCatalog.Find(save.EventId);
                    game.EventResolved = save.EventResolved;
                    game.EventEpilogue = save.EventEpilogue ?? string.Empty;
                    if (game.CurrentEvent == null) game.StartFight(true);
                    break;
                case GamePhase.BossLoot when game.Combat == null:
                    game.GeneratePaths();
                    game.Phase = GamePhase.PathChoice;
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

        // ------------------------------------------------------------ Run
        public void NewRun()
        {
            var deuter = DeuterCatalog.Find(_setup.DeuterId);
            Run = GameCatalog.CreateRun(deuter);
            Run.Veil = Math.Max(0, Math.Min(VeilCatalog.MaxVeil, _setup.Veil));
            Run.IsDaily = _setup.IsDaily;
            if (Run.Veil >= 4)
            {
                Run.MaxHp -= VeilHpCost;
                Run.Hp = Run.MaxHp;
            }

            // Die Tageskarte ist fuer alle gleich - kein Meta-Fortschritt darin.
            if (!Run.IsDaily) ApplyMeta(Run, _meta);

            // Die Bosse stehen von Anfang an fest und sind angekuendigt: wer
            // weiss, dass am Ende von Akt I der Turm wartet, baut anders.
            Run.ActBosses.Clear();
            for (var act = 1; act <= ActCatalog.ActCount; act++)
                Run.ActBosses.Add(_rng.Pick(ActCatalog.BossesOf(act)).Id);

            Combat = null;
            LastVictory = null;
            LastTurn = null;
            CurrentEvent = null;
            Rewards.Clear();
            Paths.Clear();
            ShopOffers.Clear();
            Run.FightIndex = 0;
            Phase = GamePhase.Combat;
            StartFight(false);
            Message = $"Akt I: {ActCatalog.ActNames[1]}. Am Ende wartet {UpcomingBoss()?.Name}.";
        }

        /// <summary>Der angekuendigte Boss des aktuellen Akts.</summary>
        public EnemyDefinition UpcomingBoss()
        {
            var act = Run.Act;
            if (act == 4) return ActCatalog.Finale;
            if (act < 1 || act > Run.ActBosses.Count) return null;
            return ActCatalog.Find(Run.ActBosses[act - 1]);
        }

        public void StartFight(bool advance)
        {
            if (advance) Run.FightIndex++;
            // Die Resonanz vor dem Kampf auffrischen: sie haengt an Deckgroesse,
            // Schimmer, Charms und Fortschritt und geht in den Multiplikator ein.
            Progression.UpdateDeckResonance(Run);
            var enemy = BuildEnemy();
            Combat = CombatSystem.StartCombat(Run, enemy);
            Phase = GamePhase.Combat;

            if (enemy.IsBoss)
            {
                var rules = string.Join(" ", enemy.Rules.Select(r => ActCatalog.RuleText(r, 0, enemy.RulesWeakened)));
                Message = $"{enemy.Name} erscheint. {rules}".Trim();
            }
            else Message = enemy.Tier == EnemyTier.Elite
                ? $"Elite: {enemy.Name} versperrt den Weg."
                : $"{enemy.Name} tritt aus dem Schatten.";
        }

        public TurnResult ResolveTurn()
        {
            if (Phase != GamePhase.Combat) return null;
            LastTurn = CombatSystem.ResolveTurn(Run, Combat);
            Message = string.Join("\n", LastTurn.Log.Skip(Math.Max(0, LastTurn.Log.Count - 4)));

            if (LastTurn.Victory) OnVictory();
            else if (LastTurn.Defeat)
            {
                Phase = GamePhase.GameOver;
                Message = $"Der Run endet in Akt {MetaProgress.Roman(Math.Min(4, Run.Act))}, Kampf {Run.FightIndex + 1}. Gesamt-Fate: {Run.FateScoreTotal}.";
            }
            return LastTurn;
        }

        /// <summary>Beantwortet das Angebot des Teufels.</summary>
        public bool AnswerPact(bool accept)
        {
            if (Phase != GamePhase.Combat || Combat == null) return false;
            var ok = CombatSystem.AnswerPact(Run, Combat, accept);
            if (ok)
                Message = accept
                    ? "Du unterschreibst. Deine Legungen treffen härter – dein Leben ist kürzer."
                    : "Du lehnst ab. Der Teufel lächelt und schlägt härter zu.";
            return ok;
        }

        private void OnVictory()
        {
            var enemy = Combat.Enemy.Definition;
            LastVictory = Progression.ResolveVictory(Run, Combat);
            var stats = Run.Stats;
            stats.FightsWon++;
            stats.MostShieldAtVictory = Math.Max(stats.MostShieldAtVictory, Combat.PlayerShield);
            if (Combat.Turn == 1) stats.OneTurnKills++;
            foreach (var card in Run.Deck) EventCatalog.NoteShimmer(Run, card);

            // Ueberschuss: der Treffer, der mehr nimmt, als da war, zahlt aus.
            // Ein grosser letzter Schlag soll sich lohnen, nicht verpuffen.
            var overkill = Combat.LastOverkill;
            if (overkill > 0)
            {
                var gold = Math.Min(OverkillGoldCap(Run.Act), overkill / OverkillPerGold);
                Run.Gold += gold;
                LastVictory.OverkillGold = gold;
                stats.BestOverkill = Math.Max(stats.BestOverkill, overkill);
            }

            if (enemy.Tier == EnemyTier.Elite) stats.ElitesDefeated++;

            if (enemy.IsBoss)
            {
                stats.BossesDefeated++;
                if (Run.Deck.Count <= 8) stats.ThinBossKills++;
                // Jedes gefallene Omen hinterlaesst Tinte.
                Run.AddDarkness(6);

                if (enemy.Tier == EnemyTier.Finale)
                {
                    Run.Won = true;
                    Phase = GamePhase.Victory;
                    Message = "DIE WELT IST NICHT DAS ENDE.";
                    return;
                }

                if (enemy.Act <= ActCatalog.ActCount && !Run.DefeatedBosses.Contains(enemy.Id))
                    Run.DefeatedBosses.Add(enemy.Id);
                Phase = GamePhase.BossLoot;
                Message = $"{enemy.Name} fällt. Das Omen liegt vor dir. " +
                          (LastVictory.OverkillGold > 0 ? $"Überschuss: +{LastVictory.OverkillGold} Gold." : string.Empty);
                return;
            }

            Rewards = Progression.GenerateRewards(Run, elite: enemy.Tier == EnemyTier.Elite);
            Phase = GamePhase.Reward;
            Message = $"Sieg. +{LastVictory.FateEarned} Fate, +{LastVictory.GoldEarned} Gold. " +
                      (LastVictory.OverkillGold > 0 ? $"Überschuss: +{LastVictory.OverkillGold} Gold. " : string.Empty) +
                      (LastVictory.Champion != null ? $"{LastVictory.Champion.Definition.Name} wurde vom Schicksal berührt." : string.Empty);
        }

        public static int OverkillGoldCap(int act) => 4 + 4 * Math.Min(4, Math.Max(1, act));
        /// <summary>Je so viel Ueberschuss gibt es ein Gold.</summary>
        public const int OverkillPerGold = 8;

        // ---------------------------------------------------- Omen-Beute
        /// <summary>
        /// Die Karten, die beim TRAENKEN dunkler werden: die drei, die im
        /// Bosskampf am meisten geleistet haben. Sie haben das Omen besiegt -
        /// sie trinken seine Tinte.
        /// </summary>
        public List<CardInstance> SoakTargets()
        {
            var fromFight = Combat?.Contributions.Values
                .OrderByDescending(c => c.Score)
                .Select(c => c.Card)
                .Where(c => Run.Deck.Contains(c))
                .Take(3)
                .ToList() ?? new List<CardInstance>();
            foreach (var card in Run.Deck.OrderByDescending(c => c.Level * 3 + (int)c.Shimmer * 6 + c.Definition.Rank))
            {
                if (fromFight.Count >= 3) break;
                if (!fromFight.Contains(card)) fromFight.Add(card);
            }
            return fromFight;
        }

        /// <summary>Das Grosse Arkanum, das BINDEN ins Deck holt.</summary>
        public CardDefinition OmenCard()
        {
            var id = Combat?.Enemy?.Definition?.OmenCardId;
            return string.IsNullOrEmpty(id) ? null : GameCatalog.Cards.FirstOrDefault(c => c.Id == id);
        }

        public const int SoakDarkness = 6;
        public const int BindDarkness = 10;
        public const int BanishGold = 70;
        public const int BanishLight = 8;

        public bool ChooseBossLoot(BossLootChoice choice)
        {
            if (Phase != GamePhase.BossLoot) return false;
            switch (choice)
            {
                case BossLootChoice.Soak:
                {
                    var cards = SoakTargets();
                    foreach (var card in cards)
                    {
                        card.Level++;
                        EventCatalog.Darken(Run, card);
                    }
                    Run.AddDarkness(SoakDarkness);
                    Message = "TRÄNKEN: " + string.Join(", ", cards.Select(c => $"{c.Definition.Name} ({ShimmerName(c.Shimmer)})")) +
                              " trinken die Tinte des Omens.";
                    break;
                }
                case BossLootChoice.Bind:
                {
                    var omen = OmenCard();
                    if (omen == null) return false;
                    var card = new CardInstance(omen)
                    {
                        Level = 2,
                        Shimmer = Shimmer.Blood,
                        Orientation = Orientation.Reversed
                    };
                    Run.Deck.Add(card);
                    EventCatalog.NoteShimmer(Run, card);
                    Run.AddDarkness(BindDarkness);
                    Message = $"BINDEN: {omen.Name} gehört jetzt dir – verkehrt herum und blutig.";
                    break;
                }
                default:
                {
                    Run.Gold += BanishGold;
                    var healed = Heal((int)Math.Round(Run.MaxHp * .20f));
                    Run.AddDarkness(-BanishLight);
                    Message = $"BANNEN: +{BanishGold} Gold, +{healed} HP. Das Licht kehrt ein wenig zurück.";
                    break;
                }
            }

            Progression.UpdateDeckResonance(Run);

            // Zwischen den Akten atmet man durch - nicht in der Spirale.
            if (!ActCatalog.IsSpiral(Run.FightIndex))
            {
                var healed = Heal((int)Math.Round(Run.MaxHp * (Run.Veil >= 7 ? ActTransitionHeal - .10f : ActTransitionHeal)));
                var nextAct = ActCatalog.ActOf(Run.FightIndex + 1);
                Message += nextAct <= ActCatalog.ActCount
                    ? $"\nAkt {MetaProgress.Roman(nextAct)}: {ActCatalog.ActNames[nextAct]}. Du atmest durch (+{healed} HP)."
                    : $"\nNur noch die Welt steht vor dir. Du atmest durch (+{healed} HP).";
            }

            GeneratePaths();
            Phase = GamePhase.PathChoice;
            return true;
        }

        private int Heal(int amount)
        {
            var before = Run.Hp;
            Run.Hp = Math.Min(Run.MaxHp, Run.Hp + Math.Max(0, amount));
            return Run.Hp - before;
        }

        public static string ShimmerName(Shimmer shimmer)
        {
            switch (shimmer)
            {
                case Shimmer.White: return "Weiß";
                case Shimmer.Indigo: return "Indigo";
                case Shimmer.Gold: return "Gold";
                case Shimmer.Blood: return "Blut";
                case Shimmer.Black: return "Schwarz";
                default: return "Matt";
            }
        }

        // ------------------------------------------------------- Sieg
        /// <summary>Nach dem Finale: weiter in die Schwarze Spirale.</summary>
        public void ContinueIntoSpiral()
        {
            if (Phase != GamePhase.Victory) return;
            // Der Sieg ueber die Welt ist ein Atemzug wert - wer danach ohne
            // Heilung in die Spirale stolpert, scheitert an der ersten Stufe.
            var healed = Heal((int)Math.Round(Run.MaxHp * SpiralEntryHeal));
            GeneratePaths();
            Phase = GamePhase.PathChoice;
            Message = $"Die Schwarze Spirale öffnet sich. Sie hat kein Ende – nur eine Tiefe. (+{healed} HP)";
        }

        public const float SpiralEntryHeal = .40f;

        /// <summary>Beendet einen gewonnenen Run (oder bricht einen ab).</summary>
        public void EndRun()
        {
            Phase = GamePhase.GameOver;
        }

        // ---------------------------------------------------- Belohnung
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

        // ------------------------------------------------------- Wegwahl
        public void ChoosePath(PathType path)
        {
            if (Phase != GamePhase.PathChoice) return;
            Run.StepsSinceShop = path == PathType.Shop ? 0 : Run.StepsSinceShop + 1;
            Run.StepsSinceRest = path == PathType.Rest ? 0 : Run.StepsSinceRest + 1;
            Run.LastPath = path;

            switch (path)
            {
                case PathType.Fight:
                    Run.Gold += DirectPathGold;
                    StartFight(true);
                    Message = $"Kein Umweg (+{DirectPathGold} Gold). " + Message;
                    break;
                case PathType.Elite:
                    Run.NextFightElite = true;
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
                case PathType.Event:
                    StartEvent();
                    break;
                case PathType.Rest:
                    Phase = GamePhase.Rest;
                    Message = "RAST: Ruhe dich aus oder lies eine Karte neu.";
                    break;
            }
        }

        public void ContinueFromOffgame()
        {
            if (Phase != GamePhase.Shop && Phase != GamePhase.Ritual && Phase != GamePhase.Oracle
                && Phase != GamePhase.Event && Phase != GamePhase.Rest) return;
            CurrentEvent = null;
            StartFight(true);
        }

        /// <summary>
        /// Drei Wege nach jedem Kampf. Der direkte Kampf ist immer dabei, die
        /// anderen beiden zieht das Schicksal - mit Garantien, weil reiner
        /// Zufall hier schlechtes Design waere.
        /// </summary>
        private void GeneratePaths()
        {
            var next = Run.FightIndex + 1;
            var bossNext = ActCatalog.IsBossFight(next) || ActCatalog.IsFinale(next) || ActCatalog.IsSpiralBoss(next);

            var forced = new List<PathType>();
            // Vor dem Omen: immer eine Rast anbieten. Ein Boss soll an deinem
            // Deck scheitern lassen, nicht an zufaellig fehlender Heilung.
            if (bossNext || Run.StepsSinceRest >= 5) forced.Add(PathType.Rest);
            // Ohne Haendler kann niemand ein Deck bauen.
            if (Run.StepsSinceShop >= 4) forced.Add(PathType.Shop);

            var candidates = new List<PathType> { PathType.Shop, PathType.Ritual, PathType.Oracle, PathType.Event, PathType.Rest };
            // Elite nie zweimal in Folge, nie direkt vor einem Boss und nicht in
            // der Spirale - dort waehlt die Spirale selbst.
            if (!bossNext && !ActCatalog.IsSpiral(next) && Run.LastPath != PathType.Elite
                && next % ActCatalog.FightsPerAct != 0)
                candidates.Add(PathType.Elite);
            // Ereignisse sind der haeufigste Umweg - sie tragen die Geschichten.
            candidates.Add(PathType.Event);

            Paths = new List<PathType> { PathType.Fight };
            foreach (var path in forced)
                if (Paths.Count < 3 && !Paths.Contains(path)) Paths.Add(path);
            var guard = 0;
            while (Paths.Count < 3 && guard++ < 50)
            {
                var pick = _rng.Pick(candidates);
                if (!Paths.Contains(pick)) Paths.Add(pick);
            }
            _rng.Shuffle(Paths);
        }

        // ----------------------------------------------------- Ereignis
        private void StartEvent()
        {
            var eligible = EventCatalog.All.Where(e => e.IsEligible(Run)).ToList();
            if (eligible.Count == 0)
            {
                // Alle Szenen gesehen: dann wenigstens eine Rast.
                Phase = GamePhase.Rest;
                Message = "Der Weg ist still. Du rastest.";
                return;
            }

            // Geschichten ueber Runs haben Vorrang, damit sie weitergehen.
            var weights = eligible.Select(e => e.Weight).ToList();
            CurrentEvent = _rng.PickWeighted(eligible, weights);
            EventResolved = false;
            EventEpilogue = string.Empty;
            Run.SeenEvents.Add(CurrentEvent.Id);
            Run.Stats.EventsSeen++;
            Phase = GamePhase.Event;
            Message = CurrentEvent.Title;
        }

        public bool CanChooseEventOption(int index) =>
            Phase == GamePhase.Event && CurrentEvent != null && !EventResolved
            && index >= 0 && index < CurrentEvent.Choices.Count
            && CurrentEvent.Choices[index].Available(Run);

        public bool ChooseEventOption(int index)
        {
            if (!CanChooseEventOption(index)) return false;
            var choice = CurrentEvent.Choices[index];
            EventEpilogue = choice.Resolve(new EventContext { Run = Run, Rng = _rng }) ?? string.Empty;
            EventResolved = true;
            Progression.UpdateDeckResonance(Run);
            Message = EventEpilogue;
            return true;
        }

        // ---------------------------------------------------------- Rast
        public int RestHealAmount =>
            (int)Math.Round(Run.MaxHp * (Run.Veil >= 7 ? RestHealFraction - .10f : RestHealFraction));

        /// <summary>Rasten: heilen, dann weiter.</summary>
        public bool RestHeal()
        {
            if (Phase != GamePhase.Rest) return false;
            var healed = Heal(RestHealAmount);
            StartFight(true);
            Message = $"Du rastest: +{healed} HP. " + Message;
            return true;
        }

        /// <summary>Rasten: eine Karte neu lesen (+1 Stufe), dann weiter.</summary>
        public bool RestStudy(CardInstance card)
        {
            if (Phase != GamePhase.Rest || card == null || !Run.Deck.Contains(card)) return false;
            card.Level++;
            Progression.UpdateDeckResonance(Run);
            StartFight(true);
            Message = $"Du liest {card.Definition.Name} neu: Stufe {card.Level}. " + Message;
            return true;
        }

        // -------------------------------------------------------- Haendler
        public void OpenShop()
        {
            Phase = GamePhase.Shop;
            ShopOffers.Clear();
            var card = RandomCard();
            var reversed = _rng.Chance(Run.Darkness * .005f);
            ShopOffers.Add(MakeShopOffer(new RewardOption
            {
                Type = RewardType.Card, Card = card, Title = card.Name, Description = card.Description,
                CardOrientation = reversed ? Orientation.Reversed : Orientation.Upright
            }, 38));

            var charms = GameCatalog.Charms.Where(c => Run.CharmAllowed(c.Id)).ToList();
            for (var i = 0; i < 2 && charms.Count > 0; i++)
            {
                var charm = _rng.Pick(charms);
                ShopOffers.Add(MakeShopOffer(new RewardOption { Type=RewardType.Charm, Charm=charm, Title=charm.Name, Description=charm.Description }, 58 + i * 7));
            }
            var item = _rng.Pick(GameCatalog.Items);
            ShopOffers.Add(MakeShopOffer(new RewardOption { Type=RewardType.Item, Item=item, Title=item.Name, Description=item.Description }, 46));
            Message = "Der Händler öffnet seinen Mantel.";
        }

        /// <summary>Grundpreis fuers Vergessen beim Haendler, vor Rabatten.</summary>
        public const int RemovalBasePrice = 45;
        public const int RemovalPriceStep = 25;

        /// <summary>
        /// Was das naechste Vergessen beim Haendler kostet.
        /// </summary>
        /// <remarks>
        /// Gold war bisher ab der Deckmitte eine tote Ressource - im Schnitt
        /// blieben 81 ungenutzt liegen. Vergessen ist die passende Senke: es
        /// kostet dauerhaft, staerkt den Ausduenn-Hebel und konkurriert mit
        /// dem Kauf neuer Karten um dasselbe Gold. Der Buchhalter zahlt doppelt.
        /// </remarks>
        public int RemovalPrice =>
            Progression.ShopPrice(Run, RemovalBasePrice + Run.ShopRemovals * RemovalPriceStep)
            * (Run.DeuterRule == DeuterRule.Bookkeeper ? 2 : 1);

        public bool CanRemoveAtShop(CardInstance card) =>
            Phase == GamePhase.Shop
            && card != null
            && Run.Deck.Contains(card)
            && Run.Deck.Count > GameCatalog.MinimumDeckSize
            && Run.Gold >= RemovalPrice;

        /// <summary>Loescht eine Karte beim Haendler gegen Gold.</summary>
        public bool RemoveCardAtShop(CardInstance card)
        {
            if (!CanRemoveAtShop(card))
            {
                Message = Run.Deck.Count <= GameCatalog.MinimumDeckSize
                    ? "Dünner geht es nicht."
                    : "Nicht genug Gold.";
                return false;
            }

            Run.Gold -= RemovalPrice;
            Run.ShopRemovals++;
            Run.Deck.Remove(card);
            Run.RemovedCards.Add(card);
            Progression.UpdateDeckResonance(Run);
            Message = $"{card.Definition.Name} wurde vergessen.";
            return true;
        }

        public const int RefineBasePrice = 70;
        public const int RefinePriceStep = 30;

        /// <summary>
        /// Veredeln beim Haendler: eine Karte steigt eine Stufe und dunkelt
        /// nach. Die zweite Goldsenke - Gold wird hier direkt zu Kraft, aber
        /// jedes Mal teurer und jedes Mal ein wenig dunkler.
        /// </summary>
        public int RefinePrice =>
            Progression.ShopPrice(Run, RefineBasePrice + Run.ShopRefines * RefinePriceStep);

        public bool CanRefineAtShop(CardInstance card) =>
            Phase == GamePhase.Shop && card != null && Run.Deck.Contains(card) && Run.Gold >= RefinePrice;

        public bool RefineAtShop(CardInstance card)
        {
            if (!CanRefineAtShop(card))
            {
                Message = "Nicht genug Gold.";
                return false;
            }
            Run.Gold -= RefinePrice;
            Run.ShopRefines++;
            card.Level++;
            EventCatalog.Darken(Run, card);
            Run.AddDarkness(2);
            Progression.UpdateDeckResonance(Run);
            Message = $"{card.Definition.Name} wurde veredelt: Stufe {card.Level}, {ShimmerName(card.Shimmer)}.";
            return true;
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

        // ---------------------------------------------------------- Ritual
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
            Message = ok ? $"{card.Definition.Name} entwickelt sich zu {ShimmerName(card.Shimmer)}, Stufe {card.Level}." : "Nicht genug Fate für die Entwicklung.";
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

        // --------------------------------------------------------- Intern
        /// <summary>Kopiert Lesarten, Story-Flags, Charm-Pool und das Grab in den Run.</summary>
        private static void ApplyMeta(RunState run, MetaProgress meta)
        {
            if (meta == null) return;
            foreach (var pair in meta.Interpretations)
                if (pair.Value != null && pair.Value.Count > 0)
                    run.Interpretations[pair.Key] = pair.Value.Count;
            foreach (var flag in meta.StoryFlags) run.StoryFlags.Add(flag);
            run.CharmPool = meta.CharmPool();

            var grave = meta.DeathCards.LastOrDefault();
            if (grave != null && !string.IsNullOrEmpty(grave.CardId))
            {
                run.GraveCardId = grave.CardId;
                run.GraveFight = grave.Fight;
            }
        }

        private ShopOffer MakeShopOffer(RewardOption reward, int basePrice)
        {
            return new ShopOffer { Reward=reward, Price=Progression.ShopPrice(Run, basePrice) };
        }

        private CardDefinition RandomCard() => _rng.Pick(GameCatalog.Cards);

        private EnemyDefinition PickUnseen(List<EnemyDefinition> pool)
        {
            var fresh = pool.Where(e => !Run.SeenEnemies.Contains(e.Id)).ToList();
            return _rng.Pick(fresh.Count > 0 ? fresh : pool);
        }

        private EnemyDefinition BuildEnemy()
        {
            var index = Run.FightIndex;
            var act = Math.Min(ActCatalog.ActCount, Math.Max(1, Run.Act));
            EnemyDefinition template;

            // Ein Ereignis darf einen normalen Kampf ersetzen, nie einen Boss:
            // sonst koennte der Kartenspieler das Finale verdraengen.
            var bossSlot = ActCatalog.IsBossFight(index) || ActCatalog.IsFinale(index) || ActCatalog.IsSpiral(index);
            var pending = bossSlot ? null : ActCatalog.Find(Run.PendingEnemyId);
            if (pending != null) Run.PendingEnemyId = string.Empty;
            var elite = Run.NextFightElite && !bossSlot;
            if (!bossSlot) Run.NextFightElite = false;

            if (pending != null)
                template = pending.Clone();
            else if (ActCatalog.IsFinale(index))
            {
                template = ActCatalog.Finale.Clone();
                // Das Finale traegt die Regeln der Bosse, die du geschlagen hast.
                foreach (var id in Run.DefeatedBosses)
                {
                    var boss = ActCatalog.Find(id);
                    if (boss == null) continue;
                    foreach (var rule in boss.Rules)
                        if (!template.Rules.Contains(rule)) template.Rules.Add(rule);
                }
            }
            else if (ActCatalog.IsSpiral(index))
                template = BuildSpiralEnemy(ActCatalog.SpiralDepth(index));
            else if (ActCatalog.IsBossFight(index))
            {
                var planned = act - 1 < Run.ActBosses.Count ? ActCatalog.Find(Run.ActBosses[act - 1]) : null;
                template = (planned ?? _rng.Pick(ActCatalog.BossesOf(act))).Clone();
            }
            else if (elite)
                template = PickUnseen(ActCatalog.ElitesOf(act)).Clone();
            else
                template = PickUnseen(ActCatalog.NormalsOf(act)).Clone();

            if (!Run.SeenEnemies.Contains(template.Id)) Run.SeenEnemies.Add(template.Id);
            return Scale(template);
        }

        /// <summary>
        /// Wachstum der Spirale je Tiefe: exponentiell mal quadratisch, damit
        /// auch absurde Builds irgendwann scheitern - aber nicht an der ersten
        /// Stufe. Gemessen: Sieger kommen im Schnitt einige Tiefen weit.
        /// </summary>
        public const double SpiralHpGrowth = 1.08;
        public const double SpiralHpCurve = .008;

        private static readonly BossRule[] SpiralRules =
            { BossRule.Tower, BossRule.Moon, BossRule.Death, BossRule.Wheel, BossRule.Devil, BossRule.HangedMan };

        /// <summary>
        /// Die Schwarze Spirale: Gegner aus allen Akten, superexponentiell
        /// wachsend, damit auch absurde Builds irgendwann scheitern. Jeder
        /// vierte ist der Weltenwurm mit Regeln, die sich stapeln.
        /// </summary>
        private EnemyDefinition BuildSpiralEnemy(int depth)
        {
            EnemyDefinition template;
            if (ActCatalog.IsSpiralBoss(Run.FightIndex))
            {
                template = ActCatalog.SpiralBoss.Clone();
                var ruleCount = Math.Min(SpiralRules.Length, 2 + depth / (ActCatalog.SpiralBossInterval * 2));
                foreach (var rule in _rng.PickDistinct(SpiralRules, ruleCount)) template.Rules.Add(rule);
            }
            else
            {
                var pool = ActCatalog.NormalsOf(3).Concat(ActCatalog.ElitesOf(3)).ToList();
                template = _rng.Pick(pool).Clone();
            }

            var growth = Math.Pow(SpiralHpGrowth, depth) * (1 + SpiralHpCurve * depth * depth);
            template.Id = $"{template.Id}_spirale_{depth}";
            template.Name = $"{template.Name} · Spirale {depth}";
            template.Act = 5;
            template.MaxHp = (int)Math.Round(template.MaxHp * growth);
            template.MaxStance = (int)Math.Round(template.MaxStance * (1 + depth * .06));
            template.BaseAttack += depth;
            template.Sigils = Math.Min(4, template.Sigils + depth / 8);
            return template;
        }

        /// <summary>Schleier und Verdunkelung auf einen Gegner anwenden.</summary>
        /// <remarks>
        /// Mehr Gegner-HP allein aendert kaum etwas - die Kampflaenge bestimmt
        /// der Haltungsdeckel. Die Schleier greifen deshalb dort an, wo es
        /// gemessen wirkt: Angriff, Bosshaltung, eigene Lebenskraft.
        /// </remarks>
        private EnemyDefinition Scale(EnemyDefinition enemy)
        {
            var strong = enemy.IsBoss || enemy.Tier == EnemyTier.Elite;
            if (Run.Veil >= 2 && strong)
            {
                enemy.MaxHp = (int)Math.Round(enemy.MaxHp * 1.2f);
                enemy.MaxStance = (int)Math.Round(enemy.MaxStance * 1.2f);
            }
            // Die harten Stufen greifen erst ab Akt II: sie sollen den ganzen
            // Bogen schwerer machen, nicht nur den ersten Boss zur Mauer.
            var lateAct = Math.Max(0, Math.Min(3, Run.Act - 1));
            if (Run.Veil >= 5 && strong) enemy.BaseAttack += lateAct;
            if (Run.Veil >= 6 && lateAct > 0) enemy.BaseAttack += 1;
            enemy.BaseAttack += Run.Darkness / 25;
            if (enemy.Tier == EnemyTier.Finale && Run.Veil >= 8) enemy.Sigils++;
            return enemy;
        }
    }
}
