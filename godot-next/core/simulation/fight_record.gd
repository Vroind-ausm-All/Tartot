extends RefCounted
class_name FightRecord
## Ein einzelner Kampf eines Autopilot-Runs (Simulation/Autopilot.cs).

var index: int = 0
var enemy_id: String = ""
var tier: int = Enums.EnemyTier.NORMAL
var turns: int = 0
## float32: HP-Anteil vor und nach dem Kampf.
var hp_before: float = 0.0
var hp_after: float = 0.0
var died: bool = false
var gold_after: int = 0
