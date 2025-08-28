# Soubor: scenes/rewards/TreasureScene.gd (FINÁLNÍ VERZE)
extends CanvasLayer

const ArtifactChoiceScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
# ZMĚNA: Používáme správný pool pro pokladnice!
const ARTIFACT_POOL = preload("res://data/artifacts/pool/treasure_room_pool.tres")

@onready var choices_container: HBoxContainer = $HBoxContainer

func _ready():
	_generate_artifact_choices()

func _generate_artifact_choices():
	for child in choices_container.get_children():
		child.queue_free()

	var available_artifacts = get_available_artifacts(ARTIFACT_POOL.artifacts)
	
	if available_artifacts.is_empty():
		print("⚠️ TreasureScene: Žádné dostupné artefakty pro výběr!")
		_create_skip_option()
		return

	var artifact_choices = []
	
	# --- NOVÁ LOGIKA VÁŽENÉHO VÝBĚRU ---
	# Slot 1: 80% Uncommon, 20% Rare
	var artifact1 = _get_weighted_random_artifact(available_artifacts, 0.8, ArtifactsData.ArtifactType.UNCOMMON, ArtifactsData.ArtifactType.RARE)
	if artifact1:
		artifact_choices.append(artifact1)
		available_artifacts.erase(artifact1) # Odstraníme, aby se nemohl vybrat znovu

	# Slot 2: 50% Uncommon, 50% Rare
	var artifact2 = _get_weighted_random_artifact(available_artifacts, 0.5, ArtifactsData.ArtifactType.UNCOMMON, ArtifactsData.ArtifactType.RARE)
	if artifact2:
		artifact_choices.append(artifact2)
		available_artifacts.erase(artifact2)

	# Slot 3: 80% Rare, 20% Legendary
	var artifact3 = _get_weighted_random_artifact(available_artifacts, 0.8, ArtifactsData.ArtifactType.RARE, ArtifactsData.ArtifactType.LEGENDARY)
	if artifact3:
		artifact_choices.append(artifact3)
		available_artifacts.erase(artifact3)
	# --- KONEC NOVÉ LOGIKY ---

	if artifact_choices.is_empty():
		print("⚠️ TreasureScene: Nepodařilo se vygenerovat žádné volby i přes dostupné artefakty!")
		_create_skip_option()
		return

	for artifact_data in artifact_choices:
		var choice_ui = ArtifactChoiceScene.instantiate()
		choices_container.add_child(choice_ui)
		choice_ui.display_artifact(artifact_data)
		choice_ui.artifact_chosen.connect(_on_artifact_chosen)

func get_available_artifacts(artifact_pool: Array) -> Array:
	var available = []
	for artifact in artifact_pool:
		if PlayerData.can_gain_artifact(artifact):
			available.append(artifact)
	return available

func _get_weighted_random_artifact(pool: Array, chance_for_first: float, type1: ArtifactsData.ArtifactType, type2: ArtifactsData.ArtifactType) -> ArtifactsData:
	var target_type = type1 if randf() < chance_for_first else type2
	
	var filtered_pool = pool.filter(func(art): return art.artifact_type == target_type)
	if not filtered_pool.is_empty():
		return filtered_pool.pick_random()
	
	# Fallback: pokud se nenajde cílová rarita, zkusíme tu druhou
	var fallback_type = type2 if target_type == type1 else type1
	filtered_pool = pool.filter(func(art): return art.artifact_type == fallback_type)
	if not filtered_pool.is_empty():
		return filtered_pool.pick_random()
		
	return null # Pokud v poolu není ani jedna z požadovaných rarit

func _create_skip_option():
	var skip_button = Button.new()
	skip_button.text = "Pokračovat"
	skip_button.pressed.connect(_on_skip_pressed)
	choices_container.add_child(skip_button)

func _on_skip_pressed():
	GameManager.treasure_collected()

func _on_artifact_chosen(artifact_data: ArtifactsData):
	if PlayerData.add_artifact(artifact_data):
		GameManager.treasure_collected()
	else:
		print("❌ Chyba: Tento artefakt nelze získat!")
		# Zde by se mohlo zobrazit nějaké upozornění pro hráče
