class_name RiftSound
extends Node

var music: AudioStreamPlayer
var players: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var cursor := 0
var muted := false
var enabled := true

func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	for i in 16:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		players.append(p)
	for id in ["shot", "slash", "hit", "kill", "dash", "jump", "land", "hurt", "invoke", "pick", "step", "ui", "portal"]:
		samples[id] = synth(id)
	music = AudioStreamPlayer.new()
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	music.volume_db = -12.0
	for path in ["res://assets/music/breakcore.ogg", "res://assets/music/breakcore.mp3", "res://assets/music/fallback.wav"]:
		if ResourceLoader.exists(path):
			music.stream = load(path)
			break
		# Also support loose files when using the lightweight browser preview.
		if path.ends_with(".wav") and FileAccess.file_exists(path):
			music.stream = AudioStreamWAV.load_from_file(path)
			if music.stream:
				break
	music.finished.connect(func(): music.play())

func start_music() -> void:
	if enabled and music.stream and not music.playing:
		music.play()

func play(id: String, volume: float = -9.0, pitch: float = 1.0) -> void:
	if not enabled or not samples.has(id):
		return
	var p = players[cursor % players.size()]
	cursor += 1
	p.stream = samples[id]
	p.volume_db = volume
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()

func toggle_music() -> void:
	muted = not muted
	music.volume_db = -80.0 if muted else -12.0

func synth(id: String) -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.16
	if id in ["kill", "invoke", "portal"]:
		duration = 0.4
	if id == "step":
		duration = 0.06
	var data = PackedByteArray()
	data.resize(int(rate * duration) * 2)
	var phase := 0.0
	for i in int(rate * duration):
		var t = float(i) / rate
		var k = t / duration
		var noise = randf_range(-1.0, 1.0)
		var v := 0.0
		match id:
			"shot": v = (sin(TAU * (100.0 * t - 90.0 * t * t)) * 0.6 + noise * 0.6) * exp(-t * 35)
			"slash", "dash": v = noise * sin(k * PI) * (1.0 - k) * 0.6
			"hit", "hurt": v = (noise * 0.7 + sin(t * 600.0) * 0.3) * exp(-t * 28)
			"kill", "pick", "invoke", "portal":
				phase += TAU * (350.0 + floor(k * 5.0) * 150.0) / rate
				v = sin(phase) * (1.0 - k) * 0.35 + noise * 0.05 * (1.0 - k)
			"jump": v = sin(TAU * (200.0 * t + 600.0 * t * t)) * (1.0 - k) * 0.4
			"land": v = (sin(t * 380.0) + noise) * exp(-t * 24) * 0.5
			"step": v = noise * exp(-t * 70) * 0.24
			_: v = sin(t * 4200) * exp(-t * 40) * 0.25
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
