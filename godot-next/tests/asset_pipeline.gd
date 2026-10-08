extends SceneTree
## Prueft die Asset-Pipeline ohne echte Kunst: baut ein Blatt mit 35
## Frames wie create_boss_turm.lua, exportiert es wie Aseprite (PNG +
## JSON), importiert es zu SpriteFrames und laesst eine Bossdarstellung
## damit spielen. Danach ersetzt eine echte Datei unter
## assets/sprites/bosses/turm/ die Zeichnung ohne Codeaenderung.

var _fehler := 0

func _check(b: bool, text: String) -> void:
	if not b:
		_fehler += 1
		push_error("ASSET-PIPELINE: " + text)

class TestBoss extends BossDarstellung:
	func sprite_pfad() -> String:
		return "user://test_boss_frames.tres"

func _init() -> void:
	var tags := [["idle", 0, 3], ["intro", 4, 8], ["attack", 9, 14], ["hit", 15, 17],
		["break", 18, 23], ["phase_2", 24, 30], ["death", 31, 34]]
	var bild := Image.create(128 * 35, 160, false, Image.FORMAT_RGBA8)
	var frames: Array = []
	for i in 35:
		bild.fill_rect(Rect2i(i * 128 + 40, 40, 48, 100), Color("#C9B48E"))
		frames.append({"frame": {"x": i * 128, "y": 0, "w": 128, "h": 160}, "duration": 83})
	var json := {"frames": frames, "meta": {"image": "test_boss.png", "frameTags": []}}
	for t in tags:
		json["meta"]["frameTags"].append({"name": t[0], "from": t[1], "to": t[2]})
	bild.save_png(ProjectSettings.globalize_path("user://test_boss.png"))
	var f := FileAccess.open("user://test_boss.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(json))
	f.close()

	var err := AsepriteImport.importiere("user://test_boss.json", "user://test_boss_frames.tres")
	_check(err == OK, "Import: %s" % error_string(err))
	var sf := load("user://test_boss_frames.tres") as SpriteFrames
	_check(sf != null, "SpriteFrames geladen")
	if sf != null:
		for zustand in ["idle", "intro", "attack", "hit", "collapse", "phase2", "death"]:
			_check(sf.has_animation(zustand), "Zustand %s vorhanden" % zustand)
		_check(sf.get_frame_count("phase2") == 7, "phase2 hat 7 Frames")
		_check(sf.get_animation_loop("idle") and not sf.get_animation_loop("death"), "nur idle in Schleife")

	var boss := TestBoss.new()
	root.add_child(boss)
	await process_frame
	_check(boss._sprite != null, "Darstellung nutzt das Sprite statt der Zeichnung")
	if boss._sprite != null:
		boss.tempo = 10.0
		await boss.spiele("phase2")
		_check(boss._sprite.animation == "idle", "nach phase2 zurueck in idle")
	print("ASSET-PIPELINE: fehler=%d" % _fehler)
	quit(1 if _fehler > 0 else 0)
