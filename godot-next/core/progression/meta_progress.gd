extends RefCounted
class_name MetaProgress
## Fortschritt ueber Runs hinweg (Progression/MetaProgress.cs).
##
## Bewusst kein "+5 % Schaden". Was waechst, ist das Verstaendnis (Lesarten
## der Grossen Arkana), die Auswahl (Prophezeiungen schalten Charms und
## Deuter frei), die Herausforderung (Schleier) und die Geschichte
## (Story-Flags, Totenkarten).

const CURRENT_VERSION := 2
const INT_MAX := 2147483647
## Ab wie vielen Begegnungen ein Arkanum eine neue Lesart zeigt.
const INTERPRETATION_THRESHOLDS := [1, 5, 12]
const INTERPRETATION_NAMES := ["Erste Lesart", "Transformation", "Verkehrte Lesart"]
const MAX_DEATH_CARDS := 30

var runs_started: int = 0
var runs_won: int = 0
var deaths: int = 0
var best_fights_cleared: int = 0
var best_fate_total: int = 0
var smallest_deck: int = INT_MAX
## Hoechster freigeschalteter Schleier (0-8).
var veil: int = 0
## Hoechster Schleier, auf dem ein Run gewonnen wurde (-1 = noch nie).
var highest_veil_won: int = -1
var best_spiral_depth: int = 0
var dailies_played: int = 0
var best_daily_fate: int = 0
var last_daily_seed: int = 0

## card_id -> Anzahl Begegnungen
var arcana_encounters: Dictionary = {}
## card_id -> Array[String] (Namen der Lesarten)
var interpretations: Dictionary = {}
## Menge (Dictionary als Set)
var seen_cards: Dictionary = {}
var death_cards: Array[DeathCard] = []
## Summe ueber alle Runs.
var lifetime_stats: Dictionary = {}
## Bestwert eines einzelnen Runs.
var best_stats: Dictionary = {}
var completed_prophecies: Dictionary = {}
var story_flags: Dictionary = {}

func lifetime(key: String) -> int:
	return int(lifetime_stats.get(key, 0))

func best(key: String) -> int:
	return int(best_stats.get(key, 0))

## Zaehlt eine Begegnung und gibt die dadurch freigeschaltete Lesart zurueck, sonst "".
func encounter_arcanum(card_id: String) -> String:
	if card_id == "":
		return ""
	var count := int(arcana_encounters.get(card_id, 0)) + 1
	arcana_encounters[card_id] = count
	var index := INTERPRETATION_THRESHOLDS.find(count)
	if index < 0:
		return ""
	if not interpretations.has(card_id):
		interpretations[card_id] = []
	var list: Array = interpretations[card_id]
	var name: String = INTERPRETATION_NAMES[index]
	if list.has(name):
		return ""
	list.append(name)
	return name

func has_interpretation(card_id: String, name: String) -> bool:
	return interpretations.has(card_id) and (interpretations[card_id] as Array).has(name)

func interpretation_count() -> int:
	var n := 0
	for k in interpretations:
		n += (interpretations[k] as Array).size()
	return n

# ------------------------------------------------- Freischaltungen
func unlocked_charm_ids() -> Array[String]:
	var out: Array[String] = []
	for p in ProphecyCatalog.all():
		if completed_prophecies.has(p.id):
			out.append_array(p.unlock_charms)
	return out

## Was in einem Run mit diesem Fortschritt angeboten werden darf (Menge).
func charm_pool() -> Dictionary:
	var pool := {}
	for id in GameCatalog.starter_charm_ids():
		pool[id] = true
	for id in unlocked_charm_ids():
		pool[id] = true
	return pool

func is_deuter_unlocked(deuter_id: String) -> bool:
	var deuter: DeuterDefinition = null
	for d in DeuterCatalog.all():
		if d.id == deuter_id:
			deuter = d
			break
	if deuter == null:
		return false
	return deuter.unlocked_by == "" or completed_prophecies.has(deuter.unlocked_by)

func unlocked_deuters() -> Array[DeuterDefinition]:
	var out: Array[DeuterDefinition] = []
	for d in DeuterCatalog.all():
		if is_deuter_unlocked(d.id):
			out.append(d)
	return out

## Prophezeiungen, die mit dem laufenden Run gerade erfuellt waeren, aber
## noch nicht verbucht sind. Die Oberflaeche zeigt den Moment sofort.
func pending_fulfilled(run: RunState) -> Array[ProphecyDefinition]:
	var out: Array[ProphecyDefinition] = []
	for p in ProphecyCatalog.all():
		if not completed_prophecies.has(p.id) and p.is_fulfilled(self, run):
			out.append(p)
	return out

