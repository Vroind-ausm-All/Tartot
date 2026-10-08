extends Control
class_name Schicksalsplatz
## Einer der drei Plaetze. Nimmt Karten per Tippen oder Ziehen an; ein
## eingestuerzter Platz (Turm) weist sie ab. Ob ein Platz eingestuerzt ist,
## sagt nur der Kern (CombatState.blocked_slot).

signal angetippt(slot: int)
signal abgelegt(slot: int, card: CardInstance)

const TITEL := ["VERGANGENHEIT", "GEGENWART", "ZUKUNFT"]

var slot := 0
var eingestuerzt := false
var hervorgehoben := false
var annehmen := true
var _absacken := 0.0
var _staub := 0.0
var _hinweis: Label
var _inhalt: CenterContainer

func _init(p_slot: int) -> void:
	slot = p_slot
	custom_minimum_size = Vector2(82, 92)
	mouse_filter = Control.MOUSE_FILTER_STOP

var _titel: Label

func _ready() -> void:
	_titel = Thema.label(TITEL[slot], 6, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_titel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titel)
	_inhalt = CenterContainer.new()
	_inhalt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inhalt)
	_hinweis = Thema.label("", 6, Thema.SEPIA1, HORIZONTAL_ALIGNMENT_CENTER, true)
	_hinweis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hinweis)
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	_titel.position = Vector2(0, 1)
	_titel.size = Vector2(size.x, 9)
	_inhalt.position = Vector2(0, 11)
	_inhalt.size = Vector2(size.x, 64)
	_hinweis.position = Vector2(0, size.y - 17)
	_hinweis.size = Vector2(size.x, 16)

func zeige(karte: Control, hinweis: String) -> void:
	for c in _inhalt.get_children():
		c.queue_free()
	if karte != null:
		karte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inhalt.add_child(karte)
	_hinweis.text = hinweis
	queue_redraw()

func karte_einrasten(tempo := 1.0) -> void:
	if _inhalt.get_child_count() == 0:
		return
	var k: Control = _inhalt.get_child(_inhalt.get_child_count() - 1)
	k.pivot_offset = k.custom_minimum_size * 0.5
	k.scale = Vector2(1.18, 1.18)
	var t := create_tween()
	t.set_speed_scale(tempo)
	t.tween_property(k, "scale", Vector2(0.94, 0.94), 0.08)
	t.tween_property(k, "scale", Vector2.ONE, 0.10)

## Der Turm: Riss, Staub, der Platz sackt ab.
func stuerzt_ein(tempo := 1.0) -> void:
	eingestuerzt = true
	var t := create_tween()
	t.set_speed_scale(tempo)
	t.set_parallel(true)
	t.tween_property(self, "_absacken", 1.0, 0.30).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_staub", 1.0, 0.15)
	t.chain().tween_property(self, "_staub", 0.0, 0.40)
	await t.finished

func richtet_sich_auf() -> void:
	eingestuerzt = false
	_absacken = 0.0
	queue_redraw()

func abweisen(tempo := 1.0) -> void:
	var start := position
	var t := create_tween()
	t.set_speed_scale(tempo)
	t.tween_property(self, "position", start + Vector2(4, 0), 0.04)
	t.tween_property(self, "position", start + Vector2(-4, 0), 0.04)
	t.tween_property(self, "position", start, 0.04)

func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		angetippt.emit(slot)
		accept_event()

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return annehmen and not eingestuerzt and data is Dictionary and data.has("karte")

func _drop_data(_pos: Vector2, data: Variant) -> void:
	abgelegt.emit(slot, data["karte"])

func _process(_delta: float) -> void:
	if _staub > 0.0:
		queue_redraw()

func _draw() -> void:
	var sack := _absacken * 6.0
	var r := Rect2(0, sack, size.x, size.y - sack)
	var rand := Thema.GOLD if hervorgehoben else Thema.SEPIA3
	if eingestuerzt:
		draw_rect(r, Color("#140E0C"))
		draw_rect(r, Thema.RED, false, 2.0)
		# Risse durch das Platzmotiv
		var m := r.get_center()
		var risse := [[Vector2(-30, -38), Vector2(-8, -12), Vector2(-14, 6), Vector2(4, 30), Vector2(-2, 44)],
			[Vector2(-8, -12), Vector2(22, -22), Vector2(34, -36)],
			[Vector2(-14, 6), Vector2(-34, 16)], [Vector2(4, 30), Vector2(28, 22)]]
		for linie in risse:
			var pts := PackedVector2Array()
			for p in linie:
				pts.append(m + p)
			draw_polyline(pts, Thema.RED, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(6, r.position.y + r.size.y * 0.55), "EINGESTÜRZT",
			HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 7, Thema.RED)
	else:
		draw_rect(r, Thema.DEEP)
		draw_rect(r, rand, false, 1.0 if not hervorgehoben else 2.0)
		draw_rect(Rect2(4, 12 + sack, size.x - 8, 60), Color(Thema.SEPIA3, 0.35), false, 1.0)
	if _staub > 0.0:
		for i in 12:
			var a := float(i) * 1.7
			var p := Vector2(size.x * 0.5, size.y * 0.6) + Vector2(cos(a), sin(a) * 0.5) * (20.0 + 30.0 * (1.0 - _staub))
			draw_rect(Rect2(p.x, p.y, 3, 3), Color(Thema.SEPIA1, _staub))
