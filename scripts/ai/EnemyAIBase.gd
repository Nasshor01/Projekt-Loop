# ===================================================================
# Soubor: res://scripts/ai/EnemyAIBase.gd
# POPIS: Základní třída pro všechny enemy AI - multi-action systém
# ===================================================================
class_name EnemyAIBase
extends RefCounted

# Vnitřní třída pro akce AI
class AIAction:
	enum ActionType { ATTACK, MOVE, SPECIAL, PASS, RUSH }
	var type: ActionType
	var target_unit: Unit = null
	var move_path: Array[Vector2i] = []
	var damage_multiplier: float = 1.0
	var special_data: Dictionary = {}

# === HLAVNÍ METODA - vrací POLE akcí pro multi-action systém ===
func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	# Výchozí implementace: zavolá get_next_action pro zpětnou kompatibilitu
	var action = get_next_action(enemy_unit, all_player_units, battle_grid)
	return [action]

# Zpětná kompatibilita - starší AI mohou stále overridovat tuto metodu
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

# Zjistí, zda by jednotka mohla zaútočit z dané pozice
func can_attack_from_position(position: Vector2i, attacker: Unit, target: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	var distance = battle_grid.get_distance(position, target.grid_position)
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
				if not is_instance_valid(object_on_cell) or object_on_cell == unit:
					var terrain = battle_grid.get_terrain_on_cell(neighbor)
					if not terrain or terrain.is_walkable:
						if not costs.has(neighbor) or new_cost < costs[neighbor]:
							costs[neighbor] = new_cost
							to_visit.append(neighbor)
							if neighbor != start_cell:
								reachable.append(neighbor)
	
	return reachable

# Získá všechny enemy jednotky na gridu (spojence AI)
func get_all_enemies(unit: Unit, battle_grid: BattleGrid) -> Array[Unit]:
	var allies: Array[Unit] = []
	var all_units = battle_grid.get_all_objects_on_grid()
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.faction == unit.unit_data.faction:
				allies.append(u)
	return allies

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

func create_rush_action(target: Unit, path: Array[Vector2i], multiplier: float = 3.0) -> AIAction:
	var action = AIAction.new()
	action.type = AIAction.ActionType.RUSH
	action.target_unit = target
	action.move_path = path
	action.damage_multiplier = multiplier
	return action

# === TAKTICKÉ HELPER FUNKCE ===

# Najde nejlepší pozici pro útok na cíl (přesune se tak, aby mohl zaútočit)
func find_attack_move_position(unit: Unit, target: Unit, battle_grid: BattleGrid) -> Vector2i:
	var reachable = get_reachable_cells(unit, battle_grid)
	var best_cell = Vector2i(-1, -1)
	var best_distance = INF
	
	for cell in reachable:
		if can_attack_from_position(cell, unit, target, battle_grid):
			# Preferujeme pozici nejblíže k aktuální pozici (minimum pohybu)
			var move_dist = battle_grid.get_distance(unit.grid_position, cell)
			if move_dist < best_distance:
				best_distance = move_dist
				best_cell = cell
	
	return best_cell

## Pure preview helper for intent UI — no meta/state mutation.
## True when this turn's plan can be MOVE then ATTACK (same helper Fighter/Berserker/Boss use).
func can_move_then_attack_this_turn(unit: Unit, target: Unit, battle_grid: BattleGrid) -> bool:
	if not is_instance_valid(unit) or not is_instance_valid(target):
		return false
	if can_attack_target(unit, target, battle_grid):
		return true
	var attack_pos = find_attack_move_position(unit, target, battle_grid)
	if attack_pos == Vector2i(-1, -1):
		return false
	var path = find_path(unit, attack_pos, battle_grid)
	return not path.is_empty()

# Setup-only specials that are not player-facing combat intents (Boss barrier/aura, heals, buffs…).
const _NON_PLAYER_FACING_SPECIAL_TYPES: Array[String] = [
	"dark_barrier",
	"demon_aura",
	"arcane_shield",
	"protection",
	"heal_ally",
	"holy_nova",
	"meditate",
	"buff_ally",
	"war_cry",
	"howl",
]

## Drops setup-only SPECIAL actions (dark_barrier, demon_aura, …) and PASS.
## Caps at 2 player-facing actions for intent UI (Boss may plan 3–4 including barrier/aura).
## Accepts AIAction objects or intent dicts with "special_type" / special_data.type.
## For future safe action-list previews — does not call get_actions or mutate state.
func filter_player_facing_actions(actions: Array) -> Array:
	var facing: Array = []
	for action in actions:
		if action == null:
			continue
		if action is AIAction:
			if action.type == AIAction.ActionType.PASS:
				continue
			if action.type == AIAction.ActionType.SPECIAL:
				var st := str(action.special_data.get("type", ""))
				if st in _NON_PLAYER_FACING_SPECIAL_TYPES:
					continue
			facing.append(action)
		elif action is Dictionary:
			var st2 := str(action.get("special_type", ""))
			if st2.is_empty() and action.has("special_data") and action["special_data"] is Dictionary:
				st2 = str(action["special_data"].get("type", ""))
			if st2 in _NON_PLAYER_FACING_SPECIAL_TYPES:
				continue
			var id := str(action.get("id", ""))
			if id == "pass":
				continue
			facing.append(action)
		else:
			facing.append(action)
		if facing.size() >= 2:
			break
	return facing

func _make_combat_intent(id: String, short_key: String, text_key: String, special_type: String = "") -> Dictionary:
	return {
		"id": id,
		"short_text": tr(short_key),
		"text": tr(text_key),
		"special_type": special_type,
	}

## Returns Array of combat intent dicts for UI, max 2.
## Each: { "id": String, "short_text": String, "text": String, "special_type": String }
## Pure — no mutation of unit meta/state, no show_status_text, never calls get_actions().
## Default = Fighter-like melee approach truth (ATTACK then MOVE when they can hit this turn).
## Subclasses MAY override later for Archer/Monk specials; keep overrides pure.
func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or not is_instance_valid(player) or battle_grid == null:
		return []

	# 1) Already in range → single ATTACK
	if can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]

	# 2) Can MOVE into range then ATTACK this turn → threat-first (ATTACK is primary)
	if can_move_then_attack_this_turn(unit, player, battle_grid):
		return [
			_make_combat_intent("attack", "ATTACK", "Next Move: Attack"),
			_make_combat_intent("move", "MOVE", "Next Move: Move"),
		]

	# 3) Approach only — path toward an adjacent cell exists
	var approach_path := find_path_to_adjacent(unit, player, battle_grid)
	if not approach_path.is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]

	# 4) No combat plan to telegraph
	return []

