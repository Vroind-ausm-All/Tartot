# Die Wurzel: schaltet zwischen den Schirmen um.
#
# Bewusst eine simple Zustandsmaschine statt eines Szenen-Routers - das Spiel
# hat wenige Schirme, und jeder kennt nur den Run, nie die anderen Schirme.
extends Control

const Konst := preload("res://core/konst.gd")

enum Schirm { DEUTERWAHL, WEG, KAMPF, BELOHNUNG, ENDE }

var katalog: Katalog
var run: Run = null
var schirm: int = Schirm.DEUTERWAHL
var _aktuell: Control = null
var _kampf: Kampf = null

func _ready() -> void:
	katalog = Katalog.new()
	if not katalog.laden():
		for f in katalog.fehler:
			push_error("Katalogfehler: %s" % f)
	_zeige_deuterwahl()

func _wechsle(neu: Control) -> void:
	if _aktuell != null:
		_aktuell.queue_free()
	_aktuell = neu
	add_child(neu)

func _seite(titel: String, untertitel: String = "") -> VBoxContainer:
	var hintergrund := ColorRect.new()
	hintergrund.color = Thema.TIEF
	hintergrund.set_anchors_preset(Control.PRESET_FULL_RECT)
	var wurzel := Control.new()
	wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wurzel.add_child(hintergrund)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 60
	box.offset_bottom = -60
	box.add_theme_constant_override("separation", 22)
	wurzel.add_child(box)
	box.add_child(Thema.label(titel, 52, Thema.ELFENBEIN))
	if untertitel != "":
		box.add_child(Thema.label(untertitel, 26, Thema.GRAU,
			HORIZONTAL_ALIGNMENT_CENTER, true))
	_wechsle(wurzel)
	return box

func _knopf(text: String, untertext: String = "", grund: Color = Thema.SCHWARZ,
		rand: Color = Thema.OCKER) -> Button:
	var b := Button.new()
	b.text = text if untertext == "" else "%s\n%s" % [text, untertext]
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", Thema.ELFENBEIN)
	b.add_theme_stylebox_override("normal", Thema.knopf_stil(grund, rand))
	b.add_theme_stylebox_override("hover", Thema.knopf_stil(Thema.SCHWARZ, Thema.ELFENBEIN))
	b.add_theme_stylebox_override("pressed", Thema.knopf_stil(Thema.SCHWARZ, Thema.ELFENBEIN))
	b.custom_minimum_size.y = 120
	return b

# ------------------------------------------------------------- Deuterwahl
func _zeige_deuterwahl() -> void:
	var box := _seite("TARTOT", "Waehle, wer die Karten legt.")
	for id in katalog.deuter.keys():
		var d: Dictionary = katalog.deuter[id]
		if not bool(d.get("freigeschaltet", false)):
			continue
		var b := _knopf(String(d.get("name", id)),
			"%d HP  -  %s" % [int(d.get("hp", 70)), String(d.get("untertitel", ""))])
		b.pressed.connect(_run_starten.bind(String(id)))
		box.add_child(b)
	box.add_child(Thema.label(
		"Jeder Zug ist eine Legung: Vergangenheit wirkt zu 70 % und wiederholt "
		+ "deine letzte Gegenwart. Gegenwart wirkt voll. Zukunft wirkt doppelt, "
		+ "aber erst naechste Runde - wenn du so lange lebst.", 22, Thema.GRAU,
		HORIZONTAL_ALIGNMENT_CENTER, true))

func _run_starten(deuter_id: String) -> void:
	run = Run.neu(katalog, deuter_id, 0)
	_zeige_weg()

# ------------------------------------------------------------------- Weg
func _zeige_weg() -> void:
	if run.vorbei:
		_zeige_ende()
		return
	run.wegkarten_ziehen()
	var box := _seite("WOHIN FUEHRT DEIN WEG?",
		"Abschnitt %d  -  Raum %d  -  %d HP  -  %d Gold  -  Verderbnis %d"
		% [run.abschnitt, run.raum_nr + 1, run.spieler.hp, run.gold, run.verderbnis])
	for i in run.wegkarten.size():
		var w: Dictionary = run.wegkarten[i]
		var b := _knopf(String(w["name"]).to_upper(), String(w["text"]))
		b.pressed.connect(_weg_gewaehlt.bind(i))
		box.add_child(b)
	box.add_child(Thema.label("Deck: %d Karten  -  Charms: %d Stacks  -  Luck %d"
		% [run.deck.size(), run.charms.gesamt_stacks(), run.luck], 24, Thema.GRAU))

