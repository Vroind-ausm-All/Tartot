extends RefCounted
class_name ActCatalog
## Der Bogen eines Runs (Content/Acts.cs): drei Akte, je vier Kaempfe und
## ein Boss, dann das Finale. Danach beginnt die Schwarze Spirale.
##
## Kampfindex:  0-3 Akt I, 4 Boss I · 5-8 Akt II, 9 Boss II ·
##              10-13 Akt III, 14 Boss III · 15 Finale · ab 16 Spirale

const ACT_COUNT := 3
const FIGHTS_BEFORE_BOSS := 4
const FIGHTS_PER_ACT := FIGHTS_BEFORE_BOSS + 1
const FINALE_INDEX := ACT_COUNT * FIGHTS_PER_ACT
## Jeder wievielte Spiralkampf ein Boss ist.
const SPIRAL_BOSS_INTERVAL := 4

const ACT_NAMES := [
	"",
	"Der Jahrmarkt der Omen",
	"Das Haus der Spiegel",
	"Die Schwarze Messe",
	"Das Ende der Welt",
	"Die Schwarze Spirale"
]

static var _normals: Array[EnemyDefinition] = []
static var _elites: Array[EnemyDefinition] = []
static var _bosses: Array[EnemyDefinition] = []
static var _finale: EnemyDefinition = null
static var _sun: EnemyDefinition = null
static var _spiral_boss: EnemyDefinition = null
static var _specials: Array[EnemyDefinition] = []

## 1-3 fuer die Akte, 4 fuer das Finale, 5 fuer die Spirale.
static func act_of(fight_index: int) -> int:
	if fight_index > FINALE_INDEX:
		return 5
	if fight_index == FINALE_INDEX:
		return 4
	@warning_ignore("integer_division")
	return maxi(0, fight_index) / FIGHTS_PER_ACT + 1

static func is_boss_fight(fight_index: int) -> bool:
	return fight_index >= 0 and fight_index < FINALE_INDEX and fight_index % FIGHTS_PER_ACT == FIGHTS_BEFORE_BOSS

static func is_finale(fight_index: int) -> bool:
	return fight_index == FINALE_INDEX

static func is_spiral(fight_index: int) -> bool:
	return fight_index > FINALE_INDEX

static func spiral_depth(fight_index: int) -> int:
	return maxi(0, fight_index - FINALE_INDEX)

static func is_spiral_boss(fight_index: int) -> bool:
	return is_spiral(fight_index) and spiral_depth(fight_index) % SPIRAL_BOSS_INTERVAL == 0

## Wie viele Kaempfe bis zum naechsten Boss (0 = der naechste ist einer).
static func fights_until_boss(next_fight_index: int) -> int:
	if next_fight_index >= FINALE_INDEX:
		return 0
	return FIGHTS_BEFORE_BOSS - next_fight_index % FIGHTS_PER_ACT

static func _ensure() -> void:
	if _finale != null:
		return
	_build()

static func normals() -> Array[EnemyDefinition]:
	_ensure()
	return _normals

static func elites() -> Array[EnemyDefinition]:
	_ensure()
	return _elites

static func bosses() -> Array[EnemyDefinition]:
	_ensure()
	return _bosses

static func finale() -> EnemyDefinition:
	_ensure()
	return _finale

static func sun() -> EnemyDefinition:
	_ensure()
	return _sun

## Moegliche Endgegner in Akt IV. Der Run legt sich zu Beginn fest.
static func finales() -> Array[EnemyDefinition]:
	_ensure()
	return [_finale, _sun]

static func spiral_boss() -> EnemyDefinition:
	_ensure()
	return _spiral_boss

static func specials() -> Array[EnemyDefinition]:
	_ensure()
	return _specials

static func all() -> Array[EnemyDefinition]:
	_ensure()
	var out: Array[EnemyDefinition] = []
	out.append_array(_normals)
	out.append_array(_elites)
	out.append_array(_bosses)
	out.append(_finale)
	out.append(_sun)
	out.append(_spiral_boss)
	out.append_array(_specials)
	return out

static func find(id: String) -> EnemyDefinition:
	if id == "":
		return null
	for e in all():
		if e.id == id:
			return e
	return null

static func _of(list: Array[EnemyDefinition], act: int) -> Array[EnemyDefinition]:
	var out: Array[EnemyDefinition] = []
	for e in list:
		if e.act == act:
			out.append(e)
	return out

static func normals_of(act: int) -> Array[EnemyDefinition]:
	return _of(normals(), act)

static func elites_of(act: int) -> Array[EnemyDefinition]:
	return _of(elites(), act)

static func bosses_of(act: int) -> Array[EnemyDefinition]:
	return _of(bosses(), act)

