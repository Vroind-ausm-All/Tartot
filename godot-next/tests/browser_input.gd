extends Node
## Regressionstest: Der Vollbild-UI-Container darf Maus-/Touch-Events nicht
## schlucken. Im Kampf verarbeitet KartenTisch sie via _unhandled_input.
##   godot --headless --path godot-next res://tests/browser_input.tscn

var _errors := 0

func _check(ok: bool, reason: String) -> void:
	if not ok:
		_errors += 1
		push_error("WEB INPUT: " + reason)

func _ready() -> void:
	var spiel: Node = get_tree().root.get_node("Spiel")
	spiel.use_test_storage()
	var main: Control = load("res://ui/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Main darf keine Klicks abfangen")

	spiel.new_run(RunSetup.new(), 1337)
	main.show_current()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(main.current is Kampftisch, "Kampftisch muss nach RUN BEGINNEN erscheinen")
	if main.current is Kampftisch:
		var tisch: KartenTisch = (main.current as Kampftisch)._tisch
		_check(tisch != null, "KartenTisch existiert")
		if tisch != null:
			# In der Mitte der Hand, ausserhalb der GUI-Knoepfe.
			var mouse_pos := Vector2(540, 1468)
			var down := InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			down.position = mouse_pos
			down.global_position = mouse_pos
			get_viewport().push_input(down, false)
			await get_tree().process_frame
			_check(tisch._gedrueckt, "Mausdruck kommt bei KartenTisch an")
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			up.position = mouse_pos
			up.global_position = mouse_pos
			get_viewport().push_input(up, false)
			await get_tree().process_frame
			_check(not tisch._gedrueckt, "Maus loslassen kommt bei KartenTisch an")

	spiel.abandon_to_title()
	print("Browser-Input-Test: %s (%d Fehler)" % ["OK" if _errors == 0 else "FEHLER", _errors])
	get_tree().quit(1 if _errors > 0 else 0)
