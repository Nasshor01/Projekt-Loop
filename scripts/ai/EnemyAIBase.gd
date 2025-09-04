# ===================================================================
# Soubor: res://scripts/ai/EnemyAIBase.gd
# POPIS: Základní třída pro všechny enemy AI - opravená pro typovou kompatibilitu
# ===================================================================
class_name EnemyAIBase
extends RefCounted

# Vnitřní třída pro akce AI
class AIAction:
	enum ActionType { ATTACK, MOVE, SPECIAL, PASS }
	var type: ActionType
	var target_unit: Unit = null
	var move_path: Array[Vector2i] = []
	var damage_multiplier: float = 1.0
	var special_data: Dictionary = {}

# OPRAVENÁ SIGNATURA - používá Array místo Array[Unit] pro kompatibilitu
func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
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
