class_name KartenDetail
extends Control
## Langes Druecken auf eine Karte: sie kommt gross in die Mitte, darunter
## klappt die Erklaerung auf. Solange der Finger liegt, kippt die grosse
## Karte mit ihm - so sieht man Folie und Tiefe. Loslassen schliesst.
##
## Gezeigt wird nur, was der Kern sagt (Name, Text, Seltenheit, Edition,
## Rang und Wirkungsfaktor aus KernBruecke.karte_nach). Eine verhuellte
## Karte bleibt verhuellt: der Mond verraet nichts.

const MITTE := Vector2(540, 650)
const GROSS := 2.0
const FARBNAMEN := {"Swords": "Schwerter", "Wands": "Stäbe", "Cups": "Kelche", "Pentacles": "Münzen", "Major": "Große Arkana"}
const SCHIMMER := ["matt", "weiß", "indigo", "gold", "blut", "schwarz"]
const EDITION_FARBEN := {
	"Shimmering": "F4D27A", "Glowing": "9AA8E8", "Burning": "F07A55", "Glass": "C9D6E3",
}

var offen := false

var _grund: ColorRect
var _karte: TarotKarte
var _tafel: PanelContainer
var _name: Label
var _unter: Label
var _text: RichTextLabel
var _start := Vector2.ZERO
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_grund = ColorRect.new()
	_grund.color = Color(0.03, 0.02, 0.02, 0.0)
	_grund.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grund)

	_tafel = PanelContainer.new()
	_tafel.add_theme_stylebox_override("panel", TarotStil.platte("tafel.png", Vector4(30, 30, 30, 30), Vector4(40, 26, 40, 30)))
	_tafel.position = Vector2(60, 1050)
	_tafel.custom_minimum_size = Vector2(960, 0)
	_tafel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tafel)
	var spalte := VBoxContainer.new()
	spalte.add_theme_constant_override("separation", 8)
	_tafel.add_child(spalte)
	_name = TarotStil.label("", 52, TarotStil.GOLD_HELL, false, 4)
	spalte.add_child(_name)
	_unter = TarotStil.label("", 30, TarotStil.PAPIER_DUNKEL, false, 0)
	spalte.add_child(_unter)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(880, 0)
	_text.add_theme_font_override("normal_font", TarotStil.text())
	_text.add_theme_font_override("bold_font", TarotStil.titel())
	_text.add_theme_font_size_override("normal_font_size", 36)
	_text.add_theme_font_size_override("bold_font_size", 34)
	_text.add_theme_color_override("default_color", TarotStil.PAPIER)
	_text.add_theme_constant_override("line_separation", 2)
	spalte.add_child(_text)


## Oeffnet die Erklaerung fuer `quelle`; `finger` ist der Druckpunkt.
func zeigen(quelle: TarotKarte, finger: Vector2) -> void:
	if quelle == null:
		return
	verbergen(true)
	offen = true
	visible = true
	_start = finger
	_karte = TarotKarte.aus_daten(quelle.zustand())
	_karte.basis = GROSS
	_karte.gross = true
	_karte.schwebt = true
	_karte.position = quelle.global_position
	_karte.rotation = quelle.rotation
	_karte.scale = quelle.scale
	add_child(_karte)
	_karte.ziel_position = MITTE
	_karte.ziel_skala = 1.0
	_karte.stossen(0.12)

	_name.text = str(quelle.daten.get("name", quelle.id)).to_upper() if not quelle.verschleiert else "VERHÜLLT"
	_unter.text = _unterzeile(quelle)
	_text.text = _erklaerung(quelle)
	_tafel.reset_size()
	_tafel.position.y = minf(1050.0, 1880.0 - _tafel.size.y)

	_tween = create_tween().set_parallel()
	_grund.color.a = 0.0
	_tween.tween_property(_grund, "color:a", 0.66, 0.16)
	_tafel.modulate.a = 0.0
	_tafel.pivot_offset = Vector2(_tafel.size.x * 0.5, 0)
	_tafel.scale = Vector2(1, 0.6)
	_tween.tween_property(_tafel, "modulate:a", 1.0, 0.14).set_delay(0.06)
	_tween.tween_property(_tafel, "scale", Vector2.ONE, 0.22).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	KartenKlang.spielen("schweben", 0.8, -4.0)
	KartenKlang.fuehlen(18, 0.5)


## Finger bewegt sich: die grosse Karte kippt mit.
func finger(punkt: Vector2) -> void:
	if _karte == null:
		return
	var rel := ((punkt - _start) / 140.0).clamp(Vector2(-1, -1), Vector2(1, 1))
	_karte.zeiger_relativ = rel


func verbergen(sofort := false) -> void:
	offen = false
	if _tween:
		_tween.kill()
	var karte := _karte
	_karte = null
	if karte != null and is_instance_valid(karte):
		if sofort:
			karte.queue_free()
		else:
			var t := karte.create_tween().set_parallel()
			t.tween_property(karte, "modulate:a", 0.0, 0.12)
			t.chain().tween_callback(karte.queue_free)
	if sofort:
		visible = false
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(_grund, "color:a", 0.0, 0.12)
	_tween.tween_property(_tafel, "modulate:a", 0.0, 0.1)
	_tween.chain().tween_callback(func(): visible = offen)


func _unterzeile(k: TarotKarte) -> String:
	if k.verschleiert:
		return "Der Mond verbirgt diese Karte"
	var d := k.daten
	var teile: Array[String] = []
	var zahl := str(d.get("number", ""))
	if zahl != "":
		teile.append(zahl)
	teile.append(FARBNAMEN.get(d.get("suit", "Major"), ""))
	teile.append(str(KartenDaten.seltenheit(d.get("rarity", "Common"))["name"]))
	return " · ".join(teile)


func _erklaerung(k: TarotKarte) -> String:
	if k.verschleiert:
		return "Was darunter liegt, zeigt sich erst, wenn sie gespielt ist."
	var zeilen: Array[String] = [str(k.daten.get("text", ""))]
	if k.edition != "":
		var ed := KartenDaten.edition(k.edition)
		zeilen.append("[color=#%s][b]%s:[/b][/color] %s" % [EDITION_FARBEN.get(k.edition, "FFFFFF"), ed.get("name", k.edition), ed.get("text", "")])
	if k.umgekehrt:
		zeilen.append("[color=#F08A7E][b]Umgekehrt:[/b][/color] stärker und +0,10 Multiplikator – kostet einen Teil der Wirkung als Selbstschaden (tötet nie).")
	var stand := "Rang %d · Wirkung ×%s" % [k.rang, String.num(k.faktor, 2).replace(".", ",")]
	if k.stufe > 1 or k.schimmer > 0:
		stand = "Stufe %d · Schimmer %s · %s" % [k.stufe, SCHIMMER[clampi(k.schimmer, 0, SCHIMMER.size() - 1)], stand]
	if k.kopie:
		stand += " · Kopie"
	zeilen.append("[color=#C9B48E]%s[/color]" % stand)
	if k.gezeichnet > 0:
		zeilen.append("[color=#E0544A][b]Vom Tod gezeichnet:[/b][/color] noch %d %s. Lege sie in die Zukunft und überstehe den Zug – sonst nimmt der Tod sie aus deinem Deck." % [k.gezeichnet, "Runde" if k.gezeichnet == 1 else "Runden"])
	return "\n".join(zeilen)


func _process(_delta: float) -> void:
	if _karte != null and is_instance_valid(_karte):
		_karte.z_index = 10
