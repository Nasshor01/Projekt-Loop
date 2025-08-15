# Soubor: scripts/ui/ArtifactIcon.gd
extends TextureRect
class_name ArtifactIcon

var artifact_data: ArtifactsData

func _ready():
	# Nastavíme pevnou velikost pro ikony artefaktů
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)
	
	# Zajistíme správné škálování textury
	expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func set_artifact(data: ArtifactsData):
	artifact_data = data
	if artifact_data and artifact_data.texture:
		self.texture = artifact_data.texture
		
		# OPRAVENÝ TOOLTIP - používáme get_formatted_description() místo description
		tooltip_text = "%s\n%s" % [artifact_data.artifact_name, artifact_data.get_formatted_description()]
		
		# Pokud chceš stacky v tooltipu
		if artifact_data.max_stacks > 1:
			tooltip_text += "\nStacky: %d/%d" % [artifact_data.current_stacks, artifact_data.max_stacks]
