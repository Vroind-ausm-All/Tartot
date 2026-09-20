using System;
using System.Collections.Generic;
using System.Linq;
using Tartot.Core;
using UnityEngine;
using UnityEngine.UIElements;

namespace Tartot.Unity
{
    /// <summary>
    /// Bindet den Regelkern an die Oberflaeche.
    /// </summary>
    /// <remarks>
    /// Diese Klasse enthaelt keine Spielregeln. Sie liest Zustand aus dem
    /// GameController und schickt Eingaben zurueck - mehr nicht. Wer eine
    /// Regel sucht, findet sie in Tartot.Core, nie hier.
    ///
    /// Bedienung: Karte antippen, dann einen Platz antippen. Ein belegter
    /// Platz gibt die Karte auf Tipp zurueck auf die Hand.
    /// </remarks>
    [RequireComponent(typeof(UIDocument))]
    public sealed class TartotView : MonoBehaviour
    {
        [Tooltip("0 = zufaelliger Seed. Ein fester Wert macht einen Run reproduzierbar.")]
        public long Seed;

        [Tooltip("Speicherstand automatisch nach jedem Zug schreiben.")]
        public bool AutoSave = true;

        private const string SaveKey = "tartot.save";
        private const string MetaKey = "tartot.meta";

        private GameController _game;
        private MetaProgress _meta;
        private CardElement _selected;

        // Zwischengespeicherte Elemente - Q<T>() ist zu teuer fuer jeden Frame.
        private VisualElement _root, _charmBar, _hand, _overlay, _overlayRow, _overlayButtons;
        private VisualElement _enemyHpBar, _enemyStanceBar;
        private Label _enemyName, _enemyHp, _enemyStance, _enemyIntent;
        private Label _playerHp, _playerShield, _playerFate, _playerLuck, _playerTurn;
        private Label _preview, _log, _overlayTitle, _overlaySubtitle;
        private Button _actButton;
        private readonly Dictionary<SlotPosition, VisualElement> _slots =
            new Dictionary<SlotPosition, VisualElement>();
        private readonly Dictionary<SlotPosition, VisualElement> _slotContents =
            new Dictionary<SlotPosition, VisualElement>();

        private void OnEnable()
        {
            _root = GetComponent<UIDocument>().rootVisualElement;
            CacheElements();
            _meta = MetaProgress.Deserialize(PlayerPrefs.GetString(MetaKey, string.Empty));
            StartOrResume();
        }

        private void CacheElements()
        {
            _enemyName = _root.Q<Label>("gegner-name");
            _enemyHp = _root.Q<Label>("gegner-hp");
            _enemyStance = _root.Q<Label>("gegner-haltung");
            _enemyIntent = _root.Q<Label>("gegner-absicht");
            _enemyHpBar = _root.Q<VisualElement>("gegner-hp-balken");
            _enemyStanceBar = _root.Q<VisualElement>("gegner-haltung-balken");

            _playerHp = _root.Q<Label>("spieler-hp");
            _playerShield = _root.Q<Label>("spieler-schild");
            _playerFate = _root.Q<Label>("spieler-fate");
            _playerLuck = _root.Q<Label>("spieler-luck");
            _playerTurn = _root.Q<Label>("spieler-runde");

            _charmBar = _root.Q<VisualElement>("charmleiste");
            _hand = _root.Q<VisualElement>("hand");
            _preview = _root.Q<Label>("vorschau");
            _log = _root.Q<Label>("protokoll");

            _overlay = _root.Q<VisualElement>("overlay");
            _overlayTitle = _root.Q<Label>("overlay-titel");
            _overlaySubtitle = _root.Q<Label>("overlay-untertitel");
            _overlayRow = _root.Q<VisualElement>("overlay-reihe");
            _overlayButtons = _root.Q<VisualElement>("overlay-knoepfe");

            _actButton = _root.Q<Button>("ausfuehren");
            _actButton.clicked += OnAct;

            foreach (var slot in new[] { SlotPosition.Past, SlotPosition.Present, SlotPosition.Future })
            {
                var key = slot.ToString().ToLowerInvariant();
                var element = _root.Q<VisualElement>("platz-" + key);
                _slots[slot] = element;
                _slotContents[slot] = _root.Q<VisualElement>("platz-" + key + "-inhalt");
                var captured = slot;
                element.RegisterCallback<ClickEvent>(_ => OnSlotClicked(captured));
            }
        }

        // ------------------------------------------------------ Run-Steuerung
        private void StartOrResume()
        {
            var saved = PlayerPrefs.GetString(SaveKey, string.Empty);
            if (string.IsNullOrEmpty(saved))
            {
                NewRun();
            }
            else if (SaveSystem.TryDeserialize(saved, out var save, out var error))
            {
                _game = GameController.Restore(save);
            }
            else
            {
                // Ein kaputter Stand darf den Einstieg nicht blockieren.
                Debug.LogWarning($"Speicherstand unlesbar, starte neu: {error}");
                NewRun();
            }
            Refresh();
        }

