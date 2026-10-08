extends RefCounted
class_name EventCatalog
## Alle Ereignisse (Content/Events.cs). Reihenfolge, Gewichte und jeder
## Zufallszug wie in C# - die Ereigniswahl laeuft ueber den Welt-Strom.

const SH := Enums.Shimmer

static var _all: Array[EventDefinition] = []

static func all() -> Array[EventDefinition]:
	if _all.is_empty():
		_build()
	return _all

static func find(id: String) -> EventDefinition:
	for e in all():
		if e.id == id:
			return e
	return null

# ------------------------------------------------------------- Helfer
static func strength(card: CardInstance) -> int:
	return card.shimmer * 6 + card.level * 3 + card.definition.rank + (6 if card.definition.is_major() else 0)

## Erste Karte mit der hoechsten Staerke (OrderByDescending(...).FirstOrDefault()).
static func strongest(run: RunState) -> CardInstance:
	return Num.groesstes(run.deck, func(c: CardInstance) -> int: return strength(c))

## Erste Karte mit der niedrigsten Staerke.
static func weakest(run: RunState) -> CardInstance:
	return Num.kleinstes(run.deck, func(c: CardInstance) -> int: return strength(c))

static func _can_thin(run: RunState, count: int) -> bool:
	return run.deck.size() - count >= GameCatalog.MINIMUM_DECK_SIZE

static func _remove(run: RunState, card: CardInstance) -> void:
	if card == null or not run.deck.has(card):
		return
	run.deck.erase(card)
	run.removed_cards.append(card)

static func _add(run: RunState, definition: CardDefinition, level := 1, shimmer := SH.MATTE,
		orientation := Enums.Orientation.UPRIGHT, copy := false) -> CardInstance:
	var card := CardInstance.new(definition, copy)
	card.level = maxi(1, level)
	card.shimmer = shimmer
	card.orientation = orientation
	run.deck.append(card)
	note_shimmer(run, card)
	return card

## Eine Stufe dunkler - auch ueber Gold hinaus, bis Schwarz.
static func darken(run: RunState, card: CardInstance) -> void:
	if card == null:
		return
	if card.shimmer < SH.BLACK:
		card.shimmer += 1
	note_shimmer(run, card)

static func note_shimmer(run: RunState, card: CardInstance) -> void:
	if card != null:
		run.stats.darkest_shimmer = maxi(run.stats.darkest_shimmer, card.shimmer)
	var black := 0
	for c in run.deck:
		if c.shimmer == SH.BLACK:
			black += 1
	run.stats.most_black_cards = maxi(run.stats.most_black_cards, black)

static func _hurt(run: RunState, amount: int) -> void:
	run.hp = maxi(1, run.hp - amount)

static func _heal(run: RunState, amount: int) -> int:
	var before := run.hp
	run.hp = mini(run.max_hp, run.hp + maxi(0, amount))
	return run.hp - before

static func _random_charm(ctx: EventContext) -> CharmDefinition:
	var options: Array = []
	for c in GameCatalog.charms():
		if ctx.run.charm_allowed(c.id) and ctx.run.charm_stacks(c.id) < c.max_stacks:
			options.append(c)
	return null if options.is_empty() else ctx.rng.pick(options)

static func _give_random_charm(ctx: EventContext, fallback: String) -> String:
	var charm := _random_charm(ctx)
	if charm == null:
		ctx.run.fate += 40
		return fallback + " (+40 Fate)"
	ctx.run.add_charm(charm)
	return "Du erhältst %s." % charm.name

static func _give_random_item(ctx: EventContext) -> String:
	var item: ItemDefinition = ctx.rng.pick(GameCatalog.items())
	ctx.run.add_item(item)
	return "Du erhältst %s." % item.name

static func _random_major(ctx: EventContext) -> CardDefinition:
	var majors: Array = []
	for c in GameCatalog.cards():
		if c.is_major():
			majors.append(c)
	return ctx.rng.pick(majors)

static func _name_of(card: CardInstance) -> String:
	return "" if card == null else card.definition.name

static func _leave(epilogue: String) -> EventChoice:
	return _choice("Weitergehen", "Nichts geschieht.", func(_ctx: EventContext) -> String: return epilogue)

