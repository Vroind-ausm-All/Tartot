extends Node
## Laufzeittest der Oberflaeche: spielt mit dem Autopiloten ganze Runs und
## baut nach jedem Schritt die passende Seite auf - Titel, Kampf, Belohnung,
## Wege, Haendler, Ritual, Orakel, Ereignis, Rast, Omen-Beute, Sieg, Bericht.
## Jede Seite muss ohne Laufzeitfehler entstehen.
##
##   godot --headless --path godot-next res://tests/ui_walk.tscn
##
## Exit-Code 1, wenn eine Phase nie gezeigt wurde oder der Run haengt.

func _ready() -> void:
	var main: Control = load("res://ui/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var spiel: Node = get_tree().root.get_node("Spiel")
	spiel.use_test_storage()
	var gesehen := {}
	var pilot := Autopilot.new()
	pilot.continue_into_spiral = true
	var schritte := 0
	# --shots=ordner: beim ersten Auftreten jeder Phase ein Bild (nur mit Fenster).
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		await _shot(shots, "Titel")
	for seed in [11, 12, 13, 14]:
		spiel.abandon_to_title()
		main.show_current()
		await get_tree().process_frame
		spiel.new_run(RunSetup.new(), seed)
		var game: GameController = spiel.game
		var guard := 0
		while game.phase != Enums.GamePhase.GAME_OVER and game.run.fight_index < 24 and guard < 3000:
			guard += 1
			var neu := not gesehen.has(Enums.NAMES_PHASE[game.phase])
			gesehen[Enums.NAMES_PHASE[game.phase]] = true
			main.show_current()
			await get_tree().process_frame
			if neu and shots != "":
				await _shot(shots, Enums.NAMES_PHASE[game.phase])
			if game.phase == Enums.GamePhase.COMBAT:
				if not pilot.play_turn(game):
					break
				spiel.after_turn(game.last_turn)
			elif game.phase == Enums.GamePhase.PATH_CHOICE and game.paths.has(Enums.PathType.ORACLE) and not gesehen.has("Oracle"):
				# Der Autopilot waehlt nie das Orakel - hier einmal bewusst.
				game.choose_path(Enums.PathType.ORACLE)
			else:
				pilot.step(game)
				spiel.save_run()
			schritte += 1
		gesehen[Enums.NAMES_PHASE[game.phase]] = true
		main.show_current()
		await get_tree().process_frame
	var fehlend: Array[String] = []
	for p in ["Combat", "Reward", "PathChoice", "Shop", "Ritual", "Oracle", "Event", "BossLoot", "Rest", "GameOver"]:
		if not gesehen.has(p):
			fehlend.append(p)
	if shots != "":
		await _shot(shots, "Bericht")
	print("UI-Durchlauf: %d Schritte, Phasen %s, fehlend %s" % [schritte, str(gesehen.keys()), str(fehlend)])
	spiel.abandon_to_title()
	get_tree().quit(1 if not fehlend.is_empty() else 0)

func _shot(ordner: String, name: String) -> void:
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [ordner, name])