# Najde pozici pro útok z bezpečné vzdálenosti (pro ranged)
func find_safe_attack_position(unit: Unit, target: Unit, battle_grid: BattleGrid, min_safe_distance: int = 2) -> Vector2i:
	var reachable = get_reachable_cells(unit, battle_grid)
	var best_cell = Vector2i(-1, -1)
	var best_score = -INF
	
	for cell in reachable:
		if can_attack_from_position(cell, unit, target, battle_grid):
			var dist_to_target = battle_grid.get_distance(cell, target.grid_position)
			var score = dist_to_target  # Preferujeme větší vzdálenost
			if dist_to_target < min_safe_distance:
				score -= 100  # Penalizace za příliš blízko
			if score > best_score:
				best_score = score
				best_cell = cell
	
	return best_cell

# === PATHFINDING FUNKCE ===

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

func find_path_with_movement_limit(from_unit: Unit, to_cell: Vector2i, battle_grid: BattleGrid, max_movement: int) -> Array[Vector2i]:
	var astar_grid = AStar2D.new()
	update_astar_grid(astar_grid, from_unit, battle_grid)
	
	var start_id = get_point_id(from_unit.grid_position, battle_grid)
	var end_id = get_point_id(to_cell, battle_grid)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return []

	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	var steps_taken = 0
	for i in range(path_vectors.size()):
		result_path.append(Vector2i(path_vectors[i]))
		if i > 0:
			steps_taken += 1
			if steps_taken >= max_movement:
				break
	
	return result_path

