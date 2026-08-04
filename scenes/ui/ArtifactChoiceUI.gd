# Soubor: scenes/ui/ArtifactChoiceUI.gd
extends PanelContainer
class_name ArtifactChoiceUI

signal artifact_chosen(artifact_data: ArtifactsData)

@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel

var artifact_data: ArtifactsData
var _compact := false
var _icon_only := false

const ICON_ONLY_SIZE := Vector2(96, 96)


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("artifact_chosen", artifact_data)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.GRAY, 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)


func set_compact_mode(enabled: bool) -> void:
	"""Legacy shorter face — prefer set_icon_only for reward/shop."""
	_compact = enabled
	if _icon_only:
		return
	if not is_node_ready():
		call_deferred("set_compact_mode", enabled)
		return
	if enabled:
		custom_minimum_size = Vector2(220, 0)
		icon.custom_minimum_size = Vector2(96, 96)
		description_label.custom_minimum_size = Vector2(200, 0)
		description_label.add_theme_font_size_override("normal_font_size", 13)
		name_label.add_theme_font_size_override("font_size", 16)
	else:
		custom_minimum_size = Vector2(0, 0)
		icon.custom_minimum_size = Vector2(128, 128)
		description_label.custom_minimum_size = Vector2(0, 100)
		description_label.add_theme_font_size_override("normal_font_size", 15)
		name_label.add_theme_font_size_override("font_size", 18)


func set_icon_only(enabled: bool = true) -> void:
	"""STS2-style: only the relic icon; name/desc live in tooltip."""
	_icon_only = enabled
	if not is_node_ready():
		call_deferred("_apply_icon_only_layout")
		return
	_apply_icon_only_layout()


func _apply_icon_only_layout() -> void:
	if not is_instance_valid(icon):
		return
	if _icon_only:
		if name_label:
			name_label.visible = false
		if description_label:
			description_label.visible = false
		icon.custom_minimum_size = ICON_ONLY_SIZE
		icon.size = ICON_ONLY_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		custom_minimum_size = ICON_ONLY_SIZE
		size = ICON_ONLY_SIZE
		# No chrome — just the icon
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		mouse_filter = Control.MOUSE_FILTER_STOP
		_refresh_tooltip()
	else:
		if name_label:
			name_label.visible = true
		if description_label:
			description_label.visible = true
		icon.custom_minimum_size = Vector2(128, 128)
		custom_minimum_size = Vector2(0, 0)
		tooltip_text = ""


func display_artifact(data: ArtifactsData):
	artifact_data = data
	if is_instance_valid(name_label):
		name_label.text = data.get_localized_name()
	if is_instance_valid(description_label):
		description_label.text = data.get_formatted_description()
	if data.texture and is_instance_valid(icon):
		icon.texture = data.texture
	if _icon_only:
		_apply_icon_only_layout()
	else:
		_refresh_tooltip()


func _refresh_tooltip() -> void:
	if not artifact_data:
		tooltip_text = ""
		return
	if not _icon_only:
		tooltip_text = ""
		return
	tooltip_text = "%s\n%s" % [artifact_data.get_localized_name(), artifact_data.get_formatted_description()]
	if artifact_data.max_stacks > 1:
		tooltip_text += "\n" + TranslationHelper.tr_format("artifact.stacks", {
			"current": artifact_data.current_stacks,
			"max": artifact_data.max_stacks
		})


func set_stack_info(stack_info: String):
	if not stack_info.is_empty() and name_label and not _icon_only:
		name_label.text = "%s [%s]" % [name_label.text, stack_info]
	elif not stack_info.is_empty() and _icon_only and artifact_data:
		tooltip_text = "%s [%s]\n%s" % [
			artifact_data.get_localized_name(),
			stack_info,
			artifact_data.get_formatted_description()
		]


func get_layout_natural_size() -> Vector2:
	if _icon_only:
		return ICON_ONLY_SIZE
	var ms := custom_minimum_size
	if ms.x > 1.0 and ms.y > 1.0:
		return ms
	return Vector2(220, 200)


func get_artifact_data() -> ArtifactsData:
	return artifact_data
