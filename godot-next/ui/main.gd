extends Control
## Hauptbildschirm: Titel, dann je Spielphase eine Seite. Jede Entscheidung
## geht an den GameController; die Texte folgen dem Unity-Frontend
## (TartotView.Overlays.cs), damit beide Oberflaechen dasselbe sagen.
##
## Der Kampf ist der Kartentisch (ui/tisch/kampftisch.gd, 1080 x 1920); die
## anderen Seiten stehen im selben Stil (Thema -> TarotStil). Musik, Klaenge
## und Haptik kommen aus einem KartenKlang-Knoten. Karten auf den Seiten
## sind dieselben TarotKarten wie am Tisch; langes Druecken erklaert sie.

const P := Enums.GamePhase

var current: Control
var klang: KartenKlang
var detail: KartenDetail
## Shop: false = Vergessen, true = Veredeln.
var shop_refine := false
## Ritual-Modus: 0 Vergessen, 1 Spiegeln, 2 Umkehren, 3 Entwickeln.
var ritual_mode := 0
## Titel: gewaehlte Figur und Schleier.
var title_deuter := DeuterCatalog.DEFAULT_ID
var title_veil := 0
## Ereignis: wie viele Beats schon zu sehen sind.
var event_id := ""
var event_beat := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_audio()
	title_deuter = Spiel.setup.deuter_id
	title_veil = Spiel.setup.veil
	show_current()

func _setup_audio() -> void:
	klang = KartenKlang.new()
	add_child(klang)
	var oben := CanvasLayer.new()
	oben.layer = 15
	add_child(oben)
	detail = KartenDetail.new()
	oben.add_child(detail)

# ------------------------------------------------------------ Seiten
func _replace(node: Control) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(current)

