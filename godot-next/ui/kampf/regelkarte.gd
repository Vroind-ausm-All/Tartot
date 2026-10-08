extends Control
class_name Regelkarte
## Die Regel des Bosses als Karte auf dem Tisch, mit Wachssiegel. Bricht
## ein Siegel (Phase 2), bekommt das Wachs einen Riss und der Text wird
## schaerfer - der Text kommt immer aus dem Kern (ActiveRuleTexts).

var text := ""
var gebrochen := false
var _riss := 0.0
var _label: Label

func _init() -> void:
	custom_minimum_size = Vector2(0, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_label = Thema.label("", 6, Thema.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 8
	_label.offset_right = -26
	_label.offset_top = 3
	_label.offset_bottom = -3
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_label.text = text

func setze(neuer_text: String, ist_gebrochen: bool) -> void:
	text = neuer_text
	gebrochen = ist_gebrochen
	_riss = 1.0 if gebrochen else 0.0
	if _label != null:
		_label.text = text
	queue_redraw()

## Siegelbruch: Wachs splittert, Karte wendet sich, neuer Text.
func siegel_bricht(neuer_text: String, tempo := 1.0) -> void:
	gebrochen = true
	var t := create_tween()
	t.set_speed_scale(tempo)
	t.tween_property(self, "_riss", 1.0, 0.25)
	t.tween_property(self, "scale:y", 0.05, 0.10)
	t.tween_callback(func():
		text = neuer_text
		if _label != null:
			_label.text = text)
	t.tween_property(self, "scale:y", 1.0, 0.12)
	await t.finished

## Auftritt: die Karte gleitet von oben herein, das Siegel schlaegt auf.
func auftritt(tempo := 1.0) -> void:
	pivot_offset = size * 0.5
	modulate.a = 0.0
	var start := position
	position = start + Vector2(0, -30)
	var t := create_tween()
	t.set_speed_scale(tempo)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(self, "position", start, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Thema.PAPER_DARK)
	draw_rect(r, Thema.INK, false, 2.0)
	draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), Thema.SEPIA2, false, 1.0)
	# Wachssiegel rechts
	var c := Vector2(size.x - 14, size.y * 0.5)
	draw_circle(c, 10.0, Thema.RED)
	draw_circle(c, 10.0, Color("#6E1418"), false, 2.0)
	draw_circle(c, 5.0, Color("#8E1C20"), false, 1.0)
	if _riss > 0.0:
		var a := c + Vector2(-8, -9) * _riss
		var b := c + Vector2(7, 8) * _riss
		draw_line(a, c + Vector2(-1, -1), Thema.INK, 2.0)
		draw_line(c + Vector2(-1, -1), b, Thema.INK, 2.0)
		draw_line(c, c + Vector2(8, -6) * _riss, Thema.INK, 1.5)
