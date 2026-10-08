extends RefCounted
class_name RewardOption
## Eine Belohnung oder ein Haendlerangebot (Model/States.cs).

var type: int = Enums.RewardType.CARD
var title: String = ""
var description: String = ""
var card: CardDefinition = null
var charm: CharmDefinition = null
var item: ItemDefinition = null
var fate: int = 0
# Zustand der angebotenen Karte als Daten.
var card_level: int = 1
var card_shimmer: int = Enums.Shimmer.MATTE
var card_orientation: int = Enums.Orientation.UPRIGHT
var card_edition: int = Enums.CardEdition.NONE
