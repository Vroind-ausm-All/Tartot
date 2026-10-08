extends Node
## Laufzeittest eines Boss-Slices am Kartentisch (ui/tisch/kampftisch.gd):
## echter Run bis vor den Boss (Spiel.starte_vorfuehrung), dann spielt der
## Tisch selbst - Karten ziehen, Knopf druecken - bis der Kampf endet.
## Danach Omen-Beute und Ende der Vorfuehrung.
##
##   godot --headless --path godot-next res://tests/turm_slice.tscn
##   godot --headless --path godot-next res://tests/mond_slice.tscn
##   godot --headless --path godot-next res://tests/tod_slice.tscn
##   xvfb-run godot --path godot-next res://tests/turm_slice.tscn -- --shots=ordner
##
## Exit 1, wenn der Boss nicht erscheint, ein Pflicht-Cue fehlt (etwa der
## Griff des Turms nach einem Platz) oder der Kampf nicht endet.

@export var boss_id := "boss_turm"
## Cues "typ:cue", die im Kampf mindestens einmal vorkommen muessen.
@export var pflicht: PackedStringArray = ["wertung:", "fate:", "einsturz:"]

var _cues := {}
var _shots := ""
var _ende := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.substr(8)
	# Ohne Fenster im Zeitraffer; mit Fenster in Echtzeit (fuer Bilder).
	Engine.time_scale = 1.0 if _shots != "" else 6.0
	var main: Control = load("res://ui/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var spiel: Node = get_tree().root.get_node("Spiel")
	spiel.use_test_storage()
	var fehler: Array[String] = []

	var game: GameController = spiel.starte_vorfuehrung(boss_id)
	if game == null:
		print("BOSS-SLICE %s: kein Seed gefunden" % boss_id)
		get_tree().quit(1)
		return
	main.show_current()
	var tisch := main.current as Kampftisch
	if tisch == null:
		fehler.append("kein Kampftisch")
	else:
		tisch.cue_gespielt.connect(func(c: Dictionary):
			_cues[String(c["typ"]) + ":" + String(c.get("cue", ""))] = true
			if _shots != "" and String(c["typ"]) in ["einsturz", "verhuellen", "verlust", "zeichnen"]:
				_shot_spaeter("4_" + String(c["typ"]), 0.55))
		# Der Auftritt sperrt die Eingabe, bis Boss und Regel stehen.
		if not tisch.gesperrt:
			fehler.append("Auftritt sperrt die Eingabe nicht")
		await _shot("1_auftritt", 0.6)
		while tisch.gesperrt:
			await get_tree().process_frame
		await _shot("2_tisch", 0.2)
		tisch.finished.connect(func(): _ende = true)
		tisch.selbst_spielen(60)
		var start := Time.get_ticks_msec()
		while not _ende and Time.get_ticks_msec() - start < 420000:
			await get_tree().process_frame
		if not _ende:
			fehler.append("Kampf endet nicht")
		await get_tree().process_frame
		print("BOSS-SLICE %s: Phase %s, Cues %s" % [boss_id, Enums.NAMES_PHASE[game.phase], str(_cues.keys())])
		for p in pflicht:
			if not _cues.has(p):
				fehler.append("Cue fehlt: " + p)
		if not (game.phase in [Enums.GamePhase.BOSS_LOOT, Enums.GamePhase.GAME_OVER]):
			fehler.append("weder Omen-Beute noch Niederlage")
		if game.phase == Enums.GamePhase.BOSS_LOOT:
			await _shot("6_omen_beute", 0.4)
			game.choose_boss_loot(Enums.BossLootChoice.BIND)
			main.show_current()
			await _shot("7_ende", 0.3)
			if not main.current.find_children("*", "Button", true, false).size() > 0:
				fehler.append("Ende der Vorführung ohne Knöpfe")
	Engine.time_scale = 1.0
	print("BOSS-SLICE %s: fehler=%s" % [boss_id, str(fehler)])
	spiel.abandon_to_title()
	get_tree().quit(1 if not fehler.is_empty() else 0)


## Bildschirmabzug, nur mit Fenster und --shots.
func _shot(name: String, warte: float) -> void:
	if _shots == "":
		return
	DirAccess.make_dir_recursive_absolute(_shots)
	await get_tree().create_timer(warte).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_shots, name])


func _shot_spaeter(name: String, warte: float) -> void:
	if FileAccess.file_exists("%s/%s.png" % [_shots, name]):
		return
	await _shot(name, warte)
