# Soubor: scripts/map/Map.gd
# POPIS: Kompletní finální verze s dynamickým výběrem soubojů a správným zvýrazňováním.
extends Node2D

const MapNodeScene = preload("res://scenes/map/MapNode.tscn")
const ConnectionLineScene = preload("res://scenes/map/ConnectionLine.tscn")
const TutorialSpeechClass = preload("res://scenes/ui/TutorialSpeech.gd")

const VISITED_PATH_COLOR = Color.GOLD
const REACHABLE_PATH_COLOR = Color.WHITE

# Target on-screen icon size in world pixels (independent of source texture size).
const ICON_TARGET_SIZE := {
	"boss": 300.0,
	"rest": 48.0,
	"shop": 44.0,
	"event": 54.0,
	"default": 46.0,
}
const CAMERA_HORIZONTAL_PADDING := 220.0
const CAMERA_VERTICAL_PADDING := 180.0
const CAMERA_SCROLL_STEP := 90.0
const CAMERA_MAX_WIDTH_ZOOM := 1.05
# Leave room for legend + seed panel on the left so nodes don't overlap UI.
const CAMERA_LEFT_UI_MARGIN := 210.0
const CAMERA_RIGHT_UI_MARGIN := 40.0

# --- Seznamy možných soubojů ---
# STS-style: první N normal fightů (a raná patra) berou easy pool.
const EASY_MONSTER_FIGHT_LIMIT := 3
const EASY_MONSTER_MAX_ROW := 2  # row 0..2 = první 3 patra

var easy_monster_encounters = [
	"res://data/encounters/first_battle.tres",
	"res://data/encounters/goblin_duo.tres",
	"res://data/encounters/fortress_scouts.tres",
	"res://data/encounters/fortress_bowline.tres",
	"res://data/encounters/fortress_bruiser.tres",
]
var hard_monster_encounters = [
	"res://data/encounters/one_orc.tres",
	"res://data/encounters/Skeleton.tres",
	"res://data/encounters/demon_assassin.tres",
	"res://data/encounters/assassin_squad.tres",
	"res://data/encounters/fortress_pack.tres",
]
var elite_encounters = [
	"res://data/encounters/elite_battle.tres",
	"res://data/encounters/Skeleton_army.tres",
	"res://data/encounters/support_team.tres",
	"res://data/encounters/elite_mix.tres",
	"res://data/encounters/fortress_warband.tres",
]
var boss_encounters = ["res://data/encounters/boss_battle.tres"]

var node_textures = {
	MapNodeResource.NodeType.MONSTER: preload("res://art/sprites/map/icon/monster.png"),
	MapNodeResource.NodeType.ELITE: preload("res://art/sprites/map/icon/elite.png"),
	MapNodeResource.NodeType.EVENT: preload("res://art/sprites/map/icon/event.png"),
	MapNodeResource.NodeType.REST: preload("res://art/sprites/map/icon/campfire.png"),
	MapNodeResource.NodeType.SHOP: preload("res://art/sprites/map/icon/shop.png"),
	MapNodeResource.NodeType.TREASURE: preload("res://art/sprites/map/icon/chest.png"),
	MapNodeResource.NodeType.BOSS: preload("res://art/sprites/map/icon/boss.png")
}

var map_data: MapData
var map_nodes_visual: Dictionary = {}
var _tutorial_nodes: Dictionary = {}

var node_names = {
	MapNodeResource.NodeType.MONSTER: "ui.map.node.monster",
	MapNodeResource.NodeType.ELITE: "ui.map.node.elite",
	MapNodeResource.NodeType.EVENT: "ui.map.node.event",
	MapNodeResource.NodeType.REST: "ui.map.node.rest",
	MapNodeResource.NodeType.SHOP: "ui.map.node.shop",
	MapNodeResource.NodeType.TREASURE: "ui.map.node.treasure",
	MapNodeResource.NodeType.BOSS: "ui.map.node.boss"
}

@onready var legend_container = $CanvasLayer/LegendPanel/LegendContainer

