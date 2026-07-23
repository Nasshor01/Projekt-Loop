# MusicManager.gd - Soundtrack pro celý run (hraje bez přepínání až do konce běhu)
extends Node

const RUN_SOUNDTRACK_PATH = "res://music/soundtrack/Discipline of the Inner Citadel.wav"

var _player: AudioStreamPlayer
var _volume_linear: float = 1.0

func _ready():
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_finished)
	_load_volume()
	_apply_volume()

func play_run():
	"""Spustí soundtrack runu - hraje v loopu až do stop_run()."""
	if _player == null:
		return
	if _current_stream_path() == RUN_SOUNDTRACK_PATH and _player.playing:
		return
	var stream = load(RUN_SOUNDTRACK_PATH) as AudioStream
	if stream == null:
		push_error("MusicManager: Failed to load run soundtrack: " + RUN_SOUNDTRACK_PATH)
		return
	_player.stream = stream
	_player.play()

func stop_run():
	"""Zastaví hudbu při návratu do menu."""
	if _player == null:
		return
	_player.stop()
	_player.stream = null

func is_playing() -> bool:
	return _player != null and _player.playing

func set_volume_linear(value: float):
	_volume_linear = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_volume()

func get_volume_linear() -> float:
	return _volume_linear

func _apply_volume():
	if _player == null:
		return
	# 0 = -80 dB (ticho), 1 = 0 dB (plná hlasitost)
	if _volume_linear <= 0.0:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(_volume_linear)

func _on_finished():
	if _player != null:
		_player.play()

func _current_stream_path() -> String:
	if _player == null or _player.stream == null:
		return ""
	# Godot 4: Resource nemá resource_path přímo na AudioStream vždy
	# Známe cestu - použijeme ji pro kontrolu
	return RUN_SOUNDTRACK_PATH

func _load_volume():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK and cfg.has_section_key("settings", "music_volume"):
		_volume_linear = clampf(float(cfg.get_value("settings", "music_volume")) / 100.0, 0.0, 1.0)
		_apply_volume()

func _save_volume():
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	if err != OK:
		cfg = ConfigFile.new()
	cfg.set_value("settings", "music_volume", int(_volume_linear * 100))
	cfg.save("user://settings.cfg")
