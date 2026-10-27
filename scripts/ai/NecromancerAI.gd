# Necromancer: raises up to 2 weak skeletons, then harvests a corpse in range 2.
class_name NecromancerAI
extends EnemyAIBase

const HARVEST_RANGE := 2
const MAX_SKELETONS := 2

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var spawn_cell := _spawn_cell(enemy_unit, battle_grid)
	if _owned(enemy_unit, battle_grid, "raised_skeleton") < MAX_SKELETONS and spawn_cell.x > -900:
		return [create_special_action({"type": "raise_dead", "cell": spawn_cell})]
	var corpse := _nearest_corpse(enemy_unit, battle_grid)
	var hurt := enemy_unit.current_health < enemy_unit.unit_data.max_health
	if corpse.x > -900 and hurt:
		return [create_special_action({"type": "corpse_harvest", "cell": corpse})]
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		return [create_attack_action(player_unit)]
	var attack_pos := find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path := find_path(enemy_unit, attack_pos, battle_grid)
		if path.size() > 1:
			return [create_move_action(path), create_attack_action(player_unit)]
	if corpse.x > -900:
		return [create_special_action({"type": "corpse_harvest", "cell": corpse})]
	var approach := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if approach.size() > 1:
		return [create_move_action(approach)]
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if battle_grid == null:
		return []
	var spawn_cell := _spawn_cell(unit, battle_grid)
	if _owned(unit, battle_grid, "raised_skeleton") < MAX_SKELETONS and spawn_cell.x > -900:
		return [_make_combat_intent("buff", "ui.banner.raise", "enemy.necro.intent_raise")]
	var corpse := _nearest_corpse(unit, battle_grid)
	var hurt := unit.current_health < unit.unit_data.max_health
	if corpse.x > -900 and hurt:
		return [_make_combat_intent("heal", "8", "enemy.necro.intent_harvest")]
	if not is_instance_valid(player):
		if corpse.x > -900:
			return [_make_combat_intent("heal", "8", "enemy.necro.intent_harvest")]
		return []
	if can_attack_target(unit, player, battle_grid) or find_attack_move_position(unit, player, battle_grid) != Vector2i(-1, -1):
		var intents: Array = [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
		if not can_attack_target(unit, player, battle_grid):
			intents.append(_make_combat_intent("move", "MOVE", "Next Move: Move"))
		return intents
	if corpse.x > -900:
		return [_make_combat_intent("heal", "8", "enemy.necro.intent_harvest")]
	if not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if battle_grid == null:
		return []
	var spawn_cell := _spawn_cell(unit, battle_grid)
	if _owned(unit, battle_grid, "raised_skeleton") < MAX_SKELETONS and spawn_cell.x > -900:
		return [{"cell": spawn_cell, "kind": "ember"}]
	var corpse := _nearest_corpse(unit, battle_grid)
	var hurt := unit.current_health < unit.unit_data.max_health
	if corpse.x > -900 and hurt:
		return [{"cell": corpse, "kind": "ember"}]
	if is_instance_valid(player) and (can_attack_target(unit, player, battle_grid) or find_attack_move_position(unit, player, battle_grid) != Vector2i(-1, -1)):
		return [{"cell": player.grid_position, "kind": "damage"}]
	if corpse.x > -900:
		return [{"cell": corpse, "kind": "ember"}]
	return []

func _owned(owner: Unit, battle_grid: BattleGrid, unit_id: String) -> int:
	var count := 0
	var owner_id := owner.get_instance_id()
	for obj in battle_grid.get_all_objects_on_grid():
		if obj is Unit and obj.current_health > 0 and obj.unit_data and obj.unit_data.unit_id == unit_id:
			if obj.has_meta("owner_id") and int(obj.get_meta("owner_id")) == owner_id:
				count += 1
	return count

func _spawn_cell(unit: Unit, battle_grid: BattleGrid) -> Vector2i:
	var invalid := Vector2i(-999, -999)
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = unit.grid_position + offset
		if _cell_is_open(cell, battle_grid):
			return cell
	return invalid

func _cell_is_open(cell: Vector2i, battle_grid: BattleGrid) -> bool:
	if not battle_grid.is_cell_active(cell) or is_instance_valid(battle_grid.get_object_on_cell(cell)):
		return false
	if battle_grid.has_method("blocks_ethereal") and battle_grid.blocks_ethereal(cell):
		return false
	return true

func _nearest_corpse(unit: Unit, battle_grid: BattleGrid) -> Vector2i:
	var invalid := Vector2i(-999, -999)
	if not battle_grid.has_method("corpse_cells"):
		return invalid
	var best := invalid
	var best_dist := 99
	for cell in battle_grid.corpse_cells():
		if not (cell is Vector2i):
			continue
		var dist := battle_grid.get_distance(unit.grid_position, cell)
		if dist <= HARVEST_RANGE and dist < best_dist:
			best = cell
			best_dist = dist
	return best
