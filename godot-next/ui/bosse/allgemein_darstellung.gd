extends BossDarstellung
class_name AllgemeinDarstellung
## Darstellung fuer alle Gegner ohne eigene Bossfigur: die Pixel-Silhouette
## aus PixelArt, bewegt von BossDarstellung.

var _figur: PixelArt

func _ready() -> void:
	super._ready()
	var schluessel := definition.art if definition != null and definition.art != "" else (definition.name if definition != null else "")
	_figur = PixelArt.new(schluessel)
	_figur.size = _figur.custom_minimum_size
	_figur.pivot_offset = _figur.size * Vector2(0.5, 0.9)
	add_child(_figur)

func _process(delta: float) -> void:
	super._process(delta)
	if _figur == null:
		return
	var z := minf(size.x / 110.0, size.y / 120.0)
	_figur.position = _mitte() - _figur.pivot_offset + Vector2(0, _figur.size.y * 0.4)
	_figur.scale = squash * z
	_figur.rotation = tilt
