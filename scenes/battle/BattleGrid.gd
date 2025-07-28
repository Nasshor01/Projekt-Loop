class_name BattleGrid
extends Node2D

@export var cell_size: Vector2 = Vector2(64, 64)
# Tyto hodnoty se přepíší při generování tvaru, ale necháme je tu pro přehlednost
@export var grid_columns: int = 15
@export var grid_rows: int = 10

@export var grid_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var highlight_color: Color = Color(1, 1, 0, 0.3)
@export var movement_highlight_color: Color = Color(0.2, 0.8, 0.2, 0.3)
@export var attack_highlight_color: Color = Color(1.0, 0.2, 0.2, 0.4)
@export var support_highlight_color: Color = Color(0.2, 0.5, 1.0, 0.4)
@export var aoe_highlight_color: Color = Color(0.8, 0.2, 1.0, 0.35)

@onready var units_container: Node2D = $UnitsContainer
var _terrain_container: Node2D
var camera: Camera2D

# ZMĚNA: Přidáváme slovník jen pro aktivní buňky, odděleně od jednotek!
var _active_cells: Dictionary = {}
var _grid_objects: Dictionary = {} # Toto je jen pro jednotky!
var terrain_layer: Dictionary = {}
var _mouse_over_cell: Vector2i = Vector2i(-1, -1)
var _movable_cells: Array[Vector2i] = []
var _targetable_cells: Array[Vector2i] = []
var _aoe_cells: Array[Vector2i] = []
var _targetable_cells_color: Color = attack_highlight_color

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
	# Vynutí překreslení každý snímek. To zajistí, že se tloušťka čáry
	# aktualizuje plynule při zoomování.
	queue_redraw()

# Soubor: scenes/battle/BattleGrid.gd
# Nahraďte vaši stávající funkci _draw() touto verzí.

func _draw():
	var line_thickness: float

	# Pojistka pro případ, že kamera ještě není platná.
	if not is_instance_valid(camera):
		# Pokud nemáme kameru, použijeme pevnou tloušťku 1.0.
		line_thickness = 1.0
	else:
		# --- NOVÝ A ROBUSTNĚJŠÍ VÝPOČET ---
		# 1. Nastavíme si vyšší základní tloušťku. Můžete experimentovat
		#    s hodnotou 1.5 a zvýšit ji třeba na 2.0 nebo 2.5, pokud bude potřeba.
		var base_thickness = 1.5

		# 2. Vynásobíme ji zoomem kamery, abychom kompenzovali oddálení.
		#    Když je kamera oddálená (zoom > 1), čára bude tlustší.
		line_thickness = base_thickness * camera.zoom.x
		
		# 3. Důležitá pojistka: Zajistíme, aby čára na obrazovce nikdy nebyla
		#    tenčí než cca 1 pixel, bez ohledu na zoom.
		var min_thickness_on_screen = get_canvas_transform().affine_inverse().get_scale().x
		line_thickness = max(line_thickness, min_thickness_on_screen)

	# --- Vykreslení mřížky s nově spočítanou tloušťkou ---
	for cell_pos in _active_cells:
		var top_left = Vector2(cell_pos) * cell_size
		draw_rect(Rect2(top_left, cell_size), grid_line_color, false, line_thickness)

	if is_cell_active(_mouse_over_cell):
		draw_rect(Rect2(Vector2(_mouse_over_cell) * cell_size, cell_size), highlight_color, true)
	for cell in _movable_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), movement_highlight_color, true)
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
	
	# Stále nastavíme celkovou šířku podle prvního řádku pro konzistenci
	if grid_rows > 0:
		grid_columns = shape_array[0].length()
	else:
		grid_columns = 0

	# Projdeme všechny řádky
	for y in range(grid_rows):
		var row_string = shape_array[y]
		# Projdeme všechny znaky JEN v aktuálním řádku
		for x in range(row_string.length()):
			if row_string[x] == "1":
				_active_cells[Vector2i(x, y)] = true
	
	queue_redraw()

# --- NOVÁ, JEDNODUŠŠÍ FUNKCE ---
func is_cell_active(grid_position: Vector2i) -> bool:
	return _active_cells.has(grid_position)

func place_object_on_cell(object_node: Node2D, grid_position: Vector2i, is_moving: bool = false) -> bool:
	# Kontrolujeme proti novému slovníku _active_cells
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

func show_movable_range(from_cell: Vector2i, move_range: int):
	_movable_cells.clear(); var q = [from_cell]; var dists = {from_cell: 0}
	var head = 0
	while head < q.size():
		var curr = q[head]; head += 1
		var d = dists[curr]
		if d >= move_range: continue
		for n in [curr + Vector2i.UP, curr + Vector2i.DOWN, curr + Vector2i.LEFT, curr + Vector2i.RIGHT]:
			if not dists.has(n) and is_cell_active(n) and not get_object_on_cell(n):
				var terrain_on_cell = terrain_layer.get(n)
				if not terrain_on_cell or terrain_on_cell.is_walkable:
					dists[n] = d + 1; q.append(n); _movable_cells.append(n)
	queue_redraw()

func hide_movable_range(): _movable_cells.clear(); queue_redraw()
func is_cell_movable(cell: Vector2i) -> bool: return _movable_cells.has(cell)
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
