extends RefCounted
class_name MondAudio
## Klaenge des Mondes. Cue-Namen wie in
## assets/audio/bosses/mond/REAPER_CUES.md: intro, attack, hex, drain,
## veil, hit, break, phase2, death.
##
## Liegt assets/audio/bosses/mond/mond_<cue>.wav (oder .ogg) vor, wird es
## benutzt; sonst erzeugt diese Klasse einen Platzhalter: ein Theremin-
## artiges Gleiten, Spieluhr-Sterne, gedaempftes Bandrauschen.

const RATE := 22050
const ORDNER := "res://assets/audio/bosses/mond/"

static var _cache: Dictionary = {}

static func cue(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var stream: AudioStream = null
	for endung in [".wav", ".ogg"]:
		var pfad: String = ORDNER + "mond_" + name + String(endung)
		if ResourceLoader.exists(pfad):
			stream = load(pfad)
			break
	if stream == null:
		stream = _platzhalter(name)
	_cache[name] = stream
	return stream

static func _platzhalter(name: String) -> AudioStreamWAV:
	match name:
		"intro": return _theremin(1.0, 330.0, 220.0, 0.30)
		"attack": return _schlag(0.22, 0.40)
		"hex": return _spieluhr(0.55, [987.8, 1174.7, 932.3, 1108.7], 0.22)
		"drain": return _theremin(0.45, 440.0, 160.0, 0.26)
		"veil": return _rauschen(0.6, 0.20)
		"hit": return _schlag(0.16, 0.34)
		"break": return _spieluhr(0.35, [1318.5, 1244.5, 1174.7], 0.26)
		"phase2": return _theremin(0.95, 196.0, 277.2, 0.34)
		"death": return _theremin(1.2, 392.0, 55.0, 0.32)
	return _schlag(0.12, 0.22)

static func _stream(seconds: float, sample: Callable) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(RATE)
		var value := clampf(float(sample.call(t, i)), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(value * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

## Gleitender Sinus mit Vibrato - der klassische Kino-Mond.
static func _theremin(seconds: float, von: float, nach: float, gain: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, _i: int) -> float:
		var u := t / seconds
		var f := lerpf(von, nach, u) * (1.0 + 0.012 * sin(TAU * 5.5 * t))
		var env := minf(1.0, t / 0.06) * minf(1.0, (seconds - t) / 0.2)
		# Phase ueber die mittlere Frequenz angenaehert - reicht fuer einen Platzhalter.
		return sin(TAU * f * t) * env * gain
	)

static func _spieluhr(seconds: float, toene: Array, gain: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, _i: int) -> float:
		var schritt := seconds / float(toene.size())
		var k := mini(toene.size() - 1, int(t / schritt))
		var lokal := t - k * schritt
		return sin(TAU * float(toene[k]) * lokal) * exp(-lokal * 9.0) * gain
	)

static func _schlag(seconds: float, gain: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, i: int) -> float:
		var noise := sin(float(i * 1103515245 + 4321) * 0.000001)
		return (sin(TAU * 120.0 * t) * 0.6 + noise * 0.4) * exp(-t * 16.0) * gain
	)

static func _rauschen(seconds: float, gain: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, i: int) -> float:
		var noise := sin(float(i * 48271 + 11) * 0.000013) * 0.6 + sin(float(i * 69621) * 0.000007) * 0.4
		var huelle := sin(PI * t / seconds)
		return noise * huelle * gain * (0.6 + 0.4 * sin(TAU * 3.0 * t))
	)