func _weg_gewaehlt(index: int) -> void:
	var typ: int = run.weg_waehlen(index)
	match typ:
		Konst.Raum.KAMPF, Konst.Raum.ELITE, Konst.Raum.BOSS:
			_zeige_kampf()
		Konst.Raum.RUHE:
			var g: int = run.spieler.heilen(int(float(run.spieler.hp_max) * 0.3))
			_zeige_hinweis("RAST", "Kurz nichts. Das ist selten.\n+%d HP" % g)
		Konst.Raum.HAENDLER:
			_zeige_haendler()
		Konst.Raum.RITUAL:
			_zeige_ritual()
		Konst.Raum.TRUHE:
			var cid: String = run.belohnung_charm()
			if cid != "":
				run.charms.geben(cid, 1)
				_zeige_hinweis("TRUHE", "Darin liegt: %s\n%s"
					% [String(katalog.charms[cid].get("name", cid)),
					   String(katalog.charms[cid].get("text", ""))])
			else:
				_zeige_hinweis("TRUHE", "Leer. Natuerlich.")
		_:
			if run.rng.chance(0.55):
				run.gold += 25
				_zeige_hinweis("UNBEKANNT", "Jemand hat etwas liegen lassen.\n+25 Gold")
			else:
				var schaden: int = int(float(run.spieler.hp_max) * 0.12)
				run.spieler.direktschaden(schaden)
				run.verderbnis = mini(Konst.VERDERBNIS_MAX, run.verderbnis + 3)
				_zeige_hinweis("UNBEKANNT",
					"Es war schon dort, bevor du hereinkamst.\n-%d HP, +3 Verderbnis" % schaden)

func _zeige_hinweis(titel: String, text: String) -> void:
	var box := _seite(titel, text)
	var b := _knopf("WEITER")
	b.pressed.connect(_zeige_weg)
	box.add_child(b)

# ----------------------------------------------------------------- Kampf
func _zeige_kampf() -> void:
	_kampf = run.kampf_starten(Wahl.new())
	var schirm_kampf := Kampfschirm.new(_kampf, katalog)
	schirm_kampf.kampf_vorbei.connect(_kampf_beendet)
	_wechsle(schirm_kampf)

func _kampf_beendet(gewonnen: bool) -> void:
	var erg: Dictionary = run.kampf_beenden(_kampf)
	if not gewonnen:
		_zeige_ende()
		return
	_zeige_belohnung(erg)

# ------------------------------------------------------------ Belohnung
func _zeige_belohnung(erg: Dictionary) -> void:
	var neue_charms: Array = erg.get("charms", [])
	var untertitel: String = "+%d Gold" % int(erg.get("gold", 0))
	for cid in neue_charms:
		untertitel += "  -  %s" % String(katalog.charms[cid].get("name", cid))
	var box := _seite("WAEHLE EINE KARTE", untertitel)
	var reihe := HBoxContainer.new()
	reihe.alignment = BoxContainer.ALIGNMENT_CENTER
	reihe.add_theme_constant_override("separation", 14)
	box.add_child(reihe)
	for k in run.belohnung_karten(3):
		var blatt := Kartenblatt.new(k, katalog, 220.0)
		blatt.angetippt.connect(func(b: Kartenblatt):
			run.deck.append(b.karte)
			_nach_belohnung(erg))
		reihe.add_child(blatt)
	var b := _knopf("UEBERSPRINGEN", "Ein kleines Deck ist ein gutes Deck.")
	b.pressed.connect(func(): _nach_belohnung(erg))
	box.add_child(b)

func _nach_belohnung(erg: Dictionary) -> void:
	if erg.has("beute"):
		_zeige_beute(erg["beute"])
	else:
		_zeige_weg()

## Nach einem Boss: was macht man mit dem Omen?
func _zeige_beute(optionen: Array) -> void:
	var box := _seite("DAS OMEN IST GEFALLEN",
		"Seine Tinte ist noch warm. Sie faerbt, was du damit beruehrst.")
	for o in optionen:
		var b := _knopf(String(o["name"]), String(o["text"]))
		b.pressed.connect(func():
			run.beute_waehlen(String(o["id"]))
			if run.gewonnen and not run.endlos:
				_zeige_spirale()
			else:
				_zeige_weg())
		box.add_child(b)

func _zeige_spirale() -> void:
	var box := _seite("DIE WELT IST NICHT DAS ENDE",
		"XXII - Das Schicksal. Eine Karte, die es im Tarot nicht gibt.\n"
		+ "Alle fuenf Raeume nimmt die Spirale ein verderbtes Arkanum auf. "
		+ "Sie bleiben. Sie stapeln sich.")
	var a := _knopf("IN DIE SPIRALE", "Endlosmodus - so tief du kommst.")
	a.pressed.connect(func():
		run.endlos_beginnen()
		_zeige_weg())
	box.add_child(a)
	var b := _knopf("HIER AUFHOEREN", "Den Run als Sieg beenden.")
	b.pressed.connect(_zeige_ende)
	box.add_child(b)

