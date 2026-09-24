extends SceneTree

func _init() -> void:
	var katalog := Katalog.new()
	assert(katalog.cards.size() == 78, "78 Karten erwartet")
	assert(katalog.charms.size() == 50, "50 Charms erwartet")
	assert(katalog.items.size() == 22, "22 Items erwartet")
	assert(katalog.deuters.size() == 4, "4 Deuter erwartet")
	assert(katalog.events.size() == 18, "18 Ereignisse erwartet")
	var meta := Meta.new()
	var run := Run.create(katalog, meta, "wahrsagerin", 0, 1337)
	assert(run.deck.size() == 10)
	assert(run.upcoming_bosses.size() == 3)
	run.start_combat(false)
	assert(run.combat != null)
	assert(run.combat.hand.size() > 0)
	for _turn in range(8):
		if run.combat.player_won or run.combat.player_lost:
			break
		while run.combat.slots.size() < 3 and not run.combat.hand.is_empty():
			var card: Karte = run.combat.hand[0]
			var pos := run.combat.slots.size()
			if not run.combat.place(card, pos):
				break
		if run.combat.can_resolve():
			run.combat.resolve()
	assert(run.combat.turn >= 1)
	print("TARTOT smoke: cards=%d charms=%d enemies=%d turn=%d hp=%d" % [katalog.cards.size(), katalog.charms.size(), katalog.enemies.size(), run.combat.turn, run.hp])
	quit(0)
