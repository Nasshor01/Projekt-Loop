# Soubor: scripts/ui/ArtifactIcon.gd
extends TextureRect
class_name ArtifactIcon

var artifact_data: ArtifactsData

func set_artifact(data: ArtifactsData):
	artifact_data = data
	if artifact_data and artifact_data.texture:
		self.texture = artifact_data.texture
		tooltip_text = "[b]%s[/b]\n%s" % [artifact_data.artifact_name, artifact_data.description]
