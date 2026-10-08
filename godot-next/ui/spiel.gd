extends Node
## Autoload "Spiel": haelt das laufende Spiel und den Meta-Fortschritt und
## speichert beides. Die Regeln selbst stecken im Kern (GameController und
## die Systeme dahinter); hier liegt nur, was eine Oberflaeche um den Kern
## herum braucht - wie TartotView.cs im Unity-Frontend.

var run_save := "user://tartot_run.json"
var meta_save := "user://tartot_meta.json"

var meta: MetaProgress = MetaProgress.new()
var game: GameController = null
## Figur und Schleier des letzten Runs - "Noch einmal" startet damit.
var setup: RunSetup = RunSetup.new()
## Der Bericht des gerade beendeten Runs (einmal verbucht).
var report: RunReport = null
## Schon angekuendigte Prophezeiungen dieses Runs.
var _announced: Dictionary = {}
## Vorfuehrung (Turm-Slice): kein Speichern, keine Meta-Verbuchung.
var vorfuehrung := false
## Welcher Boss in der Vorfuehrung gezeigt wird.
var vorfuehrung_boss := ""

func _ready() -> void:
	meta = _load_meta()
	_load_run()

## Fuer Tests: eigene Dateien, leerer Fortschritt - der Spielstand des
## Spielers bleibt unberuehrt.
func use_test_storage() -> void:
	run_save = "user://test_tartot_run.json"
	meta_save = "user://test_tartot_meta.json"
	_clear_run_file()
	meta = MetaProgress.new()
	game = null
	report = null

# ------------------------------------------------------------ Run
## Neuer Run. seed = 0: Tageskarte -> Tagesseed, sonst ein frischer Seed.
func new_run(p_setup: RunSetup, seed := 0) -> GameController:
	vorfuehrung = false
	setup = p_setup if p_setup != null else RunSetup.new()
	if seed == 0:
		seed = MetaProgress.daily_seed() if setup.is_daily else fresh_seed()
	# Der Meta-Fortschritt geht in den Run: Lesarten, Story-Flags,
	# freigeschaltete Charms und das Grab des letzten Runs.
	game = GameController.new(seed, meta, setup)
	report = null
	_announced.clear()
	save_run()
	return game

## Vorfuehrung eines Bosskampfs (Vertical Slice, docs/VERTICAL_SLICE.md):
## ein echter Run, dessen Akt-I- bzw. Aktboss boss_id ist, vom Autopiloten
## bis vor den Bosskampf gespielt. Nichts wird gespeichert oder verbucht.
## Liefert null, wenn kein passender Seed gefunden wurde.
func starte_vorfuehrung(boss_id: String, max_seeds := 400) -> GameController:
	var pilot := Autopilot.new()
	for seed in range(1, max_seeds + 1):
		var g := GameController.new(seed)
		var akt := g.run.act_bosses.find(boss_id) + 1
		if akt <= 0 or akt > ActCatalog.ACT_COUNT:
			continue
		var ziel := akt * ActCatalog.FIGHTS_PER_ACT - 1
		var guard := 0
		while g.phase != Enums.GamePhase.GAME_OVER and guard < 4000:
			guard += 1
			if g.phase == Enums.GamePhase.COMBAT and g.run.fight_index == ziel:
				break
			pilot.step(g)
		if g.phase == Enums.GamePhase.COMBAT and g.combat.enemy.definition.id == boss_id:
			game = g
			report = null
			_announced.clear()
			vorfuehrung = true
			vorfuehrung_boss = boss_id
			return g
	return null

## Ein Seed, der sicher in JSON-Zahlen passt (unter 2^53).
static func fresh_seed() -> int:
	return (int(Time.get_unix_time_from_system()) << 20) ^ (Time.get_ticks_usec() & 0xFFFFF)

func has_run() -> bool:
	return game != null

## Nach einem Zug: Momente, die nicht im Protokoll untergehen duerfen.
## Gibt den Text fuer die Einblendung zurueck (leer = nichts).
func after_turn(turn: TurnResult) -> String:
	var lines: Array[String] = []
	if game == null:
		return ""
	if vorfuehrung:
		return "DER TURM IST GEFALLEN" if turn != null and turn.victory else ""
	for p in meta.pending_fulfilled(game.run):
		if not _announced.has(p.id):
			_announced[p.id] = true
			lines.append("PROPHEZEIUNG ERFÜLLT\n%s\n%s" % [p.title, p.reward_text()])
	if turn != null:
		if turn.new_best_hit:
			lines.append("NEUER REKORD: Legung im Wert von %d" % game.run.stats.best_hit)
		if turn.card_lost != "":
			lines.append("DER TOD NIMMT %s" % turn.card_lost.to_upper())

	if game.phase == Enums.GamePhase.GAME_OVER:
		complete_run_once()
	elif game.phase != Enums.GamePhase.COMBAT:
		# Jeder gewonnene Kampf zaehlt als Begegnung mit den Grossen Arkana
		# im Deck - so wachsen die Lesarten (wie im Unity-Frontend).
		for card in game.run.deck:
			if card.definition.is_major():
				meta.encounter_arcanum(card.definition.id)
		save_meta()
	save_run()
	return "\n\n".join(lines)

## Verbucht den Run genau einmal und loescht den Speicherstand.
func complete_run_once() -> RunReport:
	if report != null or game == null:
		return report
	if vorfuehrung:
		report = RunReport.new()
		report.headline = "DER VORHANG FÄLLT"
		return report
	var killed_by := ""
	if not game.run.won and game.combat != null:
		killed_by = game.combat.enemy.definition.name
	report = meta.complete_run(game, null, killed_by)
	save_meta()
	_clear_run_file()
	return report

func abandon_to_title() -> void:
	game = null
	report = null
	vorfuehrung = false

# ---------------------------------------------------------- Speichern
func save_run() -> void:
	if game == null or vorfuehrung:
		return
	if game.phase == Enums.GamePhase.GAME_OVER:
		_clear_run_file()
		return
	var f := FileAccess.open(run_save, FileAccess.WRITE)
	if f != null:
		f.store_string(game.save())

func save_meta() -> void:
	var f := FileAccess.open(meta_save, FileAccess.WRITE)
	if f != null:
		f.store_string(meta.serialize())

func _load_run() -> void:
	if not FileAccess.file_exists(run_save):
		return
	var save := SaveSystem.try_deserialize(FileAccess.get_file_as_string(run_save))
	if save == null:
		# Ein kaputter Stand darf den Einstieg nicht blockieren.
		push_warning("Speicherstand unlesbar, zurück zum Titel.")
		_clear_run_file()
		return
	game = GameController.restore(save)
	setup = RunSetup.new(game.run.deuter_id, game.run.veil, game.run.is_daily)

func _load_meta() -> MetaProgress:
	if not FileAccess.file_exists(meta_save):
		return MetaProgress.new()
	return MetaProgress.deserialize(FileAccess.get_file_as_string(meta_save))

func _clear_run_file() -> void:
	if FileAccess.file_exists(run_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(run_save))
