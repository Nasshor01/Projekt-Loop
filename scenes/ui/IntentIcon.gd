extends Control

@export var bob_height: float = 6.0
@export var bob_duration: float = 1.2

@onready var icon_sprite: Sprite2D = $Sprite2D
@onready var intent_label: Label = $Label
@onready var countdown_label: Label = $CountdownLabel

var _base_position: Vector2
var _bob_tween: Tween
var _screen_position: Vector2 = Vector2.ZERO
var _bob_offset: float = 0.0

func _ready() -> void:
	visible = false
	_force_mouse_passthrough()
	_base_position = position
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
		intent_label.visible = text != ""

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
	if is_instance_valid(icon_sprite):
		icon_sprite.scale = Vector2(scale_value, scale_value)
	if is_instance_valid(intent_label):
		intent_label.scale = Vector2(scale_value, scale_value)
	if is_instance_valid(countdown_label):
		countdown_label.scale = Vector2(scale_value, scale_value)

func set_screen_position(new_position: Vector2) -> void:
	_screen_position = new_position
	global_position = _screen_position + Vector2(0, _bob_offset)

func show_intent() -> void:
	_force_mouse_passthrough()
	visible = true

func hide_intent() -> void:
	visible = false

func _start_bob() -> void:
	if is_instance_valid(_bob_tween):
		_bob_tween.kill()
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "_bob_offset", -bob_height, bob_duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "_bob_offset", bob_height, bob_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta: float) -> void:
	global_position = _screen_position + Vector2(0, _bob_offset)
