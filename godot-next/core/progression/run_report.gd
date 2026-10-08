extends RefCounted
class_name RunReport
## Was am Ende eines Runs gezeigt wird: erst was erreicht wurde, dann was
## neu ist, dann was fast geklappt haette (Progression/Prophecies.cs).

var won: bool = false
var headline: String = ""
var fights_cleared: int = 0
var act: int = 0
var spiral_depth: int = 0
var fate_total: int = 0
var best_hit: int = 0
var best_hit_combo: String = ""
var killed_by: String = ""
var darkness: int = 0
var records: Array[String] = []
var unlocked: Array[String] = []
var near_misses: Array[NearMiss] = []
