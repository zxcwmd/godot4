extends Node
## Synthesized original fallback rhythm, not a replacement for a mastered track.
var music: AudioStreamPlayer
var voices = []
var sounds = {}
var clock = 0.0
const BPM = 186.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)
	for i in range(14):
		var voice = AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		voices.append(voice)
	for kind in ["shot", "slash", "hit", "kill", "dash", "seal", "hurt", "spell", "ui"]:
		sounds[kind] = make_sfx(kind)
	var path = ""
	for ext in ["ogg", "mp3", "wav"]:
		if ResourceLoader.exists("res://assets/music/breakcore." + ext):
			path = "res://assets/music/breakcore." + ext
			break
	if not path.is_empty():
		music.stream = load(path)
	else:
		music.stream = make_break()
	music.finished.connect(func(): music.play())
	music.play()

func _process(dt: float) -> void:
	clock += dt

func beat() -> float:
	return pow(1.0 - fmod(clock * BPM / 60.0, 1.0), 4.0)

func play_sfx(kind: String, pitch: float = 1.0) -> void:
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds.get(kind, sounds["hit"])
			voice.pitch_scale = pitch * randf_range(0.94, 1.06)
			voice.play()
			return

func make_sfx(kind: String) -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.18
	if kind == "seal": duration = 0.65
	if kind == "slash": duration = 0.25
	var data = PackedByteArray()
	data.resize(int(duration * rate) * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var phase = 0.0
	for i in range(data.size() / 2):
		var t = float(i) / rate
		var env = pow(maxf(0, 1.0 - t / duration), 2)
		var noise = rng.randf_range(-1, 1)
		var value = 0.0
		match kind:
			"shot": value = (sin(t * (1400 - 4000*t)) * 0.35 + noise * 0.5) * env
			"slash", "dash": value = noise * env * sin(minf(t * 35, PI / 2)) * 0.55
			"seal": value = (sin(t * 2200) + sin(t * 3300) + sin(t * 4400)) * env * 0.14
			"kill": value = (sin(t * (2200 - t*6500)) + noise * 0.5) * env * 0.28
			"spell":
				phase += (200 + t * 1600) * TAU / rate
				value = sin(phase) * env * 0.4 + noise * env * 0.1
			"hurt": value = (sin(t * 400) + noise * 0.6) * env * 0.4
			"ui": value = sin(t * 4200) * env * 0.15
			_: value = noise * env * 0.35
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 26000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func make_break() -> AudioStreamWAV:
	var rate = 22050
	var step = 60.0 / BPM / 4.0
	var duration = step * 128
	var data = PackedByteArray()
	data.resize(int(duration * rate) * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 186
	var phase = 0.0
	for i in range(data.size() / 2):
		var t = float(i) / rate
		var s = int(t / step)
		var local = fmod(t, step)
		var n = s % 16
		var bar = s / 16
		var noise = rng.randf_range(-1, 1)
		var value = 0.0
		if n in [0, 3, 10] or (bar % 2 == 1 and n in [7, 14]):
			value += sin(240 * local + 7 * (1-exp(-local*45))) * exp(-local*33) * 0.65
		if n in [4, 12] or (bar % 2 == 1 and n in [6, 11, 15]):
			value += (noise*0.8 + sin(local * 1150)*0.25) * exp(-local*38) * 0.65
		var hat_t = fmod(local, step * (0.5 if bar == 7 else 1.0))
		value += noise * exp(-hat_t*150) * (0.18 if n%2 == 0 else 0.1)
		var notes = [55.0, 55.0, 65.41, 49.0]
		phase += TAU * notes[int(s / 32) % 4] / rate
		value += (sin(phase) + sin(phase*2) * 0.18) * 0.17 * (1-exp(-local*70))
		if n in [0, 6, 10]: value += sin(phase*8) * exp(-local*26) * 0.06
		data.encode_s16(i * 2, int(clampf(value, -0.94, 0.94) * 24000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = data.size() / 2
	return stream

func _exit_tree() -> void:
	# Release looping playback explicitly when a run is reloaded.
	music.stop()
	music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
