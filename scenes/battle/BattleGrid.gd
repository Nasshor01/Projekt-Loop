# ===================================================================
# Soubor: res://scenes/battle/BattleGrid.gd (FINÁLNÍ OPRAVA)
# POPIS: Opravena metoda pro odstranění jednotky.
# ===================================================================
class_name BattleGrid
extends Node2D

@export var cell_size: Vector2 = Vector2(64, 64)
@export var grid_columns: int = 8
@export var grid_rows: int = 6

@export var grid_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var highlight_color: Color = Color(1, 1, 0, 0.3)
@export var movement_highlight_color: Color = Color(0.2, 0.8, 0.2, 0.3)
@export var attack_highlight_color: Color = Color(1.0, 0.2, 0.2, 0.4)
@export var support_highlight_color: Color = Color(0.2, 0.5, 1.0, 0.4)
@export var aoe_highlight_color: Color = Color(0.8, 0.2, 1.0, 0.35)

@onready var units_container: Node2D = $UnitsContainer
var _terrain_container: Node2D

var _grid_objects: Dictionary = {}
var terrain_layer: Dictionary = {}
var _mouse_over_cell: Vector2i = Vector2i(-1, -1)
var _movable_cells: Array[Vector2i] = []
var _targetable_cells: Array[Vector2i] = []
var _aoe_cells: Array[Vector2i] = [] 
var _targetable_cells_color: Color = attack_highlight_color

func _ready():
	_terrain_container = Node2D.new()
	_terrain_container.name = "TerrainContainer" 
	add_child(_terrain_container) 
	move_child(_terrain_container, 0)

	if not units_container:
		units_container = Node2D.new(); units_container.name = "UnitsContainer"; add_child(units_container)
	set_process_input(true)
	queue_redraw()

func _draw():
	for i in range(grid_columns + 1):
		draw_line(Vector2(i * cell_size.x, 0), Vector2(i * cell_size.x, grid_rows * cell_size.y), grid_line_color, 1.0)
	for i in range(grid_rows + 1):
		draw_line(Vector2(0, i * cell_size.y), Vector2(grid_columns * cell_size.x, i * cell_size.y), grid_line_color, 1.0)
	if is_valid_grid_position(_mouse_over_cell):
		draw_rect(Rect2(Vector2(_mouse_over_cell) * cell_size, cell_size), highlight_color, true)
	for cell in _movable_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), movement_highlight_color, true)
	for cell in _targetable_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), _targetable_cells_color, true)
	for cell in _aoe_cells:
		draw_rect(Rect2(Vector2(cell) * cell_size, cell_size), aoe_highlight_color, true)

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		var new_mouse_cell = get_cell_at_world_position(event.position)
		if new_mouse_cell != _mouse_over_cell:
			_mouse_over_cell = new_mouse_cell
			queue_redraw()

func place_object_on_cell(object_node: Node2D, grid_position: Vector2i, is_moving: bool = false) -> bool:
	if not is_valid_grid_position(grid_position) or _grid_objects.has(grid_position): return false
	if object_node.get_parent() != units_container:
		if object_node.get_parent(): object_node.get_parent().remove_child(object_node)
		units_container.add_child(object_node)
	var cell_center_local = Vector2(grid_position.x * cell_size.x + cell_size.x / 2.0, grid_position.y * cell_size.y + cell_size.y / 2.0)
	if is_moving:
		var tween = create_tween(); tween.tween_property(object_node, "position", cell_center_local, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		object_node.position = cell_center_local
	if "grid_position" in object_node:
		object_node.grid_position = grid_position
	_grid_objects[grid_position] = object_node
	return true

func remove_object_by_instance(object_node: Node2D):
	for cell in _grid_objects.keys():
		if _grid_objects[cell] == object_node:
			_grid_objects.erase(cell)
			return

# Zbytek je stejný
func get_distance(cell_a: Vector2i, cell_b: Vector2i) -> int: return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)
func get_cell_at_world_position(world_position: Vector2) -> Vector2i:
	var local_position = to_local(world_position); return Vector2i(floori(local_position.x / cell_size.x), floori(local_position.y / cell_size.y))
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
	_movable_cells.clear(); for x in range(-move_range, move_range + 1):
		for y in range(-move_range, move_range + 1):
			if abs(x) + abs(y) > move_range or (x == 0 and y == 0): continue
			var target_cell = from_cell + Vector2i(x, y)
			var terrain_on_cell = terrain_layer.get(target_cell)
			var is_walkable = true
			if terrain_on_cell and not terrain_on_cell.is_walkable:
				is_walkable = false

			if is_valid_grid_position(target_cell) and get_object_on_cell(target_cell) == null and is_walkable:
				_movable_cells.append(target_cell)
	queue_redraw()

func hide_movable_range(): _movable_cells.clear(); queue_redraw()
func is_cell_movable(cell: Vector2i) -> bool: return _movable_cells.has(cell)

func show_aoe_highlight(cells: Array[Vector2i]):
	_aoe_cells = cells
	queue_redraw()

func hide_aoe_highlight():
	if not _aoe_cells.is_empty():
		_aoe_cells.clear()
		queue_redraw()

func get_cells_for_aoe(origin_cell: Vector2i, aoe_type: CardEffectData.AreaOfEffectType, param_x: int, param_y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match aoe_type:
		CardEffectData.AreaOfEffectType.ROW:
			for x in range(grid_columns):
				cells.append(Vector2i(x, origin_cell.y))
		CardEffectData.AreaOfEffectType.COLUMN:
			for y in range(grid_rows):
				cells.append(Vector2i(origin_cell.x, y))
		CardEffectData.AreaOfEffectType.SQUARE_X_BY_Y:
			for y in range(origin_cell.y, origin_cell.y + param_y):
				for x in range(origin_cell.x, origin_cell.x + param_x):
					var cell = Vector2i(x, y)
					if is_valid_grid_position(cell):
						cells.append(cell)
		CardEffectData.AreaOfEffectType.ALL_ON_GRID:
			var all_units = get_all_objects_on_grid()
			for unit in all_units:
				if unit.unit_data.faction == UnitData.Faction.ENEMY:
					cells.append(unit.grid_position)
	return cells


func place_terrain(grid_position: Vector2i, terrain_data: TerrainData):
	if not is_valid_grid_position(grid_position): return

	terrain_layer[grid_position] = terrain_data

	if terrain_data.sprite:
		var terrain_sprite = Sprite2D.new()
		terrain_sprite.texture = terrain_data.sprite
		terrain_sprite.position = Vector2(grid_position) * cell_size + cell_size / 2
		_terrain_container.add_child(terrain_sprite)
