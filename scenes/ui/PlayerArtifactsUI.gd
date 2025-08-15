# Soubor: scripts/ui/PlayerArtifactsUI.gd
extends HBoxContainer

const ArtifactIconScene = preload("res://scenes/ui/ArtifactIcon.tscn")

func _ready():
	# Nastavíme mezery mezi ikonami
	add_theme_constant_override("separation", 4)
	
	PlayerData.artifacts_changed.connect(update_artifacts_display)
	update_artifacts_display()

func update_artifacts_display():
	for child in get_children():
		child.queue_free()
	
	for artifact_data in PlayerData.artifacts:
		var icon_instance = ArtifactIconScene.instantiate()
		add_child(icon_instance)
		icon_instance.set_artifact(artifact_data)
