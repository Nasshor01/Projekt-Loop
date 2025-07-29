class_name BattleGrid
extends Node2D

@export var cell_size: Vector2 = Vector2(64, 64)
@export var grid_columns: int = 15
@export var grid_rows: int = 10

@export var grid_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var highlight_color: Color = Color(1, 1, 0, 0.3)
@export var movement_highlight_color: Color = Color(0.2, 0.8, 0.2, 0.3)
@export var attack_highlight_color: Color = Color(1.0, 0.2, 0.2, 0.4)
@export var support_highlight_color: Color = Color(0.2, 0.5, 1.0, 0.4)
@export var aoe_highlight_color: Color = Color(0.8, 0.2, 1.0, 0.35)
@export var player_spawn_highlight_color: Color = Color(0.2, 0.9, 0.9, 0.4) # NOVÁ BARVA
@export var movement_warning_color: Color = Color(0.9, 0.8, 0.1, 0.4) # ŽLUTÁ PRO BAHNO
@export var danger_zone_color: Color = Color(0.8, 0.2, 0.2, 0.35)      # ČERVENÁ PRO NEPŘÁTELE

@onready var units_container: Node2D = $UnitsContainer
var _terrain_container: Node2D
var camera: Camera2D

var _active_cells: Dictionary = {}
var _grid_objects: Dictionary = {}
var terrain_layer: Dictionary = {}
var _mouse_over_cell: Vector2i = Vector2i(-1, -1)
var _movable_cells: Array[Vector2i] = []
var _targetable_cells: Array[Vector2i] = []
var _aoe_cells: Array[Vector2i] = []
var _player_spawn_cells: Array[Vector2i] = [] # NOVÝ SEZNAM
var _targetable_cells_color: Color = attack_highlight_color
var _warning_cells: Array[Vector2i] = [] # Pro žluté zvýraznění
var _danger_cells: Array[Vector2i] = []  # Pro červené zvýraznění

func _ready():
	_terrain_container = Node2D.new(); _terrain_container.name = "TerrainContainer"; add_child(_terrain_container); move_child(_terrain_container, 0)
	if not units_container:
		units_container = Node2D.new(); units_container.name = "UnitsContainer"; add_child(units_container)
	
	set_process_input(true)
	set_process(true)
	queue_redraw()

func set_camera(cam_ref: Camera2D):
	self.camera = cam_ref

func _process(_delta):
	queue_redraw()

func _draw():
	var line_thickness: float
	if not is_instance_valid(camera):
		line_thickness = 1.0
	else:
		var base_thickness = 1.5
		line_thickness = base_thickness * camera.zoom.x
		var min_thickness_on_screen = get_canvas_transform().affine_inverse().get_scale().x
		line_thickness = max(line_thickness, min_thickness_on_screen)

	for cell_pos in _active_cells:
		draw_rect(Rect2(Vector2(cell_pos) * cell_size, cell_size), grid_line_color, false, line_thickness)

	if is_cell_active(_mouse_over_cell):
		draw_rect(Rect2(Vector2(_mouse_over_cell) * cell_size, cell_size), highlight_color, true)
	
	# NOVÁ VYKRESLOVACÍ LOGIKA
	for cell in _danger_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), danger_zone_color, true)
	for cell in _movable_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), movement_highlight_color, true)
	for cell in _warning_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), movement_warning_color, true)
	for cell in _player_spawn_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), player_spawn_highlight_color, true)
	for cell in _targetable_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), _targetable_cells_color, true)
	for cell in _aoe_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), aoe_highlight_color, true)

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		var new_mouse_cell = get_cell_at_world_position(get_global_mouse_position())
		if new_mouse_cell != _mouse_over_cell:
			_mouse_over_cell = new_mouse_cell
			queue_redraw()

func build_from_shape(shape_array: Array):
	_active_cells.clear()
	grid_rows = shape_array.size()
	
	if grid_rows > 0:
		grid_columns = shape_array[0].length()
	else:
		grid_columns = 0

	for y in range(grid_rows):
		var row_string = shape_array[y]
		for x in range(row_string.length()):
			if row_string[x] == "1":
				_active_cells[Vector2i(x, y)] = true
	
	queue_redraw()

func is_cell_active(grid_position: Vector2i) -> bool:
	return _active_cells.has(grid_position)

