extends Control

var current: Control
var music: AudioStreamPlayer
var projector: AudioStreamPlayer
var last_report: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_audio()
	if Spiel.run != null:
		_show_current()
	else:
		_show_title()

func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.stream = AudioBank.music()
	music.volume_db = -18
	music.autoplay = true
	add_child(music)
	projector = AudioStreamPlayer.new()
	projector.stream = AudioBank.projector()
	projector.volume_db = -25
	projector.autoplay = true
	add_child(projector)

func _replace(node: Control) -> void:
	if current != null:
		current.queue_free()
	current = node
	add_child(current)

func _page(title: String, subtitle: String = "") -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Thema.DEEP
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var film := FilmOverlay.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(film)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	box.add_child(Thema.label(title, 14, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
	if subtitle != "":
		box.add_child(Thema.label(subtitle, 6, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER, true))
	_replace(root)
	return box

func _button(box: Container, text: String, action: Callable, primary := false) -> Button:
	var b := Thema.button(text, primary)
	b.pressed.connect(action)
	box.add_child(b)
	return b

func _show_title() -> void:
	var meta := Spiel.meta
	var subtitle := "SCHICKSAL AUF ZELLULOID
Ein verfluchter Zeichentrickfilm von 1932."
	if meta.runs > 0:
		subtitle = "%d Runs · %d Siege · Schleier %d" % [meta.runs, meta.wins, meta.veil]
	var box := _page("T A R T O T", subtitle)
	box.add_child(Thema.label("DEUTER", 6, Thema.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for id in Spiel.katalog.deuters:
		var d: Dictionary = Spiel.katalog.deuter_def(String(id))
		var unlocked := meta.is_deuter_unlocked(Spiel.katalog, String(id))
		var text := "%s
%s" % [String(d["name"]).to_upper(), String(d["subtitle"])]
		var b := _button(box, text, _choose_deuter.bind(String(id)))
		b.disabled = not unlocked
		if not unlocked:
			b.tooltip_text = "Gesperrt durch Prophezeiung: %s" % String(d.get("unlock", ""))
	var daily := _button(box, "TAGESKARTE
Gleicher Seed für alle", _start_daily, true)
	daily.tooltip_text = str(Spiel.daily_seed())

func _choose_deuter(id: String) -> void:
	var box := _page(String(Spiel.katalog.deuter_def(id)["name"]).to_upper(), "Wähle den Schleier.")
	for v in range(Spiel.meta.veil + 1):
		var def: Dictionary = Spiel.katalog.veils[v]
		_button(box, "SCHLEIER %d · %s
%s" % [v, def["name"], def["text"]], func(): Spiel.new_run(id, v); _show_current(), v == 0)
	_button(box, "ZURÜCK", _show_title)

func _start_daily() -> void:
	var seed := Spiel.daily_seed()
	var ids := Spiel.katalog.deuters.keys()
	var deuter := String(ids[posmod(seed, ids.size())])
	var veil := posmod(seed / 10, 3)
	Spiel.new_run(deuter, veil, seed, true)
	_show_current()

func _show_current() -> void:
	var run := Spiel.run
	if run == null:
		_show_title()
		return
	_update_audio(run.darkness)
	match run.phase:
		Konst.Phase.COMBAT: _show_combat()
		Konst.Phase.REWARD: _show_reward()
		Konst.Phase.PATH: _show_path()
		Konst.Phase.SHOP: _show_shop()
		Konst.Phase.RITUAL: _show_ritual()
		Konst.Phase.ORACLE: _show_oracle()
		Konst.Phase.EVENT: _show_event()
		Konst.Phase.BOSS_LOOT: _show_boss_loot()
		Konst.Phase.REST: _show_rest()
		Konst.Phase.VICTORY: _show_victory()
		Konst.Phase.GAME_OVER: _show_report()

func _show_combat() -> void:
	if Spiel.run.combat == null:
		Spiel.run.phase = Konst.Phase.PATH
		Spiel.run.build_paths()
		_show_path()
		return
	var view := Kampfschirm.new(Spiel.run)
	view.finished.connect(_show_current)
	_replace(view)

func _show_path() -> void:
	var r := Spiel.run
	var next := r.next_enemy_name()
	var box := _page("WOHIN FÜHRT DEIN WEG?", "%s · %d/%d HP · %d Gold · Dunkel %d
Nächstes Omen: %s" % [_where(r), r.hp, r.max_hp, r.gold, r.darkness, next])
	for i in r.paths.size():
		var index := i
		_button(box, String(r.paths[i]["label"]), func(): r.choose_path(index); Spiel.save_run(); _show_current(), i == 0)
	box.add_child(Thema.label("Deck %d · Charms %d · Fate %d" % [r.deck.size(), _charm_count(r), r.fate], 5, Thema.SEPIA2, HORIZONTAL_ALIGNMENT_CENTER))

func _show_reward() -> void:
	var r := Spiel.run
	var box := _page("WÄHLE EINE BELOHNUNG", "Der Film hält kurz an.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	for i in r.rewards.size():
		var index := i
		var reward: Dictionary = r.rewards[i]
		if reward["type"] == "card":
			var card: Karte = reward["card"]
			var wrap := VBoxContainer.new()
			var cv := Kartenblatt.new(card)
			cv.custom_minimum_size = Vector2(64, 96)
			cv.chosen.connect(func(_c): r.choose_reward(index); Spiel.save_run(); _show_current())
			wrap.add_child(cv)
			wrap.add_child(Thema.label(card.name(), 4, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
			row.add_child(wrap)
		else:
			_button(box, String(reward.get("title", "Fate")), func(): r.choose_reward(index); Spiel.save_run(); _show_current())
	_button(box, "ÜBERSPRINGEN · +10 Fate", func(): r.fate += 10; r.choose_reward(-1); Spiel.save_run(); _show_current())

func _show_shop() -> void:
	var r := Spiel.run
	var box := _page("DER HÄNDLER", "%d Gold · Sein Mantel öffnet sich." % r.gold)
	var remove_cost := 45 + int(r.removed_cards.size()) * 25
	var rem := _button(box, "VERGESSEN · %d Gold
Schwächste Karte permanent entfernen" % remove_cost, func(): r.gold -= remove_cost; r._remove_weakest(); Spiel.save_run(); _show_shop())
	rem.disabled = r.gold < remove_cost or r.deck.size() <= Konst.MIN_DECK
	var refine_cost := 70 + int(r.removed_cards.size()) * 30
	var ref := _button(box, "VEREDELN · %d Gold
Stärkste Karte +1 und dunkler" % refine_cost, func(): r.gold -= refine_cost; var k = r._strongest(); if k: k.upgrade(); k.darken(); r.add_darkness(3); Spiel.save_run(); _show_shop())
	ref.disabled = r.gold < refine_cost
	_button(box, "WEITERGEHEN", func(): r.phase = Konst.Phase.PATH; r.build_paths(); Spiel.save_run(); _show_current(), true)

func _show_ritual() -> void:
	var r := Spiel.run
	var box := _page("RITUAL", "Forme dein Deck, nicht nur Zahlen.")
	var rem := _button(box, "VERGESSEN
Schwächste Karte entfernen", func(): r._remove_weakest(); r.phase = Konst.Phase.PATH; r.build_paths(); Spiel.save_run(); _show_current())
	rem.disabled = r.deck.size() <= Konst.MIN_DECK
	_button(box, "SPIEGELN
Stärkste Karte kopieren", func(): var k = r._strongest(); if k: r.deck.append(k.clone("ritual-copy-%d" % r.deck.size())); r.phase = Konst.Phase.PATH; r.build_paths(); Spiel.save_run(); _show_current())
	_button(box, "UMDREHEN
Stärkste Karte verkehren", func(): var k = r._strongest(); if k: k.flip(); r.phase = Konst.Phase.PATH; r.build_paths(); Spiel.save_run(); _show_current())

func _show_oracle() -> void:
	var r := Spiel.run
	var box := _page("DAS ORAKEL", "Drei Prophezeiungen. Eine gilt.")
	var pending := Spiel.katalog.prophecies.filter(func(p): return not Spiel.meta.completed.has(String(p["id"])))
	for p in pending.slice(0, 3):
		var v := Spiel.meta.prophecy_value(p, r)
		box.add_child(Thema.label("%s
%s · %d/%d" % [p["title"], p["text"], v, p["target"]], 6, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
	_button(box, "WEITER", func(): r.phase = Konst.Phase.PATH; r.build_paths(); Spiel.save_run(); _show_current(), true)

func _show_event() -> void:
	var r := Spiel.run
	var e := r.current_event
	var box := _page(String(e.get("title", "EREIGNIS")).to_upper(), "")
	var art := PixelArt.new(String(e.get("art", "")))
	art.custom_minimum_size = Vector2(160, 96)
	var center := CenterContainer.new()
	center.add_child(art)
	box.add_child(center)
	for beat in e.get("beats", []):
		box.add_child(Thema.label(String(beat), 6, Thema.PAPER, HORIZONTAL_ALIGNMENT_CENTER, true))
	if r.event_resolved:
		box.add_child(Thema.label(r.event_epilogue, 6, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
		_button(box, "WEITER", func(): r.continue_event(); Spiel.save_run(); _show_current(), true)
	else:
		var choices: Array = e.get("choices", [])
		for i in choices.size():
			var idx := i
			var c: Dictionary = choices[i]
			_button(box, "%s
%s" % [c["label"], c.get("hint", "")], func(): r.resolve_event(idx); Spiel.save_run(); _show_event())

func _show_boss_loot() -> void:
	var r := Spiel.run
	var box := _page("DAS OMEN FÄLLT", "Was geschieht mit seiner Tinte?")
	_button(box, "TRÄNKEN
Drei starke Karten wachsen und dunkeln nach", func(): r.boss_loot("soak"); Spiel.save_run(); _show_current())
	_button(box, "BINDEN
Das Omen kommt verkehrt und blutig ins Deck", func(): r.boss_loot("bind"); Spiel.save_run(); _show_current())
	_button(box, "BANNEN
Gold, Heilung, etwas Licht", func(): r.boss_loot("banish"); Spiel.save_run(); _show_current(), true)

func _show_rest() -> void:
	var r := Spiel.run
	var box := _page("RAST", "%d/%d HP · Ruhe oder lies neu." % [r.hp, r.max_hp])
	_button(box, "RUHEN", func(): r.rest_heal(); Spiel.save_run(); _show_current(), true)
	var k := r._strongest()
	if k != null:
		_button(box, "NEU LESEN
%s +1" % k.name(), func(): r.rest_study(k); Spiel.save_run(); _show_current())

func _show_victory() -> void:
	var r := Spiel.run
	var box := _page("DIE WELT IST NICHT DAS ENDE.", "Hinter dem letzten Bild dreht sich die Schwarze Spirale.")
	_button(box, "IN DIE SPIRALE", func(): r.continue_spiral(); Spiel.save_run(); _show_current(), true)
	_button(box, "DEN RUN BEENDEN", func(): r.end_run(); _show_report())

func _show_report() -> void:
	if Spiel.run != null:
		last_report = Spiel.finish_run()
	var box := _page(String(last_report.get("headline", "DU FÄLLST")), "Der Film ist gerissen.")
	for u in last_report.get("unlocked", []):
		box.add_child(Thema.label("NEU · %s" % u, 6, Thema.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, true))
	for n in last_report.get("near", []):
		box.add_child(Thema.label("BEINAHE · %s
%s" % [n["title"], n["detail"]], 5, Thema.SEPIA1, HORIZONTAL_ALIGNMENT_CENTER, true))
	_button(box, "NOCH EINMAL", _show_title, true)

func _where(r: Run) -> String:
	if r.is_finale():
		return "FINALE"
	if r.is_spiral():
		return "SPIRALE %d" % Konst.spiral_depth(r.fight_index)
	return "AKT %s · KAMPF %d/5" % [Konst.roman(r.current_act()), r.fight_index % 5 + 1]

func _charm_count(r: Run) -> int:
	var n := 0
	for id in r.charms:
		n += int(r.charms[id])
	return n

func _update_audio(darkness: int) -> void:
	if music != null:
		music.pitch_scale = 1.0 - minf(0.08, darkness * 0.0008)
	if projector != null:
		projector.pitch_scale = 1.0 - minf(0.045, darkness * 0.00045)
