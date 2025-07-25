# ===================================================================
# Soubor: res://scripts/EnemyAIController.gd
# POPIS: Čistá a funkční verze AI, která správně obchází překážky.
# ===================================================================
class_name EnemyAIController
extends Object

class AIAction:
	enum ActionType { ATTACK, MOVE, PASS }
	var type: ActionType
	var target_unit: Node2D = null
	var move_path: Array[Vector2i] = []

var astar_grid: AStar2D = AStar2D.new()
var grid_size: Vector2i
var battle_grid: BattleGrid # Ujisti se, že typ je BattleGrid

# Hlavní funkce, kterou volá BattleScene
func get_next_action(enemy_unit: Node2D, player_units: Array[Node2D], p_battle_grid: BattleGrid) -> AIAction:
	self.battle_grid = p_battle_grid
	self.grid_size = Vector2i(battle_grid.grid_columns, battle_grid.grid_rows)

	if player_units.is_empty():
		return _create_pass_action()

	var target_player = player_units[0]
	
	var distance_to_target = battle_grid.get_distance(enemy_unit.grid_position, target_player.grid_position)
	if distance_to_target <= enemy_unit.unit_data.attack_range:
		return _create_attack_action(target_player)

	var path_to_target = _find_path_to_unit(enemy_unit, target_player)
	if not path_to_target.is_empty():
		return _create_move_action(path_to_target)

	print(enemy_unit.unit_data.unit_name, " nemůže najít cestu ani zaútočit.")
	return _create_pass_action()

func _find_path_to_unit(from_unit: Node2D, to_unit: Node2D) -> Array[Vector2i]:
	_update_astar_grid(from_unit)
	
	var adjacent_cells = [
		to_unit.grid_position + Vector2i.LEFT, to_unit.grid_position + Vector2i.RIGHT,
		to_unit.grid_position + Vector2i.UP, to_unit.grid_position + Vector2i.DOWN
	]
	var best_target_cell = Vector2i(-1,-1)
	var min_dist = 999
	
	for cell in adjacent_cells:
		var terrain = battle_grid.terrain_layer.get(cell, null)
		var is_walkable = not terrain or terrain.is_walkable
		
		if battle_grid.is_valid_grid_position(cell) and battle_grid.get_object_on_cell(cell) == null and is_walkable:
			var dist_from_enemy = battle_grid.get_distance(from_unit.grid_position, cell)
			if dist_from_enemy < min_dist:
				min_dist = dist_from_enemy
				best_target_cell = cell

	if best_target_cell == Vector2i(-1, -1):
		return []

	var start_id = _get_point_id(from_unit.grid_position)
	var end_id = _get_point_id(best_target_cell)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id):
		return []

	var path_vectors = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []; for p in path_vectors: result_path.append(Vector2i(p))
	return result_path

func _update_astar_grid(moving_unit: Node2D):
	astar_grid.clear()
	var all_units = battle_grid.get_all_objects_on_grid()
	var occupied_cells: Dictionary = {}
	for unit in all_units:
		if unit != moving_unit:
			occupied_cells[unit.grid_position] = true

	# Přidáme všechny buňky jako body do grafu
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = Vector2i(x, y)
			astar_grid.add_point(_get_point_id(cell), cell)
	
	# Propojíme sousední body, POKUD jsou OBĚ políčka průchozí
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var from_cell = Vector2i(x, y)
			
			# Zkontrolujeme "startovní" políčko
			var terrain_from = battle_grid.terrain_layer.get(from_cell, null)
			if (terrain_from and not terrain_from.is_walkable) or occupied_cells.has(from_cell):
				continue # Přes tuto buňku se nedá jít
				
			var neighbors = [from_cell + Vector2i(1,0), from_cell + Vector2i(-1,0), from_cell + Vector2i(0,1), from_cell + Vector2i(0,-1)]
			for to_cell in neighbors:
				# Zkontrolujeme "cílové" políčko
				if battle_grid.is_valid_grid_position(to_cell):
					var terrain_to = battle_grid.terrain_layer.get(to_cell, null)
					if (terrain_to and not terrain_to.is_walkable) or occupied_cells.has(to_cell):
						continue # Na tuto buňku se nedá jít
					
					astar_grid.connect_points(_get_point_id(from_cell), _get_point_id(to_cell), true)

func _get_point_id(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x

func _create_attack_action(target: Node2D) -> AIAction:
	var action = AIAction.new(); action.type = AIAction.ActionType.ATTACK; action.target_unit = target; return action

func _create_move_action(path: Array[Vector2i]) -> AIAction:
	var action = AIAction.new(); action.type = AIAction.ActionType.MOVE; action.move_path = path; return action

func _create_pass_action() -> AIAction:
	var action = AIAction.new(); action.type = AIAction.ActionType.PASS; return action
