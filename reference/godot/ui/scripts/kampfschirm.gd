# Der Kampfschirm im Hochformat.
#
# Aufbau von oben nach unten, bewusst nur vier Zonen:
#   1. Gegner mit HP und naechstem Zug - mehr steht dort nicht
#   2. Spielerleiste: HP, Schild, Schicksalsfaeden, Charms als Symbole
#   3. Die Legung: Vergangenheit, Gegenwart, Zukunft
#   4. Die Hand plus SCHICKSAL AUSFUEHREN
#
# Alles Weitere (Charmtexte, Protokoll) oeffnet sich erst auf Tipp. Der Kampf
# bleibt sauber, die Komplexitaet liegt darunter.
extends Control
class_name Kampfschirm

const Konst := preload("res://core/konst.gd")

signal kampf_vorbei(gewonnen: bool)

var kampf: Kampf
var katalog: Katalog

var _gegner_box: VBoxContainer
var _spielerleiste: HBoxContainer
var _charmleiste: HBoxContainer
var _slots: Dictionary = {}          # Pos -> PanelContainer
var _slot_inhalt: Dictionary = {}    # Pos -> Kartenblatt
var _handbox: HBoxContainer
var _knopf: Button
var _protokoll: Label
var _gewaehlt: Kartenblatt = null
var _faden_leiste: HBoxContainer

func _init(p_kampf: Kampf, p_katalog: Katalog) -> void:
	kampf = p_kampf
	katalog = p_katalog
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	var hintergrund := ColorRect.new()
	hintergrund.color = Thema.TIEF
	hintergrund.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hintergrund)

	var wurzel := VBoxContainer.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.add_theme_constant_override("separation", 14)
	wurzel.offset_left = 24
	wurzel.offset_right = -24
	wurzel.offset_top = 24
	wurzel.offset_bottom = -24
	add_child(wurzel)

	_gegner_box = VBoxContainer.new()
	_gegner_box.add_theme_constant_override("separation", 6)
	wurzel.add_child(_gegner_box)

	_spielerleiste = HBoxContainer.new()
	_spielerleiste.add_theme_constant_override("separation", 20)
	wurzel.add_child(_spielerleiste)

	_faden_leiste = HBoxContainer.new()
	_faden_leiste.add_theme_constant_override("separation", 6)
	wurzel.add_child(_faden_leiste)

	_charmleiste = HBoxContainer.new()
	_charmleiste.add_theme_constant_override("separation", 12)
	wurzel.add_child(_charmleiste)

	# Der Luftraum liegt zwischen Charmleiste und Legung, nicht im Gegnerblock -
	# sonst zerquetscht der Gegnerblock die Leisten darunter.
	var luft := Control.new()
	luft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wurzel.add_child(luft)

	wurzel.add_child(_trennlinie())

	var legung := HBoxContainer.new()
	legung.add_theme_constant_override("separation", 12)
	legung.alignment = BoxContainer.ALIGNMENT_CENTER
	wurzel.add_child(legung)
	for pos in [Konst.Pos.VERGANGENHEIT, Konst.Pos.GEGENWART, Konst.Pos.ZUKUNFT]:
		legung.add_child(_slot_bauen(pos))

	_protokoll = Thema.label("", 22, Thema.GRAU, HORIZONTAL_ALIGNMENT_CENTER, true)
	_protokoll.custom_minimum_size.y = 64
	wurzel.add_child(_protokoll)

	wurzel.add_child(_trennlinie())

	_handbox = HBoxContainer.new()
	_handbox.add_theme_constant_override("separation", 8)
	_handbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wurzel.add_child(_handbox)

	_knopf = Button.new()
	_knopf.text = "SCHICKSAL AUSFUEHREN"
	_knopf.add_theme_font_size_override("font_size", 34)
	_knopf.add_theme_color_override("font_color", Thema.SCHWARZ)
	_knopf.add_theme_stylebox_override("normal", Thema.knopf_stil(Thema.OCKER, Thema.OCKER_HELL))
	_knopf.add_theme_stylebox_override("hover", Thema.knopf_stil(Thema.OCKER_HELL, Thema.ELFENBEIN))
	_knopf.add_theme_stylebox_override("pressed", Thema.knopf_stil(Thema.OCKER_HELL, Thema.ELFENBEIN))
	_knopf.pressed.connect(_ausfuehren)
	wurzel.add_child(_knopf)

	auffrischen()

func _trennlinie() -> Control:
	var c := ColorRect.new()
	c.color = Thema.GRAU
	c.custom_minimum_size.y = 1
	return c

