extends RefCounted
class_name EnemyState
## Zustand des Gegners im Kampf (Model/States.cs).

var definition: EnemyDefinition
var hp: int
var stance: int
var sigils: int
var shield: int = 0
var burn: int = 0
var attack_ramp: int = 0
var broken_this_round: bool = false
var intent: int = Enums.IntentType.ATTACK
var intent_value: int = 0
## Wie viele Siegel schon gebrochen sind. Bosse verschaerfen ihre Regel.
var phase: int = 0
## Der Mond: die naechste Absicht ist nicht sichtbar.
var intent_hidden: bool = false

func _init(p_definition: EnemyDefinition = null) -> void:
	definition = p_definition
	if definition != null:
		hp = definition.max_hp
		stance = definition.max_stance
		sigils = definition.sigils

func is_dead() -> bool:
	return hp <= 0 and sigils <= 0
