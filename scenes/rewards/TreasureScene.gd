# Soubor: scenes/rewards/TreasureScene.gd
extends CanvasLayer

const ArtifactChoiceScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
const ARTIFACT_POOL = preload("res://data/artifacts/basic_artifact_pool.tres")

@onready var choices_container: HBoxContainer = $HBoxContainer

func _ready():
	_generate_artifact_choices()



func setup_choices(artifacts: Array[ArtifactsData]):
	"""Alternativní způsob nastavení choices (pokud se používá externě)"""
	for child in choices_container.get_children():
		child.queue_free()
	
	var available_artifacts = get_available_artifacts(artifacts)
	
	if available_artifacts.is_empty():
		_create_skip_option()
		return
		
	for artifact_data in available_artifacts:
		var choice_instance = ArtifactChoiceScene.instantiate()
		choices_container.add_child(choice_instance)
		choice_instance.display_artifact(artifact_data)
		choice_instance.artifact_chosen.connect(_on_artifact_chosen)

# PŘIDEJ TYTO NOVÉ FUNKCE:
func _generate_artifact_choices():
	# Vyčistíme kontejner od starých prvků
	for child in choices_container.get_children():
		child.queue_free()
	
	# NOVÉ: Filtrujeme dostupné artefakty
	var available_artifacts = get_available_artifacts(ARTIFACT_POOL.artifacts)
	
	if available_artifacts.is_empty():
		print("⚠️ Žádné dostupné artefakty pro výběr!")
		_create_skip_option()
		return
	
	available_artifacts.shuffle()
	
	# Vybereme maximálně 3 artefakty na zobrazení
	var artifact_choices = []
	if available_artifacts.size() <= 3:
		artifact_choices = available_artifacts
	else:
		artifact_choices = available_artifacts.slice(0, 3)
	
	# Vytvoříme a zobrazíme nové UI pro výběr artefaktů
	for artifact_data in artifact_choices:
		if is_instance_valid(artifact_data):
			var choice_ui = ArtifactChoiceScene.instantiate()
			choices_container.add_child(choice_ui)
			choice_ui.display_artifact(artifact_data)
			choice_ui.artifact_chosen.connect(_on_artifact_chosen)

func get_available_artifacts(artifact_pool: Array) -> Array:
	"""Filtruje artefakty které hráč může získat"""
	var available = []
	
	for artifact in artifact_pool:
		if PlayerData.can_gain_artifact(artifact):
			available.append(artifact)
	
	return available

func _create_skip_option():
	"""Vytvoří možnost přeskočit, když nejsou dostupné artefakty"""
	var skip_button = Button.new()
	skip_button.text = "Přeskočit (žádné dostupné artefakty)"
	skip_button.pressed.connect(_on_skip_pressed)
	choices_container.add_child(skip_button)

func _on_skip_pressed():
	print("Hráč přeskočil výběr artefaktu")
	GameManager.treasure_collected()

func _on_artifact_chosen(artifact_data: ArtifactsData):
	print("Hráč si vybral artefakt: ", artifact_data.artifact_name)
	
	# OPRAVENO: Používáme novou add_artifact funkci s return hodnotu
	if PlayerData.add_artifact(artifact_data):
		print("✅ Artefakt úspěšně získán!")
		GameManager.treasure_collected()
	else:
		print("❌ Nemůžeš získat tento artefakt!")
		# Zde bys mohl zobrazit error message místo uzavření