        private void NewRun()
        {
            var seed = Seed != 0 ? Seed : DateTime.UtcNow.Ticks;
            // Der Meta-Fortschritt geht in den Run: freigeschaltete Lesarten
            // vertiefen die Wirkung der Grossen Arkana, die man oft genug
            // gespielt hat.
            _game = new GameController(seed, _meta);
            PlayerPrefs.DeleteKey(SaveKey);
        }

        private void Save()
        {
            if (!AutoSave || _game == null) return;
            PlayerPrefs.SetString(SaveKey, _game.Save());
            PlayerPrefs.SetString(MetaKey, _meta.Serialize());
            PlayerPrefs.Save();
        }

        // ------------------------------------------------------- Eingaben
        private void OnCardClicked(CardElement card)
        {
            if (_game.Phase != GamePhase.Combat) return;
            if (_selected == card) { _selected.SetSelected(false); _selected = null; }
            else
            {
                _selected?.SetSelected(false);
                _selected = card;
                _selected.SetSelected(true);
            }
            RefreshPreview();
        }

        private void OnSlotClicked(SlotPosition slot)
        {
            if (_game.Phase != GamePhase.Combat) return;

            if (_game.Combat.Slots.ContainsKey(slot))
            {
                _game.CombatSystem.ReturnSlotToHand(_game.Combat, slot);
            }
            else if (_selected != null)
            {
                _game.CombatSystem.PlaceCard(_game.Combat, _selected.Card.InstanceId, slot);
            }
            else return;

            _selected = null;
            Refresh();
        }

        private void OnAct()
        {
            if (_game.Phase != GamePhase.Combat) return;
            if (_game.Combat.Slots.Count == 0)
            {
                _log.text = "Lege mindestens eine Karte.";
                return;
            }

            var wasFight = _game.Run.FightIndex;
            _game.ResolveTurn();
            _selected = null;

            if (_game.Phase == GamePhase.GameOver)
                _meta.RegisterRun(_game, won: false,
                    killedBy: _game.Combat?.Enemy?.Definition?.Name ?? string.Empty);
            else if (_game.Run.FightIndex > wasFight)
                // Jeder ueberstandene Kampf zaehlt als Begegnung mit den
                // Grossen Arkana im Deck - so wachsen die Lesarten.
                foreach (var card in _game.Run.Deck)
                    if (card.Definition.IsMajor) _meta.EncounterArcanum(card.Definition.Id);

            Save();
            Refresh();
        }

        // ---------------------------------------------------- Darstellung
        private void Refresh()
        {
            RefreshEnemy();
            RefreshPlayer();
            RefreshCharms();
            RefreshSpread();
            RefreshHand();
            RefreshPreview();
            _log.text = _game.Message;
            _actButton.SetEnabled(_game.Phase == GamePhase.Combat);
            RefreshOverlay();
        }

        private void RefreshEnemy()
        {
            var enemy = _game.Combat?.Enemy;
            if (enemy == null) return;

            _enemyName.text = enemy.Definition.Name.ToUpperInvariant();
            _enemyHp.text = $"{Mathf.Max(0, enemy.Hp)} / {enemy.Definition.MaxHp} HP"
                            + (enemy.Sigils > 0 ? $"   ✦ {enemy.Sigils} Siegel" : string.Empty);
            SetBar(_enemyHpBar, enemy.Hp, enemy.Definition.MaxHp);

            var stanceBroken = enemy.Stance <= 0;
            _enemyStance.text = stanceBroken
                ? "HALTUNG GEBROCHEN — Schadensfenster offen"
                : $"Haltung {enemy.Stance} / {enemy.Definition.MaxStance}";
            SetBar(_enemyStanceBar, enemy.Stance, Mathf.Max(1, enemy.Definition.MaxStance));

            _enemyIntent.text = "Nächster Zug: " + IntentText(enemy);
        }

        private static void SetBar(VisualElement bar, int value, int max)
        {
            if (bar == null) return;
            var ratio = max <= 0 ? 0f : Mathf.Clamp01((float)value / max);
            bar.style.width = Length.Percent(ratio * 100f);
        }

        private static string IntentText(EnemyState enemy)
        {
            switch (enemy.Intent)
            {
                case IntentType.Guard: return $"{enemy.IntentValue} Schild";
                case IntentType.Hex: return $"Fluch ({enemy.IntentValue / 2} Schaden, −1 Luck)";
                case IntentType.Drain: return $"{enemy.IntentValue} Schaden, heilt sich";
                case IntentType.Frenzy: return $"2 × {enemy.IntentValue} Schaden";
                default: return $"{enemy.IntentValue} Schaden";
            }
        }

        private void RefreshPlayer()
        {
            var run = _game.Run;
            _playerHp.text = $"{run.Hp} / {run.MaxHp} HP";
            _playerShield.text = $"{_game.Combat?.PlayerShield ?? 0} Schild";
            _playerFate.text = $"{run.Fate} Fate";
            _playerLuck.text = $"Luck {_game.Combat?.TemporaryLuck ?? run.Luck}";
            _playerTurn.text = $"Kampf {run.FightIndex + 1} · Runde {_game.Combat?.Turn ?? 1}";
        }

