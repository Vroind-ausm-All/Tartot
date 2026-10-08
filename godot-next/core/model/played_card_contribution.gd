extends RefCounted
class_name PlayedCardContribution
## Was eine Karte in einem Kampf beigetragen hat (Model/States.cs).

var card: CardInstance
var damage: int = 0
var shield: int = 0
var healing: int = 0
## float32
var mult_contribution: float = 0.0
var stance_damage: int = 0

## Damage + Shield*0,65f + Healing*0,65f + StanceDamage*1,5f + Mult*10f, alles float32.
func score() -> float:
	var s := Num.add(damage, Num.mul(shield, 0.65))
	s = Num.add(s, Num.mul(healing, 0.65))
	s = Num.add(s, Num.mul(stance_damage, 1.5))
	return Num.add(s, Num.mul(mult_contribution, 10.0))
