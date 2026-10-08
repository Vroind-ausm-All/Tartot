extends RefCounted
class_name CombatState
## Zustand eines Kampfes (Model/States.cs).

var draw_pile: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
## SlotPosition -> CardInstance
var slots: Dictionary = {}
## Instanz-Id -> PlayedCardContribution (Einfuegereihenfolge wie C#)
var contributions: Dictionary = {}
var enemy: EnemyState
var turn: int = 1
var player_shield: int = 0
var temporary_luck: int = 0
var cards_played_this_combat: int = 0
var reshuffles: int = 0
var last_combo_signature: String = ""
var same_combo_repeats: int = 0
var future_queued_damage: int = 0
var future_queued_shield: int = 0
var future_queued_heal: int = 0
var skip_enemy_intent: bool = false
var temporary_draw_bonus: int = 0
var player_won: bool = false
var player_lost: bool = false
var last_score: ScoreBreakdown = null
var last_played_cards: Array[CardInstance] = []

## Aufeinanderfolgende Zuege mit einem Muster. Bricht bei einer Legung ohne.
var pattern_chain: int = 0
## Ueberschuss des letzten, toedlichen Treffers.
var last_overkill: int = 0
## Welt-Legungen in diesem Kampf.
var worlds_this_fight: int = 0

# --- Bossregeln -------------------------------------------------
## Der Turm: dieser Platz ist in diesem Zug eingestuerzt (-1 = keiner).
var blocked_slot: int = -1
var tower_collapses: int = 0
## Der Hierophant: beschworene Akolythen.
var acolytes: int = 0
## Die rote Sonne: kleine Sonnen am Himmel. Ab vier kommt die Supernova.
var suns: int = 0
## Der Mond: verdeckte Handkarten (Instanz-Ids). Dictionary als Menge.
var veiled_cards: Dictionary = {}
## Der Tod: gezeichnete Karte und verbleibende Runden.
var marked_card_id: String = ""
var mark_turns_left: int = 0
var next_mark_turn: int = 2
## Der Teufel: ein Pakt liegt auf dem Tisch.
var pact_pending: bool = false
## float32: zusaetzlicher Fate-Schaden aus angenommenen Pakten.
var fate_bonus: float = 0.0
## float32: zusaetzlicher Gegnerschaden, etwa nach einem abgelehnten Pakt.
var enemy_attack_bonus: float = 0.0
var pacts_offered: int = 0

func has_blocked_slot() -> bool:
	return blocked_slot >= 0

func is_veiled(card: CardInstance) -> bool:
	return veiled_cards.has(card.instance_id)

func find_in_hand(instance_id: String) -> CardInstance:
	for c in hand:
		if c.instance_id == instance_id:
			return c
	return null
