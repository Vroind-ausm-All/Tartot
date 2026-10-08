extends SceneTree
## Rauchtest des GDScript-Kerns. Jeder Fehlschlag beendet mit Code 1.
##
##   godot --headless --path godot-next --script res://tests/smoke.gd
##
## Prueft Kataloge, den bekannten Zufallsvektor des C#-Kerns, einen
## kompletten Autopilot-Run, Speichern/Laden mitten im Kampf und die
## Meta-Verbuchung. Die volle Gleichheit mit C# beweist tools/paritaet.sh.

var _fehler := 0

func _check(bedingung: bool, text: String) -> void:
	if not bedingung:
		_fehler += 1
		push_error("SMOKE FEHLGESCHLAGEN: " + text)

func _init() -> void:
	# Kataloge
	_check(GameCatalog.cards().size() == 78, "78 Karten erwartet")
	_check(GameCatalog.charms().size() == 50, "50 Charms erwartet")
	_check(GameCatalog.items().size() == 22, "22 Items erwartet")
	_check(DeuterCatalog.all().size() == 4, "4 Deuter erwartet")
	_check(EventCatalog.all().size() == 18, "18 Ereignisse erwartet")
	_check(ProphecyCatalog.all().size() == 19, "19 Prophezeiungen erwartet")
	_check(ActCatalog.bosses().size() == 8, "8 Bosse erwartet")
	_check(ActCatalog.finales().size() == 2, "2 Finale erwartet")

	# Bekannter Vektor aus DeterministicRandomTests.cs
	var r := DeterministicRandom.new(1)
	var v: Array[int] = []
	for i in 8:
		v.append(r.next_int(1000))
	_check(v == [199, 446, 908, 995, 314, 408, 749, 110], "PCG32-Vektor wie C#: %s" % str(v))

	# Ein Kampf von Hand: legen, aufloesen, Schaden
	var game := GameController.new(1337)
	_check(game.run.deck.size() == 10, "Startdeck 10 Karten")
	_check(game.run.act_bosses.size() == 4, "drei Aktbosse und ein Finale geplant")
	_check(game.phase == Enums.GamePhase.COMBAT and game.combat != null, "Kampf gestartet")
	_check(game.combat.hand.size() > 0, "Hand gezogen")
	var hp_start := game.combat.enemy.hp
	var pilot := Autopilot.new()
	_check(pilot.arrange(game), "Legung gefunden")
	_check(game.preview_score() != null, "Vorschau vorhanden")
	var turn := game.resolve_turn()
	_check(turn != null and turn.score != null, "Zug aufgeloest")
	_check(game.combat.enemy.hp < hp_start or turn.victory, "Gegner hat Schaden genommen")

	# Speichern und Laden mitten im Kampf: gleicher Folgezug
	var text := game.save()
	var restored := GameController.restore(SaveSystem.deserialize(text))
	_check(restored.save() == text, "Speicherstand stabil nach Laden")
	pilot.arrange(game)
	pilot.arrange(restored)
	var a := game.resolve_turn()
	var b := restored.resolve_turn()
	_check(a.fate_damage == b.fate_damage and game.combat.enemy.hp == restored.combat.enemy.hp, "geladenes Spiel zieht gleich weiter")

	# Ein ganzer Run und seine Verbuchung
	var outcome := pilot.play_run(7, 30)
	_check(outcome.fights_cleared > 0, "Autopilot kommt voran")
	_check(outcome.signature() == pilot.play_run(7, 30).signature(), "gleicher Seed, gleicher Run")
	var meta := MetaProgress.new()
	var report := meta.complete_run(pilot.last_game, outcome.won, outcome.died_against)
	_check(meta.runs_started == 1, "Run verbucht")
	_check(meta.completed_prophecies.has("erste_lesung"), "erste Prophezeiung erfuellt")
	_check(report.headline != "", "Bericht hat eine Ueberschrift")
	var meta2 := MetaProgress.deserialize(meta.serialize())
	_check(meta2.serialize() == meta.serialize(), "Meta-Fortschritt stabil nach Laden")

	print("TARTOT smoke: karten=%d charms=%d items=%d ereignisse=%d run=%s fehler=%d" % [
		GameCatalog.cards().size(), GameCatalog.charms().size(), GameCatalog.items().size(),
		EventCatalog.all().size(), outcome.signature(), _fehler])
	quit(1 if _fehler > 0 else 0)
