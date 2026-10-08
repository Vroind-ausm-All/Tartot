extends RefCounted
class_name AsepriteImport
## Asset-Pipeline: Aseprite-Export (PNG-Blatt + JSON-Atlas mit Tags) ->
## SpriteFrames fuer BossDarstellung.
##
## Export in Aseprite: File > Export Sprite Sheet, "JSON Data" an,
## "Tags" an, Array oder Hash egal. Tags heissen wie in der ASSET_SPEC;
## Aseprite-Namen werden auf die Zustaende der Darstellung abgebildet.
##
##   godot --headless --path godot-next --script res://tools/aseprite_import_cli.gd -- \
##     --json=res://assets/sprites/bosses/turm/boss_turm.json \
##     --out=res://assets/sprites/bosses/turm/boss_turm_frames.tres

## Aseprite-Tag -> Zustand der Darstellung.
const ZUSTAND := {"phase_2": "phase2", "break": "collapse"}
## Nur diese Zustaende laufen in Schleife.
const SCHLEIFE := ["idle"]
const FPS := 12.0

static func frames_aus_json(daten: Dictionary, textur: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var liste: Array = []
	var roh: Variant = daten.get("frames", [])
	if roh is Array:
		liste = roh
	elif roh is Dictionary:
		for k in roh:
			liste.append(roh[k])
	var tags: Array = daten.get("meta", {}).get("frameTags", [])
	if tags.is_empty():
		tags = [{"name": "idle", "from": 0, "to": liste.size() - 1}]
	for tag in tags:
		var name: String = String(tag.get("name", "idle"))
		name = ZUSTAND.get(name, name)
		frames.add_animation(name)
		frames.set_animation_speed(name, FPS)
		frames.set_animation_loop(name, SCHLEIFE.has(name))
		for i in range(int(tag.get("from", 0)), int(tag.get("to", 0)) + 1):
			if i < 0 or i >= liste.size():
				continue
			var f: Dictionary = liste[i].get("frame", {})
			var atlas := AtlasTexture.new()
			atlas.atlas = textur
			atlas.region = Rect2(float(f.get("x", 0)), float(f.get("y", 0)), float(f.get("w", 0)), float(f.get("h", 0)))
			# Dauer in ms -> relative Dauer bei 12 fps
			var dauer := float(liste[i].get("duration", 1000.0 / FPS)) / (1000.0 / FPS)
			frames.add_frame(name, atlas, dauer)
	return frames

## Laedt JSON und das daneben liegende PNG (meta.image) und speichert SpriteFrames.
static func importiere(json_pfad: String, ziel_pfad: String) -> Error:
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_pfad))
	if not daten is Dictionary:
		return ERR_PARSE_ERROR
	var bild_name := String(daten.get("meta", {}).get("image", json_pfad.get_basename() + ".png"))
	var bild_pfad := json_pfad.get_base_dir().path_join(bild_name.get_file())
	var bild := Image.load_from_file(ProjectSettings.globalize_path(bild_pfad))
	if bild == null:
		return ERR_FILE_NOT_FOUND
	var textur := ImageTexture.create_from_image(bild)
	return ResourceSaver.save(frames_aus_json(daten, textur), ziel_pfad)
