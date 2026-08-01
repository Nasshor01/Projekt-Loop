# AudioManager.gd — SFX singleton (pool + named IDs). Missing files = warn once, never crash.
extends Node

## Logical IDs used by gameplay / UI. Paths can be remapped without touching call sites.
const SFX_UI_CLICK := "ui_click"
const SFX_CARD_PLAY := "card_play"
const SFX_CARD_SHUFFLE := "card_shuffle"
const SFX_COINS := "coins"
const SFX_HIT_DEAL := "hit_deal"
const SFX_HIT_TAKE := "hit_take"
const SFX_FOOTSTEP := "footstep"

## Current pick folder — rename/move later; keep IDs stable.
const SFX_PATHS: Dictionary = {
	SFX_UI_CLICK: "res://Audio/vybrane audio/click_002.ogg",
	SFX_CARD_PLAY: "res://Audio/vybrane audio/card-place-2.ogg",
	SFX_CARD_SHUFFLE: "res://Audio/vybrane audio/card_shuffle.wav",
	SFX_COINS: "res://Audio/vybrane audio/handleCoins.ogg",
	SFX_HIT_DEAL: "res://Audio/vybrane audio/u_xjrmmgxfru-flesh-impact-266316.mp3",
	SFX_HIT_TAKE: "res://Audio/vybrane audio/u_xjrmmgxfru-flesh-impact-266316.mp3",
	SFX_FOOTSTEP: "res://Audio/vybrane audio/footstep05.ogg",
}

const POOL_SIZE := 8

var _path_overrides: Dictionary = {} # id -> path (optional runtime remap)
var _pool: Array[AudioStreamPlayer] = []
var _stream_cache: Dictionary = {} # id -> AudioStream (or null after failed load)
var _volume_linear: float = 1.0
var _warned_missing: Dictionary = {} # id -> true
var _pool_index: int = 0

func _ready() -> void:
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer"
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		add_child(player)
		_pool.append(player)
	_load_volume()
	_apply_volume_to_pool()
	# Global UI click: hook existing + future BaseButtons
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_hook_existing_buttons")

# --- Public API ---------------------------------------------------------------

func play(sfx_id: String, pitch_scale: float = 1.0, volume_scale: float = 1.0) -> void:
	"""Play named SFX. Missing/unloadable stream = no-op (warn once)."""
	if _volume_linear <= 0.0 or volume_scale <= 0.0:
		return
	var stream := _get_stream(sfx_id)
	if stream == null:
		return
	var player := _next_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	_apply_player_volume(player, volume_scale)
	player.play()

func play_path(path: String, pitch_scale: float = 1.0, volume_scale: float = 1.0) -> void:
	"""Play any AudioStream path once (not cached by ID)."""
	if path.is_empty() or _volume_linear <= 0.0 or volume_scale <= 0.0:
		return
	if not ResourceLoader.exists(path):
		_warn_once(path, "AudioManager: SFX file missing: %s" % path)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		_warn_once(path, "AudioManager: Failed to load SFX: %s" % path)
		return
	var player := _next_player()
	if player == null:
		return
	player.stream = stream
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	_apply_player_volume(player, volume_scale)
	player.play()

func play_ui_click() -> void:
	play(SFX_UI_CLICK)

func play_card_play() -> void:
	play(SFX_CARD_PLAY)

func play_card_shuffle() -> void:
	play(SFX_CARD_SHUFFLE)

func play_coins() -> void:
	play(SFX_COINS)

func play_hit_deal() -> void:
	play(SFX_HIT_DEAL, randf_range(0.95, 1.08))

func play_hit_take() -> void:
	# Same impact sample, lower pitch / slightly quieter = "hurt"
	play(SFX_HIT_TAKE, randf_range(0.78, 0.90), 0.85)

func play_footstep() -> void:
	play(SFX_FOOTSTEP, randf_range(0.92, 1.08), 0.75)

func has_sfx(sfx_id: String) -> bool:
	return _get_stream(sfx_id) != null

func set_volume_linear(value: float) -> void:
	_volume_linear = clampf(value, 0.0, 1.0)
	_apply_volume_to_pool()
	_save_volume()

func get_volume_linear() -> float:
	return _volume_linear

func register_sfx(sfx_id: String, path: String) -> void:
	"""Override / add a path at runtime (tests, hot-swap). Clears cache for that ID."""
	_path_overrides[sfx_id] = path
	_stream_cache.erase(sfx_id)
	_warned_missing.erase(sfx_id)

# --- UI click hook ------------------------------------------------------------

func _on_tree_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)

func _hook_existing_buttons() -> void:
	var root := get_tree().root
	if root:
		_hook_buttons_recursive(root)

func _hook_buttons_recursive(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)
	for child in node.get_children():
		_hook_buttons_recursive(child)

func _hook_button(button: BaseButton) -> void:
	if button.get_meta("_audio_click_hooked", false):
		return
	button.set_meta("_audio_click_hooked", true)
	if not button.pressed.is_connected(_on_any_button_pressed):
		button.pressed.connect(_on_any_button_pressed)

func _on_any_button_pressed() -> void:
	play_ui_click()

# --- Internals ----------------------------------------------------------------

func _resolve_path(sfx_id: String) -> String:
	if _path_overrides.has(sfx_id):
		return str(_path_overrides[sfx_id])
	if SFX_PATHS.has(sfx_id):
		return str(SFX_PATHS[sfx_id])
	return ""

func _get_stream(sfx_id: String) -> AudioStream:
	if _stream_cache.has(sfx_id):
		return _stream_cache[sfx_id] as AudioStream
	var path := _resolve_path(sfx_id)
	if path.is_empty():
		_warn_once(sfx_id, "AudioManager: Unknown SFX id '%s'" % sfx_id)
		_stream_cache[sfx_id] = null
		return null
	if not ResourceLoader.exists(path):
		_warn_once(sfx_id, "AudioManager: SFX missing for '%s' (%s)" % [sfx_id, path])
		_stream_cache[sfx_id] = null
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		_warn_once(sfx_id, "AudioManager: Failed to load '%s' from %s" % [sfx_id, path])
	_stream_cache[sfx_id] = stream
	return stream

func _next_player() -> AudioStreamPlayer:
	if _pool.is_empty():
		return null
	# Round-robin so overlapping hits don't cut each other off.
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	return player

func _apply_player_volume(player: AudioStreamPlayer, volume_scale: float) -> void:
	var linear := clampf(_volume_linear * volume_scale, 0.0, 1.0)
	if linear <= 0.0:
		player.volume_db = -80.0
	else:
		player.volume_db = linear_to_db(linear)

func _apply_volume_to_pool() -> void:
	for player in _pool:
		_apply_player_volume(player, 1.0)

func _warn_once(key: String, message: String) -> void:
	if _warned_missing.has(key):
		return
	_warned_missing[key] = true
	push_warning(message)

func _load_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK and cfg.has_section_key("settings", "sfx_volume"):
		_volume_linear = clampf(float(cfg.get_value("settings", "sfx_volume")) / 100.0, 0.0, 1.0)

func _save_volume() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://settings.cfg")
	if err != OK:
		cfg = ConfigFile.new()
	cfg.set_value("settings", "sfx_volume", int(_volume_linear * 100))
	cfg.save("user://settings.cfg")
