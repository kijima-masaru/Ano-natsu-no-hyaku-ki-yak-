class_name SoundSynth
extends RefCounted
## 音声素材が無い間の暫定合成音。data/audio.json の synth 指定から AudioStreamWAV を生成する。
## 素材差し替えの境界：本番では AudioManager がこのクラスの代わりに OGG を load する（docs/ASSETS_NEEDED.md）。
## 生成は決定的（seed 固定）。16bit モノラル。

const SAMPLE_RATE: int = 22050
const TYPES: PackedStringArray = ["silence", "noise", "tone", "hum", "cicada", "heartbeat", "drone", "click", "water"]

static var _cache: Dictionary = {}


static func build(id: String, spec: Dictionary) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var seconds: float = maxf(0.05, float(spec.get("seconds", 2.0)))
	var count: int = int(seconds * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var type: String = str(spec.get("type", "silence"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", id.hash()))
	match type:
		"noise": _noise(samples, rng, float(spec.get("lowpass", 0.05)))
		"tone": _tone(samples, float(spec.get("freq", 440.0)), float(spec.get("decay", 0.0)))
		"hum": _hum(samples, rng, float(spec.get("freq", 100.0)))
		"cicada": _cicada(samples, rng, float(spec.get("freq", 4200.0)), float(spec.get("density", 0.6)))
		"heartbeat": _heartbeat(samples, float(spec.get("bpm", 62.0)))
		"drone": _drone(samples, float(spec.get("freq", 55.0)))
		"click": _click(samples, rng, float(spec.get("decay", 40.0)))
		"water": _water(samples, rng)
		"silence": pass
		_:
			push_error("SoundSynth: 種別 '%s' は未対応です（%s）" % [type, ", ".join(TYPES)])
	var gain: float = clampf(float(spec.get("gain", 0.3)), 0.0, 1.0)
	var fade: int = mini(count / 2, int(SAMPLE_RATE * 0.02))
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var env: float = 1.0
		if i < fade:
			env = float(i) / fade
		elif i > count - fade:
			env = float(count - i) / fade
		var v: float = clampf(samples[i] * gain * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if bool(spec.get("loop", false)):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	_cache[id] = stream
	return stream


static func clear_cache() -> void:
	_cache.clear()


static func _noise(s: PackedFloat32Array, rng: RandomNumberGenerator, lowpass: float) -> void:
	var last: float = 0.0
	for i: int in s.size():
		last += (rng.randf_range(-1.0, 1.0) - last) * lowpass
		s[i] = last * 3.0


static func _tone(s: PackedFloat32Array, freq: float, decay: float) -> void:
	for i: int in s.size():
		var t: float = float(i) / SAMPLE_RATE
		s[i] = sin(TAU * freq * t) * (exp(-decay * t) if decay > 0.0 else 1.0)


static func _hum(s: PackedFloat32Array, rng: RandomNumberGenerator, freq: float) -> void:
	var last: float = 0.0
	for i: int in s.size():
		var t: float = float(i) / SAMPLE_RATE
		last += (rng.randf_range(-1.0, 1.0) - last) * 0.02
		s[i] = sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.2 + last * 0.8


## 蝉：高い周波数のうねりを、ランダムな鳴き・止みで並べる
static func _cicada(s: PackedFloat32Array, rng: RandomNumberGenerator, freq: float, density: float) -> void:
	var i: int = 0
	while i < s.size():
		var burst: int = int(rng.randf_range(0.3, 1.2) * SAMPLE_RATE)
		var gap: int = int(rng.randf_range(0.1, 0.8) * SAMPLE_RATE * (1.5 - density))
		var f: float = freq * rng.randf_range(0.9, 1.1)
		for k: int in mini(burst, s.size() - i):
			var t: float = float(k) / SAMPLE_RATE
			var am: float = 0.5 + 0.5 * sin(TAU * 38.0 * t)
			var env: float = minf(1.0, t * 8.0) * minf(1.0, (float(burst) / SAMPLE_RATE - t) * 4.0)
			s[i + k] += sign(sin(TAU * f * t)) * am * env * 0.35
		i += burst + gap


static func _heartbeat(s: PackedFloat32Array, bpm: float) -> void:
	var period: float = 60.0 / bpm
	for i: int in s.size():
		var t: float = fmod(float(i) / SAMPLE_RATE, period)
		var beat: float = 0.0
		for offset: float in [0.0, 0.18]:
			var dt: float = t - offset
			if dt >= 0.0 and dt < 0.12:
				beat += sin(TAU * 48.0 * dt) * exp(-dt * 30.0)
		s[i] = beat


static func _drone(s: PackedFloat32Array, freq: float) -> void:
	for i: int in s.size():
		var t: float = float(i) / SAMPLE_RATE
		s[i] = (sin(TAU * freq * t) + sin(TAU * freq * 1.003 * t) * 0.7 + sin(TAU * freq * 1.5 * t) * 0.25) * 0.5


static func _click(s: PackedFloat32Array, rng: RandomNumberGenerator, decay: float) -> void:
	for i: int in s.size():
		var t: float = float(i) / SAMPLE_RATE
		s[i] = rng.randf_range(-1.0, 1.0) * exp(-decay * t)


static func _water(s: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var last: float = 0.0
	for i: int in s.size():
		var t: float = float(i) / SAMPLE_RATE
		last += (rng.randf_range(-1.0, 1.0) - last) * 0.15
		s[i] = last * (0.7 + 0.3 * sin(TAU * 0.4 * t)) * 2.0
