# Wraith: walks through units. Terrain and traps stop it. Soul Drain is resolved on the hit.
class_name WraithAI
extends EnemyAIBase

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var plan := _plan(enemy_unit, player_unit, battle_grid)
	var mode := str(plan.get("mode", "pass"))
	if mode == "attack":
		return [create_attack_action(player_unit)]
	if mode == "move_attack" or mode == "move":
		var path: Array[Vector2i] = []
		for cell in plan.get("path", []):
			path.append(cell)
		if path.size() <= 1:
			return [create_pass_action()] if mode == "move" else [create_attack_action(player_unit)]
		if mode == "move_attack":
			return [create_move_action(path), create_attack_action(player_unit)]
		return [create_move_action(path)]
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(player) or battle_grid == null:
		return []
	var plan := _plan(unit, player, battle_grid)
	match str(plan.get("mode", "pass")):
		"attack", "move_attack":
			var intents: Array = [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
			if str(plan.get("mode", "")) == "move_attack":
				intents.append(_make_combat_intent("move", "MOVE", "Next Move: Move"))
			return intents
		"move":
			return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
		_:
			return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(player) or battle_grid == null:
		return []
	var plan := _plan(unit, player, battle_grid)
	var out: Array = []
	var mode := str(plan.get("mode", "pass"))
	if mode == "attack" or mode == "move_attack":
		out.append({"cell": player.grid_position, "kind": "damage"})
	for cell in plan.get("through", []):
		out.append({"cell": cell, "kind": "ghost"})
	return out

func _plan(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Dictionary:
	var empty: Array[Vector2i] = []
	if can_attack_target(unit, player, battle_grid):
		return {"mode": "attack", "path": empty, "through": empty}
	var strike_cell := _best_cell(unit, player, battle_grid, true)
	if strike_cell.x > -900:
		var strike_path := _path_to(unit, strike_cell, battle_grid)
		if strike_path.size() > 1:
			return {"mode": "move_attack", "path": strike_path, "through": _through_units(unit, strike_path, battle_grid)}
	var closer := _best_cell(unit, player, battle_grid, false)
	if closer.x > -900:
		var move_path := _path_to(unit, closer, battle_grid)
		if move_path.size() > 1:
			return {"mode": "move", "path": move_path, "through": _through_units(unit, move_path, battle_grid)}
	return {"mode": "pass", "path": empty, "through": empty}

func _best_cell(unit: Unit, player: Unit, battle_grid: BattleGrid, must_attack: bool) -> Vector2i:
	var invalid := Vector2i(-999, -999)
	var best := invalid
	var best_steps := 999
	var best_dist := 999
	var start := unit.grid_position
	var current_dist := battle_grid.get_distance(start, player.grid_position)
	var move_range := unit.get_current_movement_range()
	var costs := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var cost: int = int(costs[current])
		if cost > 0 and battle_grid.is_ethereal_landable(current, unit):
			var dist := battle_grid.get_distance(current, player.grid_position)
			var can_hit := dist <= unit.unit_data.attack_range
			if must_attack and can_hit:
				if cost < best_steps or (cost == best_steps and dist < best_dist):
					best = current
					best_steps = cost
					best_dist = dist
			elif not must_attack and dist < current_dist:
				if dist < best_dist or (dist == best_dist and cost < best_steps):
					best = current
					best_dist = dist
					best_steps = cost
		if cost >= move_range:
			continue
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = current + offset
			if costs.has(nxt) or battle_grid.blocks_ethereal(nxt):
				continue
			costs[nxt] = cost + 1
			queue.append(nxt)
	return best

func _path_to(unit: Unit, dest: Vector2i, battle_grid: BattleGrid) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var start := unit.grid_position
	if start == dest:
		return [start]
	var move_range := unit.get_current_movement_range()
	var parents := {}
	var costs := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var found := false
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var cost: int = int(costs[current])
		if cost >= move_range:
			continue
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = current + offset
			if costs.has(nxt) or battle_grid.blocks_ethereal(nxt):
				continue
			costs[nxt] = cost + 1
			parents[nxt] = current
			if nxt == dest:
				found = true
				break
			queue.append(nxt)
		if found:
			break
	if not found:
		return empty
	var path: Array[Vector2i] = []
	var walk := dest
	while true:
		path.push_front(walk)
		if walk == start:
			break
		walk = parents[walk]
	return path

func _through_units(unit: Unit, path: Array[Vector2i], battle_grid: BattleGrid) -> Array:
	var cells: Array = []
	for cell in path:
		if cell == unit.grid_position:
			continue
		var occ = battle_grid.get_object_on_cell(cell)
		if occ is Unit and occ != unit and occ.current_health > 0:
			cells.append(cell)
	return cells
