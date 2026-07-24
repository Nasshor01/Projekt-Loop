# MusicManager.gd - Soundtrack pro celý run (hraje bez přepínání až do konce běhu)
extends Node

const RUN_SOUNDTRACK_PATH = "res://music/soundtrack/Discipline of the Inner Citadel.wav"
const MUSIC_SEARCH_ROOT = "res://music"

var _player: AudioStreamPlayer
var _volume_linear: float = 1.0
var _resolved_path: String = ""
var _warned_missing: bool = false

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
	var path := _resolve_run_soundtrack()
	if path.is_empty():
		if not _warned_missing:
			push_warning("MusicManager: No run soundtrack found (expected %s or any audio under %s)." % [RUN_SOUNDTRACK_PATH, MUSIC_SEARCH_ROOT])
			_warned_missing = true
		return
	if _current_stream_path() == path and _player.playing:
		return
	var stream = load(path) as AudioStream
	if stream == null:
		if not _warned_missing:
			push_warning("MusicManager: Failed to load run soundtrack: " + path)
			_warned_missing = true
		_resolved_path = ""
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
	return _resolved_path

func _resolve_run_soundtrack() -> String:
	if not _resolved_path.is_empty() and ResourceLoader.exists(_resolved_path):
		return _resolved_path
	if ResourceLoader.exists(RUN_SOUNDTRACK_PATH):
		_resolved_path = RUN_SOUNDTRACK_PATH
		return _resolved_path
	var fallback := _find_first_audio_file(MUSIC_SEARCH_ROOT)
	if not fallback.is_empty():
		_resolved_path = fallback
		return _resolved_path
	return ""

func _find_first_audio_file(root_path: String) -> String:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return ""
	var stack: Array[String] = [root_path]
	while not stack.is_empty():
		var current_path: String = stack.pop_back()
		var current_dir: DirAccess = DirAccess.open(current_path)
		if current_dir == null:
			continue
		current_dir.list_dir_begin()
		var entry_name: String = current_dir.get_next()
		while entry_name != "":
			if entry_name != "." and entry_name != "..":
				var entry_path: String = current_path.path_join(entry_name)
				if current_dir.current_is_dir():
					stack.append(entry_path)
				elif entry_name.ends_with(".wav") or entry_name.ends_with(".ogg") or entry_name.ends_with(".mp3"):
					return entry_path
			entry_name = current_dir.get_next()
		current_dir.list_dir_end()
	return ""

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
