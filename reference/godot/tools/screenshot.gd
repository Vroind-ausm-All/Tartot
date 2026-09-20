# Macht Bildschirmfotos der UI, damit man das Layout ohne Geraet pruefen kann.
#   xvfb-run -a godot --path . --script tools/screenshot.gd --resolution 540x960
extends SceneTree

var _frame: int = 0
var _schritt: int = 0
var _wurzel: Control
var _ziel: String = "/tmp/tartot_shots"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(_ziel)
	var szene: PackedScene = load("res://ui/scenes/main.tscn")
	_wurzel = szene.instantiate()
	root.add_child(_wurzel)
	print("Screenshots nach ", _ziel)

func _process(_delta: float) -> bool:
	_frame += 1
	# Erst ein paar Bilder Ruhe, damit das Layout sitzt.
	if _frame % 12 != 0:
		return false
	match _schritt:
		0: _foto("01_deuterwahl")
		1: _druecke_erstes_mit("DIE WAHRSAGERIN")
		2: _foto("02_wegwahl")
		3:
			# Der Weg ist zufaellig - so lange weiterklicken, bis ein Kampf kommt.
			if _finde_kampfschirm(root) == null:
				if not _druecke_erstes_mit("KAMPF", true):
					_druecke_irgendeinen()
				_schritt -= 1
		4: _foto("03_kampf_leer")
		5: _karte_legen()
		6: _foto("04_legung")
		7: _druecke_erstes_mit("SCHICKSAL AUSFUEHREN")
		8: _foto("05_nach_ausfuehren")
		9: _karte_legen()
		10: _druecke_erstes_mit("SCHICKSAL AUSFUEHREN")
		11: _foto("06_zweiter_zug")
		_:
			print("Fertig.")
			return true
	_schritt += 1
	return false

func _foto(name: String) -> void:
	var bild: Image = root.get_texture().get_image()
	var pfad: String = "%s/%s.png" % [_ziel, name]
	bild.save_png(pfad)
	print("  ", pfad, "  ", bild.get_width(), "x", bild.get_height())

func _alle(knoten: Node, treffer: Array) -> void:
	if knoten is Button:
		treffer.append(knoten)
	for k in knoten.get_children():
		_alle(k, treffer)

func _druecke_erstes_mit(text: String, praefix: bool = false) -> bool:
	var knoepfe: Array = []
	_alle(root, knoepfe)
	for b in knoepfe:
		var t: String = String(b.text).to_upper()
		if (t.begins_with(text) if praefix else t.contains(text)) and not b.disabled:
			print("  druecke: ", String(b.text).split("\n")[0])
			b.pressed.emit()
			return true
	return false

func _druecke_irgendeinen() -> void:
	var knoepfe: Array = []
	_alle(root, knoepfe)
	for b in knoepfe:
		if not b.disabled:
			print("  weiter: ", String(b.text).split("\n")[0])
			b.pressed.emit()
			return

func _karte_legen() -> void:
	var schirm: Node = _finde_kampfschirm(root)
	if schirm == null:
		return
	var kf: Kampf = schirm.kampf
	var frei: Array[int] = kf.positionen_frei()
	var i: int = 0
	for pos in frei:
		if i >= kf.stapel.hand.size() or kf.legungen_uebrig() <= 0:
			break
		kf.legen(kf.stapel.hand[0], pos)
		i += 1
	schirm.auffrischen()
	print("  gelegt: %d Karten" % i)

func _finde_kampfschirm(knoten: Node) -> Node:
	if knoten is Kampfschirm:
		return knoten
	for k in knoten.get_children():
		var t: Node = _finde_kampfschirm(k)
		if t != null:
			return t
	return null
