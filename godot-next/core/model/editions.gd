extends RefCounted
class_name CardEditions
## Seltenheit und Editionen (Model/Editions.cs).

const SHIMMER_CHIPS := 6
const GLOW_MULT := 0.4
const BURN_X_MULT := 1.4
const BURN_BRAND := 3
const BURN_SELF_DAMAGE := 2
const GLASS_X_MULT := 1.8
const GLASS_SHATTER_CHANCE := 0.25

const ALL := [Enums.CardEdition.SHIMMERING, Enums.CardEdition.GLOWING, Enums.CardEdition.BURNING, Enums.CardEdition.GLASS]
## Editionschance einer Belohnungskarte in Promille, je Edition.
const REWARD_PERMILLE := {
	Enums.CardEdition.SHIMMERING: 25,
	Enums.CardEdition.GLOWING: 15,
	Enums.CardEdition.BURNING: 8,
	Enums.CardEdition.GLASS: 7,
}
## Die drei Legendaeren: Anfang, Wendepunkt, Ende.
const LEGENDARY_MAJORS := [0, 10, 21]

static func rarity_of(card: CardDefinition) -> int:
	if card.is_major():
		return Enums.Rarity.LEGENDARY if card.major >= 0 and LEGENDARY_MAJORS.has(card.major) else Enums.Rarity.RARE
	return Enums.Rarity.UNCOMMON if card.rank >= 11 else Enums.Rarity.COMMON

static func rarity_name(rarity: int) -> String:
	match rarity:
		Enums.Rarity.UNCOMMON: return "Ungewöhnlich"
		Enums.Rarity.RARE: return "Selten"
		Enums.Rarity.LEGENDARY: return "Legendär"
	return "Gewöhnlich"

## Farbe der Plakette (Palette der Stilbibel).
static func rarity_color(rarity: int) -> String:
	match rarity:
		Enums.Rarity.UNCOMMON: return "#3B4A8C"
		Enums.Rarity.RARE: return "#B3262B"
		Enums.Rarity.LEGENDARY: return "#E3A83B"
	return "#8F7A5A"

static func name_of(edition: int) -> String:
	match edition:
		Enums.CardEdition.SHIMMERING: return "Schimmernd"
		Enums.CardEdition.GLOWING: return "Leuchtend"
		Enums.CardEdition.BURNING: return "Brennend"
		Enums.CardEdition.GLASS: return "Gläsern"
	return ""

static func text_of(edition: int) -> String:
	match edition:
		Enums.CardEdition.SHIMMERING: return "+%d Chips" % SHIMMER_CHIPS
		Enums.CardEdition.GLOWING: return "+%s Mult" % Num.de(GLOW_MULT, 1)
		Enums.CardEdition.BURNING: return "×%s Mult, +%d Brand beim Gegner, kostet %d LP" % [Num.de(BURN_X_MULT, 1), BURN_BRAND, BURN_SELF_DAMAGE]
		Enums.CardEdition.GLASS: return "×%s Mult, zerspringt zu %d %%" % [Num.de(GLASS_X_MULT, 1), int(GLASS_SHATTER_CHANCE * 100)]
	return ""

static func chips(edition: int) -> int:
	return SHIMMER_CHIPS if edition == Enums.CardEdition.SHIMMERING else 0

## float32
static func mult_add(edition: int) -> float:
	return Num.f(GLOW_MULT) if edition == Enums.CardEdition.GLOWING else 0.0

## float32
static func mult_x(edition: int) -> float:
	if edition == Enums.CardEdition.BURNING:
		return Num.f(BURN_X_MULT)
	if edition == Enums.CardEdition.GLASS:
		return Num.f(GLASS_X_MULT)
	return 1.0
