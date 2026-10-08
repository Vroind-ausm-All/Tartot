extends RefCounted
class_name ScoreBreakdown
## Die Wertung einer Legung (Model/States.cs).

var chips: int = 0
## float32
var multiplier: float = 1.0
var fate_damage: int = 0
var combo_name: String = ""
## float32
var repeat_penalty: float = 1.0
var notes: Array[String] = []
## Laenge der Musterkette, wenn diese Legung ausgefuehrt wird.
var chain: int = 0
## Summe 21 - Die Welt.
var is_world: bool = false
## Ob die Legung ein kettenfaehiges Muster bildet.
var has_pattern: bool = false
## Fate-Treffer nach Haltung (Deckel oder Durchbruch) - was wirklich ankommt.
var expected_hit: int = 0
## Die Haltung bricht mit dieser Legung.
var breaks_stance: bool = false
## Der Fate-Treffer allein beendet den Kampf.
var lethal: bool = false
## Der Mond: eine verdeckte Karte liegt in der Legung, die Vorschau ist ungewiss.
var veiled: bool = false
## Beinahe-Treffer: "Die 7 der Kelche vollendet DIE WELT". Nur in der Vorschau.
var hints: Array[String] = []
## Die Wertung Schritt fuer Schritt - erst jede Karte, dann Muster und Editionen.
var steps: Array[ScoreStep] = []
