extends Node
## Vorfuehrfilm: Titel, dann drei Bosskaempfe am Kartentisch - jeweils bis
## der Boss nach dem Tisch gegriffen hat. Beim Turm zuerst langes Druecken
## (Erklaerung, Holo-Folie). Aufnehmen mit dem Movie Maker:
##
##   xvfb-run -s "-screen 0 1080x1920x24" godot --path godot-next \
##     --rendering-driver opengl3 --resolution 1080x1920 \
##     --write-movie film.avi --fixed-fps 30 res://tests/video.tscn

const FOLGE := [
	["boss_turm", ["einsturz"], 5],
	["boss_mond", ["verhuellen"], 5],
	["boss_tod", ["zeichnen", "verlust"], 7],
]

var _cues := {}


func _ready() -> void:
	var main: Control = load("res://ui/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var spiel: Node = get_tree().root.get_node("Spiel")
	spiel.use_test_storage()
	await _warte(2.5)
	for eintrag in FOLGE:
		var boss: String = eintrag[0]
		_cues.clear()
		if spiel.starte_vorfuehrung(boss) == null:
			continue
		main.show_current()
		var tisch := main.current as Kampftisch
		if tisch == null:
			continue
		tisch.cue_gespielt.connect(func(c: Dictionary): _cues[String(c["typ"])] = true)
		await _warte(1.0)
		while tisch.gesperrt:
			await get_tree().process_frame
		await _warte(1.6)
		if boss == "boss_turm":
			await tisch.lang_druecken_vorfuehren(1)
		var zuege := 0
		while zuege < int(eintrag[2]) and is_instance_valid(tisch) and main.current == tisch:
			zuege += 1
			await tisch.selbst_spielen(1)
			var alle := true
			for c in eintrag[1]:
				alle = alle and _cues.has(c)
			if alle:
				break
		await _warte(1.5)
		print("FILM %s: %d Zuege, Cues %s" % [boss, zuege, str(_cues.keys())])
		spiel.abandon_to_title()
		main.show_current()
		await _warte(1.0)
	get_tree().quit()


func _warte(s: float) -> void:
	await get_tree().create_timer(s).timeout