@onready var generator_node = $MapGenerator
@onready var connections_container = $Connections
@onready var seed_label: Label = $CanvasLayer/SeedLabel
@onready var seed_line_edit: LineEdit = $CanvasLayer/Panel/VBoxContainer/SeedLineEdit
@onready var generate_seed_button: Button = $CanvasLayer/Panel/VBoxContainer/GenerateSeedButton
@onready var random_seed_button: Button = $CanvasLayer/Panel/VBoxContainer/RandomSeedButton
@onready var camera: Camera2D = $Camera2D
@onready var dev_console: CanvasLayer = $DevConsole

var _map_center_x: float = 0.0
var _camera_y_min: float = 0.0
var _camera_y_max: float = 0.0

func _ready():
	# Tato funkce se volá při startu scény
	generate_seed_button.pressed.connect(_on_generate_custom_seed_pressed)
	random_seed_button.pressed.connect(_on_generate_random_seed_pressed)
	dev_console.command_submitted.connect(_on_dev_command)
	_apply_seed_controls_visibility()
	_update_ui_texts()
	initialize_map()
	_setup_legend()

func _apply_seed_controls_visibility():
	var show_seed_controls = OS.is_debug_build()
	if is_instance_valid(seed_label):
		seed_label.visible = true
	if has_node("CanvasLayer/Panel"):
		$CanvasLayer/Panel.visible = show_seed_controls
	if is_instance_valid(seed_line_edit):
		seed_line_edit.visible = show_seed_controls
	if is_instance_valid(generate_seed_button):
		generate_seed_button.visible = show_seed_controls
	if is_instance_valid(random_seed_button):
		random_seed_button.visible = show_seed_controls

func _update_ui_texts():
	if generate_seed_button:
		generate_seed_button.text = tr("ui.map.generate_seed")
	if random_seed_button:
		random_seed_button.text = tr("ui.map.random_seed")

func _on_generate_random_seed_pressed():
	# Funkce pro tlačítko náhodného seedu
	GameManager.start_new_run()

func _on_generate_custom_seed_pressed():
	# Funkce pro tlačítko vlastního seedu
	var custom_seed_text = seed_line_edit.text
	
	if custom_seed_text.is_empty():
		# Pokud je pole prázdné, chová se jako tlačítko pro náhodný seed
		GameManager.start_new_run()
		print("Vstupní pole pro seed je prázdné, generuji náhodný seed.")
	elif custom_seed_text.is_valid_int():
		# POKUD je text platné celé číslo (např. "12345")
		# Převedeme ho přímo na číslo a použijeme ho
		var seed_value = custom_seed_text.to_int()
		GameManager.start_new_run(seed_value)
		print("Generuji mapu z číselného seedu: ", seed_value)
	else:
		# POKUD text není číslo (např. "ahoj svete")
		# Použijeme hash, abychom z textu dostali unikátní číslo
		var seed_value = custom_seed_text.hash()
		GameManager.start_new_run(seed_value)
		print("Generuji mapu z textového seedu (hash): ", custom_seed_text)


func initialize_map():
	_clear_map()

	if _is_tutorial_map():
		self.map_data = _build_tutorial_map()
		GameManager.current_map_data = self.map_data
	else:
		if GameManager.current_map_data == null:
			self.map_data = generator_node.generate_map(GameManager.current_seed)
			GameManager.current_map_data = self.map_data
		else:
			self.map_data = GameManager.current_map_data
	
	seed_label.text = TranslationHelper.tr_format("ui.map.seed", {"value": GameManager.current_seed})
	seed_line_edit.text = str(GameManager.current_seed)
	
	_render_map_visuals()
	_update_highlighting()
	_setup_camera()
	_show_tutorial_coach()

func _clear_map():
	for child in get_children():
		if child is MapNode:
			child.queue_free()
	for child in connections_container.get_children():
		child.queue_free()
	map_nodes_visual.clear()
	
func _render_map_visuals():
	for node_data in map_data.all_nodes:
		var map_node_instance = MapNodeScene.instantiate()
		map_node_instance.set_data(node_data)
		if node_textures.has(node_data.type):
			var sprite = map_node_instance.get_node("Sprite2D")
			sprite.texture = node_textures[node_data.type]
			sprite.scale = _icon_scale_for_type(node_data.type, sprite.texture)

		map_node_instance.node_clicked.connect(_on_map_node_clicked)
		
		map_node_instance.node_hovered.connect(_on_map_node_hovered)
		map_node_instance.node_exited.connect(_on_map_node_exited)
		
		add_child(map_node_instance)
		map_nodes_visual[node_data] = map_node_instance

