# Soubor: scripts/ui/PlayerArtifactsUI.gd
extends HFlowContainer

const ArtifactIconScene = preload("res://scenes/ui/ArtifactIcon.tscn")

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	# Fill the ArtifactsStrip rect from GlobalUI — wrap at strip width, not full screen.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Must not steal clicks from reward/map UI under this strip (GlobalUI is a high CanvasLayer).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	PlayerData.artifacts_changed.connect(update_artifacts_display)
	update_artifacts_display()

func update_artifacts_display() -> void:
	for child in get_children():
		child.queue_free()

	for artifact_data in PlayerData.artifacts:
		var icon_instance = ArtifactIconScene.instantiate()
		add_child(icon_instance)
		icon_instance.set_artifact(artifact_data)
