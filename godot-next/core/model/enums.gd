extends RefCounted
class_name Enums
## Aufzaehlungen des Spiels - Reihenfolge und Namen wie Model/Enums.cs.
## Die Namen (NAMES_*) sind das Speicherformat: C# schreibt Enum.ToString().

enum Suit { SWORDS, WANDS, CUPS, PENTACLES, MAJOR }
enum Orientation { UPRIGHT, REVERSED }
enum SlotPosition { PAST, PRESENT, FUTURE }
enum Shimmer { MATTE, WHITE, INDIGO, GOLD, BLOOD, BLACK }
enum GamePhase { COMBAT, REWARD, PATH_CHOICE, SHOP, RITUAL, ORACLE, GAME_OVER, EVENT, BOSS_LOOT, REST, VICTORY }
enum RewardType { CARD, CHARM, ITEM, FATE }
enum PathType { FIGHT, SHOP, RITUAL, ORACLE, ELITE, EVENT, REST }
enum IntentType { ATTACK, GUARD, HEX, DRAIN, FRENZY }
enum EnemyTier { NORMAL, ELITE, BOSS, FINALE }
## Die Grundregel, die ein Boss bricht.
enum BossRule { NONE, TOWER, MOON, DEATH, WHEEL, DEVIL, HANGED_MAN, TEMPERANCE, HIEROPHANT, SUN }
enum DeuterRule { NONE, BLOOD_READER, BOOKKEEPER, HERMIT }
enum BossLootChoice { SOAK, BIND, BANISH }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum CardEdition { NONE, SHIMMERING, GLOWING, BURNING, GLASS }

enum CharmEffectType {
	SWORDS_CHIPS, WANDS_BURN, SELF_DAMAGE_POWER, DEBUFFED_LIFESTEAL, FIRST_ATTACK_BONUS,
	EVERY_THIRD_CARD_DAMAGE, ATTACK_VS_ATTACKER, KILL_RAMP, THORNS, FUTURE_POWER,
	PENTACLE_SHIELD, OVERHEAL_TO_SHIELD, START_SHIELD, DEBUFF_WARD, LOW_HP_SHIELD,
	REVERSED_SHIELD, SHIELD_RETENTION, EVERY_FIFTH_HEAL, PHOENIX, GLASS_HEART,
	COPY_POWER, REMOVE_DISCOUNT, OPENING_DRAW, DISCARD_BOOST, UPGRADED_POWER,
	RESHUFFLE_DRAW, MEMORY_RETURN, COPY_BASE, REMOVE_MAX_HP, ORACLE_SIGHT,
	SWORD_BRIDGE, WAND_COMBO, CUP_AFTER_ATTACK, PENTACLE_GOLD, FOUR_SUIT_BONUS,
	HEAL_DAMAGE, BURN_POWER, ARMOR_PIERCE, PENTACLE_LUCK, CUP_CLEANSE,
	START_LUCK, SHOP_DISCOUNT, REWARD_REROLL, RARE_CHANCE, POSITIVE_EVENT,
	GREED, EXTRA_REWARD_CHOICE, UPGRADED_REWARD_CHANCE, ELITE_CHARM_CHANCE, WORLD_THREAD
}

enum ItemEffectType {
	MIRROR_CARD, REMOVE_CARD, FLIP_CARD, UPGRADE_CARD, REORDER_DECK,
	HEAL, CLEANSE_REVEAL, TOWER_BLAST, DEVILS_BARGAIN, LINK_CARDS,
	SKIP_ENEMY_INTENT, GAIN_GOLD, UNLOCK, REROLL_SHOP, REVIVE,
	GAIN_LUCK, START_SHIELD_BUFF, TRANSFORM_CARD, REROLL_REWARD, REVEAL_PATH,
	REMOVE_CURSE, RESTORE_REMOVED_CARD
}

enum MajorArcana {
	FOOL = 0, MAGICIAN = 1, HIGH_PRIESTESS = 2, EMPRESS = 3, EMPEROR = 4,
	HIEROPHANT = 5, LOVERS = 6, CHARIOT = 7, STRENGTH = 8, HERMIT = 9,
	WHEEL = 10, JUSTICE = 11, HANGED_MAN = 12, DEATH = 13, TEMPERANCE = 14,
	DEVIL = 15, TOWER = 16, STAR = 17, MOON = 18, SUN = 19,
	JUDGEMENT = 20, WORLD = 21
}

const NAMES_SUIT := ["Swords", "Wands", "Cups", "Pentacles", "Major"]
const NAMES_ORIENTATION := ["Upright", "Reversed"]
const NAMES_SLOT := ["Past", "Present", "Future"]
const NAMES_SHIMMER := ["Matte", "White", "Indigo", "Gold", "Blood", "Black"]
const NAMES_PHASE := ["Combat", "Reward", "PathChoice", "Shop", "Ritual", "Oracle", "GameOver", "Event", "BossLoot", "Rest", "Victory"]
const NAMES_PATH := ["Fight", "Shop", "Ritual", "Oracle", "Elite", "Event", "Rest"]
const NAMES_INTENT := ["Attack", "Guard", "Hex", "Drain", "Frenzy"]
const NAMES_TIER := ["Normal", "Elite", "Boss", "Finale"]
const NAMES_RULE := ["None", "Tower", "Moon", "Death", "Wheel", "Devil", "HangedMan", "Temperance", "Hierophant", "Sun"]
const NAMES_DEUTER_RULE := ["None", "BloodReader", "Bookkeeper", "Hermit"]
const NAMES_EDITION := ["None", "Shimmering", "Glowing", "Burning", "Glass"]

## Name -> Wert (Enum.TryParse); unbekannt -> fallback.
static func parse(names: Array, text: String, fallback: int) -> int:
	var i := names.find(text)
	return i if i >= 0 else fallback

## Deutsche Anzeigenamen
const SLOT_NAME_DE := ["Vergangenheit", "Gegenwart", "Zukunft"]
const PATH_NAME_DE := ["Kampf", "Händler", "Ritual", "Orakel", "Elite", "Ereignis", "Rast"]
const SHIMMER_NAME_DE := ["Matt", "Weiß", "Indigo", "Gold", "Blut", "Schwarz"]
