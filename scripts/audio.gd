extends Node

var game
var streams: Dictionary = {}
var voices: Array = []
var music: AudioStreamPlayer
var ui_voice: AudioStreamPlayer
var cooldown = 0.0
var variation_rng = RandomNumberGenerator.new()

func setup(owner_game) -> void:
	game = owner_game
	variation_rng.randomize()
	for cue_name in ["shot", "hit", "kill", "build", "wave", "reload", "hurt", "explosion", "step", "ui"]:
		streams[cue_name] = synth(cue_name)
	for i in 16:
		var voice = AudioStreamPlayer3D.new()
		voice.max_distance = 55
		voice.unit_size = 8
		add_child(voice)
		voices.append(voice)
	ui_voice = AudioStreamPlayer.new()
	add_child(ui_voice)
	music = AudioStreamPlayer.new()
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050 * 8
	var bytes = PackedByteArray()
	bytes.resize(22050 * 8 * 2)
	for i in 22050 * 8:
		var t = i / 22050.0
		var chord = sin(TAU * 55 * t) * 0.2 + sin(TAU * 82.5 * t) * 0.08 + sin(TAU * 110 * t) * 0.04
		var pulse = pow(maxf(0, 1 - fmod(t, 0.5) * 2), 6) * sin(TAU * 41.25 * t) * 0.2
		bytes.encode_s16(i * 2, int((chord + pulse) * 12000))
	stream.data = bytes
	music.stream = stream
	add_child(music)
	if DisplayServer.get_name() != "headless": music.play()
	apply_volume()

func synth(kind: String) -> AudioStreamWAV:
	var duration = 0.12
	var frequency = 220.0
	match kind:
		"shot": frequency = 110
		"hit": frequency = 920
		"kill": frequency = 400; duration = 0.22
		"build": frequency = 660; duration = 0.25
		"wave": frequency = 165; duration = 0.7
		"reload": frequency = 300; duration = 0.2
		"hurt": frequency = 75; duration = 0.25
		"explosion": frequency = 40; duration = 0.5
		"step": frequency = 60; duration = 0.08
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes = PackedByteArray()
	var count = int(22050 * duration)
	bytes.resize(count * 2)
	var random = RandomNumberGenerator.new()
	random.seed = kind.hash()
	for i in count:
		var t = float(i) / 22050
		var envelope = pow(1.0 - float(i) / count, 2)
		var noise = random.randf_range(-1, 1) * (0.7 if kind in ["shot", "explosion", "step"] else 0.12)
		var sample = (sin(TAU * frequency * t * (1 - t)) * 0.4 + noise) * envelope
		bytes.encode_s16(i * 2, int(sample * 19000))
	stream.data = bytes
	return stream

func apply_volume() -> void:
	if music:
		music.volume_db = linear_to_db(maxf(0.0001, game.profile.data.settings.music))

func cue(kind: String, pos: Vector3 = Vector3.ZERO, volume: float = 0.7) -> void:
	if DisplayServer.get_name() == "headless": return
	if not streams.has(kind):
		return
	if kind == "ui":
		ui_voice.stream = streams[kind]
		ui_voice.volume_db = linear_to_db(maxf(0.0001, volume * float(game.profile.data.settings.volume)))
		ui_voice.play()
		return
	for voice in voices:
		if not voice.playing:
			voice.global_position = pos if pos != Vector3.ZERO else (game.player.global_position if is_instance_valid(game.player) else Vector3.ZERO)
			voice.stream = streams[kind]
			voice.volume_db = linear_to_db(maxf(0.0001, volume * float(game.profile.data.settings.volume)))
			voice.pitch_scale = variation_rng.randf_range(0.94, 1.06)
			voice.play()
			return

func stop_all() -> void:
	if ui_voice:
		ui_voice.stop()
		ui_voice.stream = null
	if music:
		music.stop()
		music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()
