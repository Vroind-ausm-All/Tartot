extends RefCounted
class_name VictorySummary
## Was ein Sieg einbringt (Progression/ProgressionSystem.cs).

var fate_earned: int = 0
var gold_earned: int = 0
var champion: CardInstance = null
## [[CardInstance, xp], ...]
var card_xp: Array = []
var best_combo: String = ""
## Gold aus dem Ueberschuss des letzten Treffers.
var overkill_gold: int = 0
