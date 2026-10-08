extends RefCounted
class_name BossRegistry
## Welche Darstellung und welche Klaenge zu einem Gegner gehoeren.
##
## Neue Bossfigur: Skript unter ui/bosse/<name>/ anlegen (erbt von
## BossDarstellung), hier eintragen, fertig. Der Kampfschirm kennt nur
## BossDarstellung und ruft spiele(cue). Schluessel ist die Sprite-Id des
## Kerns (Spiralvarianten tragen die Id ihrer Vorlage).

const DARSTELLUNGEN := {
	"boss_turm": preload("res://ui/bosse/turm/turm_boss.gd"),
	"boss_mond": preload("res://ui/bosse/mond/mond_boss.gd"),
}


static func schluessel(definition: EnemyDefinition) -> String:
	return AnimationCues.sprite_id(definition)

static func hat_eigene(definition: EnemyDefinition) -> bool:
	return DARSTELLUNGEN.has(schluessel(definition))

static func erzeuge(definition: EnemyDefinition) -> BossDarstellung:
	var skript: Script = DARSTELLUNGEN.get(schluessel(definition), null)
	var d: BossDarstellung = skript.new(definition) if skript != null else AllgemeinDarstellung.new(definition)
	return d

## Klang zu einem Cue; null = der Kampfschirm nimmt seinen Standardklang.
static func ton(definition: EnemyDefinition, cue: String) -> AudioStream:
	match schluessel(definition):
		"boss_turm": return TurmAudio.cue(cue)
		"boss_mond": return MondAudio.cue(cue)
	return null
