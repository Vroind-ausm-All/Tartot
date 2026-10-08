extends RefCounted
class_name SaveData
## Ein vollstaendiger Speicherstand eines laufenden Runs (Infrastructure/SaveGame.cs).
## Version 2: Akte, Verdunkelung, Deuter, Schleier, Ereignisse, Bossregeln.

const CURRENT_VERSION := 2

var version: int = CURRENT_VERSION
var seed: int = 0
var phase: int = Enums.GamePhase.COMBAT
## Zufallsstroeme als {"state", "inc", "draws"}.
var world_random: Dictionary = {}
var combat_random: Dictionary = {}
var progression_random: Dictionary = {}
var run: RunState
## null, wenn gerade kein Kampf laeuft.
var combat: CombatState
var enemy_id: String = ""
## Das laufende Ereignis - sonst wuerde ein Neustart es neu wuerfeln.
var event_id: String = ""
var event_resolved: bool = false
var event_epilogue: String = ""
