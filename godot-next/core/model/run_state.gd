extends RefCounted
class_name RunState
## Zustand eines Runs (Model/States.cs).

var deck: Array[CardInstance] = []
var removed_cards: Array[CardInstance] = []
## Charm-Id -> Stapel (Einfuegereihenfolge wie C#; 0 bleibt als Eintrag stehen).
var charms: Dictionary = {}
## Item-Id -> Ladungen
var items: Dictionary = {}
var max_hp: int = 72
var hp: int = 72
var gold: int = 90
var fate: int = 0
var luck: int = 2
var fight_index: int = 0
var endless_tier: int = 0
var deck_resonance: int = 1
var reward_rerolls: int = 1
var shop_rerolls: int = 1
var revive_charges: int = 0
var start_shield_buff: int = 0
var free_next_shop_purchase: bool = false
var fate_score_total: int = 0
var prophecy: String = ""
## Wie oft beim Haendler gegen Gold geloescht wurde - der Preis steigt.
var shop_removals: int = 0
## Wie oft beim Haendler veredelt wurde - der Preis steigt.
var shop_refines: int = 0

# --- Figur und Schwierigkeit ------------------------------------
var deuter_id: String = "wahrsagerin"
var deuter_rule: int = Enums.DeuterRule.NONE
var veil: int = 0
## Tageskarte: gleicher Seed, gleiche Figur, gleicher Schleier fuer alle.
var is_daily: bool = false

# --- Bogen des Runs ---------------------------------------------
## Der angekuendigte Boss je Akt (Index 3: Finale), beim Start geplant.
var act_bosses: Array[String] = []
## Besiegte Bosse. Das Finale setzt sich aus ihren Regeln zusammen.
var defeated_bosses: Array[String] = []
var seen_enemies: Array[String] = []
var seen_events: Array[String] = []
## Das Finale ist geschlagen - alles danach ist Spirale.
var won: bool = false
## Ein Ereignis kann den naechsten Gegner bestimmen.
var pending_enemy_id: String = ""
var next_fight_elite: bool = false
var last_path: int = Enums.PathType.FIGHT
var steps_since_shop: int = 0
var steps_since_rest: int = 0
## Zusaetzliche Belohnungswahlen, die ein Ereignis gewaehrt hat.
var bonus_reward_choices: int = 0

# --- Verdunkelung -----------------------------------------------
## 0-100. Je dunkler, desto staerker umgekehrte Karten - und desto haerter die Gegner.
var darkness: int = 0

# --- Geschichte ueber Runs hinweg -------------------------------
## Story-Flags (Menge): beim Start aus dem Meta-Fortschritt kopiert und im Run ergaenzt.
var story_flags: Dictionary = {}
## In diesem Run neu gesetzte Flags - wandern am Ende in den Meta-Fortschritt.
var new_story_flags: Array[String] = []
## Die Karte aus dem letzten gescheiterten Run - fuer das Grab.
var grave_card_id: String = ""
var grave_fight: int = 0
## Charms, die angeboten werden duerfen (Menge). null = alle.
var charm_pool = null
var stats := RunStats.new()
## Freigeschaltete Lesarten je Grossem Arkanum (Kopie aus dem Meta-Fortschritt).
var interpretations: Dictionary = {}

## 1-3 Akte, 4 Finale, 5 Spirale.
func act() -> int:
	return ActCatalog.act_of(fight_index)

func darkness_stage() -> int:
	@warning_ignore("integer_division")
	return mini(5, maxi(0, darkness) / 20)

func add_darkness(amount: int) -> void:
	darkness = maxi(0, mini(100, darkness + amount))
	stats.peak_darkness = maxi(stats.peak_darkness, darkness)

func set_story_flag(flag: String) -> void:
	if flag == "" or story_flags.has(flag):
		return
	story_flags[flag] = true
	new_story_flags.append(flag)

func charm_allowed(charm_id: String) -> bool:
	return charm_pool == null or (charm_pool as Dictionary).has(charm_id)

func charm_stacks(charm_id: String) -> int:
	return int(charms.get(charm_id, 0))

func add_charm(charm: CharmDefinition, amount := 1) -> void:
	charms[charm.id] = mini(charm.max_stacks, charm_stacks(charm.id) + amount)

func add_item(item: ItemDefinition, amount := 1) -> void:
	items[item.id] = int(items.get(item.id, 0)) + amount

func consume_item(item_id: String) -> bool:
	var count := int(items.get(item_id, 0))
	if not items.has(item_id) or count <= 0:
		return false
	items[item_id] = count - 1
	return true

func interpretation_count(card_id: String) -> int:
	return int(interpretations.get(card_id, 0))

func charm_total() -> int:
	var n := 0
	for k in charms:
		n += int(charms[k])
	return n

func distinct_suit_count() -> int:
	var seen := {}
	for c in deck:
		if c.definition.suit != Enums.Suit.MAJOR:
			seen[c.definition.suit] = true
	return seen.size()