func find_path_to_adjacent(from_unit: Unit, to_unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
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
	
	var best_path: Array[Vector2i] = []
	var shortest_distance = INF
	
	for target_cell in adjacent_cells:
		var path = find_path(from_unit, target_cell, battle_grid)
		if not path.is_empty() and path.size() < shortest_distance:
			shortest_distance = path.size()
			best_path = path
	
	return best_path

## Krátký ústup od bodu. Cesta obsahuje start. Prázdné pole = není kam.
func find_retreat_path(unit: Unit, from_cell: Vector2i, away_from: Vector2i, battle_grid: BattleGrid, max_steps: int) -> Array[Vector2i]:
	var best := from_cell
	var best_dist := battle_grid.get_distance(from_cell, away_from)
	var came: Dictionary = {}
	var steps_at := {from_cell: 0}
	var queue: Array[Vector2i] = [from_cell]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var steps: int = int(steps_at[current])
		if steps >= max_steps:
			continue
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = current + offset
			if steps_at.has(nxt) or not battle_grid.is_cell_active(nxt):
				continue
			var occ = battle_grid.get_object_on_cell(nxt)
			if is_instance_valid(occ) and occ != unit:
				continue
			var terrain = battle_grid.get_terrain_on_cell(nxt)
			if terrain and not terrain.is_walkable:
				continue
			steps_at[nxt] = steps + 1
			came[nxt] = current
			queue.append(nxt)
			var dist := battle_grid.get_distance(nxt, away_from)
			if dist > best_dist:
				best_dist = dist
				best = nxt
	if best == from_cell:
		return []
	var rev: Array[Vector2i] = [best]
	var cursor: Vector2i = best
	while cursor != from_cell:
		cursor = came[cursor]
		rev.append(cursor)
	rev.reverse()
	return rev

## Jedno volné pole dál od origin. (-999, -999) = není kam.
func find_push_cell(from_cell: Vector2i, away_from: Vector2i, battle_grid: BattleGrid) -> Vector2i:
	var invalid := Vector2i(-999, -999)
	var best := invalid
	var best_dist := battle_grid.get_distance(from_cell, away_from)
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var nxt: Vector2i = from_cell + offset
		if not battle_grid.is_cell_active(nxt):
			continue
		if is_instance_valid(battle_grid.get_object_on_cell(nxt)):
			continue
		var terrain = battle_grid.get_terrain_on_cell(nxt)
		if terrain and not terrain.is_walkable:
			continue
		var dist := battle_grid.get_distance(nxt, away_from)
		if dist > best_dist:
			best_dist = dist
			best = nxt
	return best

# Pathfinding z konkrétní pozice (pro simulaci pohybu)
func find_path_from_position(from_pos: Vector2i, to_cell: Vector2i, moving_unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	var astar_grid = AStar2D.new()
	update_astar_grid(astar_grid, moving_unit, battle_grid)
	var start_id = get_point_id(from_pos, battle_grid)
	var end_id = get_point_id(to_cell, battle_grid)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return []

	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	for p in path_vectors:
		result_path.append(Vector2i(p))
		
	return result_path

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
					# CRITICAL: out-of-bounds neighbors share point IDs with real cells
					# (e.g. (-1,y) → id of (cols-1,y)) and create wrap/teleport edges.
					if not battle_grid.is_valid_grid_position(to_cell):
						continue
					if not battle_grid.is_cell_active(to_cell):
						continue
					var to_id = get_point_id(to_cell, battle_grid)
					if astar_grid.has_point(to_id) and not astar_grid.is_point_disabled(to_id): 
						astar_grid.connect_points(from_id, to_id)

func get_point_id(cell: Vector2i, battle_grid: BattleGrid) -> int:
	return cell.y * battle_grid.grid_columns + cell.x
