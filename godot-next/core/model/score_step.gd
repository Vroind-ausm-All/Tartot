extends RefCounted
class_name ScoreStep
## Ein Schritt der Wertung fuer die Kaskade (Model/Editions.cs).

## Instanz-Id der Karte; leer fuer Schritte ohne Karte (Muster, Position).
var instance_id: String = ""
var label: String = ""
var chips: int = 0
var mult_add: float = 0.0
## Faktor auf den Multiplikator (1 = keiner).
var mult_x: float = 1.0
var edition: int = Enums.CardEdition.NONE
