extends RefCounted
class_name Konst

enum Suit { SWORDS, WANDS, CUPS, PENTACLES, MAJOR }
enum Orientation { UPRIGHT, REVERSED }
enum Slot { PAST, PRESENT, FUTURE }
enum Shimmer { MATTE, WHITE, INDIGO, GOLD, BLOOD, BLACK }
enum Phase { COMBAT, REWARD, PATH, SHOP, RITUAL, ORACLE, EVENT, BOSS_LOOT, REST, VICTORY, GAME_OVER }
enum Path { FIGHT, SHOP, RITUAL, ORACLE, ELITE, EVENT, REST }
enum Intent { ATTACK, GUARD, HEX, DRAIN, FRENZY }
enum Tier { NORMAL, ELITE, BOSS, FINALE }
enum BossRule { NONE, TOWER, MOON, DEATH, WHEEL, DEVIL, HANGED }
enum DeuterRule { NONE, BLOOD_READER, BOOKKEEPER, HERMIT }

const ACT_COUNT := 3
const FIGHTS_BEFORE_BOSS := 4
const FIGHTS_PER_ACT := 5
const FINALE_INDEX := 15
const SPIRAL_BOSS_INTERVAL := 4
const MAX_VEIL := 8
const MIN_DECK := 5

const POS_FACTOR := {
	Slot.PAST: 0.90,
	Slot.PRESENT: 1.00,
	Slot.FUTURE: 1.50,
}
const POS_NAME := {
	Slot.PAST: "Vergangenheit",
	Slot.PRESENT: "Gegenwart",
	Slot.FUTURE: "Zukunft",
}
const PATH_NAME := {
	Path.FIGHT: "Kampf",
	Path.SHOP: "Händler",
	Path.RITUAL: "Ritual",
	Path.ORACLE: "Orakel",
	Path.ELITE: "Elite",
	Path.EVENT: "Ereignis",
	Path.REST: "Rast",
}

const STANCE_HIT_CAP := 0.35
const STANCE_BREAK_MULT := 1.50
const STANCE_RECOVERY := 0.60
const SIGIL_REVIVE_HP := 0.45
const SIGIL_ATTACK_RAMP := 3
const REVERSED_COST := 0.08
const BLOOD_READER_MULT := 0.15
const NORMAL_REVERSED_MULT := 0.10
const INTERPRETATION_POWER := 0.10
const PATTERN_CHAIN_BONUS := 0.10
const PATTERN_CHAIN_MAX := 5
const DIRECT_PATH_GOLD := 12
const SOAK_DARKNESS := 4
const BIND_DARKNESS := 8
const BANISH_LIGHT := 8
const BANISH_GOLD := 40

const ACT_NAMES := [
	"",
	"Der Jahrmarkt der Omen",
	"Das Haus der Spiegel",
	"Die Schwarze Messe",
	"Das Ende der Welt",
	"Die Schwarze Spirale",
]

static func act_of(fight_index: int) -> int:
	if fight_index > FINALE_INDEX:
		return 5
	if fight_index == FINALE_INDEX:
		return 4
	return maxi(1, fight_index / FIGHTS_PER_ACT + 1)

static func is_boss_fight(fight_index: int) -> bool:
	return fight_index >= 0 and fight_index < FINALE_INDEX and fight_index % FIGHTS_PER_ACT == FIGHTS_BEFORE_BOSS

static func is_finale(fight_index: int) -> bool:
	return fight_index == FINALE_INDEX

static func is_spiral(fight_index: int) -> bool:
	return fight_index > FINALE_INDEX

static func spiral_depth(fight_index: int) -> int:
	return maxi(0, fight_index - FINALE_INDEX)

static func is_spiral_boss(fight_index: int) -> bool:
	return is_spiral(fight_index) and spiral_depth(fight_index) % SPIRAL_BOSS_INTERVAL == 0

static func fights_until_boss(next_fight_index: int) -> int:
	if next_fight_index >= FINALE_INDEX:
		return 0
	return FIGHTS_BEFORE_BOSS - next_fight_index % FIGHTS_PER_ACT

static func roman(value: int) -> String:
	var numerals := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return numerals[value] if value >= 0 and value < numerals.size() else str(value)
