# Soubor: scripts/ui/ArtifactIcon.gd
extends TextureRect
class_name ArtifactIcon

const ICON_SIZE := Vector2(56, 56)

var artifact_data: ArtifactsData
var _tip_text: String = ""


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = ""
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func set_artifact(data: ArtifactsData) -> void:
	artifact_data = data
	tooltip_text = ""
	_tip_text = ""
	if artifact_data and artifact_data.texture:
		texture = artifact_data.texture
		_tip_text = "%s\n%s" % [
			artifact_data.get_localized_name(),
			artifact_data.get_formatted_description()
		]
		if artifact_data.max_stacks > 1:
			_tip_text += "\n" + TranslationHelper.tr_format("artifact.stacks", {
				"current": artifact_data.current_stacks,
				"max": artifact_data.max_stacks
			})


func _on_mouse_entered() -> void:
	if _tip_text.is_empty():
		return
	ArtifactHoverTooltip.ensure(get_tree()).show_for(_tip_text, self, true)


func _on_mouse_exited() -> void:
	if is_instance_valid(ArtifactHoverTooltip.instance):
		ArtifactHoverTooltip.instance.hide_tip()


func _exit_tree() -> void:
	if is_instance_valid(ArtifactHoverTooltip.instance) and ArtifactHoverTooltip.instance.visible:
		ArtifactHoverTooltip.instance.hide_tip()
