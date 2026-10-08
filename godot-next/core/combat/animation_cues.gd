extends RefCounted
class_name AnimationCues
## Welche Animation ein Zug ausloest (Combat/AnimationCues.cs). Die Namen
## sind die Zustaende der Bossdarstellungen: idle, attack, attack1-3,
## summon, supernova, hit, phase2, death. Liegt im Kern, damit die
## Zuordnung ohne Oberflaeche getestet werden kann; die Oberflaeche spielt
## die Folge ab und faellt auf "attack" oder "idle" zurueck.

const IDLE := "idle"
const R := Enums.BossRule
const I := Enums.IntentType

## Die Folge fuer einen aufgeloesten Zug. intent ist die Absicht, die der
## Gegner in diesem Zug ausgefuehrt hat (vor dem Wuerfeln der naechsten).
static func for_turn(turn: TurnResult, enemy: EnemyState, intent: int, turn_number: int) -> Array[String]:
	var cues: Array[String] = []
	if turn == null or enemy == null:
		return cues
	if turn.fate_damage > 0 or turn.stance_broken:
		cues.append("hit")
	if turn.victory:
		cues.append("death")
		return cues
	if turn.phase_changed:
		cues.append("phase2")
	if not turn.defeat or turn.enemy_damage > 0:
		cues.append(enemy_action(turn, enemy, intent, turn_number))
	return cues

## Welcher Angriff des Blatts zur ausgefuehrten Absicht passt.
static func enemy_action(turn: TurnResult, enemy: EnemyState, intent: int, turn_number: int) -> String:
	var rules := enemy.definition.rules
	if turn.supernova:
		return "supernova"
	if rules.has(R.SUN):
		return "summon" if intent == I.GUARD else ("attack2" if intent == I.FRENZY else "attack1")
	if rules.has(R.TEMPERANCE):
		if turn.reflected > 0 or enemy.phase >= 1:
			return "attack3"
		if intent == I.GUARD:
			return "summon"
		# Wasserrunden sind ungerade, Feuerrunden gerade.
		return "attack2" if turn_number % 2 == 0 else "attack1"
	if rules.has(R.HIEROPHANT):
		for l in turn.log:
			if l.contains("Akolythen.") or l.contains("ruft einen Akolythen"):
				return "attack2"
		return "attack1" if intent == I.GUARD else "attack3"
	if rules.has(R.DEVIL):
		return "summon" if intent == I.GUARD else ("attack2" if intent == I.FRENZY else "attack1")
	if rules.has(R.MOON):
		match intent:
			I.HEX: return "attack3"
			I.DRAIN: return "attack1"
			I.GUARD: return "summon"
		return "attack2"
	if rules.has(R.TOWER) and intent != I.GUARD:
		return "attack1"
	return IDLE if intent == I.GUARD else "attack"

## Spiralgegner tragen die Id ihrer Vorlage mit Tiefe ("uhrenwurm_spirale_3").
static func sprite_id(definition: EnemyDefinition) -> String:
	var id := definition.id if definition != null else ""
	var cut := id.find("_spirale_")
	return id.substr(0, cut) if cut > 0 else id
