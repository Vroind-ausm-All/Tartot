class_name Choreografie
extends RefCounted
## Wie sich jeder Boss bewegt und angreift.
##
## art: Ruhebewegung
##   "stampfen" - Gummischlauch-Hopsen im Takt der Musik (Turm, Wagen, Kraft)
##   "schweben" - schwebt auf und ab (Sonne, Mond, Maessigkeit, Hohepriesterin)
##   "wiegen"   - wiegt sich in den Hueften (Tod, Teufel, Magier, ...)
##
## angriffe: Hinweis aus dem Regelkern (AnimationCues) -> [Bewegung, Effekt, Klang]
##   Bewegungen: ausfall, sprung, drehung, recken, ansturm, wirbel, bruellen
##   Effekte: siehe BossBuehne._effekt (blitz, steine, strahlen, welle, ...)
##
## Fehlt ein Hinweis, gilt "attack". Neue Bosse: einen Eintrag ergaenzen,
## Bild nach tools/buehne/zerlegen.py - fertig.

const STANDARD := {
	"art": "wiegen", "farbe": Color("F4D27A"), "zweite": Color("E0543A"),
	"angriffe": {
		"attack": ["ausfall", "funken", "hieb"],
		"summon": ["recken", "helfer", "beschwoeren"],
	},
}

const BOSSE := {
	"boss_turm": {
		"art": "stampfen", "farbe": Color("F4D27A"), "zweite": Color("E0543A"),
		"angriffe": {
			"attack": ["sprung", "steine", "steine"],
			"attack1": ["ausfall", "blitz", "blitz"],
			"summon": ["recken", "steine", "steine"],
		},
	},
	"boss_hierophant": {
		"art": "wiegen", "farbe": Color("F4D27A"), "zweite": Color("C73636"),
		"angriffe": {
			"attack": ["recken", "segen", "segen"],
			"attack1": ["recken", "segen", "segen"],
			"attack2": ["recken", "helfer", "chor"],
			"attack3": ["recken", "saeulen", "chor"],
			"summon": ["recken", "helfer", "chor"],
		},
	},
	"boss_maessigkeit": {
		"art": "schweben", "farbe": Color("3B6DB7"), "zweite": Color("AB3232"),
		"angriffe": {
			"attack": ["ausfall", "wasser", "wasser"],
			"attack1": ["ausfall", "wasser", "wasser"],
			"attack2": ["drehung", "feuer", "feuer"],
			"attack3": ["wirbel", "mischen", "feuer"],
			"summon": ["recken", "tropfen", "wasser"],
		},
	},
	"boss_teufel": {
		"art": "wiegen", "farbe": Color("C84B3B"), "zweite": Color("D4A23A"),
		"angriffe": {
			"attack": ["ausfall", "wuerfel", "wuerfel"],
			"attack1": ["ausfall", "wuerfel", "wuerfel"],
			"attack2": ["ausfall", "kette", "kette"],
			"summon": ["recken", "helfer", "beschwoeren"],
		},
	},
	"boss_mond": {
		"art": "schweben", "farbe": Color("C8D8F4"), "zweite": Color("3B4A8C"),
		"angriffe": {
			"attack": ["ausfall", "sterne", "orakel"],
			"attack1": ["wirbel", "nebel", "schleier"],
			"attack2": ["ausfall", "sterne", "orakel"],
			"attack3": ["recken", "orakel", "orakel"],
			"summon": ["recken", "helfer", "beschwoeren"],
		},
	},
	"boss_sonne": {
		"art": "schweben", "farbe": Color("F4C14E"), "zweite": Color("E0543A"),
		"angriffe": {
			"attack": ["recken", "strahlen", "strahlen"],
			"attack1": ["recken", "strahlen", "strahlen"],
			"attack2": ["drehung", "sonnen", "rotation"],
			"summon": ["recken", "helfer", "beschwoeren"],
			"supernova": ["recken", "supernova", "supernova"],
		},
	},
	"boss_rad": {
		"art": "wiegen", "farbe": Color("E3A83B"), "zweite": Color("3B4A8C"),
		"angriffe": {
			"attack": ["drehung", "karten", "rad"],
			"attack1": ["drehung", "karten", "rad"],
			"summon": ["recken", "helfer", "beschwoeren"],
		},
	},
	"boss_tod": {
		"art": "wiegen", "farbe": Color("EFE3C8"), "zweite": Color("B3262B"),
		"angriffe": {
			"attack": ["ausfall", "sense", "sense"],
			"summon": ["recken", "geister", "geister"],
		},
	},
	"boss_magier": {
		"art": "wiegen", "farbe": Color("DAAF37"), "zweite": Color("3B6CB7"),
		"angriffe": {
			"attack": ["ausfall", "zauberstab", "zauber"],
			"attack1": ["ausfall", "zauberstab", "zauber"],
			"attack2": ["recken", "wasser", "wasser"],
			"attack3": ["ausfall", "schwert", "schwert"],
			"summon": ["recken", "muenzen", "muenzen"],
		},
	},
	"boss_hohepriesterin": {
		"art": "schweben", "farbe": Color("6B7FB4"), "zweite": Color("E4A032"),
		"angriffe": {
			"attack": ["wirbel", "schleier", "schleier"],
			"attack1": ["wirbel", "schleier", "schleier"],
			"attack2": ["ausfall", "karten", "zauber"],
			"attack3": ["recken", "orakel", "orakel"],
			"summon": ["recken", "helfer", "beschwoeren"],
		},
	},
	"boss_herrscherin": {
		"art": "wiegen", "farbe": Color("2E6B3E"), "zweite": Color("BB323A"),
		"angriffe": {
			"attack": ["recken", "ranken", "ranken"],
			"attack1": ["recken", "ranken", "ranken"],
			"attack2": ["ausfall", "fruechte", "fruechte"],
			"attack3": ["recken", "bluete", "zauber"],
			"summon": ["recken", "helfer", "beschwoeren"],
		},
	},
	"boss_wagen": {
		"art": "stampfen", "farbe": Color("C73636"), "zweite": Color("3B6CB7"),
		"angriffe": {
			"attack": ["ansturm", "ansturm", "galopp"],
			"attack1": ["ansturm", "ansturm", "galopp"],
			"attack2": ["drehung", "radschwung", "rad"],
			"attack3": ["ausfall", "peitsche", "peitsche"],
			"summon": ["recken", "helfer", "beschwoeren"],
		},
	},
	"boss_kraft": {
		"art": "stampfen", "farbe": Color("C63B33"), "zweite": Color("F2C146"),
		"angriffe": {
			"attack": ["ausfall", "peitsche", "peitsche"],
			"attack1": ["ausfall", "peitsche", "peitsche"],
			"attack2": ["ansturm", "ansturm", "bruellen"],
			"attack3": ["bruellen", "feuer", "bruellen"],
			"summon": ["recken", "helfer", "bruellen"],
		},
	},
}


static func von(boss_id: String) -> Dictionary:
	return BOSSE.get(boss_id, STANDARD)


## [bewegung, effekt, klang] fuer einen Hinweis; faellt auf "attack" zurueck.
static func angriff(boss_id: String, hinweis: String) -> Array:
	var angriffe: Dictionary = von(boss_id)["angriffe"]
	if angriffe.has(hinweis):
		return angriffe[hinweis]
	if hinweis.begins_with("attack") and angriffe.has("attack"):
		return angriffe["attack"]
	return STANDARD["angriffe"]["attack"]


## Alle Angriffe eines Bosses (fuer die Galerie).
static func alle(boss_id: String) -> Array:
	return von(boss_id)["angriffe"].keys()