func _icon_scale_for_type(node_type: MapNodeResource.NodeType, texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE
	var tex_size := float(maxi(texture.get_width(), texture.get_height()))
	if tex_size <= 0.0:
		return Vector2.ONE
	var target := float(ICON_TARGET_SIZE["default"])
	match node_type:
		MapNodeResource.NodeType.BOSS:
			target = float(ICON_TARGET_SIZE["boss"])
		MapNodeResource.NodeType.REST:
			target = float(ICON_TARGET_SIZE["rest"])
		MapNodeResource.NodeType.SHOP:
			target = float(ICON_TARGET_SIZE["shop"])
		MapNodeResource.NodeType.EVENT:
			target = float(ICON_TARGET_SIZE["event"])
		_:
			pass
	var s := target / tex_size
	return Vector2(s, s)

func _on_map_node_clicked(clicked_node: MapNode):
	# Coop: výběr uzlu má jen host; klient jen přijímá RPC
	if _is_coop() and not MultiplayerManager.is_server():
		return
	var current_node = PlayerData.get_current_node()
	var destination_node = clicked_node.node_data
	
	var is_valid_move = false
	if _is_tutorial_map():
		var allowed = _get_tutorial_allowed_node()
		if allowed != null and destination_node != allowed:
			return
	
	if current_node == null:
		if map_data.starting_nodes.has(destination_node): is_valid_move = true
	else:
		if current_node.connections.has(destination_node): is_valid_move = true
	
	if is_valid_move:
		PlayerData.path_taken.append(destination_node)
		# Loop Vesnice: +1 střep za každý dokončený floor uzel
		if has_node("/root/SaveManager"):
			SaveManager.add_shards(1)
		_update_highlighting()
		_trigger_node_action(destination_node)
	else:
		print("Neplatný tah!")

func _is_coop() -> bool:
	return has_node("/root/MultiplayerManager") and GameManager.is_coop_run and MultiplayerManager.has_active_connection()

func _get_node_action_payload(node_data: MapNodeResource) -> Dictionary:
	"""Vrátí { action_type: String, encounter: EncounterData nebo null } pro coop RPC."""
	var result = { "action_type": "", "encounter": null }
	if _is_tutorial_map():
		if node_data == _tutorial_nodes.get("final"):
			result.action_type = "battle"
			result.encounter = load("res://data/encounters/tutorial_final_battle.tres") as EncounterData
		elif node_data == _tutorial_nodes.get("camp"):
			result.action_type = "rest"
		return result
	match node_data.type:
		MapNodeResource.NodeType.MONSTER:
			result.action_type = "battle"
			result.encounter = _pick_monster_encounter(node_data)
		MapNodeResource.NodeType.ELITE:
			result.action_type = "battle"
			if not elite_encounters.is_empty():
				result.encounter = load(elite_encounters.pick_random()) as EncounterData
		MapNodeResource.NodeType.BOSS:
			result.action_type = "battle"
			if not boss_encounters.is_empty():
				result.encounter = load(boss_encounters[0]) as EncounterData
		MapNodeResource.NodeType.TREASURE:
			result.action_type = "treasure"
		MapNodeResource.NodeType.SHOP:
			result.action_type = "shop"
		MapNodeResource.NodeType.REST:
			result.action_type = "rest"
		MapNodeResource.NodeType.EVENT:
			result.action_type = "event"
	return result

func _count_path_nodes_of_type(node_type: MapNodeResource.NodeType) -> int:
	var count := 0
	for node in PlayerData.path_taken:
		if node is MapNodeResource and node.type == node_type:
			count += 1
	return count

func _pick_monster_encounter(node_data: MapNodeResource) -> EncounterData:
	"""První 3 normal fighty + první 3 patra = easy pool. Jinak hard."""
	var monster_fight_index := _count_path_nodes_of_type(MapNodeResource.NodeType.MONSTER)
	var use_easy := monster_fight_index <= EASY_MONSTER_FIGHT_LIMIT or node_data.row <= EASY_MONSTER_MAX_ROW
	var pool: Array = easy_monster_encounters if use_easy else hard_monster_encounters
	if pool.is_empty():
		pool = hard_monster_encounters if not hard_monster_encounters.is_empty() else easy_monster_encounters
	if pool.is_empty():
		return null
	return load(pool.pick_random()) as EncounterData

func _trigger_node_action(node_data: MapNodeResource):
	var payload = _get_node_action_payload(node_data)
	# Coop: host pošle klientovi stejný krok (node_index, action_type, encounter_path)
	if _is_coop() and MultiplayerManager.is_server():
		var node_index = map_data.all_nodes.find(node_data)
		if node_index >= 0:
			var encounter_path = payload.encounter.resource_path if is_instance_valid(payload.encounter) else ""
			MultiplayerManager.rpc("receive_coop_node_action", node_index, payload.action_type, encounter_path)

	var encounter_to_start: EncounterData = payload.encounter
	if _is_tutorial_map() and node_data == _tutorial_nodes.get("final"):
		if encounter_to_start:
			GameManager.tutorial_step = GameManager.TUTORIAL_STEP_FINAL_BATTLE
		else:
			printerr("Tutorial encounter missing.")
		_save_camera_scroll_y()
		GameManager.start_battle(encounter_to_start)
		return
	elif _is_tutorial_map() and node_data == _tutorial_nodes.get("camp"):
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_CAMP_UPGRADE
		_save_camera_scroll_y()
		GameManager.go_to_rest_scene()
		return

	match node_data.type:
		MapNodeResource.NodeType.TREASURE:
			GameManager.show_treasure_node()
			return
		MapNodeResource.NodeType.SHOP:
			_save_camera_scroll_y()
			GameManager.go_to_shop()
			return
		MapNodeResource.NodeType.REST:
			_save_camera_scroll_y()
			GameManager.go_to_rest_scene()
			return
		MapNodeResource.NodeType.EVENT:
			GameManager.go_to_event_scene()
			return
		_:
			pass

	# Bitva (MONSTER / ELITE / BOSS) nebo neznámý typ
	if is_instance_valid(encounter_to_start):
		_save_camera_scroll_y()
		GameManager.start_battle(encounter_to_start)
	else:
		if node_data.type != MapNodeResource.NodeType.MONSTER and node_data.type != MapNodeResource.NodeType.ELITE and node_data.type != MapNodeResource.NodeType.BOSS:
			print("Akce typu '%s' zatím není implementována." % MapNodeResource.NodeType.keys()[node_data.type])
		else:
			printerr("Nepodařilo se načíst data souboje pro typ: ", MapNodeResource.NodeType.keys()[node_data.type])
		_update_highlighting()

func _show_tutorial_coach() -> void:
	if not _is_tutorial_map():
		return
	var line_id := "tutorial.map_camp"
	if GameManager.tutorial_step == GameManager.TUTORIAL_STEP_MAP_FINAL:
		line_id = "tutorial.map_final"
	TutorialSpeechClass.mount_line($CanvasLayer, line_id, true)

func _is_tutorial_map() -> bool:
	if not has_node("/root/GameManager"):
		return false
	return GameManager.tutorial_active and (
		GameManager.tutorial_step == GameManager.TUTORIAL_STEP_MAP_CAMP
		or GameManager.tutorial_step == GameManager.TUTORIAL_STEP_MAP_FINAL
	)

func _build_tutorial_map() -> MapData:
	_tutorial_nodes.clear()
	var data = MapData.new()
	var start_node = MapNodeResource.new()
	var camp_node = MapNodeResource.new()
	var final_node = MapNodeResource.new()
	
	start_node.type = MapNodeResource.NodeType.EVENT
	camp_node.type = MapNodeResource.NodeType.REST
	final_node.type = MapNodeResource.NodeType.MONSTER
	
	start_node.row = 0
	start_node.column = 0
	camp_node.row = 1
	camp_node.column = 0
	final_node.row = 2
	final_node.column = 0
	
	var _spacing_x = generator_node.vis_x_spacing if is_instance_valid(generator_node) else 128
	var spacing_y = generator_node.vis_y_spacing if is_instance_valid(generator_node) else 80
	start_node.position = Vector2(0, 0)
	camp_node.position = Vector2(0, -spacing_y)
	final_node.position = Vector2(0, -spacing_y * 2)
	
	start_node.connections = [camp_node]
	camp_node.incoming_connections = [start_node]
	camp_node.connections = [final_node]
	final_node.incoming_connections = [camp_node]
	
	data.all_nodes = [start_node, camp_node, final_node]
	data.starting_nodes = [start_node]
	data.boss_node = final_node
	
	_tutorial_nodes["start"] = start_node
	_tutorial_nodes["camp"] = camp_node
	_tutorial_nodes["final"] = final_node
	
	var previous_path: Array = PlayerData.path_taken.duplicate()
	PlayerData.path_taken.clear()
	
	for old_node in previous_path:
		if not is_instance_valid(old_node):
			continue
		for new_node in [start_node, camp_node, final_node]:
			if old_node.row == new_node.row and old_node.column == new_node.column:
				PlayerData.path_taken.append(new_node)
				break
	
	if PlayerData.path_taken.is_empty():
		PlayerData.path_taken.append(start_node)
	elif GameManager.tutorial_step == GameManager.TUTORIAL_STEP_MAP_FINAL:
		# Ensure Camp is marked visited after returning from Camp
		if PlayerData.path_taken.size() == 1 and PlayerData.path_taken[0] == start_node:
			PlayerData.path_taken.append(camp_node)
	
	return data

func _get_tutorial_allowed_node() -> MapNodeResource:
	if not _is_tutorial_map():
		return null
	if GameManager.tutorial_step == GameManager.TUTORIAL_STEP_MAP_CAMP:
		return _tutorial_nodes.get("camp")
	if GameManager.tutorial_step == GameManager.TUTORIAL_STEP_MAP_FINAL:
		return _tutorial_nodes.get("final")
	return null
func _update_highlighting():
	# Smažeme staré čáry, abychom je překreslili s novými barvami.
	for child in connections_container.get_children():
		child.queue_free()

	var current_node = PlayerData.get_current_node()
	var reachable_nodes: Array = []
	
	if current_node != null:
		reachable_nodes = current_node.connections
	else:
		reachable_nodes = map_data.starting_nodes

	# Projdeme všechny vizuální uzly a nastavíme jim nový vzhled.
	for node_data in map_nodes_visual:
		var visual_node: MapNode = map_nodes_visual[node_data]
		
		# KROK 1: Zastavíme všechny staré animace na tomto uzlu.
		# To je důležité, aby se nám animace nekumulovaly a nezpůsobovaly chaos.
		if visual_node.has_meta("pulse_tween"):
			var old_tween: Tween = visual_node.get_meta("pulse_tween")
			if is_instance_valid(old_tween):
				old_tween.kill()
			visual_node.remove_meta("pulse_tween")
		
		# Resetujeme měřítko pro případ, že byl uzel dříve animován.
		visual_node.scale = Vector2(1.0, 1.0)

		var is_current = (node_data == current_node)
		var is_in_path = PlayerData.path_taken.has(node_data)
		var is_reachable = reachable_nodes.has(node_data)
		
		if is_current:
			# Aktuální uzel je jasně bílý a pulzuje nejvýrazněji.
			visual_node.modulate = Color.WHITE
			var pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
			pulse_tween.tween_property(visual_node, "scale", Vector2(1.15, 1.15), 0.8)
			pulse_tween.tween_property(visual_node, "scale", Vector2(1.0, 1.0), 0.8)
			visual_node.set_meta("pulse_tween", pulse_tween)
			
		elif is_reachable:
			# Dosažitelný uzel je také bílý a jemně pulzuje.
			visual_node.modulate = Color.WHITE
			var pulse_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
			pulse_tween.tween_property(visual_node, "scale", Vector2(1.1, 1.1), 1.0)
			pulse_tween.tween_property(visual_node, "scale", Vector2(1.0, 1.0), 1.0)
			visual_node.set_meta("pulse_tween", pulse_tween)
			
		elif is_in_path:
			# Již navštívený uzel je ztmavený, ale stále dobře viditelný.
			visual_node.modulate = Color(0.6, 0.6, 0.6)
			
		else:
			# Nedosažitelný uzel je nejvíce ztmavený.
			visual_node.modulate = Color(0.35, 0.35, 0.35)

	# Znovu vykreslíme spojnice (tato část zůstává stejná).
	for from_node_data in map_data.all_nodes:
		if not map_nodes_visual.has(from_node_data): continue
		for to_node_data in from_node_data.connections:
			if not map_nodes_visual.has(to_node_data): continue
			
			var from_visual = map_nodes_visual[from_node_data]
			var to_visual = map_nodes_visual[to_node_data]
			
			var line = ConnectionLineScene.instantiate()
			line.setup(from_visual, to_visual)
			
			var is_visited_path = PlayerData.path_taken.has(from_node_data) and PlayerData.path_taken.has(to_node_data)
			var is_reachable_path = (from_node_data == current_node and reachable_nodes.has(to_node_data))
			
			if is_visited_path:
				line.default_color = VISITED_PATH_COLOR
				line.width = 6.0
			elif is_reachable_path:
				line.default_color = REACHABLE_PATH_COLOR
				line.width = 5.0

			connections_container.add_child(line)
func _get_map_bounds() -> Rect2:
	var map_rect = Rect2(map_nodes_visual.values()[0].position, Vector2.ZERO)
	for node in map_nodes_visual.values():
		map_rect = map_rect.expand(node.position)
	return map_rect

func _get_focus_node_y() -> float:
	var current_node = PlayerData.get_current_node()
	if current_node != null and map_nodes_visual.has(current_node):
		return map_nodes_visual[current_node].position.y
	if map_data != null and not map_data.starting_nodes.is_empty():
		var start_node = map_data.starting_nodes[0]
		if map_nodes_visual.has(start_node):
			return map_nodes_visual[start_node].position.y
	return _get_map_bounds().get_center().y

func _save_camera_scroll_y() -> void:
	GameManager.saved_camera_position = Vector2(_map_center_x, camera.position.y)
	GameManager.saved_camera_zoom = camera.zoom
	GameManager.has_saved_camera_state = true

func _clamp_camera_y() -> void:
	camera.position.x = _map_center_x
	camera.position.y = clampf(camera.position.y, _camera_y_min, _camera_y_max)

func _setup_camera():
	if map_nodes_visual.is_empty():
		return

	var map_rect := _get_map_bounds()
	_map_center_x = map_rect.get_center().x

	var screen_size := get_viewport_rect().size
	var available_width := maxf(screen_size.x - CAMERA_LEFT_UI_MARGIN - CAMERA_RIGHT_UI_MARGIN, 1.0)
	var fit_width := maxf(map_rect.size.x + CAMERA_HORIZONTAL_PADDING * 2.0, 1.0)
	var zoom_x := available_width / fit_width
	if _is_tutorial_map():
		zoom_x = minf(zoom_x, 0.8)
	else:
		zoom_x = minf(zoom_x, CAMERA_MAX_WIDTH_ZOOM)
	camera.zoom = Vector2(zoom_x, zoom_x)

	# Shift view so the map is centered in the free area right of the legend.
	var ui_shift_world := (CAMERA_LEFT_UI_MARGIN - CAMERA_RIGHT_UI_MARGIN) * 0.5 / zoom_x
	_map_center_x = map_rect.get_center().x - ui_shift_world

	var half_view_h := (screen_size.y * 0.5) / zoom_x
	_camera_y_min = map_rect.position.y - CAMERA_VERTICAL_PADDING + half_view_h
	_camera_y_max = map_rect.end.y + CAMERA_VERTICAL_PADDING - half_view_h
	if _camera_y_min > _camera_y_max:
		var mid_y := map_rect.get_center().y
		_camera_y_min = mid_y
		_camera_y_max = mid_y

	var target_y: float
	if GameManager.has_saved_camera_state:
		target_y = GameManager.saved_camera_position.y
	else:
		target_y = _get_focus_node_y()

	camera.position = Vector2(_map_center_x, target_y)
	_clamp_camera_y()

	# Lock horizontal pan; allow vertical travel within map bounds.
	var half_view_w := (screen_size.x * 0.5) / zoom_x
	camera.limit_left = int(_map_center_x - half_view_w)
	camera.limit_right = int(_map_center_x + half_view_w)
	camera.limit_top = int(map_rect.position.y - CAMERA_VERTICAL_PADDING)
	camera.limit_bottom = int(map_rect.end.y + CAMERA_VERTICAL_PADDING)

func _unhandled_input(event: InputEvent):
	if get_viewport().gui_get_focus_owner():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position.y -= CAMERA_SCROLL_STEP / camera.zoom.y
			_clamp_camera_y()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position.y += CAMERA_SCROLL_STEP / camera.zoom.y
			_clamp_camera_y()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var drag_vertical: bool = (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0 \
			or (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		if drag_vertical:
			camera.position.y -= event.relative.y / camera.zoom.y
			_clamp_camera_y()
			get_viewport().set_input_as_handled()

func _on_map_node_hovered(map_node: MapNode):
	# Vytvoříme krátkou animaci, která uzel zvětší. 
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_node, "scale", Vector2(1.2, 1.2), 0.15)

# Tato funkce se zavolá, když myš opustí uzel.
func _on_map_node_exited(map_node: MapNode):
	# Vytvoříme animaci, která vrátí uzel na původní velikost. 
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_node, "scale", Vector2(1.0, 1.0), 0.15)

func _on_dev_command(command: String, args: Array):
	match command:
		"goto":
			_execute_goto_command(args)
		_:
			dev_console.log_error("Neznámý příkaz: '%s'" % command)

# Logika pro příkaz GOTO
func _execute_goto_command(args: Array):
	if args.is_empty() or not args[0].begins_with("f"):
		dev_console.log_error("Použití: goto f<číslo_patra>")
		return
	
	var floor_str = args[0].substr(1)
	if not floor_str.is_valid_int():
		dev_console.log_error("Neplatné číslo patra: '%s'" % floor_str)
		return
	
	var target_floor = floor_str.to_int()
	
	# Speciální případ pro start (patro 0)
	if target_floor == 0:
		PlayerData.path_taken.clear()
		_update_highlighting()
		dev_console.log_success("Přesun na start (patro 0).")
		return

	# Najdeme VŠECHNY uzly na cílovém patře
	var target_floor_nodes: Array[MapNodeResource] = []
	for node in map_data.all_nodes:
		if node.row == target_floor:
			target_floor_nodes.append(node)
			
	if target_floor_nodes.is_empty():
		dev_console.log_error("Na patře %d nebyly nalezeny žádné uzly." % target_floor)
		return
		
	# Vytvoříme dočasný "master" uzel, který není na mapě vidět.
	var dummy_node = MapNodeResource.new()
	# Řekneme mu, že se z něj dá dostat na VŠECHNY uzly na cílovém patře.
	dummy_node.connections = target_floor_nodes
	
	# Nastavíme cestu hráče tak, jako by byl POUZE na tomto dočasném uzlu.
	PlayerData.path_taken.clear()
	PlayerData.path_taken.append(dummy_node)
	
	# Překreslíme mapu. Funkce _update_highlighting si teď přečte cesty
	# z našeho dočasného uzlu a rozsvítí všechny cílové uzly.
	_update_highlighting()
	
	dev_console.log_success("Přesun dokončen. Můžeš si vybrat jakýkoliv uzel na patře %d." % target_floor)


func _setup_legend():
	# Smažeme staré položky
	for child in legend_container.get_children():
		child.queue_free()
	
	# Počkáme jeden frame, aby se změny projevily
	await get_tree().process_frame

	# Projdeme všechny typy uzlů (VČETNĚ BOSSE!)
	for node_type in node_names:
		# Vytvoříme řádek jako HBoxContainer
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(200, 40)
		
		# Vytvoříme ikonku jako TextureButton (místo TextureRect)
		var icon = TextureButton.new()
		icon.texture_normal = node_textures[node_type]
		icon.custom_minimum_size = Vector2(32, 32)
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		icon.disabled = true  # Zakážeme klikání, ale ikonka zůstane vidět
		
		# Vytvoříme popisek
		var label = Label.new()
		label.text = " " + tr(node_names[node_type])
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Sestavíme řádek
		row.add_child(icon)
		row.add_child(label)
		
		# Přidáme malou mezeru mezi ikonkou a textem
		row.add_theme_constant_override("separation", 8)
		
		# Přidáme řádek do legendy
		legend_container.add_child(row)
		
		print("Přidána legenda pro: ", tr(node_names[node_type]))

	print("Legenda dokončena s ", legend_container.get_child_count(), " položkami")
