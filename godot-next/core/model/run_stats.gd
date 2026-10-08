extends RefCounted
class_name RunStats
## Was in einem Run geschah (Model/States.cs). Speist Prophezeiungen,
## Rekorde und den Run-Bericht.

const KEYS := [
	"worldSpreads", "bestHit", "bestOverkill", "longestChain", "bossesDefeated",
	"elitesDefeated", "fightsWon", "eventsSeen", "pactsAccepted", "reversedPlayed",
	"mostShield", "oneTurnKills", "cardsLostToDeath", "turnsPlayed", "darkestShimmer",
	"thinBossKills", "mostWorldsInFight", "peakDarkness", "mostBlackCards"
]

var world_spreads: int = 0
## Wert der staerksten Legung (Chips x Mult), vor dem Haltungsdeckel.
var best_hit: int = 0
var best_hit_combo: String = ""
var best_overkill: int = 0
var longest_chain: int = 0
var bosses_defeated: int = 0
var elites_defeated: int = 0
var fights_won: int = 0
var events_seen: int = 0
var pacts_accepted: int = 0
var reversed_played: int = 0
var most_shield_at_victory: int = 0
var one_turn_kills: int = 0
var cards_lost_to_death: int = 0
var turns_played: int = 0
var darkest_shimmer: int = 0
var thin_boss_kills: int = 0
var most_worlds_in_fight: int = 0
var peak_darkness: int = 0
var most_black_cards: int = 0

## Alle Werte unter stabilen Schluesseln - fuer Meta-Zaehler und Speicherstand.
func to_dictionary() -> Dictionary:
	return {
		"worldSpreads": world_spreads, "bestHit": best_hit, "bestOverkill": best_overkill,
		"longestChain": longest_chain, "bossesDefeated": bosses_defeated,
		"elitesDefeated": elites_defeated, "fightsWon": fights_won, "eventsSeen": events_seen,
		"pactsAccepted": pacts_accepted, "reversedPlayed": reversed_played,
		"mostShield": most_shield_at_victory, "oneTurnKills": one_turn_kills,
		"cardsLostToDeath": cards_lost_to_death, "turnsPlayed": turns_played,
		"darkestShimmer": darkest_shimmer, "thinBossKills": thin_boss_kills,
		"mostWorldsInFight": most_worlds_in_fight, "peakDarkness": peak_darkness,
		"mostBlackCards": most_black_cards
	}

func load(values: Dictionary) -> void:
	world_spreads = int(values.get("worldSpreads", 0))
	best_hit = int(values.get("bestHit", 0))
	best_overkill = int(values.get("bestOverkill", 0))
	longest_chain = int(values.get("longestChain", 0))
	bosses_defeated = int(values.get("bossesDefeated", 0))
	elites_defeated = int(values.get("elitesDefeated", 0))
	fights_won = int(values.get("fightsWon", 0))
	events_seen = int(values.get("eventsSeen", 0))
	pacts_accepted = int(values.get("pactsAccepted", 0))
	reversed_played = int(values.get("reversedPlayed", 0))
	most_shield_at_victory = int(values.get("mostShield", 0))
	one_turn_kills = int(values.get("oneTurnKills", 0))
	cards_lost_to_death = int(values.get("cardsLostToDeath", 0))
	turns_played = int(values.get("turnsPlayed", 0))
	darkest_shimmer = int(values.get("darkestShimmer", 0))
	thin_boss_kills = int(values.get("thinBossKills", 0))
	most_worlds_in_fight = int(values.get("mostWorldsInFight", 0))
	peak_darkness = int(values.get("peakDarkness", 0))
	most_black_cards = int(values.get("mostBlackCards", 0))

func get_stat(key: String) -> int:
	return int(to_dictionary().get(key, 0))
