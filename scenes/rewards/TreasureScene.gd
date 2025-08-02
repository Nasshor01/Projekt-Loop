# Soubor: scenes/rewards/TreasureScene.gd
extends CanvasLayer

const ArtifactChoiceScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
const ARTIFACT_POOL = preload("res://data/artifacts/basic_artifact_pool.tres")

@onready var choices_container: HBoxContainer = $HBoxContainer

func _ready():
	# Vezmeme data z naší knihovny
	var available_artifacts = ARTIFACT_POOL.artifacts.duplicate()
	available_artifacts.shuffle()
	
	# Vybereme maximálně 3 artefakty na zobrazení
	var artifact_choices = []
	if available_artifacts.size() <= 3:
		artifact_choices = available_artifacts
	else:
		artifact_choices = available_artifacts.slice(0, 3)
	
	# Vyčistíme kontejner od starých prvků (pro jistotu)
	for child in choices_container.get_children():
		child.queue_free()
	
	# Vytvoříme a zobrazíme nové UI pro výběr artefaktů
	for artifact_data in artifact_choices:
		if is_instance_valid(artifact_data):
			# OPRAVA: Používáme správný název proměnné "ArtifactChoiceScene"
			var choice_ui = ArtifactChoiceScene.instantiate()
			# OPRAVA: Používáme správný název proměnné "choices_container"
			choices_container.add_child(choice_ui)
			choice_ui.display_artifact(artifact_data)
			choice_ui.artifact_chosen.connect(_on_artifact_chosen)



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