# ---------------------------------------------------------- Runs
## Verbucht einen beendeten Run (Kurzform, ohne Bericht).
func register_run(game: GameController, won: bool, killed_by := "") -> void:
	complete_run(game, won, killed_by)

## Verbucht einen beendeten Run und erstellt den Bericht.
## won: null = aus dem Run lesen (Finale geschlagen).
func complete_run(game: GameController, won: Variant = null, killed_by := "") -> RunReport:
	var report := RunReport.new()
	if game == null:
		return report

	var run := game.run
	var has_won: bool = run.won if won == null else bool(won)
	var previous_best_fights := best_fights_cleared
	var previous_best_fate := best_fate_total
	var previous_best_hit := best("bestHit")

	runs_started += 1
	if has_won:
		runs_won += 1
	else:
		deaths += 1

	best_fights_cleared = maxi(best_fights_cleared, run.fight_index)
	best_fate_total = maxi(best_fate_total, run.fate_score_total)
	if run.deck.size() > 0:
		smallest_deck = mini(smallest_deck, run.deck.size())

	var stats := run.stats.to_dictionary()
	for key in stats:
		lifetime_stats[key] = lifetime(key) + int(stats[key])
		best_stats[key] = maxi(best(key), int(stats[key]))

	for card in run.deck:
		seen_cards[card.definition.id] = true
		if card.definition.is_major():
			encounter_arcanum(card.definition.id)
	for flag in run.new_story_flags:
		story_flags[flag] = true

	if has_won:
		highest_veil_won = maxi(highest_veil_won, run.veil)
		veil = mini(DeuterCatalog.MAX_VEIL, maxi(veil, run.veil + 1))
		best_spiral_depth = maxi(best_spiral_depth, ActCatalog.spiral_depth(run.fight_index))

	if run.is_daily:
		if last_daily_seed != game.seed:
			dailies_played += 1
		last_daily_seed = game.seed
		best_daily_fate = maxi(best_daily_fate, run.fate_score_total)

	if not has_won:
		var strongest: CardInstance = Num.groesstes(run.deck,
			func(c: CardInstance) -> int: return c.shimmer * 10 + c.level)
		var dc := DeathCard.new()
		dc.title = "Gefallen nach Kampf %d" % run.fight_index
		dc.fight = run.fight_index
		dc.deck_size = run.deck.size()
		dc.fate_total = run.fate_score_total
		dc.killed_by = killed_by
		dc.seed = game.seed
		dc.card_id = strongest.definition.id if strongest != null else ""
		dc.deuter_id = run.deuter_id
		death_cards.append(dc)
		if death_cards.size() > MAX_DEATH_CARDS:
			death_cards.remove_at(0)

	# Prophezeiungen: jetzt ist der Run verbucht, also ohne ihn auswerten.
	for prophecy in ProphecyCatalog.all():
		if completed_prophecies.has(prophecy.id) or not prophecy.is_fulfilled(self, null):
			continue
		completed_prophecies[prophecy.id] = true
		var reward := prophecy.reward_text()
		report.unlocked.append("Prophezeiung erfüllt: %s" % prophecy.title if reward == ""
			else "Prophezeiung erfüllt: %s — %s" % [prophecy.title, reward])

	_fill_report(report, game, has_won, killed_by, previous_best_fights, previous_best_fate, previous_best_hit)
	return report

static func _near(title: String, detail: String, reward: String, progress: float) -> NearMiss:
	var n := NearMiss.new()
	n.title = title
	n.detail = detail
	n.reward = reward
	n.progress = Num.f(progress)
	return n