func _page(title: String, subtitle: String = "") -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = ShaderMaterial.new()
	(bg.material as ShaderMaterial).shader = load("res://ui/tisch/filmgrund.gdshader")
	root.add_child(bg)
	var film := FilmOverlay.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(film)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 64)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	box.add_child(Thema.label(title, 14, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
	if subtitle != "":
		box.add_child(Thema.label(subtitle, 6, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER, true))
	_replace(root)
	return box

func _button(box: Container, text: String, action: Callable, primary := false) -> Button:
	var b := Thema.button(text, primary)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	box.add_child(b)
	return b

func _line(box: Container, text: String, size := 6, color := Thema.PAPER) -> Label:
	var l := Thema.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER, true)
	box.add_child(l)
	return l

## Fuehrt eine Aktion aus, speichert und zeigt die passende Seite.
func _act(action: Callable) -> void:
	action.call()
	Spiel.save_run()
	show_current()

## Eine Reihe Karten zum Antippen.
func _card_grid(box: Container, cards: Array, on_card: Callable, enabled: Callable = Callable()) -> void:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	var center := CenterContainer.new()
	center.add_child(grid)
	box.add_child(center)
	for c in cards:
		var view := _kartenblatt(c)
		var ok: bool = enabled.call(c) if enabled.is_valid() else true
		if ok:
			view.chosen.connect(on_card)
		else:
			view.modulate = Color(1, 1, 1, 0.35)
		grid.add_child(view)

## Eine Karte zum Antippen; langes Druecken zeigt sie gross mit Erklaerung.
func _kartenblatt(c: CardInstance) -> Kartenblatt:
	var view := Kartenblatt.new(c)
	view.lange_gedrueckt.connect(func(k, punkt): detail.zeigen(k, punkt))
	view.lang_bewegt.connect(func(punkt): detail.finger(punkt))
	view.lang_losgelassen.connect(func(): detail.verbergen())
	return view

# ---------------------------------------------------------- Ablauf
func show_current() -> void:
	var game := Spiel.game
	if game == null:
		_show_title()
		return
	if Spiel.vorfuehrung and game.phase not in [P.COMBAT, P.BOSS_LOOT, P.GAME_OVER]:
		_show_vorfuehrung_ende()
		return
	detail.verbergen(true)
	if game.phase != P.COMBAT:
		KartenKlang.musik("walzer", false)
	match game.phase:
		P.COMBAT: _show_combat()
		P.REWARD: _show_reward()
		P.PATH_CHOICE: _show_path()
		P.SHOP: _show_shop()
		P.RITUAL: _show_ritual()
		P.ORACLE: _show_oracle()
		P.EVENT: _show_event()
		P.BOSS_LOOT: _show_boss_loot()
		P.REST: _show_rest()
		P.VICTORY: _show_victory()
		P.GAME_OVER: _show_report()

func _show_title() -> void:
	var meta := Spiel.meta
	var done := meta.completed_prophecies.size()
	var subtitle := "Lege drei Karten. Lies dein Schicksal. Ändere es."
	if meta.runs_started > 0:
		subtitle = "%d Runs · %d Siege · Prophezeiungen %d/%d%s" % [meta.runs_started, meta.runs_won, done,
			ProphecyCatalog.all().size(), " · Spirale %d" % meta.best_spiral_depth if meta.best_spiral_depth > 0 else ""]
	var box := _page("T A R T O T", subtitle)
	_line(box, "DEUTER", 6, Thema.GOLD)
	for deuter in DeuterCatalog.all():
		var unlocked := meta.is_deuter_unlocked(deuter.id)
		var chosen := title_deuter == deuter.id
		var hint := deuter.rule_text
		if not unlocked:
			var p := ProphecyCatalog.find(deuter.unlocked_by)
			hint = "Gesperrt — " + (p.text if p != null else "")
		var id := deuter.id
		var b := _button(box, "%s%s — %s\n%s" % ["▸ " if chosen else "", deuter.name, deuter.subtitle, hint],
			func(): title_deuter = id; _show_title(), chosen)
		b.disabled = not unlocked

	var veil := mini(title_veil, meta.veil)
	var def := DeuterCatalog.veil(veil)
	var vb := _button(box, "SCHLEIER %d: %s — %s%s" % [veil, def["name"], def["text"],
		"\n(tippen zum Wechseln)" if meta.veil > 0 else "\nGewinne einen Run, um den ersten Schleier zu öffnen."],
		func(): title_veil = 0 if veil >= meta.veil else veil + 1; _show_title())
	vb.disabled = meta.veil <= 0

	_button(box, "RUN BEGINNEN", func():
		var id := title_deuter if meta.is_deuter_unlocked(title_deuter) else DeuterCatalog.DEFAULT_ID
		Spiel.new_run(RunSetup.new(id, veil))
		show_current(), true)

	if OS.is_debug_build() or OS.get_name() == "Web":
		for vorf in [["boss_turm", "XVI DER TURM"], ["boss_tod", "XIII DER TOD"], ["boss_mond", "XVIII DER MOND"]]:
			var boss_id: String = vorf[0]
			_button(box, "VORFÜHRUNG — %s\nder Bosskampf aus einem echten Run, ohne Speichern" % vorf[1],
				func():
					if Spiel.starte_vorfuehrung(boss_id) != null:
						show_current())

	var daily := RunSetup.daily()
	var daily_done := meta.last_daily_seed == MetaProgress.daily_seed()
	_button(box, "TAGESKARTE — %s, Schleier %d%s" % [DeuterCatalog.find(daily.deuter_id).name, daily.veil,
		"\nHeute schon gelegt · bester Wert %d Fate" % meta.best_daily_fate if daily_done else "\nFür alle derselbe Seed."],
		func(): Spiel.new_run(daily); show_current())

func _show_combat() -> void:
	var view := Kampftisch.new(Spiel.game)
	view.finished.connect(show_current)
	_replace(view)

func _show_reward() -> void:
	var game := Spiel.game
	var box := _page("WÄHLE EINE BELOHNUNG", game.message)
	for i in game.rewards.size():
		var index := i
		var reward := game.rewards[i]
		_button(box, "%s\n%s" % [reward.title, reward.description], func(): _act(func(): game.choose_reward(index)))
	_button(box, "ÜBERSPRINGEN — dein Deck bleibt dünn", func(): _act(game.skip_reward_for_fate), true)

static func path_label(path: int) -> String:
	match path:
		Enums.PathType.SHOP: return "HÄNDLER — sein Mantel öffnet sich"
		Enums.PathType.RITUAL: return "RITUAL — forme dein Deck"
		Enums.PathType.ORACLE: return "ORAKEL — eine Prophezeiung"
		Enums.PathType.ELITE: return "ELITE — mehr Gefahr, sichere Charms"
		Enums.PathType.EVENT: return "UNBEKANNT — etwas wartet am Wegrand"
		Enums.PathType.REST: return "RAST — heilen oder eine Karte neu lesen"
	return "KAMPF — kein Umweg (+%d Gold)" % GameController.DIRECT_PATH_GOLD

func _show_path() -> void:
	var game := Spiel.game
	var run := game.run
	var box := _page("WOHIN FÜHRT DEIN WEG?", "%s\n%d Karten · %d Gold · %d/%d HP · Resonanz %d/10" % [
		game.message, run.deck.size(), run.gold, run.hp, run.max_hp, run.deck_resonance])
	# Das naechste Omen steht immer da - wer weiss, was kommt, plant.
	var next := run.fight_index + 1
	if not ActCatalog.is_spiral(next):
		var boss: EnemyDefinition = game.finale_of_run() if ActCatalog.is_finale(next) or run.act() == 4 else game.upcoming_boss()
		var until := ActCatalog.fights_until_boss(next)
		if boss != null:
			_line(box, "ALS NÄCHSTES: %s" % boss.name.to_upper() if until == 0
				else "Noch %d %s bis %s" % [until, "Kampf" if until == 1 else "Kämpfe", boss.name], 6, Thema.GOLD)
			if not boss.rules.is_empty():
				var texts: Array[String] = []
				for r in boss.rules:
					texts.append(ActCatalog.rule_text(r, 0, boss.rules_weakened))
				_line(box, " ".join(texts), 5, Thema.RED)
	for path in game.paths:
		var p := path
		_button(box, path_label(p), func(): _act(func(): game.choose_path(p)))

func _show_shop() -> void:
	var game := Spiel.game
	var run := game.run
	var box := _page("DER HÄNDLER", "%d Gold%s" % [run.gold, " · der nächste Kauf ist umsonst" if run.free_next_shop_purchase else ""])
	for i in game.shop_offers.size():
		var index := i
		var offer := game.shop_offers[i]
		var b := _button(box, "%s — %s" % [offer.reward.title, "verkauft" if offer.sold else "%d Gold" % offer.price],
			func(): game.buy_shop_offer(index); Spiel.save_run(); _show_shop())
		b.disabled = offer.sold or not (run.free_next_shop_purchase or run.gold >= offer.price)
		b.tooltip_text = offer.reward.description
	# Zwei Goldsenken an derselben Deck-Reihe: Vergessen macht das Deck
	# duenner, Veredeln macht eine Karte staerker - und dunkler.
	_line(box, "VEREDELN — %d Gold: eine Stufe hoch, eine Stufe dunkler" % game.refine_price() if shop_refine
		else "VERGESSEN — %d Gold je Karte" % game.removal_price(), 6, Thema.GOLD)
	_card_grid(box, run.deck, func(c: CardInstance):
		if shop_refine:
			game.refine_at_shop(c)
		else:
			game.remove_card_at_shop(c)
		Spiel.save_run()
		_show_shop(),
		func(c: CardInstance) -> bool: return game.can_refine_at_shop(c) if shop_refine else game.can_remove_at_shop(c))
	_line(box, game.message, 5, Thema.SEPIA1)
	_button(box, "ZUM VERGESSEN WECHSELN" if shop_refine else "ZUM VEREDELN WECHSELN", func(): shop_refine = not shop_refine; _show_shop())
	_button(box, "WEITERGEHEN", func(): shop_refine = false; _act(game.continue_from_offgame), true)

const RITUAL_MODES := [
	["VERGESSEN", "Die Karte verlässt das Deck (120 Fate)."],
	["SPIEGELN", "Eine Kopie kommt ins Deck (160 Fate)."],
	["UMKEHREN", "Die Karte dreht sich um (90 Fate)."],
	["ENTWICKELN", "Eine Stufe höher, ein Schimmer dunkler (220 Fate)."],
]

func _show_ritual() -> void:
	var game := Spiel.game
	var box := _page("RITUAL", "Du veränderst nicht nur Zahlen. Du formst dein Deck.\n%d Fate" % game.run.fate)
	var mode: Array = RITUAL_MODES[ritual_mode]
	_line(box, "%s — %s" % [mode[0], mode[1]], 6, Thema.GOLD)
	_card_grid(box, game.run.deck, func(c: CardInstance):
		var ok := false
		match ritual_mode:
			0: ok = game.ritual_remove(c)
			1: ok = game.ritual_mirror(c)
			2: ok = game.ritual_flip(c)
			_: ok = game.ritual_evolve(c)
		Spiel.save_run()
		if ok:
			_act(game.continue_from_offgame)
		else:
			_show_ritual())
	_line(box, game.message, 5, Thema.SEPIA1)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for i in RITUAL_MODES.size():
		var m := i
		var b := Thema.button(RITUAL_MODES[i][0], i == ritual_mode)
		b.custom_minimum_size = Vector2(228, 110)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(func(): ritual_mode = m; _show_ritual())
		row.add_child(b)
	_button(box, "WEITERGEHEN", func(): _act(game.continue_from_offgame), true)

const ORACLE := [
	["XXI", "Kleine Decks und 21er-Legungen werden belohnt. +1 Luck."],
	["BLUT", "Umgekehrte Karten wachsen schneller."],
	["EINHEIT", "Ein fokussiertes Deck wird belohnt. +60 Fate."],
]

func _show_oracle() -> void:
	var game := Spiel.game
	var box := _page("DAS ORAKEL", "Drei Prophezeiungen. Eine gilt.")
	for o in ORACLE:
		var id: String = o[0]
		_button(box, "%s\n%s" % [o[0], o[1]], func(): game.choose_oracle(id); _act(game.continue_from_offgame))
	_button(box, "WEITERGEHEN", func(): _act(game.continue_from_offgame), true)

## Ein Ereignis spielt sich wie eine kurze Szene: ein Satz nach dem
## anderen, dann die Entscheidung, dann der Schlusssatz.
func _show_event() -> void:
	var game := Spiel.game
	var scene := game.current_event
	if scene == null:
		var b := _page("DER WEG IST STILL")
		_button(b, "WEITERGEHEN", func(): _act(game.continue_from_offgame), true)
		return
	if scene.id != event_id:
		event_id = scene.id
		event_beat = 0
	var box := _page(scene.title.to_upper(), "— eine Geschichte, die sich erinnert —" if scene.is_story() else "")
	box.add_child(_szenenbild(scene.art))
	var beats := scene.beats_for(game.run)
	var shown := beats.size() if game.event_resolved else mini(event_beat + 1, beats.size())
	for i in shown:
		_line(box, beats[i], 6, Thema.PAPER if i < shown - 1 or game.event_resolved else Thema.GOLD_LIGHT)
	if game.event_resolved:
		_line(box, game.event_epilogue, 6, Thema.GOLD_LIGHT)
		_button(box, "WEITERGEHEN", func(): _act(game.continue_from_offgame), true)
		return
	if shown < beats.size():
		_button(box, "…", func(): event_beat += 1; _show_event())
		return
	for i in scene.choices.size():
		var index := i
		var choice := scene.choices[i]
		var b := _button(box, "%s\n%s" % [choice.label, choice.hint], func(): game.choose_event_option(index); Spiel.save_run(); _show_event())
		b.disabled = not game.can_choose_event_option(index)

func _show_boss_loot() -> void:
	var game := Spiel.game
	var omen := game.omen_card()
	var box := _page("DAS OMEN FÄLLT", game.message + "\nWas geschieht mit seiner Tinte?")
	if omen != null:
		var vorschau := CardInstance.new(omen)
		vorschau.level = 2
		vorschau.shimmer = Enums.Shimmer.BLOOD
		vorschau.orientation = Enums.Orientation.REVERSED
		var mitte := CenterContainer.new()
		mitte.add_child(_kartenblatt(vorschau))
		box.add_child(mitte)
	var soak: Array[String] = []
	for c in game.soak_targets():
		soak.append(c.definition.name)
	_button(box, "TRÄNKEN — %s\nje eine Stufe höher und dunkler · +%d Verdunkelung" % [", ".join(soak), GameController.SOAK_DARKNESS],
		func(): _act(func(): game.choose_boss_loot(Enums.BossLootChoice.SOAK)))
	if omen != null:
		_button(box, "BINDEN — %s kommt ins Deck\nverkehrt und blutig · +%d Verdunkelung" % [omen.name, GameController.BIND_DARKNESS],
			func(): _act(func(): game.choose_boss_loot(Enums.BossLootChoice.BIND)))
	_button(box, "BANNEN — +%d Gold, Heilung\n−%d Verdunkelung" % [GameController.BANISH_GOLD, GameController.BANISH_LIGHT],
		func(): _act(func(): game.choose_boss_loot(Enums.BossLootChoice.BANISH)))

func _show_rest() -> void:
	var game := Spiel.game
	var run := game.run
	var box := _page("RAST", "%d / %d HP. Ruhe dich aus – oder lies eine Karte neu." % [run.hp, run.max_hp])
	_button(box, "RUHEN — +%d HP" % game.rest_heal_amount(), func(): _act(game.rest_heal), true)
	_line(box, "ODER EINE KARTE NEU LESEN (+1 Stufe):", 6, Thema.GOLD)
	_card_grid(box, run.deck, func(c: CardInstance): _act(func(): game.rest_study(c)))

func _show_victory() -> void:
	var game := Spiel.game
	var box := _page("DIE WELT IST NICHT DAS ENDE.",
		"Du hast gewonnen. Hinter der Welt dreht sich die Schwarze Spirale – sie hat kein Ende, nur eine Tiefe.")
	_button(box, "IN DIE SPIRALE", func(): _act(game.continue_into_spiral), true)
	_button(box, "DEN RUN BEENDEN", func(): game.end_run(); Spiel.complete_run_once(); show_current())

func _show_report() -> void:
	var report := Spiel.complete_run_once()
	if report == null:
		_show_title()
		return
	var box := _page(report.headline if report.headline != "" else "DU FÄLLST",
		("%s\n" % report.killed_by if report.killed_by != "" else "") +
		"Kampf %d · %d Fate · Verdunkelung %d" % [report.fights_cleared + 1, report.fate_total, report.darkness])
	if report.best_hit > 0:
		_line(box, "Stärkste Legung: %d — %s" % [report.best_hit, report.best_hit_combo], 6)
	if not report.records.is_empty():
		_line(box, "REKORDE", 6, Thema.GOLD)
		for r in report.records:
			_line(box, r, 6, Thema.GOLD_LIGHT)
	if not report.unlocked.is_empty():
		_line(box, "NEU FREIGESCHALTET", 6, Thema.GOLD)
		for u in report.unlocked:
			_line(box, u, 6, Thema.GOLD_LIGHT)
	if not report.near_misses.is_empty():
		_line(box, "BEINAHE", 6, Thema.GOLD)
		for n in report.near_misses:
			_line(box, n.title, 6, Thema.PAPER)
			_line(box, n.detail if n.reward == "" else "%s\n→ %s" % [n.detail, n.reward], 5, Thema.SEPIA1)
			var bar := ProgressBar.new()
			bar.max_value = 1.0
			bar.value = clampf(n.progress, 0.0, 1.0)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 16)
			box.add_child(bar)
	# Ein Tipp bis zum naechsten Run - mit derselben Figur, demselben Schleier.
	_button(box, "NOCH EINMAL", func():
		Spiel.new_run(RunSetup.new(Spiel.setup.deuter_id, Spiel.setup.veil))
		show_current(), true)
	_button(box, "ANDERE FIGUR, ANDERER SCHLEIER", func(): Spiel.abandon_to_title(); show_current())

