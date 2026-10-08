extends RefCounted
class_name CardDefinition
## Unveraenderliche Kartendefinition (Model/Cards.cs).

var id: String = ""
var name: String = ""
var suit: int = Enums.Suit.SWORDS
var rank: int = 1
var base_power: int = 1
## Arkana-Nummer 0-21, -1 fuer Kleine Arkana.
var major: int = -1
var description: String = ""

func is_major() -> bool:
	return suit == Enums.Suit.MAJOR

## Gewoehnlich (Zahlen), ungewoehnlich (Hof), selten (Arkana), legendaer (Narr, Rad, Welt).
func rarity() -> int:
	return CardEditions.rarity_of(self)

## Die Zahl auf der Karte: fuer Arkana die Arkana-Nummer (Der Narr ist die 0, spielt aber mit Rang 1).
func display_number() -> int:
	return major if is_major() and major >= 0 else rank