# ------------------------------------------------------ Regeltexte
## Kurzbeschreibung einer Bossregel fuer die aktuelle Phase.
static func rule_text(rule: int, phase: int, weakened: bool) -> String:
	match rule:
		Enums.BossRule.TOWER:
			if weakened: return "Der Turm: alle 4 Runden stürzt eine Position ein."
			if phase >= 1: return "Der Turm: jede 2. Runde stürzt eine Position ein."
			return "Der Turm: jede 3. Runde stürzt eine Position ein."
		Enums.BossRule.MOON:
			if weakened: return "Der Mond: jede 3. Runde verbirgt er Absicht und eine Handkarte."
			if phase >= 1: return "Der Mond: Absicht immer verborgen, zwei Handkarten verdeckt."
			return "Der Mond: jede 2. Runde verbirgt er Absicht und eine Handkarte."
		Enums.BossRule.DEATH:
			if weakened: return "Der Tod zeichnet eine Karte. Nach 4 Runden gehört sie ihm."
			if phase >= 1: return "Der Tod zeichnet eine Karte. Nach 2 Runden gehört sie ihm."
			return "Der Tod zeichnet eine Karte. Nach 3 Runden gehört sie ihm. Leg sie in die Zukunft, um sie zu retten."
		Enums.BossRule.WHEEL:
			if weakened: return "Das Rad: jede 2. Runde rücken deine Positionen weiter."
			if phase >= 1: return "Das Rad: deine Positionen drehen sich rückwärts."
			return "Das Rad: deine Positionen rücken jede Runde eins weiter."
		Enums.BossRule.DEVIL:
			if weakened: return "Der Teufel bietet einmal einen Pakt an."
			return "Der Teufel verhandelt: mehr Schaden gegen deine Lebenskraft."
		Enums.BossRule.HANGED_MAN:
			if weakened: return "Der Gehängte: jede 2. Runde ist die Legung gespiegelt."
			if phase >= 1: return "Der Gehängte: Legung gespiegelt, eine Handkarte weniger."
			return "Der Gehängte: Vergangenheit und Zukunft tauschen die Rollen."
		Enums.BossRule.TEMPERANCE:
			if weakened: return "Die Mäßigkeit: Wasser- und Feuerrunden wechseln sich ab."
			if phase >= 1: return "Die Mäßigkeit mischt: ohne Stab UND Kelch spiegelt sie 15 % deines Treffers zurück."
			return "Die Mäßigkeit: Wasserrunden schwächen Stäbe, Feuerrunden schwächen Kelche (−35 %)."
		Enums.BossRule.HIEROPHANT:
			if weakened: return "Der Hierophant: jede 3. Runde ein Akolyth (höchstens 2), jeder segnet ihn mit Schild."
			if phase >= 1: return "Der Hierophant ruft jede Runde Akolythen (bis 5). Jeder segnet und schlägt härter."
			return "Der Hierophant: jede 2. Runde ein Akolyth (bis 3). Jeder segnet ihn mit 4 Schild. Haltung brechen vertreibt sie."
		Enums.BossRule.SUN:
			if phase >= 1: return "Die rote Sonne: jede Runde zwei neue Sonnen. Bei vier: SUPERNOVA."
			return "Die rote Sonne: jede Runde eine neue Sonne. Bei vier: SUPERNOVA, je Sonne 3 Schaden. Haltung brechen löscht sie."
	return ""

# ------------------------------------------------------ Gegner
# Absichten: A = Angriff, G = Schild, H = Fluch, D = Aussaugen, F = Raserei
static func _p(code: String) -> Array[int]:
	var out: Array[int] = []
	for c in code:
		match c:
			"G": out.append(Enums.IntentType.GUARD)
			"H": out.append(Enums.IntentType.HEX)
			"D": out.append(Enums.IntentType.DRAIN)
			"F": out.append(Enums.IntentType.FRENZY)
			_: out.append(Enums.IntentType.ATTACK)
	return out

static func _e(id: String, name: String, tier: int, act: int, hp: int, stance: int, attack: int,
		sigils: int, pattern: String, flavor: String, art := "") -> EnemyDefinition:
	var d := EnemyDefinition.new()
	d.id = id
	d.name = name
	d.tier = tier
	d.act = act
	d.max_hp = hp
	d.max_stance = stance
	d.base_attack = attack
	d.sigils = sigils
	d.pattern = _p(pattern)
	d.flavor = flavor
	d.art = art if art != "" else id
	return d