func place_object_on_cell(object_node: Node2D, grid_position: Vector2i, is_moving: bool = false) -> bool:
	if not is_cell_active(grid_position) or _grid_objects.has(grid_position): return false
	
	if object_node.get_parent() != units_container:
		if object_node.get_parent(): object_node.get_parent().remove_child(object_node)
		units_container.add_child(object_node)
	
	var cell_center_local = Vector2(grid_position) * cell_size + cell_size / 2.0
	if is_moving:
		var tween = create_tween(); tween.tween_property(object_node, "position", cell_center_local, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		object_node.position = cell_center_local
	
	if "grid_position" in object_node:
		object_node.grid_position = grid_position
	
	_grid_objects[grid_position] = object_node
	return true

func remove_object_by_instance(object_node: Node2D):
	var key_to_remove = null
	for cell in _grid_objects:
		if _grid_objects[cell] == object_node:
			key_to_remove = cell
			break
	if key_to_remove != null:
		_grid_objects.erase(key_to_remove)

func get_distance(cell_a: Vector2i, cell_b: Vector2i) -> int: return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)
func get_cell_at_world_position(world_position: Vector2) -> Vector2i:
	var local_position = to_local(world_position); return Vector2i(floor(local_position.x / cell_size.x), floor(local_position.y / cell_size.y))
func is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position.x >= 0 and grid_position.x < grid_columns and grid_position.y >= 0 and grid_position.y < grid_rows
func get_object_on_cell(grid_position: Vector2i) -> Node2D:
	return _grid_objects.get(grid_position, null)
func get_all_objects_on_grid() -> Array[Node2D]:
	var units: Array[Node2D] = []; for unit in _grid_objects.values():
		if unit is Node2D: units.append(unit)
	return units
func show_targetable_cells(cells: Array[Vector2i], is_attack: bool):
	_targetable_cells = cells; _targetable_cells_color = attack_highlight_color if is_attack else support_highlight_color; queue_redraw()
func hide_targetable_cells(): _targetable_cells.clear(); queue_redraw()

func show_movable_range(unit: Unit):
	hide_movable_range()
	if not is_instance_valid(unit) or not is_instance_valid(unit.unit_data):
		return

	var move_range = unit.get_current_movement_range()
	var start_cell = unit.grid_position

	# Slovník pro ukládání nejnižších nákladů na dosažení každé buňky
	var costs = {start_cell: 0}
	# Pole buněk, které ještě musíme prozkoumat
	var to_visit = [start_cell]

	while not to_visit.is_empty():
		# <<< ZDE JE KLÍČOVÁ OPRAVA >>>
		# Nahrazujeme neexistující funkci 'min_by' standardním cyklem.
		# Najdeme buňku s nejnižší cenou, kterou jsme ještě neprozkoumali.
		var current_cell = to_visit[0]
		for cell in to_visit:
			if costs[cell] < costs[current_cell]:
				current_cell = cell
		
		to_visit.erase(current_cell)
		var cost_to_current = costs[current_cell]

		# Prozkoumáme sousedy
		for neighbor_offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_cell = current_cell + neighbor_offset

			if not is_cell_active(neighbor_cell) or get_object_on_cell(neighbor_cell):
				continue
			var terrain = get_terrain_on_cell(neighbor_cell)
			if terrain and not terrain.is_walkable:
				continue

			var cost_to_enter = 1
			if terrain:
				cost_to_enter = terrain.movement_cost

			var new_cost = cost_to_current + cost_to_enter

			if new_cost <= move_range and (not costs.has(neighbor_cell) or new_cost < costs[neighbor_cell]):
				costs[neighbor_cell] = new_cost
				if not to_visit.has(neighbor_cell):
					to_visit.append(neighbor_cell)

	costs.erase(start_cell)
	for cell in costs.keys():
		var terrain = get_terrain_on_cell(cell)
		if terrain and terrain.movement_cost > 1:
			if not _warning_cells.has(cell): _warning_cells.append(cell)
		else:
			if not _movable_cells.has(cell): _movable_cells.append(cell)

	queue_redraw()

func hide_movable_range():
	_movable_cells.clear()
	_warning_cells.clear() # Přidáno čištění varovných buněk
	queue_redraw()

