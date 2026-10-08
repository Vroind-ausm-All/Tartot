extends RefCounted
class_name CueBuilder
## Baut aus einem aufgeloesten Zug die Folge der Darstellung
## (docs/VERTICAL_SLICE.md, 5.3). Eingaben sind ausschliesslich Kernfakten:
## der Zustand vor dem Zug, das TurnResult, der Zustand danach und
## AnimationCues.for_turn. Hier wird nichts berechnet, was der Kern nicht
## schon entschieden hat.
##
## Jeder Cue ist ein Dictionary mit "typ" und Daten:
##   wertung   {text}            ein Schritt der Wertungskaskade (ScoreBreakdown.steps)
##   fate      {wert, bricht}    der Fate-Treffer
##   boss      {cue, ton}        eine Animation der Bossdarstellung
##   siegel    {text}            Siegelbruch: Regelkarte splittert, neuer Regeltext
##   einsturz  {slot}            Turm: ein Platz stuerzt ein
##   aufrichten {slot}           ein Platz ist wieder frei
##   spieler   {schaden, heilung, schild}
##   verlust   {text}            Der Tod nimmt eine Karte

## vorher: {"blocked": int, "hp": int, "phase": int, "intent": int, "turn": int, "player_hp": int}
static func vorher(game: GameController) -> Dictionary:
	var c := game.combat
	return {
		"blocked": c.blocked_slot,
		"hp": c.enemy.hp,
		"phase": c.enemy.phase,
		"intent": c.enemy.intent,
		"turn": c.turn,
		"player_hp": game.run.hp,
		"enemy": c.enemy,
	}

static func baue(v: Dictionary, turn: TurnResult, game: GameController) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	if turn == null:
		return cues
	var combat := game.combat
	var score := turn.score

	# Wertungskaskade: Karten, dann Muster - genau die Schritte des Kerns.
	if score != null:
		for st in score.steps:
			var teile: Array[String] = []
			if st.chips != 0:
				teile.append("+%d Chips" % st.chips)
			if absf(st.mult_add) > 0.001:
				teile.append("+%s Mult" % Num.de(st.mult_add))
			if absf(st.mult_x - 1.0) > 0.001:
				teile.append("×%s" % Num.de(st.mult_x))
			cues.append({"typ": "wertung", "text": "%s  %s" % [st.label, " ".join(teile)]})
		cues.append({"typ": "fate", "wert": turn.fate_damage, "bricht": turn.stance_broken,
			"text": "%s · %d × %s = %d" % [score.combo_name, score.chips, Num.de(score.multiplier), score.fate_damage]})

	# Boss-Animationen in der Reihenfolge des Kerns.
	var anim := AnimationCues.for_turn(turn, v["enemy"], int(v["intent"]), int(v["turn"]))
	for a in anim:
		match a:
			"hit":
				var stark := turn.stance_broken or turn.enemy_damage >= 12
				cues.append({"typ": "boss", "cue": "hit_stark" if stark else "hit", "ton": "break" if stark else "hit"})
			"phase2":
				cues.append({"typ": "siegel", "text": " ".join(CombatSystem.active_rule_texts(combat))})
				cues.append({"typ": "boss", "cue": "phase2", "ton": "phase2"})
			"death":
				cues.append({"typ": "boss", "cue": "death", "ton": "death"})
			_:
				cues.append({"typ": "boss", "cue": a, "ton": "attack" if a.begins_with("attack") else ""})
				var schaden := int(v["player_hp"]) - game.run.hp
				if schaden != 0 or turn.shield_gained > 0:
					cues.append({"typ": "spieler", "schaden": maxi(0, schaden), "heilung": maxi(0, -schaden), "schild": turn.shield_gained})

	if turn.card_lost != "":
		cues.append({"typ": "verlust", "text": "DER TOD NIMMT %s" % turn.card_lost.to_upper()})

	# Der Turm setzt den Platz fuer den naechsten Zug (PrepareRules).
	if turn.tower_collapsed >= 0:
		cues.append({"typ": "boss", "cue": "collapse", "ton": "lightning"})
		cues.append({"typ": "einsturz", "slot": turn.tower_collapsed})
	elif int(v["blocked"]) >= 0 and combat.blocked_slot != int(v["blocked"]):
		cues.append({"typ": "aufrichten", "slot": int(v["blocked"])})
	return cues
