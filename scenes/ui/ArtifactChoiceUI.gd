# Soubor: scenes/ui/ArtifactChoiceUI.gd
extends PanelContainer
class_name ArtifactChoiceUI

signal artifact_chosen(artifact_data: ArtifactsData)

@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var description_label: RichTextLabel = $VBoxContainer/DescriptionLabel

var artifact_data: ArtifactsData

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("artifact_chosen", artifact_data)
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.GRAY, 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func display_artifact(data: ArtifactsData):
	artifact_data = data
	name_label.text = data.artifact_name
	description_label.text = data.description
	if data.texture:
		icon.texture = data.texture