func is_cell_movable(cell: Vector2i) -> bool:
	# Nyní kontroluje oba typy buněk
	return _movable_cells.has(cell) or _warning_cells.has(cell)

func show_aoe_highlight(cells: Array[Vector2i]):
	_aoe_cells = cells; queue_redraw()
func hide_aoe_highlight():
	if not _aoe_cells.is_empty(): _aoe_cells.clear(); queue_redraw()

func get_cells_for_aoe(origin_cell: Vector2i, aoe_type: CardEffectData.AreaOfEffectType, param_x: int, param_y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match aoe_type:
		CardEffectData.AreaOfEffectType.ROW:
			for x in range(grid_columns): cells.append(Vector2i(x, origin_cell.y))
		CardEffectData.AreaOfEffectType.COLUMN:
			for y in range(grid_rows): cells.append(Vector2i(origin_cell.x, y))
		CardEffectData.AreaOfEffectType.SQUARE_X_BY_Y:
			for y in range(origin_cell.y, origin_cell.y + param_y):
				for x in range(origin_cell.x, origin_cell.x + param_x):
					var cell = Vector2i(x, y)
					if is_valid_grid_position(cell): cells.append(cell)
		CardEffectData.AreaOfEffectType.ALL_ON_GRID:
			var all_units = get_all_objects_on_grid();
			for unit in all_units:
				if unit.unit_data.faction == UnitData.Faction.ENEMY: cells.append(unit.grid_position)
	return cells
func place_terrain(grid_position: Vector2i, terrain_data: TerrainData):
	if not is_cell_active(grid_position): return
	terrain_layer[grid_position] = terrain_data
	if terrain_data.sprite:
		var terrain_sprite = Sprite2D.new(); terrain_sprite.texture = terrain_data.sprite
		terrain_sprite.scale = cell_size / terrain_sprite.texture.get_size()
		terrain_sprite.position = Vector2(grid_position) * cell_size + cell_size / 2
		_terrain_container.add_child(terrain_sprite)
func get_terrain_on_cell(grid_position: Vector2i) -> TerrainData:
	return terrain_layer.get(grid_position, null)

# NOVÉ FUNKCE PRO VÝBĚR SPAWNU HRÁČE
func get_player_spawn_points(num_columns: int) -> Array[Vector2i]:
	var spawn_points: Array[Vector2i] = []
	for y in range(grid_rows):
		for x in range(num_columns):
			var cell = Vector2i(x, y)
			if is_cell_active(cell) and get_object_on_cell(cell) == null:
				var terrain = get_terrain_on_cell(cell)
				if not terrain or terrain.is_walkable:
					spawn_points.append(cell)
	return spawn_points

func show_player_spawn_points(cells: Array[Vector2i]):
	_player_spawn_cells = cells
	queue_redraw()

func hide_player_spawn_points():
	if not _player_spawn_cells.is_empty():
		_player_spawn_cells.clear()
		queue_redraw()

func is_cell_a_valid_spawn_point(cell: Vector2i) -> bool:
	return _player_spawn_cells.has(cell)

func show_danger_zone(enemy_units: Array[Node2D]):
	_danger_cells.clear()
	var danger_dict = {}
	for enemy in enemy_units:
		if not is_instance_valid(enemy): continue
		var enemy_data = enemy.get_unit_data()
		if not is_instance_valid(enemy_data): continue
		
		var attack_range = enemy_data.attack_range
		for x in range(-attack_range, attack_range + 1):
			for y in range(-attack_range, attack_range + 1):
				if abs(x) + abs(y) <= attack_range:
					var cell = enemy.grid_position + Vector2i(x, y)
					if is_cell_active(cell):
						danger_dict[cell] = true

	# <<< ZDE JE NOVÁ, EXPLICITNÍ OPRAVA >>>
	# Místo přímého přiřazení projdeme všechny klíče a ručně je přidáme
	# do nového, správně typovaného pole. To je pro Godot 100% srozumitelné.
	var new_danger_cells: Array[Vector2i] = []
	for cell_key in danger_dict.keys():
		new_danger_cells.append(cell_key)
	
	_danger_cells = new_danger_cells
	queue_redraw()

func hide_danger_zone():
	_danger_cells.clear()
	queue_redraw()
