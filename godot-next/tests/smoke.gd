extends SceneTree
## Rauchtest: laedt den Katalog, spielt einen Kampf und prueft dabei, dass
## wirklich Zuege aufgeloest werden. Jeder Fehlschlag beendet mit Code 1.

var _fehler := 0

func _check(bedingung: bool, text: String) -> void:
	if not bedingung:
		_fehler += 1
		push_error("SMOKE FEHLGESCHLAGEN: " + text)

func _init() -> void:
	var katalog := Katalog.new()
	_check(katalog.cards.size() == 78, "78 Karten erwartet")
	_check(katalog.charms.size() == 50, "50 Charms erwartet")
	_check(katalog.items.size() == 22, "22 Items erwartet")
	_check(katalog.deuters.size() == 4, "4 Deuter erwartet")
	_check(katalog.events.size() == 18, "18 Ereignisse erwartet")
	var meta := Meta.new()
	var run := Run.create(katalog, meta, "wahrsagerin", 0, 1337)
	_check(run.deck.size() == 10, "Startdeck 10 Karten")
	_check(run.upcoming_bosses.size() == 3, "drei geplante Bosse")
	run.start_combat(false)
	_check(run.combat != null, "Kampf gestartet")
	_check(run.combat.hand.size() > 0, "Hand gezogen")
	var hp_start := run.combat.enemy_hp
	var zuege := 0
	for _turn in range(12):
		if run.combat.player_won or run.combat.player_lost:
			break
		while run.combat.slots.size() < 3 and not run.combat.hand.is_empty():
			var card: Karte = run.combat.hand[0]
			var pos := run.combat.slots.size()
			if not run.combat.place(card, pos):
				break
		if run.combat.can_resolve():
			var score: Dictionary = run.combat.resolve()
			_check(not score.is_empty(), "resolve liefert eine Wertung")
			zuege += 1
	_check(zuege > 0, "mindestens ein Zug aufgeloest")
	_check(run.combat.enemy_hp < hp_start or run.combat.enemy_sigils < int(run.combat.enemy_def.get("sigils", 0)) or run.combat.player_won, "Gegner hat Schaden genommen")
	print("TARTOT smoke: cards=%d charms=%d enemies=%d zuege=%d turn=%d hp=%d gegner=%d fehler=%d" % [katalog.cards.size(), katalog.charms.size(), katalog.enemies.size(), zuege, run.combat.turn, run.hp, run.combat.enemy_hp, _fehler])
	quit(1 if _fehler > 0 else 0)
