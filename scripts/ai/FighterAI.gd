# ===================================================================
# Soubor: res://scripts/ai/FighterAI.gd
# POPIS: Jednoduchá melee AI - jdi a zaútoč
# ===================================================================
extends EnemyAIBase

var astar_grid: AStar2D = AStar2D.new()
var grid_size: Vector2i
var battle_grid: BattleGrid

func get_next_action(enemy_unit: Unit, all_player_units: Array, p_battle_grid: BattleGrid) -> AIAction:
	self.battle_grid = p_battle_grid
	self.grid_size = Vector2i(battle_grid.grid_columns, battle_grid.grid_rows)
	
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# 1. Pokud můžeme zaútočit, zaútočíme
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		print("Fighter útočí na hráče!")
		return create_attack_action(player_unit)
	
	# 2. Pokud nemůžeme zaútočit, pokusíme se přiblížit
	var path = find_path_to_adjacent(enemy_unit, player_unit)
	if not path.is_empty():
		print("Fighter se pohybuje směrem k hráči")
		return create_move_action(path)
	
	# 3. Nemůžeme se pohnout ani zaútočit
	print("Fighter nemůže najít cestu k hráči")
	return create_pass_action()

func find_path_to_adjacent(from_unit: Unit, to_unit: Unit) -> Array[Vector2i]:
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
		var path = find_path(from_unit, target_cell)
		if not path.is_empty() and path.size() < shortest_distance:
			shortest_distance = path.size()
			best_path = path
	
	return best_path

func find_path(from_unit: Unit, to_cell: Vector2i) -> Array[Vector2i]:
	update_astar_grid(from_unit)
	var start_id = get_point_id(from_unit.grid_position)
	var end_id = get_point_id(to_cell)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return []
	
	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	for p in path_vectors:
		result_path.append(Vector2i(p))
	
	return result_path

func update_astar_grid(moving_unit: Unit):
	astar_grid.clear()
	var all_units = battle_grid.get_all_objects_on_grid()
	var occupied_cells: Dictionary = {}
	
	# Označíme obsazená pole
	for unit in all_units:
		if unit != moving_unit and is_instance_valid(unit):
			occupied_cells[unit.grid_position] = true
	
	# Přidáme všechna aktivní pole do A*
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = Vector2i(x, y)
			var point_id = get_point_id(cell)
			
			if battle_grid.is_cell_active(cell):
				astar_grid.add_point(point_id, cell)
				
				var terrain = battle_grid.get_terrain_on_cell(cell)
				var is_blocked = occupied_cells.has(cell) or (terrain and not terrain.is_walkable)
				
				if is_blocked:
					astar_grid.set_point_disabled(point_id, true)
	
	# Propojíme sousední body
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var from_cell = Vector2i(x, y)
			var from_id = get_point_id(from_cell)
			
			if astar_grid.has_point(from_id) and not astar_grid.is_point_disabled(from_id):
				for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var to_cell = from_cell + offset
					var to_id = get_point_id(to_cell)
					
					if astar_grid.has_point(to_id) and not astar_grid.is_point_disabled(to_id):
						astar_grid.connect_points(from_id, to_id)

func get_point_id(cell: Vector2i) -> int:
	return cell.y * grid_size.x + cell.x
