# ===================================================================
# Soubor: res://scripts/ai/EnemyAIBase.gd
# POPIS: Základní třída pro všechny enemy AI - s přidanou RUSH akcí
# ===================================================================
class_name EnemyAIBase
extends RefCounted

# Vnitřní třída pro akce AI
class AIAction:
	enum ActionType { ATTACK, MOVE, SPECIAL, PASS, RUSH }  # PŘIDÁNO: RUSH
	var type: ActionType
	var target_unit: Unit = null
	var move_path: Array[Vector2i] = []
	var damage_multiplier: float = 1.0
	var special_data: Dictionary = {}

# OPRAVENÁ SIGNATURA - používá Array místo Array[Unit] pro kompatibilitu
func get_next_action(_enemy_unit: Unit, _all_player_units: Array, _battle_grid: BattleGrid) -> AIAction:
	return create_pass_action()

# === HELPER FUNKCE ===
func find_closest_player(enemy_unit: Unit, all_player_units: Array) -> Unit:
	var closest_player: Unit = null
	var min_dist = INF
	
	for player in all_player_units:
		if is_instance_valid(player) and player is Unit:
			var dist = enemy_unit.global_position.distance_to(player.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_player = player
	return closest_player

func get_valid_players(all_player_units: Array) -> Array[Unit]:
	var valid_players: Array[Unit] = []
	for unit in all_player_units:
		if is_instance_valid(unit) and unit is Unit:
			valid_players.append(unit)
	return valid_players

func can_attack_target(attacker: Unit, target: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	
	var distance = battle_grid.get_distance(attacker.grid_position, target.grid_position)
	return distance <= attacker.unit_data.attack_range

func get_reachable_cells(unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var start_cell = unit.grid_position
	var to_visit = [start_cell]
	var costs = {start_cell: 0}
	var movement_range = unit.get_current_movement_range()
	
	var head = 0
	while head < to_visit.size():
		var current = to_visit[head]
		head += 1
		
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = current + offset
			var new_cost = costs[current] + 1
			
			if new_cost <= movement_range and battle_grid.is_cell_active(neighbor):
				var object_on_cell = battle_grid.get_object_on_cell(neighbor)
				if not object_on_cell or object_on_cell == unit:
					var terrain = battle_grid.get_terrain_on_cell(neighbor)
					if not terrain or terrain.is_walkable:
						if not costs.has(neighbor) or new_cost < costs[neighbor]:
							costs[neighbor] = new_cost
							to_visit.append(neighbor)
							if neighbor != start_cell:
								reachable.append(neighbor)
	
	return reachable

# === AKCE TVOŘÍCÍ FUNKCE ===
func create_pass_action() -> AIAction:
	var action = AIAction.new()
	action.type = AIAction.ActionType.PASS
	return action

func create_attack_action(target: Unit, multiplier: float = 1.0) -> AIAction:
	var action = AIAction.new()
	action.type = AIAction.ActionType.ATTACK
	action.target_unit = target
	action.damage_multiplier = multiplier
	return action

func create_move_action(path: Array[Vector2i]) -> AIAction:
	var action = AIAction.new()
	action.type = AIAction.ActionType.MOVE
	action.move_path = path
	return action

func create_special_action(data: Dictionary = {}) -> AIAction:
	var action = AIAction.new()
	action.type = AIAction.ActionType.SPECIAL
	action.special_data = data
	return action

# NOVÁ FUNKCE: Vytvoří RUSH akci
func create_rush_action(target: Unit, path: Array[Vector2i], multiplier: float = 3.0) -> AIAction:
	var action = AIAction.new()
	action.type = AIAction.ActionType.RUSH
	action.target_unit = target
	action.move_path = path
	action.damage_multiplier = multiplier
	return action

# === PATHFINDING FUNKCE ===

# Základní pathfinding - najde cestu z from_unit na to_cell
func find_path(from_unit: Unit, to_cell: Vector2i, battle_grid: BattleGrid) -> Array[Vector2i]:
	var astar_grid = AStar2D.new()
	update_astar_grid(astar_grid, from_unit, battle_grid)
	var start_id = get_point_id(from_unit.grid_position, battle_grid)
	var end_id = get_point_id(to_cell, battle_grid)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return []

	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	for p in path_vectors:
		result_path.append(Vector2i(p))
		
	return result_path

# Pathfinding s limitem pohybu - omezí cestu na max_movement kroků
func find_path_with_movement_limit(from_unit: Unit, to_cell: Vector2i, battle_grid: BattleGrid, max_movement: int) -> Array[Vector2i]:
	var astar_grid = AStar2D.new()
	update_astar_grid(astar_grid, from_unit, battle_grid)
	
	var start_id = get_point_id(from_unit.grid_position, battle_grid)
	var end_id = get_point_id(to_cell, battle_grid)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return []

	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	# Omez cestu na maximální pohyb
	var steps_taken = 0
	for i in range(path_vectors.size()):
		result_path.append(Vector2i(path_vectors[i]))
		if i > 0: # Nepočítej startovní pozici
			steps_taken += 1
			if steps_taken >= max_movement:
				break
	
	return result_path

# Najde cestu k sousednímu poli cílové jednotky
func find_path_to_adjacent(from_unit: Unit, to_unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	# Najdeme všechna sousední pole k cíli
	var adjacent_cells: Array[Vector2i] = []
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = to_unit.grid_position + offset
		if battle_grid.is_cell_active(cell):
			var object_on_cell = battle_grid.get_object_on_cell(cell)
			if not object_on_cell or object_on_cell == from_unit:
				var terrain = battle_grid.get_terrain_on_cell(cell)
				if not terrain or terrain.is_walkable:
					adjacent_cells.append(cell)
	
	if adjacent_cells.is_empty():
		return []
	
	# Najdeme nejkratší cestu k nejbližšímu sousednímu poli
	var best_path: Array[Vector2i] = []
	var shortest_distance = INF
	
	for target_cell in adjacent_cells:
		var path = find_path(from_unit, target_cell, battle_grid)
		if not path.is_empty() and path.size() < shortest_distance:
			shortest_distance = path.size()
			best_path = path
	
	return best_path

# Aktualizuje A* grid pro pathfinding
func update_astar_grid(astar_grid: AStar2D, moving_unit: Unit, battle_grid: BattleGrid):
	astar_grid.clear()
	var grid_size = Vector2i(battle_grid.grid_columns, battle_grid.grid_rows)
	var all_units = battle_grid.get_all_objects_on_grid()
	var occupied_cells: Dictionary = {}
	for unit in all_units:
		if unit != moving_unit and is_instance_valid(unit): 
			occupied_cells[unit.grid_position] = true
			
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = Vector2i(x, y)
			var point_id = get_point_id(cell, battle_grid)
			if battle_grid.is_cell_active(cell):
				astar_grid.add_point(point_id, cell)
				var terrain = battle_grid.get_terrain_on_cell(cell)
				if occupied_cells.has(cell) or (terrain and not terrain.is_walkable): 
					astar_grid.set_point_disabled(point_id, true)
					
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var from_cell = Vector2i(x, y)
			var from_id = get_point_id(from_cell, battle_grid)
			if astar_grid.has_point(from_id) and not astar_grid.is_point_disabled(from_id):
				for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var to_cell = from_cell + offset
					var to_id = get_point_id(to_cell, battle_grid)
					if astar_grid.has_point(to_id) and not astar_grid.is_point_disabled(to_id): 
						astar_grid.connect_points(from_id, to_id)

# Vypočítá point ID pro A* grid
func get_point_id(cell: Vector2i, battle_grid: BattleGrid) -> int:
	return cell.y * battle_grid.grid_columns + cell.x