# ---------------------------------------------------------- Haendler
func _zeige_haendler() -> void:
	var box := _seite("DER HAENDLER",
		"Sein Mantel oeffnet sich. Darin haengt zu viel.  -  %d Gold" % run.gold)
	var kosten_loeschen: int = run.kosten_loeschen()
	var a := _knopf("VERGESSEN", "Karte loeschen - %d Gold" % kosten_loeschen)
	a.disabled = run.gold < kosten_loeschen or run.deck.size() <= Konst.DECK_MIN_GROESSE
	a.pressed.connect(func():
		var weg: Karte = Wahl._extrem(run.deck, false)
		if weg != null and run.karte_loeschen(weg):
			run.gold -= kosten_loeschen
		_zeige_haendler())
	box.add_child(a)

	var preis_spiegeln: int = run.preis(Konst.KOSTEN_SPIEGELN)
	var b := _knopf("SPIEGELN", "Karte kopieren - %d Gold" % preis_spiegeln)
	b.disabled = run.gold < preis_spiegeln
	b.pressed.connect(func():
		var beste: Karte = Wahl._extrem(run.deck, true)
		if beste != null:
			run.karte_spiegeln(beste)
			run.gold -= preis_spiegeln
		_zeige_haendler())
	box.add_child(b)

	var preis_aufwerten: int = run.preis(Konst.KOSTEN_AUFWERTEN)
	var c := _knopf("GOLDENE NADEL", "Karte verbessern - %d Gold" % preis_aufwerten)
	c.disabled = run.gold < preis_aufwerten
	c.pressed.connect(func():
		var ziel: Karte = Wahl._extrem(run.deck, true)
		if ziel != null and run.karte_aufwerten(ziel):
			run.gold -= preis_aufwerten
		_zeige_haendler())
	box.add_child(c)

	var cid: String = run.belohnung_charm()
	if cid != "":
		var preis_charm: int = run.preis(60)
		var d := _knopf(String(katalog.charms[cid].get("name", cid)),
			"%s - %d Gold" % [String(katalog.charms[cid].get("text", "")), preis_charm])
		d.disabled = run.gold < preis_charm
		d.pressed.connect(func():
			if run.charms.geben(cid, 1) > 0:
				run.gold -= preis_charm
			_zeige_haendler())
		box.add_child(d)

	var w := _knopf("WEITERGEHEN")
	w.pressed.connect(_zeige_weg)
	box.add_child(w)

# ------------------------------------------------------------ Ritual
func _zeige_ritual() -> void:
	var box := _seite("RITUAL", "Du veraenderst nicht nur Zahlen. Du formst dein Deck.")
	var a := _knopf("VERGESSEN", "Loesche deine schwaechste Karte permanent.")
	a.disabled = run.deck.size() <= Konst.DECK_MIN_GROESSE
	a.pressed.connect(func():
		var weg: Karte = Wahl._extrem(run.deck, false)
		if weg != null:
			run.karte_loeschen(weg)
		_zeige_weg())
	box.add_child(a)
	var b := _knopf("SPIEGELN", "Kopiere deine staerkste Karte permanent.")
	b.pressed.connect(func():
		var beste: Karte = Wahl._extrem(run.deck, true)
		if beste != null:
			run.karte_spiegeln(beste)
		_zeige_weg())
	box.add_child(b)
	var c := _knopf("UMDREHEN", "Drehe deine staerkste Karte auf ihre umgekehrte Seite.")
	c.pressed.connect(func():
		var beste: Karte = Wahl._extrem(run.deck, true)
		if beste != null:
			run.karte_umdrehen(beste)
		_zeige_weg())
	box.add_child(c)

# -------------------------------------------------------------- Ende
func _zeige_ende() -> void:
	var titel: String = "DIE LEGUNG IST BEENDET" if run.gewonnen else "DU FAELLST"
	var box := _seite(titel,
		"Abschnitt %d, Raum %d  -  Deck %d Karten  -  Charms %d  -  Verderbnis %d"
		% [run.abschnitt, run.raum_nr, run.deck.size(),
		   run.charms.gesamt_stacks(), run.verderbnis])
	for zeile in run.log.slice(maxi(0, run.log.size() - 8)):
		box.add_child(Thema.label(zeile, 22, Thema.GRAU))
	var b := _knopf("NOCH EINMAL")
	b.pressed.connect(_zeige_deuterwahl)
	box.add_child(b)
