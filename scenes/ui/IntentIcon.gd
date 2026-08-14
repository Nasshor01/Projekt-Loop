extends Control

@export var bob_height: float = 6.0
@export var bob_duration: float = 1.2
## When true (dual-intent row), use a slightly smaller bob amplitude.
@export var compact_mode: bool = false

const _DEFAULT_BOB_HEIGHT := 6.0
const _COMPACT_BOB_HEIGHT := 4.0

## Base Label layout from IntentIcon.tscn (scale 1.0).
const _BASE_INTENT_FONT := 27
const _BASE_COUNTDOWN_FONT := 28
const _BASE_INTENT_SIZE := Vector2(96, 24)
const _BASE_INTENT_TOP := 20.0
const _BASE_COUNTDOWN_POS := Vector2(10, -26)
const _BASE_COUNTDOWN_SIZE := Vector2(26, 24)

@onready var icon_sprite: Sprite2D = $Sprite2D
@onready var intent_label: Label = $Label
@onready var countdown_label: Label = $CountdownLabel

var _base_position: Vector2
var _bob_tween: Tween
var _screen_position: Vector2 = Vector2.ZERO
var _bob_offset: float = 0.0
var _icon_scale: float = 1.0
var _show_intent_label: bool = true

func _ready() -> void:
	visible = false
	_force_mouse_passthrough()
	_base_position = position
	if compact_mode:
		bob_height = _COMPACT_BOB_HEIGHT
	_start_bob()
	set_process(true)
	if countdown_label:
		countdown_label.visible = false

func _force_mouse_passthrough() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_intent(icon: Texture2D, text: String) -> void:
	_force_mouse_passthrough()
	if is_instance_valid(icon_sprite):
		icon_sprite.texture = icon
		icon_sprite.visible = icon != null
	if is_instance_valid(intent_label):
		intent_label.text = text
		intent_label.visible = _show_intent_label and text != ""

func set_label_visible(p_visible: bool) -> void:
	"""When false, hide the under-icon value label (e.g. dual-intent row shows values on the row)."""
	_show_intent_label = p_visible
	if is_instance_valid(intent_label):
		intent_label.visible = p_visible and intent_label.text != ""

func set_countdown(turns: int) -> void:
	"""Zobrazí číselný odpočet kol na ikoně (0 = skrýt)"""
	if not is_instance_valid(countdown_label):
		return
	_force_mouse_passthrough()
	if turns > 0:
		countdown_label.text = str(turns)
		countdown_label.visible = true
	else:
		countdown_label.text = ""
		countdown_label.visible = false

func clear_countdown() -> void:
	"""Skryje odpočet"""
	if is_instance_valid(countdown_label):
		countdown_label.visible = false

func get_icon_texture_size() -> Vector2:
	if is_instance_valid(icon_sprite) and icon_sprite.texture:
		return icon_sprite.texture.get_size()
	return Vector2(64, 64)

func set_icon_scale(scale_value: float) -> void:
	_icon_scale = scale_value
	if is_instance_valid(icon_sprite):
		icon_sprite.scale = Vector2(scale_value, scale_value)
	_layout_labels_for_scale(scale_value)

func _layout_labels_for_scale(s: float) -> void:
	# Scale font/size/position instead of Label.scale so text stays centered under the sprite
	# (Control.scale pivots from top-left and drifts relative to Sprite2D center).
	if is_instance_valid(intent_label):
		intent_label.scale = Vector2.ONE
		intent_label.add_theme_font_size_override("font_size", maxi(1, int(round(float(_BASE_INTENT_FONT) * s))))
		var intent_size := _BASE_INTENT_SIZE * s
		intent_label.position = Vector2(-intent_size.x * 0.5, _BASE_INTENT_TOP * s)
		intent_label.size = intent_size
	if is_instance_valid(countdown_label):
		countdown_label.scale = Vector2.ONE
		countdown_label.add_theme_font_size_override("font_size", maxi(1, int(round(float(_BASE_COUNTDOWN_FONT) * s))))
		var cd_size := _BASE_COUNTDOWN_SIZE * s
		countdown_label.position = _BASE_COUNTDOWN_POS * s
		countdown_label.size = cd_size

func get_extent_below_center(scale_value: float) -> float:
	var tex_h := get_icon_texture_size().y * scale_value
	var below := tex_h * 0.5
	if _show_intent_label and is_instance_valid(intent_label) and intent_label.visible and intent_label.text != "":
		below += _BASE_INTENT_TOP * scale_value + _BASE_INTENT_SIZE.y * scale_value
	return below

func set_screen_position(new_position: Vector2) -> void:
	_screen_position = new_position
	global_position = _screen_position + Vector2(0, _bob_offset)

func show_intent() -> void:
	_force_mouse_passthrough()
	visible = true

func hide_intent() -> void:
	visible = false

func set_compact_mode(enabled: bool) -> void:
	compact_mode = enabled
	bob_height = _COMPACT_BOB_HEIGHT if compact_mode else _DEFAULT_BOB_HEIGHT
	if is_inside_tree():
		_start_bob()

func _start_bob() -> void:
	if is_instance_valid(_bob_tween):
		_bob_tween.kill()
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "_bob_offset", -bob_height, bob_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "_bob_offset", bob_height, bob_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta: float) -> void:
	global_position = _screen_position + Vector2(0, _bob_offset)