static func _choice(label: String, hint: String, resolve: Callable, available: Callable = Callable()) -> EventChoice:
	var c := EventChoice.new()
	c.label = label
	c.hint = hint
	c.resolve = resolve
	if available.is_valid():
		c.available = available
	return c

static func _event(id: String, title: String, art: String, beats: Array[String], choices: Array[EventChoice],
		opts: Dictionary = {}) -> EventDefinition:
	var e := EventDefinition.new()
	e.id = id
	e.title = title
	e.art = art
	e.beats = beats
	e.choices = choices
	e.min_act = int(opts.get("min_act", 1))
	e.max_act = int(opts.get("max_act", 4))
	e.min_darkness = int(opts.get("min_darkness", 0))
	e.requires_flag = String(opts.get("requires", ""))
	e.excludes_flag = String(opts.get("excludes", ""))
	e.weight = Num.f(float(opts.get("weight", 1.0)))
	if opts.has("dark"):
		e.dark_beats.assign(opts["dark"])
	if opts.has("condition"):
		e.condition = opts["condition"]
	if opts.has("dynamic"):
		e.dynamic_beats = opts["dynamic"]
	_all.append(e)
	return e

# ------------------------------------------------------------ Katalog
static func _build() -> void:
	# ============ Geschichte I: Der Kartenspieler (ueber Runs) ============
	_event("kartenspieler_1", "Der Kartenspieler am Kreuzweg", "kartenspieler", [
		"Mitten auf dem Weg steht ein Tisch. Ein Stuhl fehlt – deiner.",
		"Der Mann dahinter mischt ein Deck, das deinem sehr ähnlich sieht.",
		"„Eine Karte“, sagt er. „Die höhere gewinnt.“"
	], [
		_choice("Setze 30 Gold", "Hälfte-Hälfte: +50 Gold oder −30 Gold.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_1")
			if ctx.rng.chance(0.5):
				ctx.run.gold += 50
				return "Er zahlt, ohne hinzusehen. „Glück ist auch eine Fähigkeit.“"
			ctx.run.gold -= 30
			return "Er lächelt, als hätte er es vorher gewusst.",
			func(run: RunState) -> bool: return run.gold >= 30),
		_choice("Setze deine schwächste Karte", "Hälfte-Hälfte: ein Großes Arkanum – oder die Karte ist fort.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_1")
			if ctx.rng.chance(0.5):
				var major := _random_major(ctx)
				_add(ctx.run, major)
				return "Er schiebt dir %s über den Tisch. Die Karte ist noch warm." % major.name
			var lost := weakest(ctx.run)
			_remove(ctx.run, lost)
			return "%s verschwindet in seinem Deck. Es sah aus, als gehöre sie dorthin." % _name_of(lost),
			func(run: RunState) -> bool: return _can_thin(run, 1)),
		_choice("Geh vorbei", "Nichts geschieht. Vorerst.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_1")
			return "Er ruft dir nach: „Wir sehen uns wieder. Das tun wir immer.“")
	], {"max_act": 2, "excludes": "spieler_1", "weight": 2.0})

	_event("kartenspieler_2", "Der Kartenspieler erinnert sich", "kartenspieler", [
		"Derselbe Tisch. Diesmal steht ein zweiter Stuhl da.",
		"„Du hast letztes Mal gezögert“, sagt er. Er hat recht, und das beunruhigt dich.",
		"Er legt drei Karten verdeckt hin. Eine davon trägt dein Gesicht."
	], [
		_choice("Zieh die mittlere", "Ein Drittel: deine stärkste Karte steigt 2 Stufen. Sonst −12 HP.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_2")
			if ctx.rng.chance(Num.dv(1.0, 3.0)):
				var best := strongest(ctx.run)
				if best != null:
					best.level += 2
				return "Dein Gesicht. %s fühlt sich schwerer an." % _name_of(best)
			_hurt(ctx.run, 12)
			return "Eine leere Karte. Sie schneidet dir in den Finger, als du sie zurücklegst."),
		_choice("Zieh alle drei", "Sicher: +1 Luck für den Run, +8 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_2")
			ctx.run.luck += 1
			ctx.run.add_darkness(8)
			return "„Gier ist auch eine Antwort“, sagt er und schreibt etwas auf."),
		_choice("Steh auf und geh", "+25 Fate.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_2")
			ctx.run.fate += 25
			return "Er nickt, als hättest du richtig gewählt.")
	], {"min_act": 2, "max_act": 3, "requires": "spieler_1", "excludes": "spieler_2", "weight": 3.0})

	_event("kartenspieler_3", "Der Kartenspieler zeigt sein Blatt", "kartenspieler", [
		"Der Tisch steht jetzt in einem leeren Saal. Der Mann trägt deinen Mantel.",
		"Er dreht seine Karten um. Es sind deine – mit jedem Schimmer, den du ihnen gegeben hast.",
		"„Ich bin, was bleibt, wenn du aufhörst zu spielen.“"
	], [
		_choice("Fordere ihn heraus", "Der nächste Kampf gilt ihm. Sieg: eine Charm-Belohnung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_3")
			ctx.run.pending_enemy_id = "kartenspieler"
			ctx.run.next_fight_elite = true
			return "Er mischt. Zum ersten Mal sieht er dir in die Augen.",
			func(run: RunState) -> bool: return not ActCatalog.is_boss_fight(run.fight_index + 1) and not ActCatalog.is_finale(run.fight_index + 1)),
		_choice("Lass ihn gewinnen", "Radmarke und 60 Fate.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("spieler_3")
			ctx.run.add_item(GameCatalog.item("wheel_token"))
			ctx.run.fate += 60
			return "Er steckt das Deck ein. „Bis zum nächsten Mal. Es gibt immer ein nächstes Mal.“")
	], {"min_act": 3, "max_act": 3, "requires": "spieler_2", "excludes": "spieler_3", "weight": 4.0})

	# ============ Geschichte II: Die Tinte (ueber Runs) ============
	_event("tinte_1", "Das Tintenfass", "tintenfass", [
		"Ein Tintenfass am Wegrand, randvoll, obwohl es regnet.",
		"Etwas darin atmet. Die Oberfläche hebt und senkt sich."
	], [
		_choice("Tauche deine stärkste Karte ein", "Sie springt auf Blutschimmer. +8 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("tinte_1")
			var best := strongest(ctx.run)
			if best != null and best.shimmer < SH.BLOOD:
				best.shimmer = SH.BLOOD
			note_shimmer(ctx.run, best)
			ctx.run.add_darkness(8)
			return "%s kommt rot heraus. Die Tinte im Fass ist ein wenig weniger geworden." % _name_of(best)),
		_choice("Verschließe es", "+40 Fate.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("tinte_1")
			ctx.run.fate += 40
			return "Der Deckel klemmt. Von innen klopft es, zweimal.")
	], {"min_darkness": 20, "excludes": "tinte_1", "weight": 2.0})

	_event("tinte_2", "Die Schreiber", "schreiber", [
		"In einem Saal ohne Fenster sitzen Schreiber und kopieren dein Deck.",
		"Jede Karte, die sie abschreiben, verblasst ein wenig in deiner Hand.",
		"Die Abschriften sind schwärzer als die Originale."
	], [
		_choice("Lass sie schreiben", "Zwei zufällige Karten werden kopiert – mit Blutschimmer. +10 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("tinte_2")
			var picks := ctx.rng.pick_distinct(ctx.run.deck, 2)
			for card: CardInstance in picks:
				_add(ctx.run, card.definition, card.level, SH.BLOOD, card.orientation, true)
			ctx.run.add_darkness(10)
			return "Sie reichen dir die Abschriften, ohne aufzusehen. Die Tinte ist noch nass.",
			func(run: RunState) -> bool: return run.deck.size() >= 2),
		_choice("Verbrenne die Abschriften", "Glutknoten, −5 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("tinte_2")
			var ember := GameCatalog.charm("ember_knot")
			if ctx.run.charm_stacks(ember.id) < ember.max_stacks:
				ctx.run.add_charm(ember)
			ctx.run.add_darkness(-5)
			return "Das Papier brennt grün. Die Schreiber schreiben einfach weiter, jetzt auf den Tischen.")
	], {"min_act": 2, "min_darkness": 30, "requires": "tinte_1", "excludes": "tinte_2", "weight": 3.0})

	_event("tinte_3", "Das Schwarze Blatt", "schwarzes_blatt", [
		"Am Ende des Saals liegt ein einzelnes Blatt, schwärzer als die Nacht hinter dir.",
		"Es kennt deinen Namen. Es hat ihn schon unterschrieben.",
		"Nur eine Zeile ist noch frei."
	], [
		_choice("Unterschreibe", "Deine stärkste Karte wird schwarz. +15 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("tinte_3")
			var best := strongest(ctx.run)
			if best != null:
				best.shimmer = SH.BLACK
			note_shimmer(ctx.run, best)
			ctx.run.add_darkness(15)
			return "Die Tinte kriecht in %s. Du hörst sie denken." % _name_of(best)),
		_choice("Zerreiße es", "Heile vollständig, −10 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.set_story_flag("tinte_3")
			ctx.run.hp = ctx.run.max_hp
			ctx.run.add_darkness(-10)
			return "Es reißt wie Haut. Danach ist es sehr still, und du bist sehr wach.")
	], {"min_act": 3, "min_darkness": 40, "requires": "tinte_2", "excludes": "tinte_3", "weight": 4.0})

	# ============ Das Grab: der letzte Run liegt hier ============
	_event("grab", "Das Grab mit deinem Namen", "grab", [], [
		_choice("Grab es aus", "Die Karte kehrt zurück – Stufe 3, Indigo. +6 Verdunkelung.", func(ctx: EventContext) -> String:
			var definition := GameCatalog.card(ctx.run.grave_card_id)
			_add(ctx.run, definition, 3, SH.INDIGO)
			ctx.run.grave_card_id = ""
			ctx.run.add_darkness(6)
			return "%s ist kalt, aber sie erinnert sich an dich." % definition.name),
		_choice("Leg Blumen nieder", "Heile 15 HP, −6 Verdunkelung.", func(ctx: EventContext) -> String:
			_heal(ctx.run, 15)
			ctx.run.add_darkness(-6)
			ctx.run.grave_card_id = ""
			return "Die Blumen welken sofort. Trotzdem fühlst du dich leichter.")
	], {"weight": 2.0,
		"condition": func(run: RunState) -> bool: return run.grave_card_id != "" and GameCatalog.card(run.grave_card_id) != null,
		"dynamic": func(run: RunState) -> Array[String]: return [
			"Ein frisches Grab. Der Stein trägt deinen Namen und die Zahl %d." % run.grave_fight,
			"Darunter liegt ein Deck. Es riecht nach deinem letzten Run.",
			"Obenauf: %s." % GameCatalog.card(run.grave_card_id).name
		]})

	# ============ Einzelne Szenen ============
	_event("naeherin", "Die Näherin", "naeherin", [
		"Eine Frau sitzt auf einem Stapel Karten und näht sie aneinander.",
		"Ihre Finger sind aus Faden. Sie sieht nicht auf."
	], [
		_choice("Lass zwei Karten vernähen", "Deine zwei schwächsten Karten verschwinden, die stärkste steigt eine Stufe.", func(ctx: EventContext) -> String:
			_remove(ctx.run, weakest(ctx.run))
			_remove(ctx.run, weakest(ctx.run))
			var best := strongest(ctx.run)
			if best != null:
				best.level += 1
			return "Die Naht hält. %s trägt jetzt zwei fremde Ränder." % _name_of(best),
			func(run: RunState) -> bool: return _can_thin(run, 2)),
		_choice("Bitte um einen Faden", "Weißer Faden (+3 Schild zu Kampfbeginn).", func(ctx: EventContext) -> String:
			var thread := GameCatalog.charm("white_thread")
			if ctx.run.charm_stacks(thread.id) >= thread.max_stacks:
				ctx.run.fate += 30
				return "Sie hat keinen mehr für dich. (+30 Fate)"
			ctx.run.add_charm(thread)
			return "Sie beißt ihn ab und legt ihn dir in die Hand. Er ist warm."),
		_leave("Die Nadel hält kurz inne, als du gehst.")
	], {"dark": [
		"Eine Frau näht Karten aneinander. Diesmal näht sie mit deinem Haar.",
		"„Du bist dunkler geworden“, sagt sie, ohne aufzusehen. „Das hält besser.“"
	]})

	_event("spiegelkabinett", "Das Spiegelkabinett", "spiegel", [
		"Hundert Spiegel. In neunundneunzig bewegst du dich mit.",
		"In einem stehst du still und lächelst."
	], [
		_choice("Tritt in den stillen Spiegel", "Eine zufällige Karte deines Decks wird kopiert. +4 Verdunkelung.", func(ctx: EventContext) -> String:
			var card: CardInstance = ctx.rng.pick(ctx.run.deck)
			_add(ctx.run, card.definition, card.level, card.shimmer, card.orientation, true)
			ctx.run.add_darkness(4)
			return "Du kommst mit zwei %s heraus. Eine davon ist spiegelverkehrt signiert." % card.definition.name,
			func(run: RunState) -> bool: return run.deck.size() > 0),
		_choice("Zerschlag ihn", "+45 Gold, −8 HP.", func(ctx: EventContext) -> String:
			ctx.run.gold += 45
			_hurt(ctx.run, 8)
			return "Hinter dem Glas liegen Münzen. Und ein Zahn."),
		_leave("Hinter dir drehen sich neunundneunzig Spiegelbilder um.")
	])

	_event("leichenschmaus", "Der Leichenschmaus", "tafel", [
		"Eine lange Tafel im Nebel. Die Gäste sind satt, aber sie essen weiter.",
		"Ein Platz ist gedeckt. Die Serviette trägt deine Initialen."
	], [
		_choice("Iss mit", "Heile 40 % – eine zufällige aufrechte Karte kippt um.", func(ctx: EventContext) -> String:
			var healed := _heal(ctx.run, Num.rnd(Num.mul(ctx.run.max_hp, 0.40)))
			var upright: Array = []
			for c in ctx.run.deck:
				if c.orientation == Enums.Orientation.UPRIGHT:
					upright.append(c)
			if upright.is_empty():
				return "+%d HP. Es schmeckt nach nichts." % healed
			var flipped: CardInstance = ctx.rng.pick(upright)
			flipped.orientation = Enums.Orientation.REVERSED
			return "+%d HP. Als du aufstehst, liegt %s verkehrt herum." % [healed, flipped.definition.name]),
		_choice("Gib ihnen eine Karte", "Deine schwächste Karte geht, +4 Max-HP.", func(ctx: EventContext) -> String:
			var w := weakest(ctx.run)
			_remove(ctx.run, w)
			ctx.run.max_hp += 4
			ctx.run.hp += 4
			return "Sie essen %s mit Messer und Gabel. Höflich." % _name_of(w),
			func(run: RunState) -> bool: return _can_thin(run, 1)),
		_leave("Niemand bemerkt, dass du gehst. Dein Teller bleibt voll.")
	])

	_event("kinder_im_nebel", "Die Kinder im Nebel", "kinder", [
		"Sie spielen Tarot mit flachen Steinen. Keines der Kinder hat einen Schatten.",
		"„Spielst du mit?“, fragen sie alle gleichzeitig."
	], [
		_choice("Spiel mit", "+1 Luck für den Run, +5 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.luck += 1
			ctx.run.add_darkness(5)
			return "Du gewinnst. Sie freuen sich mehr als du."),
		_choice("Gib ihnen 20 Gold", "Ein zufälliges Item.", func(ctx: EventContext) -> String:
			ctx.run.gold -= 20
			return "Sie geben dir etwas zurück, das sie gefunden haben. " + _give_random_item(ctx),
			func(run: RunState) -> bool: return run.gold >= 20),
		_leave("Sie spielen weiter. Einer der Steine trägt jetzt dein Gesicht.")
	], {"min_darkness": 15})

	_event("uhrmacher", "Der Uhrmacher ohne Zeiger", "uhrmacher", [
		"„Ich kann dir Zeit geben“, sagt er. „Nicht viel. Deine.“",
		"Auf dem Tresen tickt eine Uhr ohne Zeiger."
	], [
		_choice("Tausche 8 Max-HP gegen Reife", "Deine stärkste Karte steigt eine Stufe und dunkelt nach. +5 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.max_hp -= 8
			ctx.run.hp = mini(ctx.run.hp, ctx.run.max_hp)
			var best := strongest(ctx.run)
			if best != null:
				best.level += 1
				darken(ctx.run, best)
			ctx.run.add_darkness(5)
			return "%s altert in deiner Hand. Du auch, ein wenig." % _name_of(best),
			func(run: RunState) -> bool: return run.max_hp > 30),
		_choice("Kaufe Ruhe", "35 Gold: heile 30 %.", func(ctx: EventContext) -> String:
			ctx.run.gold -= 35
			var healed := _heal(ctx.run, Num.rnd(Num.mul(ctx.run.max_hp, 0.30)))
			return "+%d HP. Die Uhr bleibt stehen, solange du schläfst." % healed,
			func(run: RunState) -> bool: return run.gold >= 35),
		_leave("Die Uhr tickt lauter, als du gehst.")
	], {"min_act": 2})

	_event("beichtstuhl", "Der Beichtstuhl", "beichtstuhl", [
		"Ein Beichtstuhl mitten auf einer Wiese. Die Tür steht offen.",
		"Durch das Gitter flüstert jemand deinen Namen – falsch betont."
	], [
		_choice("Beichte", "−12 Verdunkelung, −25 Gold.", func(ctx: EventContext) -> String:
			ctx.run.gold -= 25
			ctx.run.add_darkness(-12)
			return "Du erzählst alles. Er klingt enttäuscht, dass es so wenig war.",
			func(run: RunState) -> bool: return run.gold >= 25),
		_choice("Lüge", "+60 Fate, +10 Verdunkelung.", func(ctx: EventContext) -> String:
			ctx.run.fate += 60
			ctx.run.add_darkness(10)
			return "Er glaubt dir jedes Wort. Das ist das Schlimmste daran."),
		_leave("Das Flüstern hört auf. Du bist nicht sicher, ob das besser ist.")
	], {"dark": [
		"Ein Beichtstuhl mitten auf einer Wiese. Das Gras um ihn ist schwarz.",
		"Durch das Gitter flüstert jemand: „Du schon wieder.“"
	]})

	_event("brunnen", "Das Orakel im Brunnen", "brunnen", [
		"Tief unten spiegelt sich ein Gesicht, das nicht deins ist.",
		"Es bewegt die Lippen, sobald du dich vorbeugst."
	], [
		_choice("Hör zu", "Die nächsten zwei Belohnungen bieten eine Wahl mehr.", func(ctx: EventContext) -> String:
			ctx.run.bonus_reward_choices += 2
			return "Es flüstert Möglichkeiten. Zu viele, um sie alle zu behalten."),
		_choice("Wirf eine Münze", "10 Gold: ein Drittel für einen zufälligen Charm.", func(ctx: EventContext) -> String:
			ctx.run.gold -= 10
			if not ctx.rng.chance(Num.dv(1.0, 3.0)):
				return "Die Münze fällt lange. Du hörst sie nie aufschlagen."
			return "Etwas fliegt zurück nach oben. " + _give_random_charm(ctx, "Nichts kommt zurück."),
			func(run: RunState) -> bool: return run.gold >= 10),
		_leave("Das Gesicht sieht dir nach, bis du hinter dem Hügel bist.")
	])

	_event("wanderzirkus", "Der Wanderzirkus", "zirkus", [
		"Ein Zelt, das von innen größer ist als von außen.",
		"Der Direktor hat keinen Kopf, nur einen Hut. Der Hut lächelt."
	], [
		_choice("Kaufe ein Los", "25 Gold: 40 % Charm, 35 % Item, 25 % nichts.", func(ctx: EventContext) -> String:
			ctx.run.gold -= 25
			var roll := ctx.rng.next_float()
			if roll < Num.f(0.40):
				return "Ein Gewinn! " + _give_random_charm(ctx, "Der Preis ist ausverkauft.")
			if roll < Num.f(0.75):
				return "Ein Trostpreis. " + _give_random_item(ctx)
			return "Eine Niete. Der Hut lacht, und alle lachen mit.",
			func(run: RunState) -> bool: return run.gold >= 25),
		_choice("Tritt als Attraktion auf", "+50 Gold, −10 HP.", func(ctx: EventContext) -> String:
			ctx.run.gold += 50
			_hurt(ctx.run, 10)
			return "Sie werfen Messer. Die Menge jubelt bei jedem, der trifft."),
		_leave("Die Musik folgt dir noch eine Weile.")
	])

	_event("hebamme", "Die Hebamme der Omen", "hebamme", [
		"Sie wiegt etwas im Arm, das in ein Tarottuch gewickelt ist.",
		"Es greift nach dir. Es hat deine Hände."
	], [
		_choice("Nimm es an dich", "Ein zufälliges Großes Arkanum, umgekehrt. +8 Verdunkelung.", func(ctx: EventContext) -> String:
			var major := _random_major(ctx)
			_add(ctx.run, major, 1, SH.MATTE, Enums.Orientation.REVERSED)
			ctx.run.add_darkness(8)
			return "Unter dem Tuch liegt %s, kopfüber. Es hört auf zu weinen." % major.name),
		_choice("Segne es", "Eine zufällige Karte deines Decks steigt 2 Stufen.", func(ctx: EventContext) -> String:
			var card: CardInstance = ctx.rng.pick(ctx.run.deck)
			card.level += 2
			return "Sie nickt. Irgendwo in deinem Deck wird %s schwerer." % card.definition.name,
			func(run: RunState) -> bool: return run.deck.size() > 0),
		_leave("Sie singt ihm etwas vor. Es ist dein Name.")
	], {"min_act": 2})

	_event("hungriger_haendler", "Der Händler hat Hunger", "haendler", [
		"Der Händler sitzt am Wegrand und kaut. Sein Mantel ist leer.",
		"„Nur ein Happen“, sagt er. „Dann öffne ich wieder.“"
	], [
		_choice("Füttere ihn mit einer Karte", "Deine schwächste Karte geht; dein nächster Kauf ist umsonst.", func(ctx: EventContext) -> String:
			var w := weakest(ctx.run)
			_remove(ctx.run, w)
			ctx.run.free_next_shop_purchase = true
			return "Er kaut %s sehr gründlich. „Beim nächsten Mal geht's aufs Haus.“" % _name_of(w),
			func(run: RunState) -> bool: return _can_thin(run, 1)),
		_choice("Füttere ihn mit Gold", "40 Gold: ein zufälliger Charm.", func(ctx: EventContext) -> String:
			ctx.run.gold -= 40
			return "Er spuckt etwas aus und wischt es an seinem Ärmel ab. " + _give_random_charm(ctx, "Er hat nichts mehr."),
			func(run: RunState) -> bool: return run.gold >= 40),
		_leave("Er kaut weiter. Du hörst es noch lange.")
	], {"min_act": 2})

	_event("waage", "Die Waage", "waage", [
		"Eine Waage ohne Richter. In der einen Schale liegt ein Herz.",
		"Die andere Schale ist leer und wartet."
	], [
		_choice("Leg eine Karte hinein", "Deine schwächste Kleine Arkana wird gegen eine andere derselben Farbe getauscht – eine Stufe höher.", func(ctx: EventContext) -> String:
			var minors: Array = []
			for c in ctx.run.deck:
				if not c.definition.is_major():
					minors.append(c)
			var w: CardInstance = Num.kleinstes(minors, func(c: CardInstance) -> int: return strength(c))
			if w == null:
				return "Die Waage rührt sich nicht."
			var options: Array = []
			for d in GameCatalog.cards():
				if d.suit == w.definition.suit and d.id != w.definition.id:
					options.append(d)
			var replacement: CardDefinition = ctx.rng.pick(options)
			_remove(ctx.run, w)
			_add(ctx.run, replacement, w.level + 1, w.shimmer, w.orientation)
			return "%s wiegt zu wenig. Die Waage gibt dir %s." % [w.definition.name, replacement.name],
			func(run: RunState) -> bool:
				for c in run.deck:
					if not c.definition.is_major():
						return true
				return false),
		_choice("Leg dein ganzes Gold hinein", "Ab 80 Gold wird ein Charm, den du trägst, stärker. Das Gold ist fort.", func(ctx: EventContext) -> String:
			var gold := ctx.run.gold
			ctx.run.gold = 0
			var owned: Array = []
			for c in GameCatalog.charms():
				var stacks := ctx.run.charm_stacks(c.id)
				if stacks > 0 and stacks < c.max_stacks:
					owned.append(c)
			if gold < 80 or owned.is_empty():
				return "Die Waage rührt sich nicht. Das Gold ist trotzdem fort."
			var charm: CharmDefinition = ctx.rng.pick(owned)
			ctx.run.add_charm(charm)
			return "Die Schale sinkt. %s wird schwerer an deinem Hals." % charm.name,
			func(run: RunState) -> bool: return run.gold > 0),
		_leave("Das Herz in der Schale schlägt einmal, als du gehst.")
	])
