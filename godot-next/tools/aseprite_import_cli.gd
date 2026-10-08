extends SceneTree
## Kommandozeile fuer AsepriteImport (siehe dort).

func _init() -> void:
	var json := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--json="):
			json = a.substr(7)
		elif a.begins_with("--out="):
			out = a.substr(6)
	if json == "" or out == "":
		print("Aufruf: -- --json=res://...json --out=res://..._frames.tres")
		quit(2)
		return
	var err := AsepriteImport.importiere(json, out)
	print("Aseprite-Import %s -> %s: %s" % [json, out, error_string(err)])
	quit(0 if err == OK else 1)
