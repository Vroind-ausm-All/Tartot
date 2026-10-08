extends RefCounted
class_name EnemyDefinition
## Ein Gegner (Model/Definitions.cs). Wird vor jedem Kampf geklont, weil
## Schleier, Verdunkelung, Spirale und Finale ihn veraendern.

var id: String = ""
var name: String = ""
var max_hp: int = 1
var max_stance: int = 0
var base_attack: int = 0
var sigils: int = 0
var flavor: String = ""
var tier: int = Enums.EnemyTier.NORMAL
## Akt, in dem der Gegner auftaucht (1-3, 4 = Finale, 5 = Spirale).
var act: int = 1
## Absichtsfolge (IntentType), zyklisch. Leer = allgemeines Muster.
var pattern: Array[int] = []
## Die Regeln, die dieser Gegner bricht (BossRule).
var rules: Array[int] = []
## Im Finale wirken die Regeln der besiegten Bosse abgeschwaecht.
var rules_weakened: bool = false
## Das Grosse Arkanum, das ein Boss verkoerpert - fuer BINDEN.
var omen_card_id: String = ""
## Schluessel fuer die Silhouette in der Darstellung.
var art: String = ""
## float32: mehr Gold beim Sieg.
var gold_factor: float = 1.0
## Lebenskraft der zweiten Phase (0 = 45 % der Max-HP).
var phase_hp: int = 0
## Wo der Kampf spielt (Buehne im Kampfbild).
var stage: String = ""

func is_boss() -> bool:
	return tier == Enums.EnemyTier.BOSS or tier == Enums.EnemyTier.FINALE

func has_rule(rule: int) -> bool:
	return rules.has(rule)

## Flache Kopie - der Katalog bleibt unveraendert.
func clone() -> EnemyDefinition:
	var c := EnemyDefinition.new()
	c.id = id
	c.name = name
	c.max_hp = max_hp
	c.max_stance = max_stance
	c.base_attack = base_attack
	c.sigils = sigils
	c.flavor = flavor
	c.tier = tier
	c.act = act
	c.pattern = pattern.duplicate()
	c.rules = rules.duplicate()
	c.rules_weakened = rules_weakened
	c.omen_card_id = omen_card_id
	c.art = art
	c.gold_factor = gold_factor
	c.phase_hp = phase_hp
	c.stage = stage
	return c
