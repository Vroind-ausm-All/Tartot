extends RefCounted
class_name RunOutcome
## Was ein Autopilot-Run am Ende erreicht hat (Simulation/Autopilot.cs).

var fights: Array[FightRecord] = []
## Die vollstaendige Run-Statistik (RunStats.to_dictionary).
var stats: Dictionary = {}
var fights_cleared: int = 0
var deck_size: int = 0
var gold: int = 0
var fate: int = 0
var hp: int = 0
var charm_stacks: int = 0
var turns_played: int = 0
var deck_resonance: int = 0
var shop_removals: int = 0
var gold_spent: int = 0
var died_against: String = "-"
var reached_limit: bool = false
## Das Finale wurde geschlagen.
var won: bool = false
## 1-3 Akte, 4 Finale, 5 Spirale.
var act_reached: int = 0
var spiral_depth: int = 0
var darkness: int = 0
var world_spreads: int = 0
var longest_chain: int = 0
var best_hit: int = 0
var events_seen: int = 0
var pacts_accepted: int = 0
var cards_lost_to_death: int = 0
var bosses_defeated: int = 0
var darkest_shimmer: int = 0
var rests_taken: int = 0
var elites_fought: int = 0
var shop_visits: int = 0
var paths_with_shop: int = 0

## Kurzform zum Vergleich zweier Laeufe (Determinismus-Tests) - wie in C#.
func signature() -> String:
	return "%d|%d|%d|%d|%d|%d|%d|%s" % [fights_cleared, deck_size, gold, fate, hp, charm_stacks, turns_played, died_against]
