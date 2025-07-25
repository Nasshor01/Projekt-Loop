# MapGenerator.gd
extends Node

#=============================================================================
# EXPORTOVANÉ PROMĚNNÉ (Nastavitelné v Inspectoru)
#=============================================================================

@export_group("Map Geometry", "geom_")
@export var geom_floors: int = 15
@export var geom_map_width: int = 7
@export var geom_paths_to_generate: int = 6

@export_group("Visuals & Spacing", "vis_")
@export var vis_x_spacing: int = 128
@export var vis_y_spacing: int = 80
@export var vis_position_randomness: Vector2 = Vector2(20, 15)
@export var vis_boss_y_offset: float = -80.0

@export_group("Room Type Weights", "weight_")
@export_subgroup("Standard Rooms")
@export var weight_monster: float = 46.0
@export var weight_event: float = 10.0
@export_subgroup("Special Rooms")
@export var weight_elite: float = 20.0
@export var weight_rest: float = 12.0
@export var weight_shop: float = 5.0

@export_group("Room Placement Rules", "rule_")
@export var rule_treasure_floor: int = 8
@export var rule_pre_boss_rest_floor: int = 14
@export var rule_min_elite_floor: int = 5
@export var rule_min_rest_floor: int = 5
@export var rule_rest_blacklist_floor: int = 13 # Patro, kde odpočinek být nesmí

@export_group("Advanced Generation", "adv_")
@export var adv_path_generation_attempts: int = 10
@export var adv_room_assign_attempts: int = 20
@export var adv_unique_type_attempts: int = 20

#=============================================================================
# INTERNÍ SKRIPT
#=============================================================================

# Přednačtení našich vlastních Resource skriptů.
const MapNodeRes = preload("res://scripts/map/MapNodeResource.gd")
const MapDataRes = preload("res://scripts/map/MapData.gd")

# Hlavní veřejná funkce, která spustí celý proces generování.
func generate_map(seed_value: int) -> MapData:
	seed(seed_value)
	var map_data = MapDataRes.new()

	var grid = _generate_initial_grid()
	_generate_paths(grid)
	_fix_dead_ends(grid)
	map_data.all_nodes = _prune_unconnected_nodes(grid)
	_assign_room_types(map_data)

	return map_data

func _generate_initial_grid() -> Array[Array]:
	var grid: Array[Array] = []
	for i in range(geom_floors):
		grid.append([])
		for j in range(geom_map_width):
			var node = MapNodeRes.new()
			node.row = i
			node.column = j
			var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * vis_position_randomness
			var base_x = (j - (geom_map_width - 1) / 2.0) * vis_x_spacing
			var base_y = i * -vis_y_spacing
			node.position = Vector2(base_x, base_y) + random_offset
			grid[i].append(node)
	return grid

func _generate_paths(grid: Array[Array]):
	var generated_edges: Array = []
	for _i in range(geom_paths_to_generate):
		var current_node = grid[0].pick_random()
		for floor_idx in range(geom_floors - 1):
			var next_floor_idx = floor_idx + 1
			var possible_targets: Array = []
			for offset in [-1, 0, 1]:
				var target_col = current_node.column + offset
				if target_col >= 0 and target_col < geom_map_width:
					possible_targets.append(grid[next_floor_idx][target_col])
			if possible_targets.is_empty(): break
			
			var next_node = null
			var attempts = adv_path_generation_attempts
			while attempts > 0 and next_node == null:
				var chosen_target = possible_targets.pick_random()
				if not _does_edge_cross(current_node, chosen_target, generated_edges):
					next_node = chosen_target
					current_node.connections.append(next_node)
					next_node.incoming_connections.append(current_node)
					generated_edges.append([current_node, chosen_target])
				attempts -= 1
			
			if next_node: current_node = next_node
			else: break

func _does_edge_cross(start_node, end_node, existing_edges: Array) -> bool:
	for edge in existing_edges:
		if start_node in edge or end_node in edge: continue
		if Geometry2D.segment_intersects_segment(start_node.position, end_node.position, edge[0].position, edge[1].position):
			return true
	return false

func _fix_dead_ends(grid: Array[Array]):
	for i in range(geom_floors - 1):
		for j in range(geom_map_width):
			var node = grid[i][j]
			var is_part_of_map = not node.incoming_connections.is_empty() or i == 0
			var is_dead_end = node.connections.is_empty()
			if is_part_of_map and is_dead_end:
				var target_node = grid[i + 1][j]
				node.connections.append(target_node)
				target_node.incoming_connections.append(node)

func _prune_unconnected_nodes(grid: Array[Array]) -> Array:
	var connected_nodes: Array = []
	for row_array in grid:
		for node in row_array:
			if not node.connections.is_empty() or not node.incoming_connections.is_empty():
				connected_nodes.append(node)
	return connected_nodes

