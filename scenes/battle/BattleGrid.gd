class_name BattleGrid
extends Node3D

# --- 3D NASTAVENÍ ---
@export var cell_size_3d: float = 2.0
@export var floor_mesh: Mesh 
@export var cursor_mesh: Mesh

# --- VZHLED MŘÍŽKY (ŠACHOVNICE) ---
@export_group("Grid Appearance")
@export var material_light: StandardMaterial3D # Světlé políčko
@export var material_dark: StandardMaterial3D  # Tmavé políčko
# ----------------------------------

# --- PŮVODNÍ NASTAVENÍ ---
@export var grid_columns: int = 15
@export var grid_rows: int = 10

@export var grid_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var highlight_color: Color = Color(1, 1, 0, 0.3)
@export var movement_highlight_color: Color = Color(0.2, 0.8, 0.2, 0.3)
@export var attack_highlight_color: Color = Color(1.0, 0.2, 0.2, 0.4)
@export var support_highlight_color: Color = Color(0.2, 0.5, 1.0, 0.4)
@export var aoe_highlight_color: Color = Color(0.8, 0.2, 1.0, 0.35)
@export var player_spawn_highlight_color: Color = Color(0.2, 0.9, 0.9, 0.4)
@export var movement_warning_color: Color = Color(0.9, 0.8, 0.1, 0.4)
@export var danger_zone_color: Color = Color(0.8, 0.2, 0.2, 0.35)

@onready var units_container: Node3D = $UnitsContainer
var _terrain_container: Node3D
var _highlights_container: Node3D

var camera: Camera3D

var _active_cells: Dictionary = {}
var _grid_objects: Dictionary = {}
var terrain_layer: Dictionary = {}
var _mouse_over_cell: Vector2i = Vector2i(-1, -1)

var _movable_cells: Array[Vector2i] = []
var _targetable_cells: Array[Vector2i] = []
var _aoe_cells: Array[Vector2i] = []
var _player_spawn_cells: Array[Vector2i] = []
var _warning_cells: Array[Vector2i] = []
var _danger_cells: Array[Vector2i] = []
var _targetable_cells_color: Color = attack_highlight_color

func _ready():
	_terrain_container = Node3D.new()
	_terrain_container.name = "TerrainContainer"
	add_child(_terrain_container)
	
	_highlights_container = Node3D.new()
	_highlights_container.name = "HighlightsContainer"
	add_child(_highlights_container)
	
	if not units_container:
		units_container = Node3D.new()
		units_container.name = "UnitsContainer"
		add_child(units_container)
	
	set_process_input(true)
	set_process(true)

func set_camera(cam_ref: Camera3D):
	self.camera = cam_ref

func _process(_delta): pass 

func set_mouse_over_cell(cell: Vector2i):
	if cell != _mouse_over_cell:
		_mouse_over_cell = cell
		update_visual_highlights()

func build_from_shape(shape_array: Array):
	_active_cells.clear()
	
	if _terrain_container:
		for child in _terrain_container.get_children():
			child.queue_free()
	
	grid_rows = shape_array.size()
	if grid_rows > 0:
		grid_columns = shape_array[0].length()
	else:
		grid_columns = 0

	for y in range(grid_rows):
		var row_string = shape_array[y]
		for x in range(row_string.length()):
			if row_string[x] == "1":
				var pos = Vector2i(x, y)
				_active_cells[pos] = true
				
				if floor_mesh and _terrain_container:
					var tile = MeshInstance3D.new()
					tile.mesh = floor_mesh
					tile.name = "Tile_%d_%d" % [x, y]
					
					# --- ŠACHOVNICOVÁ LOGIKA ---
					# Pokud nemáme materiály, necháme základní barvu meshe
					if material_light and material_dark:
						if (x + y) % 2 == 0:
							tile.material_override = material_light
						else:
							tile.material_override = material_dark
					# ---------------------------
					
					_terrain_container.add_child(tile)
					tile.position = Vector3(x * cell_size_3d, -0.1, y * cell_size_3d)

func is_cell_active(grid_position: Vector2i) -> bool:
	return _active_cells.has(grid_position)

func place_object_on_cell(object_node: Node3D, grid_position: Vector2i, is_moving: bool = false) -> bool:
	if not is_cell_active(grid_position) or _grid_objects.has(grid_position): return false
	
	if object_node.get_parent() != units_container:
		if object_node.get_parent(): object_node.get_parent().remove_child(object_node)
		units_container.add_child(object_node)
	
	var target_pos_3d = Vector3(grid_position.x * cell_size_3d, 0.0, grid_position.y * cell_size_3d)
	
	if is_moving:
		var tween = create_tween()
		tween.tween_property(object_node, "position", target_pos_3d, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		object_node.position = target_pos_3d
	
	if "grid_position" in object_node:
		object_node.grid_position = grid_position
	
	_grid_objects[grid_position] = object_node
	return true

func remove_object_by_instance(object_node: Node):
	var key_to_remove = null
	for cell in _grid_objects:
		if _grid_objects[cell] == object_node:
			key_to_remove = cell
			break
	if key_to_remove != null:
		_grid_objects.erase(key_to_remove)

func get_distance(cell_a: Vector2i, cell_b: Vector2i) -> int: 
	return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)

func is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position.x >= 0 and grid_position.x < grid_columns and grid_position.y >= 0 and grid_position.y < grid_rows

