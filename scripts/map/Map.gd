# Soubor: scripts/map/Map.gd
# POPIS: Kompletní finální verze s dynamickým výběrem soubojů a správným zvýrazňováním.
extends Node2D

const MapNodeScene = preload("res://scenes/map/MapNode.tscn")
const ConnectionLineScene = preload("res://scenes/map/ConnectionLine.tscn")

const VISITED_PATH_COLOR = Color.GOLD
const REACHABLE_PATH_COLOR = Color.WHITE

# --- Seznamy možných soubojů ---
var monster_encounters = [
	"res://data/encounters/first_battle.tres",
	"res://data/encounters/goblin_duo.tres",
	"res://data/encounters/one_orc.tres",
	"res://data/encounters/Skeleton.tres",
	"res://data/encounters/demon_assassin.tres",
	"res://data/encounters/assassin_squad.tres"
]
var elite_encounters = [
	"res://data/encounters/elite_battle.tres",
	"res://data/encounters/Skeleton_army.tres",
	"res://data/encounters/support_team.tres",
	"res://data/encounters/elite_mix.tres"
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
			
			# --- ZMĚNA ZDE ---
			# Rozšířené nastavení velikosti pro různé typy uzlů
			match node_data.type:
				MapNodeResource.NodeType.BOSS:
					sprite.scale = Vector2(0.17, 0.17)      # Velký boss
				MapNodeResource.NodeType.REST:
					sprite.scale = Vector2(0.04, 0.04)      # Campfire je o něco větší
				MapNodeResource.NodeType.SHOP:
					sprite.scale = Vector2(0.028, 0.028)    # Obchod je o něco menší
				_: # Znak _ znamená "pro všechny ostatní případy"
					# Výchozí velikost pro ostatní ikony (Monster, Elite, Event, atd.)
					sprite.scale = Vector2(0.03125, 0.03125)
			# --- KONEC ZMĚNY ---

		map_node_instance.node_clicked.connect(_on_map_node_clicked)
		
		map_node_instance.node_hovered.connect(_on_map_node_hovered)
		map_node_instance.node_exited.connect(_on_map_node_exited)
		
		add_child(map_node_instance)
		map_nodes_visual[node_data] = map_node_instance

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
			if not monster_encounters.is_empty():
				result.encounter = load(monster_encounters.pick_random()) as EncounterData
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
		GameManager.saved_camera_position = camera.position
		GameManager.saved_camera_zoom = camera.zoom
		GameManager.has_saved_camera_state = true
		GameManager.start_battle(encounter_to_start)
		return
	elif _is_tutorial_map() and node_data == _tutorial_nodes.get("camp"):
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_CAMP_UPGRADE
		GameManager.saved_camera_position = camera.position
		GameManager.saved_camera_zoom = camera.zoom
		GameManager.has_saved_camera_state = true
		GameManager.go_to_rest_scene()
		return

	match node_data.type:
		MapNodeResource.NodeType.TREASURE:
			GameManager.show_treasure_node()
			return
		MapNodeResource.NodeType.SHOP:
			GameManager.saved_camera_position = camera.position
			GameManager.saved_camera_zoom = camera.zoom
			GameManager.has_saved_camera_state = true
			GameManager.go_to_shop()
			return
		MapNodeResource.NodeType.REST:
			GameManager.saved_camera_position = camera.position
			GameManager.saved_camera_zoom = camera.zoom
			GameManager.has_saved_camera_state = true
			GameManager.go_to_rest_scene()
			return
		MapNodeResource.NodeType.EVENT:
			GameManager.go_to_event_scene()
			return
		_:
			pass

	# Bitva (MONSTER / ELITE / BOSS) nebo neznámý typ
	if is_instance_valid(encounter_to_start):
		GameManager.saved_camera_position = camera.position
		GameManager.saved_camera_zoom = camera.zoom
		GameManager.has_saved_camera_state = true
		GameManager.start_battle(encounter_to_start)
	else:
		if node_data.type != MapNodeResource.NodeType.MONSTER and node_data.type != MapNodeResource.NodeType.ELITE and node_data.type != MapNodeResource.NodeType.BOSS:
			print("Akce typu '%s' zatím není implementována." % MapNodeResource.NodeType.keys()[node_data.type])
		else:
			printerr("Nepodařilo se načíst data souboje pro typ: ", MapNodeResource.NodeType.keys()[node_data.type])
		_update_highlighting()

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
	
	var spacing_x = generator_node.vis_x_spacing if is_instance_valid(generator_node) else 128
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
func _setup_camera():
	if map_nodes_visual.is_empty(): return
	
	if _is_tutorial_map():
		var map_rect = Rect2(map_nodes_visual.values()[0].position, Vector2.ZERO)
		for node in map_nodes_visual.values():
			map_rect = map_rect.expand(node.position)
		map_rect = map_rect.grow(120.0)
		camera.position = map_rect.get_center()
		camera.zoom = Vector2(0.8, 0.8)
	elif GameManager.has_saved_camera_state:
		# Načteme uloženou pozici a zoom.
		camera.position = GameManager.saved_camera_position
		camera.zoom = GameManager.saved_camera_zoom
	else:
		# Vypočítáme výchozí (oddálený) pohled.
		var map_rect = Rect2(map_nodes_visual.values()[0].position, Vector2.ZERO)
		for node in map_nodes_visual.values():
			map_rect = map_rect.expand(node.position)
		
		var padding = 200.0
		map_rect = map_rect.grow(padding)
		camera.position = map_rect.get_center()
		
		var screen_size = get_viewport_rect().size
		var zoom_level = max(map_rect.size.x / screen_size.x, map_rect.size.y / screen_size.y)
		
		# Výchozí zoom je o 10 % oddálenější.
		camera.zoom = Vector2(zoom_level, zoom_level) * 0.25

	# Nastavení limitů kamery, aby nevyjela z mapy.
	var final_rect = Rect2(map_nodes_visual.values()[0].position, Vector2.ZERO)
	for node in map_nodes_visual.values():
		final_rect = final_rect.expand(node.position)
	final_rect = final_rect.grow(250.0)

	camera.limit_left = int(final_rect.position.x)
	camera.limit_top = int(final_rect.position.y)
	camera.limit_right = int(final_rect.end.x)
	camera.limit_bottom = int(final_rect.end.y)

func _unhandled_input(event: InputEvent):
	# Pokud má fokus nějaký UI element, neděláme nic
	if get_viewport().gui_get_focus_owner(): 
		return
	
	# Zoom kolečkem myši
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Přiblížení - zvětšíme zoom
			camera.zoom = camera.zoom * 1.1
			camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Oddálení - zmenšíme zoom  
			camera.zoom = camera.zoom * 0.9
			camera.zoom = camera.zoom.clamp(Vector2(0.3, 0.3), Vector2(3.0, 3.0))
	
	# Pohyb kamery pomocí tažení myší
	elif event is InputEventMouseMotion:
		# Pohyb pomocí STŘEDNÍHO tlačítka myši (kolečko)
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera.position -= event.relative / camera.zoom
		
		# ALTERNATIVNĚ: Pohyb pomocí PRAVÉHO tlačítka myši
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			camera.position -= event.relative / camera.zoom

		# ALTERNATIVNĚ: Pohyb pomocí LEVÉHO tlačítka myši
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			camera.position -= event.relative / camera.zoom

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