func _assign_room_types(map_data: MapData):
	var all_nodes = map_data.all_nodes
	
	for node in all_nodes:
		if node.row == 0:
			node.type = MapNodeRes.NodeType.MONSTER
		elif node.row == rule_treasure_floor:
			node.type = MapNodeRes.NodeType.TREASURE
		elif node.row == rule_pre_boss_rest_floor:
			node.type = MapNodeRes.NodeType.REST
	
	map_data.starting_nodes = all_nodes.filter(func(n): return n.row == 0)

	var top_row_nodes = all_nodes.filter(func(n): return n.row == geom_floors - 1)
	if not top_row_nodes.is_empty():
		var boss_node = MapNodeRes.new()
		boss_node.type = MapNodeRes.NodeType.BOSS
		boss_node.row = geom_floors
		
		# --- ZDE JE KLÍČOVÁ ZMĚNA ---
		# K původní pozici přičteme náš nový offset.
		var base_boss_y = geom_floors * -vis_y_spacing
		boss_node.position = Vector2(0, base_boss_y + vis_boss_y_offset)
		
		map_data.boss_node = boss_node
		all_nodes.append(boss_node)
		for node in top_row_nodes:
			node.connections.append(boss_node)
			boss_node.incoming_connections.append(node)

	var unassigned_nodes = all_nodes.filter(func(n): return n.type == MapNodeRes.NodeType.UNASSIGNED)
	var weights = {
		MapNodeRes.NodeType.MONSTER: weight_monster, MapNodeRes.NodeType.ELITE: weight_elite,
		MapNodeRes.NodeType.EVENT: weight_event, MapNodeRes.NodeType.REST: weight_rest,
		MapNodeRes.NodeType.SHOP: weight_shop
	}
	
	for node in unassigned_nodes:
		var attempts = adv_room_assign_attempts
		while attempts > 0:
			var chosen_type = _get_weighted_random_type(weights)
			if _is_placement_valid(node, chosen_type):
				node.type = chosen_type
				break
			attempts -= 1
		if node.type == MapNodeRes.NodeType.UNASSIGNED:
			node.type = MapNodeRes.NodeType.MONSTER
			
	_ensure_unique_destinations(all_nodes, weights)
func _is_placement_valid(node: MapNodeRes, type_to_check: MapNodeRes.NodeType) -> bool:
	# Pravidla pro pevná patra - mají nejvyšší prioritu.
	if node.row == rule_treasure_floor and type_to_check != MapNodeRes.NodeType.TREASURE:
		return false # Na tomto patře smí být POUZE poklad.
	
	if node.row == rule_pre_boss_rest_floor and type_to_check != MapNodeRes.NodeType.REST:
		return false # Na tomto patře smí být POUZE odpočinek.
	
	if node.row == 0 and type_to_check != MapNodeRes.NodeType.MONSTER:
		return false # Na prvním patře smí být POUZE monstra.

	# Ostatní pravidla pro ostatní patra.
	if type_to_check == MapNodeRes.NodeType.ELITE and node.row < rule_min_elite_floor: 
		return false
		
	if type_to_check == MapNodeRes.NodeType.REST and node.row < rule_min_rest_floor: 
		return false
		
	if type_to_check == MapNodeRes.NodeType.REST and node.row == rule_rest_blacklist_floor: 
		return false
	
	var special_types = [
		MapNodeRes.NodeType.ELITE, MapNodeRes.NodeType.REST, 
		MapNodeRes.NodeType.SHOP, MapNodeRes.NodeType.EVENT
	]
	if special_types.has(type_to_check):
		for connected_node in node.incoming_connections:
			if connected_node.type == type_to_check: 
				return false
				
	return true
func _get_weighted_random_type(weights: Dictionary) -> MapNodeRes.NodeType:
	var total_weight = 0.0
	for key in weights: total_weight += weights[key]
	if total_weight <= 0: return MapNodeRes.NodeType.MONSTER # Pojistka
	
	var random_value = randf() * total_weight
	for type in weights:
		if random_value < weights[type]: return type
		random_value -= weights[type]
	return MapNodeRes.NodeType.MONSTER

func _ensure_unique_destinations(nodes: Array, weights: Dictionary):
	for node in nodes:
		if node.connections.size() <= 1:
			continue

		var used_types_for_this_node: Array[MapNodeRes.NodeType] = []
		
		for connection in node.connections:
			if connection.type in used_types_for_this_node:
				var new_type_found = false
				var attempts = adv_unique_type_attempts
				while attempts > 0 and not new_type_found:
					var new_type = _get_weighted_random_type(weights)
					
					if not new_type in used_types_for_this_node and _is_placement_valid(connection, new_type):
						connection.type = new_type
						new_type_found = true
					
					attempts -= 1
				
				# --- ZDE JE KLÍČOVÁ ZMĚNA ---
				# Pokud se nenašla náhrada, zkusíme MONSTER, ale POUZE pokud je to platné!
				if not new_type_found:
					var monster_type = MapNodeRes.NodeType.MONSTER
					if not monster_type in used_types_for_this_node and _is_placement_valid(connection, monster_type):
						# print(" -> Nepodařilo se najít unikátní typ. Přiřazuji MONSTER jako zálohu.")
						connection.type = monster_type
					# Pokud ani monstrum není platné (např. jsme na patře s pokladem),
					# neuděláme nic a necháme duplicitu. To je lepší než porušit pravidlo.
			
			used_types_for_this_node.append(connection.type)