func _fill_report(report: RunReport, game: GameController, won: bool, killed_by: String,
		previous_best_fights: int, previous_best_fate: int, previous_best_hit: int) -> void:
	var run := game.run
	report.won = won
	report.fights_cleared = run.fight_index
	report.act = mini(4, run.act())
	report.spiral_depth = ActCatalog.spiral_depth(run.fight_index)
	report.fate_total = run.fate_score_total
	report.best_hit = run.stats.best_hit
	report.best_hit_combo = run.stats.best_hit_combo
	report.killed_by = killed_by
	report.darkness = run.darkness

	if won:
		report.headline = "DIE WELT FIEL · Spirale Tiefe %d" % report.spiral_depth if report.spiral_depth > 0 else "DIE WELT FIEL"
	else:
		report.headline = "GEFALLEN IN AKT %s" % Num.roman(run.act()) if run.act() <= ActCatalog.ACT_COUNT else "GEFALLEN VOR DER WELT"

	if run.fight_index > previous_best_fights and previous_best_fights > 0:
		report.records.append("Neuer Tiefenrekord: Kampf %d." % (run.fight_index + 1))
	if run.fate_score_total > previous_best_fate and previous_best_fate > 0:
		report.records.append("Neuer Fate-Rekord: %d." % run.fate_score_total)
	if run.stats.best_hit > previous_best_hit and previous_best_hit > 0:
		report.records.append("Härtester Treffer aller Zeiten: %d (%s)." % [run.stats.best_hit, run.stats.best_hit_combo])

	# --- Beinahe: was knapp verfehlt wurde ---------------------
	var near: Array = []
	for prophecy in ProphecyCatalog.all():
		if completed_prophecies.has(prophecy.id):
			continue
		var progress := prophecy.progress(self, null)
		if progress < 0.25:
			continue
		near.append(_near(prophecy.title,
			"%s (%d / %d)" % [prophecy.text, prophecy.value_of(self, null), prophecy.target],
			prophecy.reward_text(), progress))

	if not won:
		var gap := previous_best_fights - run.fight_index
		if gap >= 0 and gap <= 2 and previous_best_fights > 0:
			near.append(_near(
				"Genau dein Rekord" if gap == 0 else "%d %s unter deinem Rekord" % [gap, "Kampf" if gap == 1 else "Kämpfe"],
				"Dein tiefster Run endete in Kampf %d." % (previous_best_fights + 1), "",
				Num.sub(1.0, Num.mul(gap, 0.05))))

		# Am Boss gestorben: wie viel fehlte?
		var enemy: EnemyState = game.combat.enemy if game.combat != null else null
		var share := 1.0 if enemy == null else Num.dv(enemy.hp, maxi(1, enemy.definition.max_hp))
		# Nur wenn wirklich wenig fehlte - ein Boss mit vollem Leben ist kein Beinahe.
		var close := enemy != null and enemy.hp > 0 and (share <= 0.5 if enemy.sigils == 0 else share <= 0.25)
		if enemy != null and enemy.definition.is_boss() and close:
			var finale := enemy.definition.tier == Enums.EnemyTier.FINALE
			near.append(_near(
				"%s hatte noch %d HP" % [enemy.definition.name, enemy.hp] + (" und %d Siegel" % enemy.sigils if enemy.sigils > 0 else ""),
				"Ein Siegel stand noch." if enemy.sigils > 0 else "Ein, zwei Legungen mehr.",
				"Der Sieg hätte Schleier %d geöffnet" % mini(DeuterCatalog.MAX_VEIL, run.veil + 1) if finale
					else "Dahinter wartete Akt %s" % Num.roman(mini(ActCatalog.ACT_COUNT, run.act() + 1)),
				Num.mul(0.5, Num.sub(1.0, share)) if enemy.sigils > 0 else Num.sub(1.0, share)))
		elif run.act() == ActCatalog.ACT_COUNT:
			var left := ActCatalog.FINALE_INDEX - run.fight_index
			near.append(_near("Das Finale war nah",
				"Noch %d %s bis zur Welt." % [left, "Kampf" if left == 1 else "Kämpfe"],
				"Schleier %d öffnet sich mit dem Sieg" % mini(DeuterCatalog.MAX_VEIL, run.veil + 1), 0.8))

	# Lesarten, die eine einzige Begegnung entfernt sind.
	var majors: Array = []
	for c in run.deck:
		if c.definition.is_major() and not majors.has(c.definition):
			majors.append(c.definition)
	for card: CardDefinition in majors:
		var count := int(arcana_encounters.get(card.id, 0))
		for i in INTERPRETATION_THRESHOLDS.size():
			if INTERPRETATION_THRESHOLDS[i] != count + 1:
				continue
			near.append(_near("%s: noch 1 Begegnung" % card.name,
				"bis zur Lesart „%s“." % INTERPRETATION_NAMES[i],
				"+%d %% Wirkung für dieses Arkanum" % roundi(Num.mul(CombatSystem.INTERPRETATION_POWER_PER_READING, 100.0)),
				0.95))

	var sorted := Num.sortiert(near, func(n: NearMiss) -> float: return n.progress, true)
	for n: NearMiss in sorted.slice(0, 3):
		report.near_misses.append(n)

## Tageskarte: derselbe Seed fuer alle Spieler an einem Tag (UTC).
## utc: {"year", "month", "day"}; leer = jetzt.
static func daily_seed(utc: Dictionary = {}) -> int:
	var now := utc if not utc.is_empty() else Time.get_datetime_dict_from_system(true)
	return int(now["year"]) * 10000 + int(now["month"]) * 100 + int(now["day"])

# ------------------------------------------------------- Speichern
static func _sorted_keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys

