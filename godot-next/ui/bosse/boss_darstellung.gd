extends Control
class_name BossDarstellung
## Grundlage aller Bossdarstellungen. Kennt keine Regel: sie bekommt Cues
## (Namen aus AnimationCues plus "intro" und "collapse") und spielt sie ab.
##
## Zustaende: intro, idle, attack, hit, collapse, phase2, death - dieselben
## Namen wie in den Asset-Spezifikationen (assets/sprites/bosses/*/ASSET_SPEC.md).
##
## Asset-Pipeline: liegt unter sprite_pfad() ein SpriteFrames-Asset mit
## Animationen dieser Namen, zeigt die Darstellung das Sprite; sonst
## zeichnet sie prozedural (_zeichne). Die Bewegung (Stauchen, Wackeln,
## Blitz) kommt in beiden Faellen von hier.

signal animation_finished(name: String)

var definition: EnemyDefinition
var state := "idle"
var frame := 0
var phase_two := false
## Animationswerte - getweent, gezeichnet in _draw.
var squash := Vector2.ONE
var offset_px := Vector2.ZERO
var tilt := 0.0
var alpha := 1.0
var flash := 0.0
var shake := 0.0
## Tempo der Animationen (Tests drehen hoch).
var tempo := 1.0
var _token := 0
var _sprite: AnimatedSprite2D = null

func _init(p_definition: EnemyDefinition = null) -> void:
	definition = p_definition
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0 / 12.0
	timer.autostart = true
	timer.timeout.connect(_tick)
	add_child(timer)
	_lade_sprite()

## Pfad eines SpriteFrames-Assets; leer = nur prozedural.
func sprite_pfad() -> String:
	return ""

## Massstab der prozeduralen Zeichnung fuer die aktuelle Groesse.
func zoom() -> float:
	return 1.0

## Zeichnet die Figur um den Nullpunkt (Fuesse etwa bei y = +90 * zoom).
func _zeichne() -> void:
	pass

func _lade_sprite() -> void:
	var pfad := sprite_pfad()
	if pfad == "" or not ResourceLoader.exists(pfad):
		return
	var frames := load(pfad) as SpriteFrames
	if frames == null:
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite_spielen("idle")

func _sprite_spielen(name: String) -> void:
	if _sprite == null:
		return
	var sf := _sprite.sprite_frames
	if sf.has_animation(name):
		_sprite.play(name)
	elif name.begins_with("attack") and sf.has_animation("attack"):
		_sprite.play("attack")
	elif sf.has_animation("idle"):
		_sprite.play("idle")

func _tick() -> void:
	frame = (frame + 1) % 4
	if state == "idle":
		offset_px.y = -2.0 if frame in [1, 2] else 0.0
		squash = Vector2(1.0 + (0.012 if frame == 2 else 0.0), 1.0 - (0.012 if frame == 2 else 0.0))
	flash = maxf(0.0, flash - 0.18)
	shake = maxf(0.0, shake - 0.16)

func _process(_delta: float) -> void:
	modulate.a = alpha
	if _sprite != null:
		_sprite.position = _mitte()
		_sprite.scale = squash
		_sprite.rotation = tilt
	queue_redraw()

func _mitte() -> Vector2:
	var c := Vector2(size.x * 0.5, size.y * 0.54) + offset_px
	if shake > 0.0:
		c += Vector2(sin(Time.get_ticks_msec() * 0.061), cos(Time.get_ticks_msec() * 0.079)) * (4.0 * shake)
	return c

func _draw() -> void:
	if _sprite == null:
		draw_set_transform(_mitte(), tilt, squash * zoom())
		_zeichne()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.93, 0.75, flash * 0.18))

# ------------------------------------------------------------ Cues
func set_phase_two(enabled: bool) -> void:
	phase_two = enabled

## Spielt einen Cue und kehrt zurueck, wenn er fertig ist.
func spiele(cue: String) -> void:
	match cue:
		"intro": await play_intro()
		"hit": await play_hit(false)
		"hit_stark": await play_hit(true)
		"phase2": await play_phase_two()
		"collapse": await play_collapse()
		"death": await play_death()
		"idle", "summon", "veil": await play_bob()
		_: await play_attack()

