class_name KernBruecke
extends RefCounted
## Die Bruecke zwischen Kartentisch und Regelkern - die GDScript-Fassung
## von godot-karten/kern/TartotKern.cs, aber auf einem laufenden
## GameController (Spiel.game) statt eines eigenen Runs.
##
## Hier stehen keine Regeln. Die Bruecke uebersetzt nur: Zustand hinaus als
## Dictionary (dieselben Schluessel wie in godot-karten), Absichten hinein
## als Methodenaufruf. Plaetze sind Zahlen: 0 Vergangenheit, 1 Gegenwart,
## 2 Zukunft.

const ABSICHTEN := ["Attack", "Guard", "Hex", "Drain", "Frenzy"]

var game: GameController
var _pilot := Autopilot.new()


func _init(p_game: GameController) -> void:
	game = p_game


func laeuft() -> bool:
	return game != null and game.combat != null


# ------------------------------------------------------------ Zustand
## Alles, was der Kampftisch zeigen muss.
func kampf() -> Dictionary:
	if not laeuft():
		return {}
	var k := game.combat
	var run := game.run
	var g := k.enemy
	var hand: Array = []
	for karte in k.hand:
		hand.append(karte_nach(karte, k))
	var plaetze := {}
	for slot in k.slots:
		plaetze[int(slot)] = karte_nach(k.slots[slot], k)
	var akt := run.act()
	var mal := CombatSystem.marked_card(run, k)
	return {
		"akt": akt,
		"akt_name": ActCatalog.ACT_NAMES[mini(akt, ActCatalog.ACT_NAMES.size() - 1)],
		"wo": Kampftisch.wo(run),
		"kampf": run.fight_index + 1,
		"zug": k.turn,
		"gegner": {
			"id": g.definition.id,
			"sprite": AnimationCues.sprite_id(g.definition),
			"name": g.definition.name,
			"lp": g.hp,
			"max_lp": g.definition.max_hp,
			"haltung": g.stance,
			"max_haltung": g.definition.max_stance,
			"siegel": g.sigils,
			"schild": g.shield,
			"brand": g.burn,
			"absicht": "Verborgen" if g.intent_hidden else ABSICHTEN[g.intent],
			"absicht_wert": 0 if g.intent_hidden else g.intent_value,
			"boss": g.definition.is_boss(),
			"phase": g.phase,
			"mond": CombatSystem.has_rule(k, Enums.BossRule.MOON),
			"regeln": CombatSystem.active_rule_texts(k),
			"flavor": g.definition.flavor,
		},
		"spieler": {
			"lp": run.hp,
			"max_lp": run.max_hp,
			"schild": k.player_shield,
			"glueck": k.temporary_luck,
			"gold": run.gold,
			"fate": run.fate,
			"dunkel": run.darkness,
		},
		"hand": hand,
		"plaetze": plaetze,
		"gesperrt": k.blocked_slot,
		"wirkt_als": [game.combat_system.effective_slot(k, 0), game.combat_system.effective_slot(k, 1),
			game.combat_system.effective_slot(k, 2)],
		"stapel": k.draw_pile.size(),
		"mischungen": k.reshuffles,
		"ablage": k.discard_pile.size(),
		"pakt": k.pact_pending,
		# Die Karte, die der Tod gezeichnet hat (sie kann auch im Stapel liegen).
		"mal": karte_nach(mal, k) if mal != null else {},
		"pakt_bonus": CombatSystem.pact_bonus(k),
		"pakt_preis": CombatSystem.pact_cost(k),
	}


static func karte_nach(karte: CardInstance, k: CombatState) -> Dictionary:
	return {
		"instanz": karte.instance_id,
		"id": karte.definition.id,
		"edition": "" if karte.edition == Enums.CardEdition.NONE else Enums.NAMES_EDITION[karte.edition],
		"umgekehrt": karte.is_reversed(),
		"stufe": karte.level,
		"schimmer": karte.shimmer,
		"verschleiert": k != null and k.is_veiled(karte),
		"gezeichnet": k.mark_turns_left if k != null and k.marked_card_id == karte.instance_id else 0,
		"rang": karte.effective_rank(),
		"faktor": karte.power_multiplier(),
		"kopie": karte.is_copy,
	}


# ------------------------------------------------------------ Legen
func legen(instanz: String, platz: int) -> bool:
	if not laeuft():
		return false
	return game.combat_system.place_card(game.combat, instanz, platz)


func zuruecknehmen(platz: int) -> bool:
	return laeuft() and game.combat_system.return_slot_to_hand(game.combat, platz)


