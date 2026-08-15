# Soubor: FloatingText.gd
# Combat float: optional status/intent Texture2D + outlined number/text (no emoji).
extends Control

@onready var _hbox: HBoxContainer = $HBox
@onready var _icon: TextureRect = $HBox/Icon
@onready var _label: Label = $HBox/Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_hbox):
		_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_icon):
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_label):
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Sets content and returns measured size for centering. Call animate() after positioning.
func prepare(text_to_show: String, color: Color, icon: Texture2D = null) -> Vector2:
	if not is_node_ready():
		await ready
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = text_to_show
	_label.add_theme_color_override("font_color", color)
	if icon != null:
		_icon.texture = icon
		_icon.visible = true
	else:
		_icon.texture = null
		_icon.visible = false
	_hbox.reset_size()
	var sz: Vector2 = _hbox.get_combined_minimum_size()
	custom_minimum_size = sz
	size = sz
	return sz

func animate() -> void:
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(0.75, 0.75)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	var move_fade = create_tween()
	move_fade.set_parallel(true)
	move_fade.tween_property(self, "position:y", position.y - 56, 0.9).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	move_fade.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.3)
	await move_fade.finished
	queue_free()

## Back-compat: prepare + animate in one call (position must already be set, or set after prepare).
func start(text_to_show: String, color: Color, icon: Texture2D = null) -> void:
	await prepare(text_to_show, color, icon)
	await animate()
