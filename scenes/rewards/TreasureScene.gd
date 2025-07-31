# Soubor: scenes/rewards/TreasureScene.gd
extends CanvasLayer

const ArtifactChoiceScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
const ALL_ARTIFACTS_PATH = "res://data/artifacts/"

@onready var choices_container: HBoxContainer = $HBoxContainer

func _ready():
	var all_artifacts = _load_all_artifacts(ALL_ARTIFACTS_PATH)
	all_artifacts.shuffle()
	
	var choices: Array[ArtifactsData] = []
	for i in range(min(3, all_artifacts.size())):
		choices.append(all_artifacts[i])
	
	setup_choices(choices)

func _load_all_artifacts(path: String) -> Array[ArtifactsData]:
	var artifacts: Array[ArtifactsData] = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "." or file_name == "..":
				file_name = dir.get_next()
				continue

			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				artifacts.append_array(_load_all_artifacts(full_path))
			elif file_name.ends_with(".tres"):
				var resource = load(full_path)
				if resource is ArtifactsData:
					artifacts.append(resource)
			
			file_name = dir.get_next()
	else:
		printerr("Nepodařilo se otevřít složku: ", path)
	return artifacts

func setup_choices(artifacts: Array[ArtifactsData]):
	for child in choices_container.get_children():
		child.queue_free()
		
	for artifact_data in artifacts:
		var choice_instance = ArtifactChoiceScene.instantiate()
		choices_container.add_child(choice_instance)
		choice_instance.display_artifact(artifact_data)
		choice_instance.artifact_chosen.connect(_on_artifact_chosen)

func _on_artifact_chosen(artifact_data: ArtifactsData):
	print("Hráč si vybral artefakt: ", artifact_data.artifact_name)
	PlayerData.add_artifact(artifact_data)
	GameManager.treasure_collected()
