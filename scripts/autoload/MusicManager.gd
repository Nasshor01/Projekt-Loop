# MusicManager.gd — continuous soundtrack playlist (not per-scene)
extends Node

const SOUNDTRACK_DIR := "res://Audio/soundtrack"

## Prefer this order; any other audio in the folder is appended.
const PREFERRED_ORDER: Array[String] = [
	"Ash in the Hourglass.wav",
	"Corridor of Returning.wav",
	"Cards Against the Dark.wav",
	"Embers at Rest.wav",
	"The Village Remembers.wav",
	"Boss of the Same Day.wav",
	"Broken Cycle.wav",
]

var _player: AudioStreamPlayer = null
var _volume_linear: float = 1.0
var _playlist: Array[String] = []
var _playlist_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_player()
	_build_playlist()
	_load_volume()
	_apply_volume()
	_start_current_track()

func play() -> void:
	if not is_node_ready():
		call_deferred("play")
		return
	if _player != null and _player.playing:
		_apply_volume()
		return
	_start_current_track()

func play_run() -> void:
	play()

func play_menu() -> void:
	play()

func stop_run() -> void:
	pass

func stop() -> void:
	if _player != null:
		_player.stop()

func is_playing() -> bool:
	return _player != null and _player.playing

func set_volume_linear(value: float) -> void:
	_volume_linear = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_volume()

func get_volume_linear() -> float:
	return _volume_linear

func _ensure_player() -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "MusicPlayer"
		add_child(_player)
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = "Master"
	if not _player.finished.is_connected(_on_finished):
		_player.finished.connect(_on_finished)
	return _player

func _build_playlist() -> void:
	_playlist.clear()
	var found: Dictionary = {} # basename -> full path
	var dir := DirAccess.open(SOUNDTRACK_DIR)
	if dir != null:
		dir.list_dir_begin()
		var name: String = dir.get_next()
		while name != "":
			if not dir.current_is_dir():
				var lower := name.to_lower()
				if lower.ends_with(".wav") or lower.ends_with(".ogg") or lower.ends_with(".mp3"):
					found[name] = SOUNDTRACK_DIR.path_join(name)
			name = dir.get_next()
		dir.list_dir_end()
	for preferred in PREFERRED_ORDER:
		if found.has(preferred):
			_playlist.append(str(found[preferred]))
			found.erase(preferred)
	# Any leftovers (new drops) go at the end, sorted for stability.
	var leftovers: Array = found.values()
	leftovers.sort()
	for path in leftovers:
		_playlist.append(str(path))
	if _playlist.is_empty():
		push_error("MusicManager: no tracks in %s" % SOUNDTRACK_DIR)
	_playlist_index = 0

func _start_current_track() -> void:
	var player: AudioStreamPlayer = _ensure_player()
	if _playlist.is_empty():
		_build_playlist()
	if _playlist.is_empty():
		return
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, false)
	if _playlist_index < 0 or _playlist_index >= _playlist.size():
		_playlist_index = 0
	var path: String = _playlist[_playlist_index]
	if not ResourceLoader.exists(path):
		push_error("MusicManager: missing %s — skipping" % path)
		_advance_and_play()
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_error("MusicManager: failed to load %s — skipping" % path)
		_advance_and_play()
		return
	player.stream = stream
	player.bus = "Master"
	_apply_volume()
	player.play()

func _advance_and_play() -> void:
	if _playlist.is_empty():
		return
	_playlist_index += 1
	if _playlist_index >= _playlist.size():
		_playlist_index = 0
		_playlist.shuffle()
	_start_current_track()

func _on_finished() -> void:
	_advance_and_play()

func _apply_volume() -> void:
	if _player == null:
		return
	if _volume_linear <= 0.001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(_volume_linear) + 6.0

func _load_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK and cfg.has_section_key("settings", "music_volume"):
		var raw: float = float(cfg.get_value("settings", "music_volume", 100))
		_volume_linear = clampf(raw, 0.0, 100.0) / 100.0

func _save_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		cfg = ConfigFile.new()
	cfg.set_value("settings", "music_volume", int(round(_volume_linear * 100.0)))
	cfg.save("user://settings.cfg")