func _slot_bauen(pos: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(300, 300)
	p.add_theme_stylebox_override("panel", Thema.rahmen(Thema.GRAU, 2, Thema.SCHWARZ, 8))
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(box)
	var titel := Thema.label(Konst.POS_NAME[pos].to_upper(), 20, Thema.OCKER)
	box.add_child(titel)
	var inhalt := CenterContainer.new()
	inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inhalt.name = "Inhalt"
	box.add_child(inhalt)
	_slots[pos] = p
	p.gui_input.connect(_slot_angetippt.bind(pos))
	return p

# -------------------------------------------------------------- Interaktion
func _slot_angetippt(ereignis: InputEvent, pos: int) -> void:
	var tipp: bool = (ereignis is InputEventMouseButton and ereignis.pressed) \
		or (ereignis is InputEventScreenTouch and ereignis.pressed)
	if not tipp:
		return
	if kampf.legung.has(pos):
		kampf.zurueckziehen(pos)
		_gewaehlt = null
		auffrischen()
		return
	if _gewaehlt == null:
		return
	if kampf.legen(_gewaehlt.karte, pos):
		_gewaehlt = null
		auffrischen()

func _hand_angetippt(blatt: Kartenblatt) -> void:
	if _gewaehlt == blatt:
		_gewaehlt = null
	else:
		_gewaehlt = blatt
	auffrischen()

func _ausfuehren() -> void:
	if kampf.vorbei():
		return
	var vorher: int = kampf.log.size()
	kampf.ausfuehren()
	_gewaehlt = null
	auffrischen()
	var neu: Array[String] = []
	for i in range(vorher, kampf.log.size()):
		neu.append(kampf.log[i])
	_protokoll.text = "\n".join(neu.slice(maxi(0, neu.size() - 2)))
	if kampf.vorbei():
		_knopf.text = "SIEG" if kampf.gewonnen() else "GEFALLEN"
		_knopf.disabled = true
		kampf_vorbei.emit(kampf.gewonnen())

# ------------------------------------------------------------- Darstellung
func auffrischen() -> void:
	_gegner_zeichnen()
	_spieler_zeichnen()
	_faeden_zeichnen()
	_charms_zeichnen()
	_legung_zeichnen()
	_hand_zeichnen()

func _gegner_zeichnen() -> void:
	for kind in _gegner_box.get_children():
		kind.queue_free()
	for i in kampf.gegner.size():
		var g: Kaempfer = kampf.gegner[i]
		if g.tot:
			continue
		# Platzhalter fuer die animierte Cartoon-Silhouette.
		var silhouette := Thema.label("▲", 92, Thema.ELFENBEIN)
		_gegner_box.add_child(silhouette)
		_gegner_box.add_child(Thema.label(g.name.to_upper(), 34, Thema.ELFENBEIN))
		_gegner_box.add_child(Thema.label("%d / %d HP" % [g.hp, g.hp_max], 30, Thema.BLUT))
		_gegner_box.add_child(Thema.label("Naechster Zug: %s" % kampf.absicht_text(i), 26, Thema.OCKER))
		var st: String = g.status_text()
		if st != "":
			_gegner_box.add_child(Thema.label(st, 22, Thema.GRAU))

func _spieler_zeichnen() -> void:
	for kind in _spielerleiste.get_children():
		kind.queue_free()
	var s: Kaempfer = kampf.spieler
	_spielerleiste.add_child(Thema.label("%d/%d HP" % [s.hp, s.hp_max], 30, Thema.ELFENBEIN))
	_spielerleiste.add_child(Thema.label("%d Schild" % s.stapel(Konst.St.SCHILD), 30, Thema.INDIGO_HELL))
	_spielerleiste.add_child(Thema.label("Runde %d" % kampf.runde, 26, Thema.GRAU))
	var st: String = s.status_text()
	if st != "":
		_spielerleiste.add_child(Thema.label(st, 22, Thema.GRAU))

func _faeden_zeichnen() -> void:
	for kind in _faden_leiste.get_children():
		kind.queue_free()
	_faden_leiste.add_child(Thema.label("Schicksal", 24, Thema.GRAU))
	for i in Konst.FADEN_MAX:
		var punkt := Thema.label("●" if i < kampf.faden else "○", 28,
			Thema.OCKER if i < kampf.faden else Thema.GRAU)
		_faden_leiste.add_child(punkt)

func _charms_zeichnen() -> void:
	for kind in _charmleiste.get_children():
		kind.queue_free()
	for eintrag in kampf.charms.leiste():
		var knopf := Button.new()
		knopf.text = "%s x%d" % [String(eintrag["name"]).substr(0, 10), int(eintrag["n"])]
		knopf.add_theme_font_size_override("font_size", 20)
		knopf.add_theme_color_override("font_color",
			Thema.seltenheitsfarbe(String(eintrag["selten"])))
		knopf.flat = true
		knopf.tooltip_text = String(eintrag["text"])
		# Tippen zeigt den vollen Text - im Kampf steht nur Name und Anzahl.
		var beschreibung: String = "%s x%d: %s" % [
			String(eintrag["name"]), int(eintrag["n"]), String(eintrag["text"])]
		knopf.pressed.connect(_charm_erklaeren.bind(beschreibung))
		_charmleiste.add_child(knopf)

func _charm_erklaeren(text: String) -> void:
	_protokoll.text = text

func _legung_zeichnen() -> void:
	for pos in _slots.keys():
		var p: PanelContainer = _slots[pos]
		var inhalt: CenterContainer = p.get_node("Box/Inhalt")
		for kind in inhalt.get_children():
			kind.queue_free()
		var gesperrt: bool = kampf.gesperrte_positionen.has(pos)
		var rand: Color = Thema.BLUT if gesperrt else (
			Thema.OCKER if kampf.legung.has(pos) else Thema.GRAU)
		p.add_theme_stylebox_override("panel", Thema.rahmen(rand, 2, Thema.SCHWARZ, 8))
		if gesperrt:
			inhalt.add_child(Thema.label("ZERSTOERT", 22, Thema.BLUT))
		elif kampf.legung.has(pos):
			var blatt := Kartenblatt.new(kampf.legung[pos], katalog, 150.0)
			inhalt.add_child(blatt)

func _hand_zeichnen() -> void:
	for kind in _handbox.get_children():
		kind.queue_free()
	for k in kampf.stapel.hand:
		var blatt := Kartenblatt.new(k, katalog, 186.0)
		blatt.angetippt.connect(_hand_angetippt)
		blatt.gewaehlt = (_gewaehlt != null and _gewaehlt.karte == k)
		_handbox.add_child(blatt)