func _show_vorfuehrung_ende() -> void:
	var game := Spiel.game
	var box := _page("ENDE DER VORFÜHRUNG", game.message)
	_button(box, "NOCH EINMAL", func():
		if Spiel.starte_vorfuehrung(Spiel.vorfuehrung_boss) != null:
			show_current(), true)
	_button(box, "ZUM TITEL", func(): Spiel.abandon_to_title(); show_current())

## Bild einer Szene: eine gemalte Buehne der Boss-Blaetter im Goldrahmen.
## Welche Buehne, haengt fest am Schluessel der Szene.
func _szenenbild(schluessel: String) -> Control:
	var buehnen: Array[String] = []
	for name in DirAccess.get_directories_at("res://buehnen"):
		buehnen.append(name)
	buehnen.sort()
	var rahmen := PanelContainer.new()
	rahmen.add_theme_stylebox_override("panel", TarotStil.platte("tafel.png", Vector4(30, 30, 30, 30), Vector4(14, 14, 14, 14)))
	rahmen.custom_minimum_size = Vector2(0, 470)
	rahmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if buehnen.is_empty():
		return rahmen
	var bild := TextureRect.new()
	bild.texture = load("res://buehnen/%s/hintergrund.jpg" % buehnen[absi(hash(schluessel)) % buehnen.size()])
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bild.modulate = Color(0.85, 0.8, 0.72)
	bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rahmen.add_child(bild)
	return rahmen