## Alle Plaetze leeren (die Karten gehen auf die Hand).
func abraeumen() -> void:
	if not laeuft():
		return
	for platz in [0, 1, 2]:
		game.combat_system.return_slot_to_hand(game.combat, platz)


## Die beste Legung laut Autopilot: [{instanz, platz}, ...]. Veraendert nichts.
func vorschlag() -> Array:
	var liste: Array = []
	if not laeuft():
		return liste
	for e in _pilot.suggest_layout(game):
		liste.append({"instanz": e[0], "platz": int(e[1])})
	return liste


# ------------------------------------------------------------ Wertung
## Was die aktuelle Legung ergaebe - ohne Nebenwirkung.
func vorschau() -> Dictionary:
	if not laeuft() or game.combat.slots.is_empty():
		return {}
	return wertung_nach(game.combat_system.preview_score(game.run, game.combat))


static func wertung_nach(w: ScoreBreakdown) -> Dictionary:
	if w == null:
		return {}
	var schritte: Array = []
	for s in w.steps:
		schritte.append({"id": s.instance_id, "label": s.label, "chips": s.chips, "mult": s.mult_add, "xmult": s.mult_x})
	var hinweise: Array = []
	for h in w.hints:
		hinweise.append(h)
	return {
		"chips": w.chips,
		"mult": w.multiplier,
		"schicksal": w.fate_damage,
		"muster": w.combo_name,
		"treffer": w.expected_hit,
		"toedlich": w.lethal,
		"haltung_bricht": w.breaks_stance,
		"welt": w.is_world,
		"kette": w.chain,
		"schritte": schritte,
		"hinweise": hinweise,
	}


## Fuehrt den Zug aus. Liefert die Wertungsschritte fuer die Kaskade, was
## danach geschah, die Animationshinweise des Kerns (AnimationCues) und die
## Folge des CueBuilders (Einsturz, Verhuellen, Kartenverlust ...).
func ausfuehren() -> Dictionary:
	if not laeuft() or game.phase != Enums.GamePhase.COMBAT:
		return {}
	var vorher_deck := {}
	for c in game.run.deck:
		vorher_deck[c.instance_id] = karte_nach(c, game.combat)
	var gelegt: Array = []
	for slot in game.combat.slots:
		gelegt.append(game.combat.slots[slot].instance_id)
	var lp_vorher := game.run.hp
	var gegner := game.combat.enemy
	var absicht := gegner.intent
	var zug_nummer := game.combat.turn
	var vorher := CueBuilder.vorher(game)

	var zug := game.resolve_turn()
	if zug == null:
		return {}

	var weg: Array = []
	for id in gelegt:
		var noch := false
		for c in game.run.deck:
			if c.instance_id == id:
				noch = true
				break
		if vorher_deck.has(id) and not noch:
			weg.append(id)

	# "schicksal" ist der Wert der Legung (die Kaskade zaehlt ihn hoch),
	# "angekommen" das, was nach Haltung und Schild beim Gegner landet.
	var ergebnis := wertung_nach(zug.score)
	ergebnis["angekommen"] = zug.fate_damage
	ergebnis["gegner_angriff"] = zug.enemy_damage
	ergebnis["heilung"] = zug.healing
	ergebnis["schild"] = zug.shield_gained
	ergebnis["lp_verlust"] = maxi(0, lp_vorher - game.run.hp)
	ergebnis["haltung_gebrochen"] = zug.stance_broken
	ergebnis["phase_wechsel"] = zug.phase_changed
	ergebnis["sieg"] = zug.victory
	ergebnis["niederlage"] = zug.defeat
	ergebnis["ueberschuss"] = zug.overkill
	ergebnis["rekord"] = zug.new_best_hit
	ergebnis["zersprungen"] = weg
	# Was das Deck sonst verlassen hat (der Tod nimmt eine Karte): als Karte.
	var noch_da := {}
	for c in game.run.deck:
		noch_da[c.instance_id] = true
	var verloren: Array = []
	for id in vorher_deck:
		if not noch_da.has(id) and not gelegt.has(id):
			verloren.append(vorher_deck[id])
	ergebnis["verloren"] = verloren
	ergebnis["log"] = Array(zug.log)
	ergebnis["animationen"] = Array(AnimationCues.for_turn(zug, gegner, absicht, zug_nummer))
	ergebnis["angriff"] = ABSICHTEN[absicht]
	ergebnis["boss"] = gegner.definition.is_boss()
	ergebnis["cues"] = CueBuilder.baue(vorher, zug, game)
	ergebnis["zug"] = zug
	return ergebnis