func get_object_on_cell(grid_position: Vector2i) -> Node:
	return _grid_objects.get(grid_position, null)

func get_all_objects_on_grid() -> Array:
	var units = []
	for unit in _grid_objects.values():
		if is_instance_valid(unit): units.append(unit)
	return units

func update_visual_highlights():
	for child in _highlights_container.get_children():
		child.queue_free()
	
	if not cursor_mesh: return

	var create_cursor = func(cell: Vector2i, color: Color):
		if not is_cell_active(cell): return
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = cursor_mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_inst.material_override = mat
		
		_highlights_container.add_child(mesh_inst)
		mesh_inst.position = Vector3(cell.x * cell_size_3d, 0.05, cell.y * cell_size_3d)

	for cell in _danger_cells: create_cursor.call(cell, danger_zone_color)
	for cell in _movable_cells: create_cursor.call(cell, movement_highlight_color)
	for cell in _warning_cells: create_cursor.call(cell, movement_warning_color)
	for cell in _player_spawn_cells: create_cursor.call(cell, player_spawn_highlight_color)
	for cell in _targetable_cells: create_cursor.call(cell, _targetable_cells_color)
	for cell in _aoe_cells: create_cursor.call(cell, aoe_highlight_color)
	
	if is_valid_grid_position(_mouse_over_cell) and is_cell_active(_mouse_over_cell):
		create_cursor.call(_mouse_over_cell, highlight_color)

func show_targetable_cells(cells: Array[Vector2i], is_attack: bool):
	_targetable_cells = cells
	_targetable_cells_color = attack_highlight_color if is_attack else support_highlight_color
	update_visual_highlights()

func hide_targetable_cells():
	_targetable_cells.clear()
	update_visual_highlights()

func show_movable_range(unit: Node):
	hide_movable_range()
	if not is_instance_valid(unit) or not is_instance_valid(unit.unit_data):
		return

	var move_range = unit.get_current_movement_range()
	var start_cell = unit.grid_position
	var costs = {start_cell: 0}
	var to_visit = [start_cell]

	while not to_visit.is_empty():
		var current_cell = to_visit[0]
		for cell in to_visit:
			if costs[cell] < costs[current_cell]:
				current_cell = cell
		
		to_visit.erase(current_cell)
		var cost_to_current = costs[current_cell]

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

	update_visual_highlights()

func hide_movable_range():
	_movable_cells.clear()
	_warning_cells.clear()
	update_visual_highlights()

func is_cell_movable(cell: Vector2i) -> bool:
	return _movable_cells.has(cell) or _warning_cells.has(cell)

func show_aoe_highlight(cells: Array[Vector2i]):
	_aoe_cells = cells
	update_visual_highlights()

func hide_aoe_highlight():
	if not _aoe_cells.is_empty(): 
		_aoe_cells.clear()
		update_visual_highlights()

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
		var terrain_sprite = Sprite3D.new()
		terrain_sprite.texture = terrain_data.sprite
		# Zvětšili jsme pixely, aby to bylo hezky vidět (stejně jako Unit)
		terrain_sprite.pixel_size = 0.04 
		terrain_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		terrain_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
		_terrain_container.add_child(terrain_sprite)
		
		# --- ROZHODOVÁNÍ PODLE TYPU TERÉNU ---
		if terrain_data.is_flat_on_ground:
			# A) BAHNO / POCE (Leží na zemi)
			# Osa Y znamená, že sprite leží "na zádech"
			terrain_sprite.axis = Vector3.AXIS_Y 
			terrain_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			# Pozice: X, 0.02 (těsně nad podlahou, aby neproblikávalo), Z
			terrain_sprite.position = Vector3(grid_position.x * cell_size_3d, 0.02, grid_position.y * cell_size_3d)
		
		else:
			# B) KÁMEN / STROM (Stojí)
			# Osa Z je standard pro stojící sprity
			terrain_sprite.axis = Vector3.AXIS_Z
			# Zapneme Y-Billboard, aby se otáčel za kamerou (jako postavy)
			terrain_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			# Vypneme Centered, aby stál nohama na zemi (nebo upravíme offset)
			terrain_sprite.centered = true
			# Pozice: Zvedneme ho (0.7), aby nebyl zapadlý v zemi
			terrain_sprite.position = Vector3(grid_position.x * cell_size_3d, 0.7, grid_position.y * cell_size_3d)

func get_terrain_on_cell(grid_position: Vector2i) -> TerrainData:
	return terrain_layer.get(grid_position, null)

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
	update_visual_highlights()

func hide_player_spawn_points():
	if not _player_spawn_cells.is_empty():
		_player_spawn_cells.clear()
		update_visual_highlights()

func is_cell_a_valid_spawn_point(cell: Vector2i) -> bool:
	return _player_spawn_cells.has(cell)

func show_danger_zone(enemy_units: Array):
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

	var new_danger_cells: Array[Vector2i] = []
	for cell_key in danger_dict.keys():
		new_danger_cells.append(cell_key)
	
	_danger_cells = new_danger_cells
	update_visual_highlights()

func hide_danger_zone():
	_danger_cells.clear()
	update_visual_highlights()

func get_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var line_points: Array[Vector2i] = []
	var x0 = from_cell.x; var y0 = from_cell.y
	var x1 = to_cell.x; var y1 = to_cell.y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		line_points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
			
	return line_points
