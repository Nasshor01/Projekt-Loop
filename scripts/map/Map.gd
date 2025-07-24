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
	
]
var elite_encounters = [
	"res://data/encounters/elite_battle.tres",
	"res://data/encounters/Skeleton_army.tres"
]
var boss_encounters = ["res://data/encounters/boss_battle.tres"]

var node_textures = {
	MapNodeResource.NodeType.MONSTER: preload("res://art/sprites/map/icons/monster.png"),
	MapNodeResource.NodeType.ELITE: preload("res://art/sprites/map/icons/elite.png"),
	MapNodeResource.NodeType.EVENT: preload("res://art/sprites/map/icons/unknown.png"),
	MapNodeResource.NodeType.REST: preload("res://art/sprites/map/icons/bonfire.png"),
	MapNodeResource.NodeType.SHOP: preload("res://art/sprites/map/icons/shop.png"),
	MapNodeResource.NodeType.TREASURE: preload("res://art/sprites/map/icons/chest.png"),
	MapNodeResource.NodeType.BOSS: preload("res://art/sprites/map/icons/boss.png")
}

var map_data: MapData
var map_nodes_visual: Dictionary = {}

@onready var generator_node = $MapGenerator
@onready var connections_container = $Connections
@onready var seed_label: Label = $CanvasLayer/SeedLabel
@onready var seed_line_edit: LineEdit = $CanvasLayer/Panel/VBoxContainer/SeedLineEdit
@onready var generate_seed_button: Button = $CanvasLayer/Panel/VBoxContainer/GenerateSeedButton
@onready var random_seed_button: Button = $CanvasLayer/Panel/VBoxContainer/RandomSeedButton
@onready var camera: Camera2D = $Camera2D

func _ready():
	generate_seed_button.pressed.connect(func(): GameManager.start_new_run())
	random_seed_button.pressed.connect(func(): GameManager.start_new_run())
	initialize_map()

func initialize_map():
	_clear_map()

	if GameManager.current_map_data == null:
		self.map_data = generator_node.generate_map(GameManager.current_seed)
		GameManager.current_map_data = self.map_data
	else:
		self.map_data = GameManager.current_map_data
	
	seed_label.text = "Seed: " + str(GameManager.current_seed)
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
			if node_data.type == MapNodeResource.NodeType.BOSS: sprite.scale = Vector2(0.5, 0.5)
		
		# Připojení signálu pro kliknutí (toto už tam máte)
		map_node_instance.node_clicked.connect(_on_map_node_clicked)
		
		# --- PŘIDEJTE TYTO DVĚ ŘÁDKY ---
		map_node_instance.node_hovered.connect(_on_map_node_hovered)
		map_node_instance.node_exited.connect(_on_map_node_exited)
		
		add_child(map_node_instance)
		map_nodes_visual[node_data] = map_node_instance
func _on_map_node_clicked(clicked_node: MapNode):
	var current_node = PlayerData.get_current_node()
	var destination_node = clicked_node.node_data
	
	var is_valid_move = false
	if current_node == null:
		if map_data.starting_nodes.has(destination_node): is_valid_move = true
	else:
		if current_node.connections.has(destination_node): is_valid_move = true
	
	if is_valid_move:
		PlayerData.path_taken.append(destination_node)
		_trigger_node_action(destination_node)
	else:
		print("Neplatný tah!")

func _trigger_node_action(node_data: MapNodeResource):
	var encounter_to_start: EncounterData = null

	# Zjistíme, o jaký typ místnosti se jedná, a připravíme příslušná data.
	match node_data.type:
		MapNodeResource.NodeType.MONSTER:
			if not monster_encounters.is_empty():
				encounter_to_start = load(monster_encounters.pick_random())
		
		MapNodeResource.NodeType.ELITE:
			if not elite_encounters.is_empty():
				encounter_to_start = load(elite_encounters.pick_random())

		MapNodeResource.NodeType.BOSS:
			if not boss_encounters.is_empty():
				encounter_to_start = load(boss_encounters[0])

		# Pro ostatní typy místností (Event, Shop, atd.), které nezačínají bitvu.
		_:
			# Vypíšeme do konzole, že akce zatím není implementována.
			print("Akce typu '%s' zatím není implementována. Pokračuje se dál." % MapNodeResource.NodeType.keys()[node_data.type])
			# Aktualizujeme zvýraznění mapy pro další tah.
			_update_highlighting()
			# Ukončíme funkci, protože nepokračujeme do bitvy.
			return

	# Zkontrolujeme, zda se podařilo načíst data pro souboj.
	if is_instance_valid(encounter_to_start):
		# Klíčový krok: Před opuštěním scény mapy si uložíme stav kamery.
		GameManager.saved_camera_position = camera.position
		GameManager.saved_camera_zoom = camera.zoom
		GameManager.has_saved_camera_state = true
		
		# Přes GameManager spustíme přechod na bojovou scénu.
		GameManager.start_battle(encounter_to_start)
	else:
		# Pokud se data souboje nenačetla, vypíšeme chybu a jen aktualizujeme mapu.
		printerr("Nepodařilo se načíst data souboje pro typ: ", MapNodeResource.NodeType.keys()[node_data.type])
		_update_highlighting()
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

	if GameManager.has_saved_camera_state:
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
	if get_viewport().gui_get_focus_owner(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera.zoom = camera.zoom.move_toward(Vector2(0.5, 0.5), 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera.zoom = camera.zoom.move_toward(Vector2(3.0, 3.0), 0.1)
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE: camera.position -= event.relative / camera.zoom

func _on_map_node_hovered(map_node: MapNode):
	# Vytvoříme krátkou animaci, která uzel zvětší. 
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_node, "scale", Vector2(1.2, 1.2), 0.15)

# Tato funkce se zavolá, když myš opustí uzel.
func _on_map_node_exited(map_node: MapNode):
	# Vytvoříme animaci, která vrátí uzel na původní velikost. 
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(map_node, "scale", Vector2(1.0, 1.0), 0.15)
