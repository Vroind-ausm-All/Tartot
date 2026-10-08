extends Control
class_name Kartenblatt
## Eine Karte ausserhalb des Kampfes (Haendler, Ritual, Rast, Omen): dieselbe
## Karte wie am Tisch (TarotKarte), nur kleiner. Antippen waehlt sie, langes
## Druecken zeigt sie gross mit Erklaerung (lange_gedrueckt -> KartenDetail).

signal chosen(card: CardInstance)
signal lange_gedrueckt(karte: TarotKarte, punkt: Vector2)
signal lang_bewegt(punkt: Vector2)
signal lang_losgelassen

const MASS := 0.78
const LANG := 0.4

var card: CardInstance
var karte: TarotKarte
var _gedrueckt := false
var _druck_pos := Vector2.ZERO
var _dauer := 0.0
var _lang := false


func _init(p_card: CardInstance) -> void:
	card = p_card
	custom_minimum_size = TarotKarte.GROESSE * MASS + Vector2(8, 12)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	karte = TarotKarte.aus_daten(KernBruecke.karte_nach(card, null))
	karte.basis = MASS
	karte.position = custom_minimum_size * 0.5
	add_child(karte)
	mouse_entered.connect(func(): karte.schwebt = true; karte.stossen(0.05))
	mouse_exited.connect(func(): karte.schwebt = false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_gedrueckt = true
			_druck_pos = event.global_position
			_dauer = 0.0
			_lang = false
		elif _gedrueckt:
			_gedrueckt = false
			if _lang:
				_lang = false
				lang_losgelassen.emit()
			elif event.global_position.distance_to(_druck_pos) < 24.0:
				karte.stossen(0.1)
				chosen.emit(card)
			accept_event()
	elif event is InputEventMouseMotion:
		karte.zeiger_setzen(event.global_position)
		if _lang:
			lang_bewegt.emit(event.global_position)
		elif _gedrueckt and event.global_position.distance_to(_druck_pos) > 24.0:
			_gedrueckt = false


func _process(delta: float) -> void:
	karte.ziel_position = size * 0.5
	if _gedrueckt and not _lang:
		_dauer += delta
		if _dauer >= LANG:
			_lang = true
			lange_gedrueckt.emit(karte, _druck_pos)
