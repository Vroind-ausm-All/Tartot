extends RefCounted
class_name DeuterDefinition
## Eine spielbare Figur (Model/Definitions.cs, Content/Deuters.cs).

var id: String = ""
var name: String = ""
var subtitle: String = ""
var rule_text: String = ""
var rule: int = Enums.DeuterRule.NONE
var max_hp: int = 72
var gold: int = 90
var luck: int = 2
var deck: Array[String] = []
## Karten-Ids im Startdeck, die umgekehrt liegen.
var reversed_cards: Array[String] = []
var charms: Array[String] = []
var items: Array[String] = []
## Leer = von Anfang an spielbar, sonst die Prophezeiung, die freischaltet.
var unlocked_by: String = ""