func _start(name: String) -> int:
	_token += 1
	state = name
	_sprite_spielen(name)
	return _token

func _ende(token: int, name: String) -> void:
	if token == _token and name != "death":
		state = "idle"
		_sprite_spielen("idle")
	animation_finished.emit(name)

func _tween() -> Tween:
	var t := create_tween()
	t.set_speed_scale(tempo)
	return t

func play_intro() -> void:
	var token := _start("intro")
	squash = Vector2(0.72, 1.28)
	alpha = 0.0
	var t := _tween()
	t.set_parallel(true)
	t.tween_property(self, "alpha", 1.0, 0.18)
	t.tween_property(self, "squash", Vector2(1.08, 0.94), 0.24)
	t.chain().tween_property(self, "squash", Vector2.ONE, 0.12)
	await t.finished
	_ende(token, "intro")

func play_bob(name := "idle") -> void:
	var token := _start(name)
	var t := _tween()
	t.tween_property(self, "offset_px", Vector2(0, -6), 0.10)
	t.tween_property(self, "offset_px", Vector2.ZERO, 0.14)
	await t.finished
	_ende(token, name)

func play_attack(name := "attack") -> void:
	var token := _start(name)
	var t := _tween()
	t.tween_property(self, "squash", Vector2(0.88, 1.14), 0.10)
	t.tween_property(self, "offset_px", Vector2(0, 12), 0.07)
	t.tween_property(self, "squash", Vector2(1.18, 0.80), 0.05)
	t.tween_callback(func(): flash = 0.55; shake = 0.8)
	t.tween_property(self, "offset_px", Vector2.ZERO, 0.12)
	t.tween_property(self, "squash", Vector2.ONE, 0.09)
	await t.finished
	_ende(token, name)

func play_hit(strong := false) -> void:
	var token := _start("hit")
	flash = 1.0
	shake = 1.0 if strong else 0.65
	var t := _tween()
	t.tween_property(self, "squash", Vector2(1.16, 0.78) if strong else Vector2(1.08, 0.90), 0.045)
	t.tween_property(self, "offset_px", Vector2(-6, 0), 0.045)
	t.tween_property(self, "offset_px", Vector2(4, 0), 0.045)
	t.tween_property(self, "offset_px", Vector2.ZERO, 0.055)
	t.tween_property(self, "squash", Vector2.ONE, 0.07)
	await t.finished
	_ende(token, "hit")

func play_collapse() -> void:
	var token := _start("collapse")
	flash = 1.0
	shake = 1.0
	var t := _tween()
	t.tween_property(self, "tilt", -0.045, 0.05)
	t.tween_property(self, "tilt", 0.055, 0.05)
	t.tween_property(self, "tilt", -0.025, 0.05)
	t.tween_property(self, "tilt", 0.0, 0.08)
	await t.finished
	_ende(token, "collapse")

func play_phase_two() -> void:
	var token := _start("phase2")
	phase_two = true
	flash = 1.0
	shake = 1.0
	var t := _tween()
	t.tween_property(self, "squash", Vector2(1.20, 0.78), 0.08)
	t.tween_property(self, "squash", Vector2(0.92, 1.16), 0.08)
	t.tween_property(self, "squash", Vector2(1.10, 0.88), 0.08)
	t.tween_property(self, "squash", Vector2.ONE, 0.14)
	await t.finished
	_ende(token, "phase2")

func play_death() -> void:
	var token := _start("death")
	flash = 1.0
	shake = 1.0
	var t := _tween()
	t.tween_property(self, "squash", Vector2(1.28, 0.66), 0.09)
	t.tween_property(self, "tilt", -0.08, 0.06)
	t.tween_property(self, "tilt", 0.11, 0.06)
	t.tween_property(self, "squash", Vector2(1.04, 0.42), 0.10)
	t.set_parallel(true)
	t.tween_property(self, "alpha", 0.0, 0.38)
	t.tween_property(self, "offset_px", Vector2(0, 40), 0.38)
	await t.finished
	_ende(token, "death")
