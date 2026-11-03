extends Node

## AudioManager: Centralized sound management, audio synthesis, and volume control.

var music_player: AudioStreamPlayer = null
var sfx_pool: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 8

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

var coin_sound_wav: AudioStreamWAV = null
var upgrade_sound_wav: AudioStreamWAV = null
var wave_clear_wav: AudioStreamWAV = null
var ui_click_wav: AudioStreamWAV = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Setup music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)

	# Setup SFX pool to prevent clipping or audio lag
	for i in range(max_sfx_players):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_pool.append(p)

	_synthesize_sound_effects()
	_load_saved_volume()
	_start_ambient_sky_drone.call_deferred()


func _load_saved_volume() -> void:
	if get_node_or_null("/root/SaveManager") != null:
		master_volume = SaveManager.master_volume
		music_volume = SaveManager.music_volume
		sfx_volume = SaveManager.sfx_volume


func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(0.001, master_volume)))


func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	if music_player != null:
		music_player.volume_db = linear_to_db(maxf(0.001, music_volume))


func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)


func play_sound(stream: AudioStream, pitch_scale: float = 1.0, volume_offset: float = 0.0) -> void:
	if stream == null or sfx_volume <= 0.001:
		return

	for p in sfx_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.volume_db = linear_to_db(maxf(0.001, sfx_volume)) + volume_offset
			p.play()
			return


func play_coin_sound() -> void:
	play_sound(coin_sound_wav, randf_range(0.95, 1.15), -2.0)


func play_upgrade_sound() -> void:
	play_sound(upgrade_sound_wav, 1.0, 0.0)


func play_wave_clear_sound() -> void:
	play_sound(wave_clear_wav, 1.0, 1.0)


func play_click_sound() -> void:
	play_sound(ui_click_wav, randf_range(0.9, 1.1), -4.0)


# --- Procedural Audio Synthesis ---

func _synthesize_sound_effects() -> void:
	coin_sound_wav = _create_bell_tone(987.77, 0.18, 0.45)
	upgrade_sound_wav = _create_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.35)
	wave_clear_wav = _create_arpeggio([440.0, 554.37, 659.25, 880.0], 0.40)
	ui_click_wav = _create_click_tone(0.03)


func _create_bell_tone(freq: float, duration: float, decay: float) -> AudioStreamWAV:
	var sample_rate: int = 11025
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = exp(-t * (1.0 / decay) * 6.0)
		var val: float = sin(t * freq * TAU) * env
		data[i] = int(clampi(int(val * 127.0) + 128, 0, 255))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav


func _create_arpeggio(freqs: Array, duration: float) -> AudioStreamWAV:
	var sample_rate: int = 11025
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)

	var note_duration: float = duration / freqs.size()
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var note_idx: int = mini(int(t / note_duration), freqs.size() - 1)
		var freq: float = freqs[note_idx]
		var local_t: float = fmod(t, note_duration)
		var env: float = exp(-local_t * 5.0)
		var val: float = sin(t * freq * TAU) * env * 0.8
		data[i] = int(clampi(int(val * 127.0) + 128, 0, 255))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav


func _create_click_tone(duration: float) -> AudioStreamWAV:
	var sample_rate: int = 11025
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var env: float = 1.0 - (float(i) / num_samples)
		var val: float = sin(t * 1200.0 * TAU) * env * 0.5
		data[i] = int(clampi(int(val * 127.0) + 128, 0, 255))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav


func _start_ambient_sky_drone() -> void:
	# Optimized loopable atmospheric sky drone (seamless 1-second harmonic period)
	var sample_rate: int = 11025
	var duration: float = 1.0
	var num_samples: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(num_samples)

	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		var val: float = (sin(t * 110.0 * TAU) * 0.4 + sin(t * 165.0 * TAU) * 0.3) * 0.25
		data[i] = int(clampi(int(val * 127.0) + 128, 0, 255))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.data = data

	if music_player != null and music_player.is_inside_tree():
		music_player.stream = wav
		music_player.volume_db = linear_to_db(maxf(0.001, music_volume)) - 10.0
		music_player.play()
