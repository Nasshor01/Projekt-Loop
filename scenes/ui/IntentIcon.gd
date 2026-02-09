extends Node2D

@export var bob_height: float = 6.0
@export var bob_duration: float = 1.2

@onready var icon_sprite: Sprite2D = $Sprite2D
@onready var intent_label: Label = $Label

var _base_position: Vector2
var _bob_tween: Tween
var _screen_position: Vector2 = Vector2.ZERO
var _bob_offset: float = 0.0

func _ready() -> void:
	visible = false
	_base_position = position
	_start_bob()
	set_process(true)

func set_intent(icon: Texture2D, text: String) -> void:
	if is_instance_valid(icon_sprite):
		icon_sprite.texture = icon
		icon_sprite.visible = icon != null
	if is_instance_valid(intent_label):
		intent_label.text = text
		intent_label.visible = text != ""

func get_icon_texture_size() -> Vector2:
	if is_instance_valid(icon_sprite) and icon_sprite.texture:
		return icon_sprite.texture.get_size()
	return Vector2(64, 64)

func set_icon_scale(scale_value: float) -> void:
	if is_instance_valid(icon_sprite):
		icon_sprite.scale = Vector2(scale_value, scale_value)
	if is_instance_valid(intent_label):
		intent_label.scale = Vector2(scale_value, scale_value)

func set_screen_position(new_position: Vector2) -> void:
	_screen_position = new_position
	position = _screen_position + Vector2(0, _bob_offset)

func show_intent() -> void:
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
	position = _screen_position + Vector2(0, _bob_offset)
