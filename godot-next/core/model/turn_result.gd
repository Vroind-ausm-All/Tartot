extends RefCounted
class_name TurnResult
## Ergebnis eines aufgeloesten Zuges (Combat/CombatSystem.cs).

var log: Array[String] = []
var score: ScoreBreakdown = null
var fate_damage: int = 0
var enemy_damage: int = 0
var healing: int = 0
var shield_gained: int = 0
var stance_broken: bool = false
var victory: bool = false
var defeat: bool = false
## Wie weit der toedliche Treffer ueber das Leben hinausging.
var overkill: int = 0
## Der haerteste Treffer dieses Runs - und es gab schon einen davor.
var new_best_hit: bool = false
## Ein Siegel ist gebrochen, der Boss wechselt die Phase.
var phase_changed: bool = false
## Der Tod hat eine Karte genommen (Name), sonst leer.
var card_lost: String = ""
## Die rote Sonne hat ihre Supernova ausgeloest.
var supernova: bool = false
## Die Maessigkeit hat einen Teil des Treffers zurueckgespiegelt.
var reflected: int = 0
## Glaeserne Karten, die in diesem Zug zersprungen sind (Namen).
var shattered: Array[String] = []
## Der Turm hat in diesem Zug einen Platz eingestuerzt (fuer die Praesentation).
var tower_collapsed: int = -1
