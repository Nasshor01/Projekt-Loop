# Soubor: scenes/rewards/TreasureScene.gd (FINÁLNÍ VERZE)
extends CanvasLayer

const ArtifactChoiceScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
# ZMĚNA: Používáme správný pool pro pokladnice!
const ARTIFACT_POOL = preload("res://data/artifacts/pool/treasure_room_pool.tres")

@onready var title_label: Label = $Label
@onready var choices_container: HBoxContainer = $HBoxContainer

var _is_coop: bool = false
var _is_host: bool = true
# Coop: sledování výběru
var _coop_my_choice_path: String = ""
var _coop_other_choice_path: String = ""
var _coop_my_done: bool = false
var _coop_other_done: bool = false

func _ready():
	if title_label:
		title_label.text = tr("ui.treasure.title")
	
	_is_coop = has_node("/root/GameManager") and GameManager.is_coop_run
	_is_host = not _is_coop or (has_node("/root/MultiplayerManager") and MultiplayerManager.is_server())
	
	if _is_coop and not _is_host:
		# Klient: použij pending data od hosta
		var pending = GameManager._coop_pending_treasure_paths
		if not pending.is_empty():
			_generate_from_host_data(pending)
			GameManager._coop_pending_treasure_paths = []
		else:
			# Data ještě nepřišla – čekáme (poll)
			_wait_for_treasure_data()
	else:
		_generate_artifact_choices()
		# Host v coopu: pošli artifact paths klientovi přes autoload
		if _is_coop and _is_host and has_node("/root/MultiplayerManager"):
			var paths: Array = []
			for child in choices_container.get_children():
				if child.has_method("get_artifact_data"):
					var ad = child.get_artifact_data()
					if is_instance_valid(ad):
						paths.append(ad.resource_path)
			MultiplayerManager.rpc("receive_go_to_treasure", paths)

func _wait_for_treasure_data():
	"""Klient: čeká na treasure data od hosta."""
	for i in range(50):
		await get_tree().create_timer(0.1).timeout
		var pending = GameManager._coop_pending_treasure_paths
		if not pending.is_empty():
			_generate_from_host_data(pending)
			GameManager._coop_pending_treasure_paths = []
			return
	# Fallback
	_generate_artifact_choices()

func _generate_from_host_data(paths: Array):
	for child in choices_container.get_children():
		child.queue_free()
	if paths.is_empty():
		_create_skip_option()
		return
	for path in paths:
		var artifact_data = load(path) as ArtifactsData
		if not is_instance_valid(artifact_data):
			continue
		var choice_ui = ArtifactChoiceScene.instantiate()
		choices_container.add_child(choice_ui)
		choice_ui.display_artifact(artifact_data)
		choice_ui.artifact_chosen.connect(_on_artifact_chosen)

func _generate_artifact_choices():
	for child in choices_container.get_children():
		child.queue_free()

	var available_artifacts = get_available_artifacts(ARTIFACT_POOL.artifacts)
	
	if available_artifacts.is_empty():
		print(tr("log.treasure.no_artifacts"))
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
		print(tr("log.treasure.no_choices"))
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
	skip_button.text = tr("ui.common.continue")
	skip_button.pressed.connect(_on_skip_pressed)
	choices_container.add_child(skip_button)

func _on_skip_pressed():
	if _is_coop:
		_coop_my_done = true
		rpc("_rpc_treasure_peer_done", "")
		_coop_check_both_done()
	else:
		GameManager.treasure_collected()

func _on_artifact_chosen(artifact_data: ArtifactsData):
	if _is_coop:
		# Zkontroluj jestli druhý hráč nevybral stejný artefakt
		if artifact_data.resource_path == _coop_other_choice_path:
			return  # Blokuj
		if PlayerData.add_artifact(artifact_data):
			_coop_my_choice_path = artifact_data.resource_path
			_coop_my_done = true
			_coop_update_visuals()
			rpc("_rpc_treasure_peer_done", artifact_data.resource_path)
			_coop_check_both_done()
	else:
		if PlayerData.add_artifact(artifact_data):
			GameManager.treasure_collected()
		else:
			print(tr("log.treasure.cannot_gain_artifact"))

@rpc("any_peer", "call_remote")
func _rpc_treasure_peer_done(chosen_path: String):
	"""Druhý hráč vybral artefakt (nebo skipnul)."""
	_coop_other_choice_path = chosen_path
	_coop_other_done = true
	_coop_update_visuals()
	_coop_check_both_done()

func _coop_update_visuals():
	"""Vizuální označení vybraných artefaktů."""
	for child in choices_container.get_children():
		if not child.has_method("get_artifact_data"):
			continue
		var ad = child.get_artifact_data()
		if not is_instance_valid(ad):
			continue
		if ad.resource_path == _coop_my_choice_path:
			child.modulate = Color(0.5, 1.0, 0.5)  # Zelená – moje volba
		elif ad.resource_path == _coop_other_choice_path:
			child.modulate = Color(0.5, 0.5, 1.0)  # Modrá – druhý hráč
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Nelze kliknout
		else:
			child.modulate = Color.WHITE
			child.mouse_filter = Control.MOUSE_FILTER_STOP

func _coop_check_both_done():
	if _coop_my_done and _coop_other_done:
		await get_tree().create_timer(0.5).timeout
		GameManager.treasure_collected()