static func _write_counts(counts: Dictionary) -> Dictionary:
	var node := {}
	for k in _sorted_keys(counts):
		node[k] = int(counts[k])
	return node

static func _write_set(values: Dictionary) -> Array:
	return _sorted_keys(values)

static func _read_counts(node: Variant, target: Dictionary) -> void:
	if not node is Dictionary:
		return
	for k in node:
		target[String(k)] = Num.rnd(float(node[k]))

static func _read_set(root: Dictionary, key: String, target: Dictionary) -> void:
	var arr: Variant = root.get(key, [])
	if not arr is Array:
		return
	for entry in arr:
		if entry is String:
			target[entry] = true

func to_dict() -> Dictionary:
	var interp := {}
	for k in interpretations:
		interp[k] = (interpretations[k] as Array).duplicate()
	var deaths_arr: Array = []
	for dc in death_cards:
		deaths_arr.append({"title": dc.title, "fight": dc.fight, "deck": dc.deck_size, "fate": dc.fate_total,
			"by": dc.killed_by, "seed": dc.seed, "card": dc.card_id, "deuter": dc.deuter_id})
	return {
		"version": CURRENT_VERSION,
		"runsStarted": runs_started,
		"runsWon": runs_won,
		"deaths": deaths,
		"bestFights": best_fights_cleared,
		"bestFate": best_fate_total,
		"smallestDeck": 0 if smallest_deck == INT_MAX else smallest_deck,
		"veil": veil,
		"highestVeilWon": highest_veil_won,
		"bestSpiral": best_spiral_depth,
		"dailies": dailies_played,
		"bestDaily": best_daily_fate,
		"lastDaily": last_daily_seed,
		"arcana": _write_counts(arcana_encounters),
		"interpretations": interp,
		"seen": _write_set(seen_cards),
		"deathCards": deaths_arr,
		"lifetime": _write_counts(lifetime_stats),
		"best": _write_counts(best_stats),
		"prophecies": _write_set(completed_prophecies),
		"flags": _write_set(story_flags),
	}

func serialize(indented := false) -> String:
	return JSON.stringify(to_dict(), "  " if indented else "", false)

static func _get_int(root: Dictionary, key: String, fallback := 0) -> int:
	var v: Variant = root.get(key, null)
	if v is float or v is int:
		return Num.rnd(float(v))
	return fallback

static func deserialize(text: String) -> MetaProgress:
	var meta := MetaProgress.new()
	if text.strip_edges() == "":
		return meta
	var root: Variant = JSON.parse_string(text)
	if not root is Dictionary:
		return meta
	meta.runs_started = _get_int(root, "runsStarted")
	meta.runs_won = _get_int(root, "runsWon")
	meta.deaths = _get_int(root, "deaths")
	meta.best_fights_cleared = _get_int(root, "bestFights")
	meta.best_fate_total = _get_int(root, "bestFate")
	var smallest := _get_int(root, "smallestDeck")
	meta.smallest_deck = INT_MAX if smallest <= 0 else smallest
	meta.veil = _get_int(root, "veil")
	meta.highest_veil_won = _get_int(root, "highestVeilWon", -1)
	meta.best_spiral_depth = _get_int(root, "bestSpiral")
	meta.dailies_played = _get_int(root, "dailies")
	meta.best_daily_fate = _get_int(root, "bestDaily")
	meta.last_daily_seed = _get_int(root, "lastDaily")

	_read_counts(root.get("arcana"), meta.arcana_encounters)

	var interp: Variant = root.get("interpretations")
	if interp is Dictionary:
		for k in interp:
			var list: Array = []
			if interp[k] is Array:
				for v in interp[k]:
					if v is String:
						list.append(v)
			meta.interpretations[String(k)] = list

	_read_set(root, "seen", meta.seen_cards)

	var deaths_arr: Variant = root.get("deathCards", [])
	if deaths_arr is Array:
		for entry in deaths_arr:
			if not entry is Dictionary:
				continue
			var dc := DeathCard.new()
			dc.title = String(entry.get("title", ""))
			dc.fight = _get_int(entry, "fight")
			dc.deck_size = _get_int(entry, "deck")
			dc.fate_total = _get_int(entry, "fate")
			dc.killed_by = String(entry.get("by", ""))
			dc.seed = _get_int(entry, "seed")
			dc.card_id = String(entry.get("card", ""))
			dc.deuter_id = String(entry.get("deuter", ""))
			meta.death_cards.append(dc)

	_read_counts(root.get("lifetime"), meta.lifetime_stats)
	_read_counts(root.get("best"), meta.best_stats)
	_read_set(root, "prophecies", meta.completed_prophecies)
	_read_set(root, "flags", meta.story_flags)
	return meta
