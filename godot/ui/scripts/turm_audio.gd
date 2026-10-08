extends RefCounted
class_name TurmAudio

const RATE := 22050

static func cue(name: String) -> AudioStreamWAV:
	match name:
		"intro": return _organ_chord(0.78, [82.41, 103.83, 123.47], 0.34)
		"hit": return _impact(0.20, 96.0, 0.42)
		"break": return _crack(0.38)
		"lightning": return _lightning(0.42)
		"phase2": return _organ_chord(0.92, [73.42, 92.50, 116.54, 146.83], 0.40)
		"death": return _collapse(1.10)
		_: return _impact(0.12, 160.0, 0.24)

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

static func _organ_chord(seconds: float, freqs: Array, gain: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, _i: int) -> float:
		var attack := minf(1.0, t / 0.035)
		var release := minf(1.0, (seconds - t) / 0.18)
		var sum := 0.0
		for f in freqs:
			sum += sin(TAU * float(f) * t)
			sum += 0.22 * sin(TAU * float(f) * 2.0 * t)
		return sum / maxf(1.0, float(freqs.size())) * gain * attack * release
	)

static func _impact(seconds: float, tone: float, gain: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, i: int) -> float:
		var noise := sin(float(i * 1103515245 + 12345) * 0.000001)
		return (sin(TAU * tone * t) * 0.72 + noise * 0.28) * exp(-t * 14.0) * gain
	)

static func _crack(seconds: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, i: int) -> float:
		var noise := sin(float(i * 2654435761) * 0.000003)
		var square := sign(sin(TAU * 34.0 * t))
		return (noise * 0.38 + square * 0.22 + sin(TAU * 68.0 * t) * 0.34) * exp(-t * 7.0)
	)

static func _lightning(seconds: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, i: int) -> float:
		var noise := sin(float(i * 214013 + 2531011) * 0.00001)
		var snap := exp(-t * 34.0) * sin(TAU * 760.0 * t)
		var rumble := exp(-t * 4.5) * sin(TAU * 54.0 * t)
		return snap * 0.42 + rumble * 0.30 + noise * exp(-t * 9.0) * 0.16
	)

static func _collapse(seconds: float) -> AudioStreamWAV:
	return _stream(seconds, func(t: float, i: int) -> float:
		var noise := sin(float(i * 48271 + 7) * 0.000017)
		var fall := sin(TAU * (82.0 - 42.0 * t) * t)
		var hit := sin(TAU * 46.0 * t) * exp(-pow((t - 0.62) * 13.0, 2.0))
		return fall * exp(-t * 2.2) * 0.30 + noise * minf(1.0, t * 4.0) * exp(-t * 2.8) * 0.20 + hit * 0.38
	)
