extends Node
## Laufzeittest des Turm-Slices: echter Run bis vor den Turm, dann der
## Bosskampf über den Kampftisch (Legung per Autopilot, Ausführen über den
## Knopfpfad, Cue-Folge mit hohem Tempo), Omen-Beute, Ende der Vorführung.
##
##   godot --headless --path godot-next res://tests/turm_slice.tscn
##   xvfb-run godot --path godot-next res://tests/turm_slice.tscn -- --shots=ordner
##
## Exit 1, wenn der Turm nicht erscheint oder ein Pflicht-Cue fehlt.

var _cues := {}
var _shots := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shots = a.substr(8)
	var tempo := 1.0 if _shots != "" else 12.0
	var main: Control = load("res://ui/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var spiel: Node = get_tree().root.get_node("Spiel")
	spiel.use_test_storage()
	var fehler: Array[String] = []

	var game: GameController = spiel.starte_vorfuehrung("boss_turm")
	if game == null:
		print("TURM-SLICE: kein Seed mit dem Turm gefunden")
		get_tree().quit(1)
		return
	main.show_current()
	var schirm := main.current as Kampfschirm
	if schirm == null:
		fehler.append("kein Kampfschirm")
	else:
		schirm.tempo = tempo
		schirm.boss.tempo = tempo
		schirm.cue_gespielt.connect(func(c: Dictionary): _cues[String(c["typ"]) + ":" + String(c.get("cue", ""))] = true)
		if not schirm.boss is TurmBoss:
			fehler.append("Turm-Darstellung fehlt")
		# Der Auftritt sperrt die Eingabe, bis Turm und Regelkarte stehen.
		if not schirm.gesperrt:
			fehler.append("Auftritt sperrt die Eingabe nicht")
		await _shot("1_auftritt", 0.5)
		while schirm.gesperrt:
			await get_tree().process_frame
		await _shot("2_regelkarte", 0.1)
		var pilot := Autopilot.new()
		var zuege := 0
		var einsturz_gezeigt := false
		var phase2_gezeigt := false
		while game.phase == Enums.GamePhase.COMBAT and zuege < 40:
			zuege += 1
			if game.combat.pact_pending:
				game.answer_pact(false)
			pilot.arrange(game)
			schirm._refresh()
			if zuege == 1:
				await _shot("3_legung", 0.1)
			schirm._resolve()
			while schirm.gesperrt and game.phase == Enums.GamePhase.COMBAT:
				await get_tree().process_frame
			if not einsturz_gezeigt and game.combat.blocked_slot >= 0:
				einsturz_gezeigt = true
				await _shot("4_eingestuerzt", 0.1)
			if not phase2_gezeigt and game.combat.enemy.phase >= 1:
				phase2_gezeigt = true
				await _shot("5_phase2", 0.1)
		# Nach dem Kampf wechselt der Hauptschirm auf die Omen-Beute.
		var warte := 0
		while main.current == schirm and warte < 600:
			warte += 1
			await get_tree().process_frame
		print("TURM-SLICE: %d Züge, Phase %s, Cues %s" % [zuege, Enums.NAMES_PHASE[game.phase], str(_cues.keys())])
		for pflicht in ["wertung:", "fate:", "boss:collapse", "einsturz:"]:
			if not _cues.has(pflicht):
				fehler.append("Cue fehlt: " + pflicht)
		if not (_cues.has("boss:death") or game.phase == Enums.GamePhase.GAME_OVER):
			fehler.append("weder Turmtod noch Niederlage")
		if game.phase == Enums.GamePhase.BOSS_LOOT:
			await _shot("6_omen_beute", 0.3)
			game.choose_boss_loot(Enums.BossLootChoice.BIND)
			main.show_current()
			await _shot("7_ende", 0.3)
			if not main.current.find_children("*", "Button", true, false).size() > 0:
				fehler.append("Ende der Vorführung ohne Knöpfe")
	print("TURM-SLICE: fehler=%s" % str(fehler))
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
