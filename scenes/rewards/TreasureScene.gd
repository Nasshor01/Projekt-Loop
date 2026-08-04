# Soubor: scenes/rewards/TreasureScene.gd
extends CanvasLayer

const ArtifactChoiceScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")
const ARTIFACT_POOL = preload("res://data/artifacts/pool/treasure_room_pool.tres")

@onready var title_label: Label = %Label
@onready var skip_button: Button = %SkipButton

var artifact_slots: Array[LayoutSlot] = []

var _is_coop: bool = false
var _is_host: bool = true
var _coop_my_choice_path: String = ""
var _coop_other_choice_path: String = ""
var _coop_my_done: bool = false
var _coop_other_done: bool = false

func _ready():
	_collect_layout_slots()
	for slot in artifact_slots:
		if is_instance_valid(slot):
			slot.visible = false
	if title_label:
		title_label.text = tr("ui.treasure.title")
	if skip_button and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)

	_is_coop = has_node("/root/GameManager") and GameManager.is_coop_run
	_is_host = not _is_coop or (has_node("/root/MultiplayerManager") and MultiplayerManager.is_server())

	if _is_coop and not _is_host:
		var pending = GameManager._coop_pending_treasure_paths
		if not pending.is_empty():
			_generate_from_host_data(pending)
			GameManager._coop_pending_treasure_paths = []
		else:
			_wait_for_treasure_data()
	else:
		_generate_artifact_choices()
		if _is_coop and _is_host and has_node("/root/MultiplayerManager"):
			var paths: Array = []
			for ui in _iter_artifact_uis():
				var ad = ui.get_artifact_data()
				if is_instance_valid(ad):
					paths.append(ad.resource_path)
			MultiplayerManager.rpc("receive_go_to_treasure", paths)


func _collect_layout_slots() -> void:
	artifact_slots.clear()
	var root := get_node_or_null("Slots")
	if root == null:
		return
	var i := 0
	while true:
		var slot := root.get_node_or_null("ArtifactSlot_%d" % i) as LayoutSlot
		if slot == null:
			break
		artifact_slots.append(slot)
		i += 1


func _wait_for_treasure_data():
	for i in range(50):
		await get_tree().create_timer(0.1).timeout
		var pending = GameManager._coop_pending_treasure_paths
		if not pending.is_empty():
			_generate_from_host_data(pending)
			GameManager._coop_pending_treasure_paths = []
			return
	_generate_artifact_choices()


func _clear_slots() -> void:
	for slot in artifact_slots:
		if is_instance_valid(slot):
			slot.clear_mounted()
			slot.visible = false
	if skip_button:
		skip_button.visible = false


func _mount_artifact(artifact_data: ArtifactsData, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= artifact_slots.size():
		return
	var slot: LayoutSlot = artifact_slots[slot_index]
	slot.visible = true
	var choice_ui = ArtifactChoiceScene.instantiate()
	slot.mount(choice_ui)
	choice_ui.set_icon_only(true)
	choice_ui.display_artifact(artifact_data)
	choice_ui.artifact_chosen.connect(_on_artifact_chosen)
	slot.fit_mounted()


func _generate_from_host_data(paths: Array):
	_clear_slots()
	if paths.is_empty():
		_create_skip_option()
		return
	var idx := 0
	for path in paths:
		var artifact_data = load(path) as ArtifactsData
		if not is_instance_valid(artifact_data):
			continue
		_mount_artifact(artifact_data, idx)
		idx += 1
	if idx == 0:
		_create_skip_option()


func _generate_artifact_choices():
	_clear_slots()
	var available_artifacts = get_available_artifacts(ARTIFACT_POOL.artifacts)

	if available_artifacts.is_empty():
		print(tr("log.treasure.no_artifacts"))
		_create_skip_option()
		return

	var artifact_choices = []

	# Slot 1: 80% Uncommon, 20% Rare
	var artifact1 = _get_weighted_random_artifact(available_artifacts, 0.8, ArtifactsData.ArtifactType.UNCOMMON, ArtifactsData.ArtifactType.RARE)
	if artifact1:
		artifact_choices.append(artifact1)
		available_artifacts.erase(artifact1)

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

	if artifact_choices.is_empty():
		print(tr("log.treasure.no_choices"))
		_create_skip_option()
		return

	for i in range(artifact_choices.size()):
		_mount_artifact(artifact_choices[i], i)


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
	var fallback_type = type2 if target_type == type1 else type1
	filtered_pool = pool.filter(func(art): return art.artifact_type == fallback_type)
	if not filtered_pool.is_empty():
		return filtered_pool.pick_random()
	return null


func _create_skip_option():
	if skip_button:
		skip_button.visible = true
		skip_button.text = tr("ui.common.continue")


func _iter_artifact_uis() -> Array:
	var arts: Array = []
	for slot in artifact_slots:
		if not is_instance_valid(slot) or not slot.visible:
			continue
		var mounted := slot.get_mounted()
		if is_instance_valid(mounted):
			arts.append(mounted)
	return arts


func _on_skip_pressed():
	if _is_coop:
		_coop_my_done = true
		rpc("_rpc_treasure_peer_done", "")
		_coop_check_both_done()
	else:
		GameManager.treasure_collected()


func _on_artifact_chosen(artifact_data: ArtifactsData):
	if _is_coop:
		if artifact_data.resource_path == _coop_other_choice_path:
			return
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
	_coop_other_choice_path = chosen_path
	_coop_other_done = true
	_coop_update_visuals()
	_coop_check_both_done()


func _coop_update_visuals():
	for child in _iter_artifact_uis():
		if not child.has_method("get_artifact_data"):
			continue
		var ad = child.get_artifact_data()
		if not is_instance_valid(ad):
			continue
		if ad.resource_path == _coop_my_choice_path:
			child.modulate = Color(0.5, 1.0, 0.5)
		elif ad.resource_path == _coop_other_choice_path:
			child.modulate = Color(0.5, 0.5, 1.0)
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			child.modulate = Color.WHITE
			child.mouse_filter = Control.MOUSE_FILTER_STOP


func _coop_check_both_done():
	if _coop_my_done and _coop_other_done:
		await get_tree().create_timer(0.5).timeout
		GameManager.treasure_collected()
