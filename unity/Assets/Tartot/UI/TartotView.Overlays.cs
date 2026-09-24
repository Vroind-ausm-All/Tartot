using System;
using System.Linq;
using Tartot.Core;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Die Overlays: Titel, Belohnung, Wege, Haendler, Ritual, Orakel,
    /// Ereignis, Omen-Beute, Rast, Sieg und der Run-Bericht.
    /// </summary>
    /// <remarks>
    /// Die Reihenfolge der Knoepfe im Bericht ist Absicht: "NOCH EINMAL" steht
    /// oben und startet sofort mit derselben Figur und demselben Schleier.
    /// Zwischen Tod und naechstem Run liegt genau ein Tipp.
    /// </remarks>
    public sealed partial class TartotView
    {
        /// <summary>Wie viele Beats der laufenden Szene schon zu sehen sind.</summary>
        private int _eventBeat;
        private string _eventId = string.Empty;
        /// <summary>Haendler: Deck-Reihe vergisst (false) oder veredelt (true).</summary>
        private bool _shopRefine;

        private void RefreshOverlay()
        {
            _overlayRow.Clear();
            _overlayButtons.Clear();
            _overlayTitle.EnableInClassList("titel__marke", _showTitle || _game == null);

            if (_showTitle || _game == null)
            {
                BuildTitleOverlay();
                _overlay.style.display = DisplayStyle.Flex;
                return;
            }

            switch (_game.Phase)
            {
                case GamePhase.Combat:
                    _overlay.style.display = DisplayStyle.None;
                    return;
                case GamePhase.Reward: BuildRewardOverlay(); break;
                case GamePhase.PathChoice: BuildPathOverlay(); break;
                case GamePhase.Shop: BuildShopOverlay(); break;
                case GamePhase.Ritual: BuildRitualOverlay(); break;
                case GamePhase.Oracle: BuildOracleOverlay(); break;
                case GamePhase.Event: BuildEventOverlay(); break;
                case GamePhase.BossLoot: BuildBossLootOverlay(); break;
                case GamePhase.Rest: BuildRestOverlay(); break;
                case GamePhase.Victory: BuildVictoryOverlay(); break;
                case GamePhase.GameOver: BuildReportOverlay(); break;
            }
            _overlay.style.display = DisplayStyle.Flex;
        }

        private Button OverlayButton(string text, Action action, bool secondary = false)
        {
            var button = new Button(() => { action(); Save(); Refresh(); }) { text = text };
            button.AddToClassList("knopf");
            if (secondary) button.AddToClassList("knopf--zweitrangig");
            _overlayButtons.Add(button);
            return button;
        }

        private Label RowLabel(string text, string cssClass)
        {
            var label = new Label(text);
            label.AddToClassList(cssClass);
            _overlayRow.Add(label);
            return label;
        }

        // ----------------------------------------------------------- Titel
        private void BuildTitleOverlay()
        {
            _overlayTitle.text = "TARTOT";
            var done = _meta.CompletedProphecies.Count;
            _overlaySubtitle.text = _meta.RunsStarted == 0
                ? "Lege drei Karten. Lies dein Schicksal. Ändere es."
                : $"{_meta.RunsStarted} Runs · {_meta.RunsWon} Siege · Prophezeiungen {done}/{ProphecyCatalog.All.Count}" +
                  (_meta.BestSpiralDepth > 0 ? $" · Spirale {_meta.BestSpiralDepth}" : string.Empty);

            RowLabel("DEUTER", "bericht__abschnitt");
            foreach (var deuter in DeuterCatalog.All)
            {
                var unlocked = _meta.IsDeuterUnlocked(deuter.Id);
                var selected = _setup.DeuterId == deuter.Id;
                var hint = unlocked
                    ? deuter.RuleText
                    : "Gesperrt — " + (ProphecyCatalog.Find(deuter.UnlockedBy)?.Text ?? string.Empty);
                var captured = deuter.Id;
                var button = OverlayButton($"{(selected ? "▸ " : string.Empty)}{deuter.Name} — {deuter.Subtitle}\n{hint}",
                    () => _setup = new RunSetup { DeuterId = captured, Veil = _setup.Veil }, secondary: !selected);
                button.SetEnabled(unlocked);
            }

            var veil = Math.Min(_setup.Veil, _meta.Veil);
            var definition = VeilCatalog.Get(veil);
            var veilButton = OverlayButton($"SCHLEIER {veil}: {definition.Name} — {definition.Text}" +
                                           (_meta.Veil > 0 ? "\n(tippen zum Wechseln)" : "\nGewinne einen Run, um den ersten Schleier zu öffnen."),
                () => _setup = new RunSetup { DeuterId = _setup.DeuterId, Veil = veil >= _meta.Veil ? 0 : veil + 1 },
                secondary: true);
            veilButton.SetEnabled(_meta.Veil > 0);

            OverlayButton("RUN BEGINNEN", () =>
            {
                var chosen = _meta.IsDeuterUnlocked(_setup.DeuterId) ? _setup.DeuterId : DeuterCatalog.DefaultId;
                NewRun(new RunSetup { DeuterId = chosen, Veil = veil });
            });

            var daily = RunSetup.Daily();
            var dailyDone = _meta.LastDailySeed == MetaProgress.DailySeed();
            OverlayButton($"TAGESKARTE — {DeuterCatalog.Find(daily.DeuterId).Name}, Schleier {daily.Veil}" +
                          (dailyDone ? $"\nHeute schon gelegt · bester Wert {_meta.BestDailyFate} Fate" : "\nFür alle derselbe Seed."),
                () => NewRun(daily), secondary: true);
        }

        // ------------------------------------------------------- Belohnung
        private void BuildRewardOverlay()
        {
            _overlayTitle.text = "WÄHLE EINE BELOHNUNG";
            _overlaySubtitle.text = _game.Message;
            for (var i = 0; i < _game.Rewards.Count; i++)
            {
                var index = i;
                var reward = _game.Rewards[i];
                OverlayButton($"{reward.Title}\n{reward.Description}",
                    () => _game.ChooseReward(index), secondary: true);
            }
            OverlayButton("ÜBERSPRINGEN — dein Deck bleibt dünn", () => _game.SkipRewardForFate());
        }

        // ---------------------------------------------------------- Wege
        private void BuildPathOverlay()
        {
            var run = _game.Run;
            _overlayTitle.text = "WOHIN FÜHRT DEIN WEG?";
            _overlaySubtitle.text = $"{_game.Message}\n{run.Deck.Count} Karten · {run.Gold} Gold · {run.Hp}/{run.MaxHp} HP · Resonanz {run.DeckResonance}/10";

            // Das naechste Omen steht immer da - wer weiss, was kommt, plant.
            var next = run.FightIndex + 1;
            if (!ActCatalog.IsSpiral(next))
            {
                var boss = ActCatalog.IsFinale(next) || run.Act == 4 ? ActCatalog.Finale : _game.UpcomingBoss();
                var until = ActCatalog.FightsUntilBoss(next);
                if (boss != null)
                    RowLabel(until == 0
                            ? $"ALS NÄCHSTES: {boss.Name.ToUpperInvariant()}"
                            : $"Noch {until} {(until == 1 ? "Kampf" : "Kämpfe")} bis {boss.Name}",
                        "bericht__abschnitt");
                if (boss != null && boss.Rules.Count > 0)
                    RowLabel(string.Join(" ", boss.Rules.Select(r => ActCatalog.RuleText(r, 0, boss.RulesWeakened))), "bericht__zeile");
            }

            foreach (var path in _game.Paths)
            {
                var captured = path;
                OverlayButton(PathLabel(path), () => _game.ChoosePath(captured), secondary: true);
            }
        }

        private static string PathLabel(PathType path)
        {
            switch (path)
            {
                case PathType.Shop: return "HÄNDLER — sein Mantel öffnet sich";
                case PathType.Ritual: return "RITUAL — forme dein Deck";
                case PathType.Oracle: return "ORAKEL — eine Prophezeiung";
                case PathType.Elite: return "ELITE — mehr Gefahr, sichere Charms";
                case PathType.Event: return "UNBEKANNT — etwas wartet am Wegrand";
                case PathType.Rest: return "RAST — heilen oder eine Karte neu lesen";
                default: return $"KAMPF — kein Umweg (+{GameController.DirectPathGold} Gold)";
            }
        }

        // -------------------------------------------------------- Haendler
        private void BuildShopOverlay()
        {
            _overlayTitle.text = "DER HÄNDLER";
            _overlaySubtitle.text = $"{_game.Run.Gold} Gold" + (_game.Run.FreeNextShopPurchase ? " · der nächste Kauf ist umsonst" : string.Empty);
            for (var i = 0; i < _game.ShopOffers.Count; i++)
            {
                var index = i;
                var offer = _game.ShopOffers[i];
                var button = OverlayButton(
                    offer.Sold ? $"{offer.Reward.Title} — verkauft"
                               : $"{offer.Reward.Title} — {offer.Price} Gold",
                    () => _game.BuyShopOffer(index), secondary: true);
                button.SetEnabled(!offer.Sold && (_game.Run.FreeNextShopPurchase || _game.Run.Gold >= offer.Price));
            }

            // Zwei Goldsenken an derselben Deck-Reihe: Vergessen macht das Deck
            // duenner, Veredeln macht eine Karte staerker - und dunkler.
            RowLabel(_shopRefine
                    ? $"VEREDELN — {_game.RefinePrice} Gold: eine Stufe hoch, eine Stufe dunkler"
                    : $"VERGESSEN — {_game.RemovalPrice} Gold je Karte",
                "overlay__untertitel");

            var deckRow = new VisualElement();
            deckRow.AddToClassList("overlay__reihe");
            foreach (var card in _game.Run.Deck)
            {
                var element = new CardElement(card, clicked =>
                {
                    if (_shopRefine) _game.RefineAtShop(clicked.Card);
                    else _game.RemoveCardAtShop(clicked.Card);
                    Save();
                    Refresh();
                });
                element.SetEnabled(_shopRefine ? _game.CanRefineAtShop(card) : _game.CanRemoveAtShop(card));
                deckRow.Add(element);
            }
            _overlayRow.Add(deckRow);

            OverlayButton(_shopRefine ? "ZUM VERGESSEN WECHSELN" : "ZUM VEREDELN WECHSELN",
                () => _shopRefine = !_shopRefine, secondary: true);
            OverlayButton("WEITERGEHEN", () => { _shopRefine = false; _game.ContinueFromOffgame(); });
        }

        private void BuildRitualOverlay()
        {
            _overlayTitle.text = "RITUAL";
            _overlaySubtitle.text = "Du veränderst nicht nur Zahlen. Du formst dein Deck.";
            foreach (var card in _game.Run.Deck.Take(12))
            {
                var element = new CardElement(card, clicked =>
                {
                    _game.RitualRemove(clicked.Card);
                    Save();
                    Refresh();
                });
                _overlayRow.Add(element);
            }
            OverlayButton("WEITERGEHEN", () => _game.ContinueFromOffgame());
        }

        private void BuildOracleOverlay()
        {
            _overlayTitle.text = "DAS ORAKEL";
            _overlaySubtitle.text = "Drei Prophezeiungen. Eine gilt.";
            foreach (var prophecy in new[] { "XXI", "BLUT", "EINHEIT" })
            {
                var captured = prophecy;
                OverlayButton(captured, () => _game.ChooseOracle(captured), secondary: true);
            }
            OverlayButton("WEITERGEHEN", () => _game.ContinueFromOffgame());
        }

        // ------------------------------------------------- Zwischensequenz
        /// <summary>
        /// Ein Ereignis spielt sich wie eine kurze Szene: ein Satz nach dem
        /// anderen, dann die Entscheidung, dann der Schlusssatz.
        /// </summary>
        private void BuildEventOverlay()
        {
            var scene = _game.CurrentEvent;
            if (scene == null) { OverlayButton("WEITERGEHEN", () => _game.ContinueFromOffgame()); return; }
            if (scene.Id != _eventId)
            {
                _eventId = scene.Id;
                _eventBeat = 0;
            }

            _overlayTitle.text = scene.Title.ToUpperInvariant();
            _overlaySubtitle.text = scene.IsStory ? "— eine Geschichte, die sich erinnert —" : string.Empty;

            var picture = new VisualElement();
            picture.AddToClassList("szene__bild");
            picture.AddToClassList("szene--" + scene.Art);
            _overlayRow.Add(picture);

            var beats = scene.BeatsFor(_game.Run);
            var shown = _game.EventResolved ? beats.Length : Math.Min(_eventBeat + 1, beats.Length);
            for (var i = 0; i < shown; i++)
            {
                var beat = RowLabel(beats[i], "szene__beat");
                if (i == shown - 1 && !_game.EventResolved) beat.AddToClassList("szene__beat--neu");
            }

            if (_game.EventResolved)
            {
                RowLabel(_game.EventEpilogue, "szene__schluss");
                OverlayButton("WEITERGEHEN", () => _game.ContinueFromOffgame());
                return;
            }

            if (shown < beats.Length)
            {
                OverlayButton("…", () => _eventBeat++, secondary: true);
                return;
            }

            for (var i = 0; i < scene.Choices.Count; i++)
            {
                var index = i;
                var choice = scene.Choices[i];
                var button = OverlayButton($"{choice.Label}\n{choice.Hint}", () => _game.ChooseEventOption(index), secondary: true);
                button.SetEnabled(_game.CanChooseEventOption(index));
            }
        }

        // ------------------------------------------------------ Omen-Beute
        private void BuildBossLootOverlay()
        {
            var omen = _game.OmenCard();
            _overlayTitle.text = "DAS OMEN FÄLLT";
            _overlaySubtitle.text = _game.Message + "\nWas geschieht mit seiner Tinte?";

            var soak = string.Join(", ", _game.SoakTargets().Select(c => c.Definition.Name));
            OverlayButton($"TRÄNKEN — {soak}\nje eine Stufe höher und dunkler · +{GameController.SoakDarkness} Verdunkelung",
                () => _game.ChooseBossLoot(BossLootChoice.Soak), secondary: true);
            if (omen != null)
                OverlayButton($"BINDEN — {omen.Name} kommt ins Deck\nverkehrt und blutig · +{GameController.BindDarkness} Verdunkelung",
                    () => _game.ChooseBossLoot(BossLootChoice.Bind), secondary: true);
            OverlayButton($"BANNEN — +{GameController.BanishGold} Gold, Heilung\n−{GameController.BanishLight} Verdunkelung",
                () => _game.ChooseBossLoot(BossLootChoice.Banish), secondary: true);
        }

        // ------------------------------------------------------------ Rast
        private void BuildRestOverlay()
        {
            _overlayTitle.text = "RAST";
            _overlaySubtitle.text = $"{_game.Run.Hp} / {_game.Run.MaxHp} HP. Ruhe dich aus – oder lies eine Karte neu.";
            OverlayButton($"RUHEN — +{_game.RestHealAmount} HP", () => _game.RestHeal());

            RowLabel("ODER EINE KARTE NEU LESEN (+1 Stufe):", "overlay__untertitel");
            var deckRow = new VisualElement();
            deckRow.AddToClassList("overlay__reihe");
            foreach (var card in _game.Run.Deck)
                deckRow.Add(new CardElement(card, clicked =>
                {
                    _game.RestStudy(clicked.Card);
                    Save();
                    Refresh();
                }));
            _overlayRow.Add(deckRow);
        }

        // ------------------------------------------------------------ Sieg
        private void BuildVictoryOverlay()
        {
            _overlayTitle.text = "DIE WELT IST NICHT DAS ENDE.";
            _overlaySubtitle.text = "Du hast gewonnen. Hinter der Welt dreht sich die Schwarze Spirale – " +
                                    "sie hat kein Ende, nur eine Tiefe.";
            OverlayButton("IN DIE SPIRALE", () => _game.ContinueIntoSpiral());
            OverlayButton("DEN RUN BEENDEN", () => { _game.EndRun(); CompleteRunOnce(); }, secondary: true);
        }

        // ------------------------------------------------------- Bericht
        private void BuildReportOverlay()
        {
            CompleteRunOnce();
            var report = _report;
            _overlayTitle.text = report?.Headline ?? "DU FÄLLST";
            _overlaySubtitle.text = report == null ? string.Empty
                : (string.IsNullOrEmpty(report.KilledBy) ? string.Empty : report.KilledBy + "\n") +
                  $"Kampf {report.FightsCleared + 1} · {report.FateTotal} Fate · Verdunkelung {report.Darkness}";

            if (report != null)
            {
                if (report.BestHit > 0)
                    RowLabel($"Stärkste Legung: {report.BestHit} — {report.BestHitCombo}", "bericht__zeile");

                if (report.Records.Count > 0)
                {
                    RowLabel("REKORDE", "bericht__abschnitt");
                    foreach (var record in report.Records) RowLabel(record, "bericht__neu");
                }

                if (report.Unlocked.Count > 0)
                {
                    RowLabel("NEU FREIGESCHALTET", "bericht__abschnitt");
                    foreach (var unlocked in report.Unlocked) RowLabel(unlocked, "bericht__neu");
                }

                if (report.NearMisses.Count > 0)
                {
                    RowLabel("BEINAHE", "bericht__abschnitt");
                    foreach (var near in report.NearMisses) _overlayRow.Add(NearMissElement(near));
                }
            }

            // Ein Tipp bis zum naechsten Run - mit derselben Figur, demselben Schleier.
            OverlayButton("NOCH EINMAL", () => NewRun(new RunSetup { DeuterId = _setup.DeuterId, Veil = _setup.Veil }));
            OverlayButton("ANDERE FIGUR, ANDERER SCHLEIER", () => { _showTitle = true; _game = null; }, secondary: true);
        }

        private static VisualElement NearMissElement(NearMiss near)
        {
            var box = new VisualElement();
            box.AddToClassList("beinahe");
            var title = new Label(near.Title);
            title.AddToClassList("beinahe__titel");
            box.Add(title);
            var text = new Label(string.IsNullOrEmpty(near.Reward) ? near.Detail : $"{near.Detail}\n→ {near.Reward}");
            text.AddToClassList("beinahe__text");
            box.Add(text);
            var bar = new VisualElement();
            bar.AddToClassList("beinahe__balken");
            var fill = new VisualElement();
            fill.AddToClassList("beinahe__fuellung");
            fill.style.width = Length.Percent(Math.Max(0f, Math.Min(1f, near.Progress)) * 100f);
            bar.Add(fill);
            box.Add(bar);
            return box;
        }
    }
}