static func _boss(id: String, name: String, act: int, hp: int, stance: int, attack: int, sigils: int,
		pattern: String, rule: int, omen: int, flavor: String, phase_hp := 0, stage := "") -> EnemyDefinition:
	var b := _e(id, name, Enums.EnemyTier.BOSS, act, hp, stance, attack, sigils, pattern, flavor)
	b.rules.append(rule)
	b.omen_card_id = "major_%d" % omen
	b.phase_hp = phase_hp
	b.stage = stage
	return b

static func _build() -> void:
	var N := Enums.EnemyTier.NORMAL
	var EL := Enums.EnemyTier.ELITE
	# Akt I - Der Jahrmarkt der Omen. Jeder Gegner lehrt eine Absicht.
	_normals = [
		_e("lachender_henker", "Der lachende Henker", N, 1, 148, 29, 19, 0, "AAF",
			"Ein viel zu langer Hals, ein viel zu breites Grinsen. Der Strick hängt lose."),
		_e("zahnmuenze", "Die Münze mit Zähnen", N, 1, 133, 34, 17, 0, "GAA",
			"Sie rollt. Sie klappert. Wenn sie sich öffnet, sieht man das Gebiss."),
		_e("kelchtrinker", "Der Kelchtrinker", N, 1, 160, 24, 17, 0, "ADA",
			"Er trinkt aus einem Kelch, in dem ein Auge schwimmt. Das Auge sieht dich."),
		_e("schreiende_klinge", "Die schreiende Klinge", N, 1, 110, 19, 25, 0, "AH",
			"Ein Schwert mit einem Mund in der Schneide. Es schreit den eigenen Namen."),
		_e("zwillingsschatten", "Die Zwillingsschatten", N, 1, 125, 29, 17, 0, "FGA",
			"Zwei Schatten einer Figur, die es nicht gibt. Sie tun nicht dasselbe."),
		_e("kleiner_mond", "Der kleine grinsende Mond", N, 1, 144, 29, 19, 0, "HAA",
			"Er hängt zu niedrig und grinst zu breit. Manchmal blinzelt er nicht."),
		# Akt II - Das Haus der Spiegel
		_e("hutmann", "Der Hutmann", N, 2, 289, 44, 19, 0, "GAAH",
			"Unter dem Hut ist noch ein Hut. Und darunter wieder einer."),
		_e("augensammlerin", "Die Augensammlerin", N, 2, 255, 40, 20, 0, "HAF",
			"Sie trägt die Augen anderer an einer Schnur. Keines davon ist ihres."),
		_e("blutorgel", "Die Blutorgel", N, 2, 323, 48, 17, 0, "DADG",
			"Jede Pfeife ein Finger. Sie spielt sich selbst und trifft nie denselben Ton."),
		_e("wachsbote", "Der Wachsbote", N, 2, 238, 35, 23, 0, "AAG",
			"Er bringt eine Nachricht, die schmilzt, bevor man sie lesen kann."),
		_e("mondfresser", "Der Mondfresser", N, 2, 306, 44, 19, 0, "AHF",
			"Unter halben HP wird er aggressiver und verbirgt, was er vorhat."),
		_e("nadelwitwe", "Die Nadelwitwe", N, 2, 280, 53, 19, 0, "GAGA",
			"Sie näht zwischen den Stichen. Was sie näht, trägt dein Gesicht."),
		# Akt III - Die Schwarze Messe
		_e("uhrenwurm", "Der Uhrenwurm", N, 3, 420, 68, 20, 0, "AGAH",
			"Er frisst Minuten. In seinem Bauch schlägt es immer eins."),
		_e("sieben_finger", "Die Sieben Finger", N, 3, 378, 60, 22, 0, "FAA",
			"Sieben Finger ohne Hand. Sie zählen mit, wie oft du getroffen hast."),
		_e("laecheln_ohne_gesicht", "Das Lächeln ohne Gesicht", N, 3, 448, 68, 19, 0, "DAHA",
			"Nur ein Mund, frei schwebend. Er wird breiter, je länger der Kampf dauert."),
		_e("gerichtsdiener", "Der lächelnde Gerichtsdiener", N, 3, 406, 64, 21, 0, "AAG",
			"Er stellt dir deine eigene Vorladung zu. Er hat sie selbst geschrieben.")
	]
	_elites = [
		_e("papierpriester", "Der Papierpriester", EL, 1, 228, 40, 20, 1, "GAHA",
			"Sein Gewand ist aus Verträgen. Er liest laut, aber niemand hört Worte."),
		_e("fette_ratte", "Die fette Ratte des Händlers", EL, 1, 262, 35, 18, 0, "ADG",
			"Sie hat Münzen gefressen. Man hört sie klimpern, wenn sie atmet."),
		_e("spiegelschwester", "Die Spiegelschwester", EL, 2, 448, 56, 22, 1, "AFGH",
			"Sie ahmt dich nach, aber immer eine Sekunde zu spät - und etwas zu genau."),
		_e("muenzmaul", "Das Münzmaul", EL, 2, 480, 60, 21, 0, "GAD",
			"Es bestraft lange Kämpfe und spuckt am Ende alles aus, was es gefressen hat."),
		_e("henker_verkehrt", "Der Henker (umgekehrt)", EL, 3, 598, 72, 24, 1, "FAGA",
			"Derselbe Hals, dasselbe Grinsen - aber der Strick hält jetzt ihn."),
		_e("sonnenkind", "Das Sonnenkind", EL, 3, 624, 72, 23, 1, "ADFH",
			"Ein Splitter der roten Sonne. Er wartet nur, bis du müde wirst.")
	]
	# Die Ratte und das Maul tragen, was sie gefressen haben.
	for e in _elites:
		if e.id == "fette_ratte" or e.id == "muenzmaul":
			e.gold_factor = Num.f(2.5)
	var R := Enums.BossRule
	_bosses = [
		_boss("boss_turm", "XVI · Der Turm", 1, 323, 44, 20, 1, "AAGF", R.TOWER, 16,
			"Er wächst hinter dir hoch. Jeder Blitz nimmt dir eine Möglichkeit.", 0, "Jahrmarkt der Omen"),
		_boss("boss_hierophant", "V · Der Hierophant", 1, 240, 44, 19, 1, "AGAH", R.HIEROPHANT, 5,
			"Glaube verbindet. Und fesselt.", 320, "Kathedrale der Stimmen"),
		_boss("boss_tod", "XIII · Der Tod", 2, 510, 64, 22, 1, "AHAD", R.DEATH, 13,
			"Ein weißes Gesicht, ein roter Schnitt. Er nimmt nicht dich - er nimmt deine Karten.", 0, "Haus der Spiegel"),
		_boss("boss_rad", "X · Rad des Schicksals", 2, 495, 60, 22, 1, "AFGA", R.WHEEL, 10,
			"Es dreht. Deine Positionen bleiben nicht, wo du sie gelegt hast.", 0, "Haus der Spiegel"),
		_boss("boss_teufel", "XV · Der Teufel", 3, 240, 72, 20, 1, "ADAF", R.DEVIL, 15,
			"Ein kleines Spielchen, nur ein einziges ...", 320, "Verbotenes Casino"),
		_boss("boss_gehaengter", "XII · Der Gehängte", 3, 650, 79, 22, 1, "GAAH", R.HANGED_MAN, 12,
			"Er hängt verkehrt. Von seiner Seite aus liegt deine Zukunft links.", 0, "Die Schwarze Messe"),
		_boss("boss_mond", "XVIII · Der Mond", 3, 220, 72, 21, 1, "HADA", R.MOON, 18,
			"Nicht alles, was du siehst, ist wahr.", 320, "Spiegelsee"),
		_boss("boss_maessigkeit", "XIV · Die Mäßigkeit", 3, 220, 70, 21, 1, "AAHF", R.TEMPERANCE, 14,
			"Nicht zu viel. Nicht zu wenig. Genau richtig.", 300, "Brücke der Elemente")
	]
	# Die Welt: das Finale. Die Regeln setzt der Run ein.
	_finale = _e("boss_welt", "XXI · Die Welt", Enums.EnemyTier.FINALE, 4, 504, 65, 24, 2, "AHFGD",
		"Alles, was du besiegt hast, ist noch da. Es sieht nur jetzt zusammen aus.")
	_finale.omen_card_id = "major_21"
	_finale.rules_weakened = true
	# Die rote Sonne: das zweite moegliche Finale (Akt IV).
	_sun = _e("boss_sonne", "XIX · Die rote Sonne", Enums.EnemyTier.FINALE, 4, 300, 65, 24, 1, "AFAG",
		"Sie brennt, um alles sichtbar zu machen - auch deinen Hochmut.")
	_sun.omen_card_id = "major_19"
	_sun.rules.append(R.SUN)
	_sun.phase_hp = 420
	_sun.stage = "Himmelszirkus"
	_spiral_boss = _e("weltenwurm", "Der Weltenwurm", Enums.EnemyTier.BOSS, 5, 620, 46, 24, 1, "AFDHA",
		"Die Welt ist nicht das Ende. Er frisst sie von hinten und wächst mit jeder Schleife.")
	_spiral_boss.omen_card_id = "major_21"
	_specials = [
		_e("kartenspieler", "Der Kartenspieler", EL, 3, 546, 68, 22, 1, "AHGF",
			"Er spielt deine Karten. Besser als du.")
	]