        private void RefreshCharms()
        {
            _charmBar.Clear();
            foreach (var pair in _game.Run.Charms.Where(p => p.Value > 0))
            {
                var definition = GameCatalog.Charms.FirstOrDefault(c => c.Id == pair.Key);
                if (definition == null) continue;

                // Im Kampf steht nur Name und Anzahl. Der Text kommt auf Tipp -
                // so bleibt der Kampfschirm sauber.
                var chip = new Label($"{definition.Name} ×{pair.Value}");
                chip.AddToClassList("charm");
                var text = $"{definition.Name} ×{pair.Value}: {definition.Description}";
                chip.RegisterCallback<ClickEvent>(_ => _log.text = text);
                _charmBar.Add(chip);
            }
        }

        private void RefreshSpread()
        {
            foreach (var slot in _slots.Keys.ToList())
            {
                var content = _slotContents[slot];
                content.Clear();
                var occupied = _game.Combat != null && _game.Combat.Slots.TryGetValue(slot, out var card);
                _slots[slot].EnableInClassList("platz--belegt", occupied);
                if (occupied) content.Add(new CardElement(_game.Combat.Slots[slot]));
            }
        }

        private void RefreshHand()
        {
            _hand.Clear();
            _selected = null;
            if (_game.Combat == null) return;
            foreach (var card in _game.Combat.Hand)
                _hand.Add(new CardElement(card, OnCardClicked));
        }

        private void RefreshPreview()
        {
            if (_game.Phase != GamePhase.Combat || _game.Combat.Slots.Count == 0)
            {
                _preview.text = string.Empty;
                return;
            }
            // Die Vorschau ist garantiert nebenwirkungsfrei - siehe
            // CombatSystem.PreviewScore.
            var score = _game.PreviewScore();
            if (score == null) { _preview.text = string.Empty; return; }

            var penalty = score.RepeatPenalty < 1f
                ? $" × Wiederholung {score.RepeatPenalty:0.00}"
                : string.Empty;
            _preview.text = $"{score.ComboName}: {score.Chips} × {score.Multiplier:0.00}{penalty} = {score.FateDamage}";
        }

        // -------------------------------------------------------- Overlay
        private void RefreshOverlay()
        {
            _overlayRow.Clear();
            _overlayButtons.Clear();

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
                case GamePhase.GameOver: BuildGameOverOverlay(); break;
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

        private void BuildPathOverlay()
        {
            _overlayTitle.text = "WOHIN FÜHRT DEIN WEG?";
            _overlaySubtitle.text = $"{_game.Run.Deck.Count} Karten · {_game.Run.Gold} Gold · Resonanz {_game.Run.DeckResonance}/10";
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
                default: return "KAMPF — etwas wartet";
            }
        }

        private void BuildShopOverlay()
        {
            _overlayTitle.text = "DER HÄNDLER";
            _overlaySubtitle.text = $"{_game.Run.Gold} Gold";
            for (var i = 0; i < _game.ShopOffers.Count; i++)
            {
                var index = i;
                var offer = _game.ShopOffers[i];
                var button = OverlayButton(
                    offer.Sold ? $"{offer.Reward.Title} — verkauft"
                               : $"{offer.Reward.Title} — {offer.Price} Gold",
                    () => _game.BuyShopOffer(index), secondary: true);
                button.SetEnabled(!offer.Sold && _game.Run.Gold >= offer.Price);
            }

            // Vergessen: die Goldsenke. Karte antippen, um sie dauerhaft aus
            // dem Deck zu nehmen. Der Preis steigt mit jeder Loeschung.
            var removalPrice = _game.RemovalPrice;
            var headline = new Label($"VERGESSEN — {removalPrice} Gold je Karte");
            headline.AddToClassList("overlay__untertitel");
            _overlayRow.Add(headline);

            var deckRow = new VisualElement();
            deckRow.AddToClassList("overlay__reihe");
            foreach (var card in _game.Run.Deck)
            {
                var element = new CardElement(card, clicked =>
                {
                    _game.RemoveCardAtShop(clicked.Card);
                    Save();
                    Refresh();
                });
                element.SetEnabled(_game.CanRemoveAtShop(card));
                deckRow.Add(element);
            }
            _overlayRow.Add(deckRow);

            OverlayButton("WEITERGEHEN", () => _game.ContinueFromOffgame());
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

        private void BuildGameOverOverlay()
        {
            _overlayTitle.text = "DU FÄLLST";
            _overlaySubtitle.text =
                $"Kampf {_game.Run.FightIndex + 1} · {_game.Run.Deck.Count} Karten · {_game.Run.FateScoreTotal} Fate gesamt\n" +
                $"Beste Tiefe bisher: Kampf {_meta.BestFightsCleared + 1}";
            OverlayButton("NOCH EINMAL", NewRun);
        }
    }
}
