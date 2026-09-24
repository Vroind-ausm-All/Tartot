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
    ///
    /// Aufgeteilt: diese Datei traegt Bindung und Kampf, die Overlays
    /// (Titel, Wege, Ereignisse, Bericht) stehen in TartotView.Overlays.cs.
    /// </remarks>
    [RequireComponent(typeof(UIDocument))]
    public sealed partial class TartotView : MonoBehaviour
    {
        [Tooltip("0 = zufaelliger Seed. Ein fester Wert macht einen Run reproduzierbar.")]
        public long Seed;

        [Tooltip("Speicherstand automatisch nach jedem Zug schreiben.")]
        public bool AutoSave = true;

        private const string SaveKey = "tartot.save";
        private const string MetaKey = "tartot.meta";
        private const string SetupKey = "tartot.setup";

        private GameController _game;
        private MetaProgress _meta;
        private CardElement _selected;

        /// <summary>Titelschirm statt Run: Deuter, Schleier, Tageskarte.</summary>
        private bool _showTitle;
        private RunSetup _setup = new RunSetup();
        /// <summary>Der Bericht des beendeten Runs - einmal verbucht, dann nur noch gezeigt.</summary>
        private RunReport _report;
        /// <summary>Prophezeiungen, die in diesem Run schon eingeblendet wurden.</summary>
        private readonly HashSet<string> _announced = new HashSet<string>();
        private string _toast = string.Empty;

        // Zwischengespeicherte Elemente - Q<T>() ist zu teuer fuer jeden Frame.
        private VisualElement _root, _frame, _charmBar, _hand, _overlay, _overlayRow, _overlayButtons, _pact;
        private VisualElement _enemyHpBar, _enemyStanceBar;
        private Label _enemyName, _enemyRule, _enemyHp, _enemyStance, _enemyIntent;
        private Label _playerHp, _playerShield, _playerFate, _playerLuck, _playerDark, _playerTurn;
        private Label _preview, _previewHint, _log, _overlayTitle, _overlaySubtitle, _pactText, _toastLabel;
        private Button _actButton;
        private readonly Dictionary<SlotPosition, VisualElement> _slots =
            new Dictionary<SlotPosition, VisualElement>();
        private readonly Dictionary<SlotPosition, VisualElement> _slotContents =
            new Dictionary<SlotPosition, VisualElement>();
        private readonly Dictionary<SlotPosition, Label> _slotHints =
            new Dictionary<SlotPosition, Label>();

        private static readonly Dictionary<SlotPosition, string> DefaultSlotHints = new Dictionary<SlotPosition, string>
        {
            [SlotPosition.Past] = "90 % — Vorbereitung",
            [SlotPosition.Present] = "100 % — sicher",
            [SlotPosition.Future] = "150 % — nach dem Gegner"
        };

        private void OnEnable()
        {
            _root = GetComponent<UIDocument>().rootVisualElement;
            CacheElements();
            _meta = MetaProgress.Deserialize(PlayerPrefs.GetString(MetaKey, string.Empty));
            _setup = LoadSetup();
            StartOrResume();
        }

        private void CacheElements()
        {
            _frame = _root.Q<VisualElement>("wurzel");
            _enemyName = _root.Q<Label>("gegner-name");
            _enemyRule = _root.Q<Label>("gegner-regel");
            _enemyHp = _root.Q<Label>("gegner-hp");
            _enemyStance = _root.Q<Label>("gegner-haltung");
            _enemyIntent = _root.Q<Label>("gegner-absicht");
            _enemyHpBar = _root.Q<VisualElement>("gegner-hp-balken");
            _enemyStanceBar = _root.Q<VisualElement>("gegner-haltung-balken");

            _playerHp = _root.Q<Label>("spieler-hp");
            _playerShield = _root.Q<Label>("spieler-schild");
            _playerFate = _root.Q<Label>("spieler-fate");
            _playerLuck = _root.Q<Label>("spieler-luck");
            _playerDark = _root.Q<Label>("spieler-dunkel");
            _playerTurn = _root.Q<Label>("spieler-runde");

            _charmBar = _root.Q<VisualElement>("charmleiste");
            _hand = _root.Q<VisualElement>("hand");
            _preview = _root.Q<Label>("vorschau");
            _previewHint = _root.Q<Label>("vorschau-hinweis");
            _log = _root.Q<Label>("protokoll");

            _pact = _root.Q<VisualElement>("pakt");
            _pactText = _root.Q<Label>("pakt-text");
            _root.Q<Button>("pakt-ja").clicked += () => OnPact(true);
            _root.Q<Button>("pakt-nein").clicked += () => OnPact(false);

            _toastLabel = _root.Q<Label>("toast");
            _toastLabel.RegisterCallback<ClickEvent>(_ => { _toast = string.Empty; RefreshToast(); });

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
                _slotHints[slot] = _root.Q<Label>("platz-" + key + "-hinweis");
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
                _showTitle = true;
            }
            else if (SaveSystem.TryDeserialize(saved, out var save, out var error))
            {
                _game = GameController.Restore(save);
            }
            else
            {
                // Ein kaputter Stand darf den Einstieg nicht blockieren.
                Debug.LogWarning($"Speicherstand unlesbar, zurueck zum Titel: {error}");
                PlayerPrefs.DeleteKey(SaveKey);
                _showTitle = true;
            }
            Refresh();
        }

        private void NewRun(RunSetup setup)
        {
            _setup = setup ?? new RunSetup();
            var seed = Seed != 0 ? Seed
                : _setup.IsDaily ? MetaProgress.DailySeed()
                : DateTime.UtcNow.Ticks;
            // Der Meta-Fortschritt geht in den Run: Lesarten, Story-Flags,
            // freigeschaltete Charms und das Grab des letzten Runs.
            _game = new GameController(seed, _meta, _setup);
            _report = null;
            _announced.Clear();
            _toast = string.Empty;
            _eventId = string.Empty;
            _showTitle = false;
            PlayerPrefs.DeleteKey(SaveKey);
            PlayerPrefs.SetString(SetupKey, $"{_setup.DeuterId}|{_setup.Veil}");
            Save();
        }

        private static RunSetup LoadSetup()
        {
            var parts = PlayerPrefs.GetString(SetupKey, string.Empty).Split('|');
            var setup = new RunSetup();
            if (parts.Length == 2)
            {
                setup.DeuterId = parts[0];
                if (int.TryParse(parts[1], out var veil)) setup.Veil = veil;
            }
            return setup;
        }

        private void Save()
        {
            if (!AutoSave) return;
            if (_game != null && _game.Phase != GamePhase.GameOver) PlayerPrefs.SetString(SaveKey, _game.Save());
            else PlayerPrefs.DeleteKey(SaveKey);
            PlayerPrefs.SetString(MetaKey, _meta.Serialize());
            PlayerPrefs.Save();
        }

        /// <summary>
        /// Verbucht den beendeten Run genau einmal. Danach zeigt der Bericht,
        /// was neu ist und was knapp verfehlt wurde.
        /// </summary>
        private void CompleteRunOnce()
        {
            if (_report != null || _game == null) return;
            var killedBy = _game.Run.Won ? string.Empty : _game.Combat?.Enemy?.Definition?.Name ?? string.Empty;
            _report = _meta.CompleteRun(_game, null, killedBy);
            Save();
        }

        // ------------------------------------------------------- Eingaben
        private void OnCardClicked(CardElement card)
        {
            if (_game.Phase != GamePhase.Combat) return;
            _toast = string.Empty;
            if (_selected == card) { _selected.SetSelected(false); _selected = null; }
            else
            {
                _selected?.SetSelected(false);
                _selected = card;
                _selected.SetSelected(true);
            }
            RefreshPreview();
            RefreshToast();
        }

        private void OnSlotClicked(SlotPosition slot)
        {
            if (_game == null || _game.Phase != GamePhase.Combat) return;
            _toast = string.Empty;

            if (_game.Combat.Slots.ContainsKey(slot))
            {
                _game.CombatSystem.ReturnSlotToHand(_game.Combat, slot);
            }
            else if (_selected != null)
            {
                if (!_game.CombatSystem.PlaceCard(_game.Combat, _selected.Card.InstanceId, slot))
                    _log.text = "Dieser Platz ist eingestürzt.";
            }
            else return;

            _selected = null;
            Refresh();
        }

        private void OnPact(bool accept)
        {
            if (_game == null) return;
            _game.AnswerPact(accept);
            Save();
            Refresh();
        }

        private void OnAct()
        {
            if (_game == null || _game.Phase != GamePhase.Combat) return;
            if (_game.Combat.Slots.Count == 0)
            {
                _log.text = "Lege mindestens eine Karte.";
                return;
            }

            var turn = _game.ResolveTurn();
            _selected = null;
            // Vor dem Verbuchen: danach steckt der Run schon in den
            // Lebenszeit-Werten und wuerde doppelt zaehlen.
            AnnounceMoments(turn);

            if (_game.Phase == GamePhase.GameOver)
                CompleteRunOnce();
            else if (_game.Phase != GamePhase.Combat)
                // Jeder gewonnene Kampf zaehlt als Begegnung mit den Grossen
                // Arkana im Deck - so wachsen die Lesarten. Vorher wurde hier
                // auf einen hoeheren Kampfindex geprueft; der steigt aber erst
                // beim naechsten Kampfstart, also zaehlte kein Sieg.
                foreach (var card in _game.Run.Deck)
                    if (card.Definition.IsMajor)
                        _meta.EncounterArcanum(card.Definition.Id);

            Save();
            Refresh();
        }

        /// <summary>
        /// Die Momente, die nicht im Protokoll untergehen duerfen: eine
        /// erfuellte Prophezeiung, ein neuer Rekord, eine verlorene Karte.
        /// </summary>
        private void AnnounceMoments(TurnResult turn)
        {
            var lines = new List<string>();
            foreach (var prophecy in _meta.PendingFulfilled(_game.Run))
                if (_announced.Add(prophecy.Id))
                    lines.Add($"PROPHEZEIUNG ERFÜLLT\n{prophecy.Title}\n{prophecy.RewardText}");
            if (turn != null)
            {
                if (turn.NewBestHit) lines.Add($"NEUER REKORD: Legung im Wert von {_game.Run.Stats.BestHit}");
                if (!string.IsNullOrEmpty(turn.CardLost)) lines.Add($"DER TOD NIMMT {turn.CardLost.ToUpperInvariant()}");
            }
            if (lines.Count > 0) _toast = string.Join("\n\n", lines);
        }

        // ---------------------------------------------------- Darstellung
        private void Refresh()
        {
            RefreshDarkness();
            if (_game != null && !_showTitle)
            {
                RefreshEnemy();
                RefreshPlayer();
                RefreshCharms();
                RefreshSpread();
                RefreshHand();
                RefreshPreview();
                RefreshPact();
                _log.text = _game.Message;
                _actButton.SetEnabled(_game.Phase == GamePhase.Combat);
            }
            RefreshOverlay();
            RefreshToast();
        }

        private void RefreshDarkness()
        {
            var stage = _game == null || _showTitle ? 0 : _game.Run.DarknessStage;
            for (var i = 1; i <= 5; i++) _frame?.EnableInClassList($"wurzel--dunkel-{i}", i == stage);
        }

        private void RefreshToast()
        {
            _toastLabel.text = _toast;
            _toastLabel.style.display = string.IsNullOrEmpty(_toast) ? DisplayStyle.None : DisplayStyle.Flex;
        }

        private void RefreshEnemy()
        {
            var enemy = _game.Combat?.Enemy;
            if (enemy == null) return;

            _enemyName.text = enemy.Definition.Name.ToUpperInvariant();
            _enemyRule.text = string.Join("  ·  ", CombatSystem.ActiveRuleTexts(_game.Combat));

            // Der Mond zeigt sein Leben nur ungefaehr.
            var moon = CombatSystem.HasRule(_game.Combat, BossRule.Moon);
            var hp = Mathf.Max(0, enemy.Hp);
            _enemyHp.text = (moon ? $"≈ {(hp + 9) / 10 * 10}" : hp.ToString()) + $" / {enemy.Definition.MaxHp} HP"
                            + (enemy.Sigils > 0 ? $"   ✦ {enemy.Sigils} Siegel" : string.Empty);
            SetBar(_enemyHpBar, enemy.Hp, enemy.Definition.MaxHp);

            var stanceBroken = enemy.Stance <= 0;
            _enemyStance.text = stanceBroken
                ? "HALTUNG GEBROCHEN — Schadensfenster offen"
                : $"Haltung {enemy.Stance} / {enemy.Definition.MaxStance}";
            SetBar(_enemyStanceBar, enemy.Stance, Mathf.Max(1, enemy.Definition.MaxStance));

            _enemyIntent.text = "Nächster Zug: " + (enemy.IntentHidden ? "??? — der Mond verbirgt es" : IntentText(enemy));
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
            _playerFate.text = $"{run.Fate} Fate · {run.Gold} Gold";
            _playerLuck.text = $"Luck {_game.Combat?.TemporaryLuck ?? run.Luck}";
            _playerDark.text = run.Darkness > 0 ? $"Dunkel {run.Darkness}" : string.Empty;
            _playerTurn.text = $"{Where(run).ToUpperInvariant()} · RUNDE {_game.Combat?.Turn ?? 1}";
        }

        /// <summary>"Akt II · Kampf 3/5", "FINALE" oder "Spirale 4".</summary>
        private static string Where(RunState run)
        {
            if (ActCatalog.IsFinale(run.FightIndex)) return "FINALE";
            if (ActCatalog.IsSpiral(run.FightIndex)) return $"Spirale {ActCatalog.SpiralDepth(run.FightIndex)}";
            return $"Akt {MetaProgress.Roman(run.Act)} · Kampf {run.FightIndex % ActCatalog.FightsPerAct + 1}/{ActCatalog.FightsPerAct}";
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

        private CardElement CombatCard(CardInstance card, Action<CardElement> onClick)
        {
            var combat = _game.Combat;
            var veiled = combat != null && combat.VeiledCards.Contains(card.InstanceId);
            var mark = combat != null && combat.MarkedCardId == card.InstanceId ? combat.MarkTurnsLeft : 0;
            return new CardElement(card, onClick, veiled, mark);
        }

        private void RefreshSpread()
        {
            var combat = _game.Combat;
            foreach (var slot in _slots.Keys.ToList())
            {
                var content = _slotContents[slot];
                content.Clear();
                var occupied = combat != null && combat.Slots.ContainsKey(slot);
                var blocked = combat != null && combat.BlockedSlot.HasValue && combat.BlockedSlot.Value == slot;
                var effective = combat == null ? slot : _game.CombatSystem.EffectiveSlot(combat, slot);

                _slots[slot].EnableInClassList("platz--belegt", occupied);
                _slots[slot].EnableInClassList("platz--eingestuerzt", blocked);
                _slots[slot].EnableInClassList("platz--verschoben", effective != slot);
                _slotHints[slot].text = blocked ? "EINGESTÜRZT — der Turm"
                    : effective != slot ? $"wirkt als {CombatSystem.SlotName(effective)}"
                    : DefaultSlotHints[slot];
                if (occupied) content.Add(CombatCard(combat.Slots[slot], null));
            }
        }

        private void RefreshHand()
        {
            _hand.Clear();
            _selected = null;
            if (_game.Combat == null) return;
            foreach (var card in _game.Combat.Hand)
                _hand.Add(CombatCard(card, OnCardClicked));
        }

        private void RefreshPreview()
        {
            _preview.EnableInClassList("vorschau--toedlich", false);
            _previewHint.text = string.Empty;
            if (_game.Phase != GamePhase.Combat || _game.Combat.Slots.Count == 0)
            {
                _preview.text = string.Empty;
                return;
            }
            // Die Vorschau ist garantiert nebenwirkungsfrei - siehe
            // CombatSystem.PreviewScore.
            var score = _game.PreviewScore();
            if (score == null) { _preview.text = string.Empty; return; }

            if (score.Veiled)
            {
                _preview.text = "Die Legung liegt im Mondlicht — ungewiss.";
                return;
            }

            var penalty = score.RepeatPenalty < 1f
                ? $" × Wiederholung {score.RepeatPenalty:0.00}"
                : string.Empty;
            var landing = score.BreaksStance ? $" → HALTUNG BRICHT: {score.ExpectedHit}"
                : score.ExpectedHit < score.FateDamage ? $" → Haltung deckelt: {score.ExpectedHit}"
                : string.Empty;
            var chain = score.Chain >= 2 ? $" · Kette ×{score.Chain}" : string.Empty;
            _preview.text = $"{score.ComboName}: {score.Chips} × {score.Multiplier:0.00}{penalty} = {score.FateDamage}{landing}{chain}";
            _preview.EnableInClassList("vorschau--toedlich", score.Lethal);
            _previewHint.text = string.Join("   ·   ", score.Hints);
        }

        private void RefreshPact()
        {
            var pending = _game.Phase == GamePhase.Combat && _game.Combat != null && _game.Combat.PactPending;
            _pact.style.display = pending ? DisplayStyle.Flex : DisplayStyle.None;
            if (!pending) return;
            var bonus = CombatSystem.PactBonus(_game.Combat);
            var cost = CombatSystem.PactCost(_game.Combat);
            _pactText.text = $"Der Teufel bietet einen Pakt: +{bonus * 100:0} % Fate-Schaden für diesen Kampf.\n" +
                             $"Preis: {cost} Max-HP für immer und +{CombatSystem.PactDarkness} Verdunkelung.\n" +
                             $"Lehnst du ab, schlägt er {CombatSystem.PactDeclinePenalty * 100:0} % härter zu.";
        }
    }
}
