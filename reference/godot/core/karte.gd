# Eine Karteninstanz im Deck des Spielers.
#
# Die Karte selbst ist absichtlich duenn: sie haelt nur ihren Zustand.
# Was sie *tut*, steht in der Vorlage im Katalog (data/*.json). So kann
# dieselbe Vorlage 5x im Deck liegen, jede mit eigener Stufe und Tinte.
extends RefCounted
class_name Karte

const Konst := preload("res://core/konst.gd")

## Laufende Nummer fuer eindeutige Instanz-IDs innerhalb eines Runs.
static var _naechste_id: int = 1

var id: int = 0                      # eindeutig im Run (Markierungen, Verbindungen)
var vorlage: String = ""             # z. B. "schwerter_07" oder "arkana_13"
var farbe: int = Konst.Farbe.SCHWERTER
var rang: int = 1                    # 1-14 kleine Arkana, 0-22 grosse Arkana
var ori: int = Konst.Ori.AUFRECHT
var stufe: int = 0                   # 0-3, das "+" im Namen
var tinte: int = 0                   # 0-5 Verderbnisgrad, verdunkelt die Karte
var ist_kopie: bool = false          # durch Spiegeln entstanden
var ist_fluch: bool = false          # kann nicht normal gespielt werden
var verbunden_mit: int = 0           # Die Liebenden: id der Partnerkarte
var fluechtig: bool = false          # existiert nur fuer diesen Kampf
var markiert: bool = false           # Der Tod hat sie markiert

static func neu(p_vorlage: String, p_farbe: int, p_rang: int) -> Karte:
	var k := Karte.new()
	k.id = _naechste_id
	_naechste_id += 1
	k.vorlage = p_vorlage
	k.farbe = p_farbe
	k.rang = p_rang
	return k

static func setze_id_zaehler(wert: int) -> void:
	_naechste_id = maxi(1, wert)

static func id_zaehler() -> int:
	return _naechste_id

func kopie() -> Karte:
	var k := Karte.new()
	k.id = _naechste_id
	_naechste_id += 1
	k.vorlage = vorlage
	k.farbe = farbe
	k.rang = rang
	k.ori = ori
	k.stufe = stufe
	k.tinte = tinte
	k.ist_kopie = true
	k.ist_fluch = ist_fluch
	k.fluechtig = fluechtig
	return k

## Zaehlwert fuer Muster (Summe 21, Konvergenz, Schicksalskette).
## Grosse Arkana zaehlen mit ihrer Arkana-Nummer.
func musterwert() -> int:
	return rang

func ist_grosse_arkana() -> bool:
	return farbe == Konst.Farbe.ARKANA

func ist_hofkarte() -> bool:
	return not ist_grosse_arkana() and rang >= Konst.RANG_BUBE

func ist_umgekehrt() -> bool:
	return ori == Konst.Ori.UMGEKEHRT

func drehen() -> void:
	ori = Konst.Ori.AUFRECHT if ori == Konst.Ori.UMGEKEHRT else Konst.Ori.UMGEKEHRT

func aufwerten(n: int = 1) -> bool:
	if stufe >= Konst.STUFE_MAX:
		return false
	stufe = mini(Konst.STUFE_MAX, stufe + n)
	# Aufwerten faerbt die Karte dunkler - Macht hat einen sichtbaren Preis.
	tinte = mini(5, tinte + 1)
	return true

## Flacher Bonus auf skalierende Werte aus Stufe und Tinte.
func flachbonus() -> int:
	return Konst.STUFE_BONUS[clampi(stufe, 0, Konst.STUFE_MAX)] + int(float(tinte) * 0.5)

func rangname() -> String:
	if ist_grosse_arkana():
		return Konst.roemisch(rang)
	if Konst.RANG_NAME.has(rang):
		return String(Konst.RANG_NAME[rang])
	return str(rang)

func anzeigename() -> String:
	var basis: String
	if ist_grosse_arkana():
		basis = "%s" % Konst.roemisch(rang)
	else:
		basis = "%s der %s" % [rangname(), Konst.FARBE_NAME[farbe]]
	basis += Konst.STUFE_NAME[clampi(stufe, 0, Konst.STUFE_MAX)]
	if ist_umgekehrt():
		basis += " (umgekehrt)"
	return basis

## Verdunkelungsstufe fuer die Darstellung: 0 = Blass ... 5 = Leer.
func tintenname() -> String:
	return Konst.VERDERBNIS_STUFEN_NAME[clampi(tinte, 0, 5)]

func speichern() -> Dictionary:
	return {
		"id": id, "vorlage": vorlage, "farbe": farbe, "rang": rang,
		"ori": ori, "stufe": stufe, "tinte": tinte, "kopie": ist_kopie,
		"fluch": ist_fluch, "verbunden": verbunden_mit,
		"fluechtig": fluechtig, "markiert": markiert,
	}

static func aus_speicher(d: Dictionary) -> Karte:
	var k := Karte.new()
	k.id = int(d.get("id", 0))
	k.vorlage = String(d.get("vorlage", ""))
	k.farbe = int(d.get("farbe", 0))
	k.rang = int(d.get("rang", 1))
	k.ori = int(d.get("ori", 0))
	k.stufe = int(d.get("stufe", 0))
	k.tinte = int(d.get("tinte", 0))
	k.ist_kopie = bool(d.get("kopie", false))
	k.ist_fluch = bool(d.get("fluch", false))
	k.verbunden_mit = int(d.get("verbunden", 0))
	k.fluechtig = bool(d.get("fluechtig", false))
	k.markiert = bool(d.get("markiert", false))
	return k
