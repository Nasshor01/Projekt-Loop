# Kopinice: v řadě probodne (7 / 4). V kontaktu jen 4 a ústup o 1. Mimo řadu se nejdřív srovná.
class_name LancerAI
extends "res://scripts/ai/EnemyAIBase.gd"

const CLOSE_DAMAGE := 4
const PIERCE_DAMAGE := 4
const RETREAT_STEPS := 1

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var target := _line_target(enemy_unit, player_unit, battle_grid)
	var mode := _mode(enemy_unit, player_unit, battle_grid)
	if mode == "close":
		var poke_target: Unit = target if target != null else player_unit
		var poke := create_attack_action(poke_target)
		poke.special_data["flat_extra"] = CLOSE_DAMAGE - enemy_unit.unit_data.attack_damage
		var actions: Array[AIAction] = [poke]
		var retreat := find_retreat_path(enemy_unit, enemy_unit.grid_position, poke_target.grid_position, battle_grid, RETREAT_STEPS)
		if retreat.size() > 1:
			actions.append(create_special_action({"type": "disengage", "move_path": retreat}))
		return actions
	if mode == "pierce" and target != null:
		var thrust := create_attack_action(target)
		thrust.special_data["piercing_thrust"] = true
		thrust.special_data["pierce_extra"] = PIERCE_DAMAGE - enemy_unit.unit_data.attack_damage
		return [thrust]
	var align := _align_cell(enemy_unit, player_unit, battle_grid)
	if align != Vector2i(-999, -999):
		var path := find_path(enemy_unit, align, battle_grid)
		if not path.is_empty():
			return [create_move_action(path)]
	var approach := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not approach.is_empty():
		return [create_move_action(approach)]
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or not is_instance_valid(player) or battle_grid == null:
		return []
	var target := _line_target(unit, player, battle_grid)
	var mode := _mode(unit, player, battle_grid)
	if mode == "close":
		var away: Vector2i = target.grid_position if target != null else player.grid_position
		var intents: Array = [_make_combat_intent("attack", "ATTACK", "enemy.lancer.intent_close")]
		var retreat := find_retreat_path(unit, unit.grid_position, away, battle_grid, RETREAT_STEPS)
		if retreat.size() > 1:
			intents.append(_make_combat_intent("move", "MOVE", "enemy.lancer.intent_retreat"))
		else:
			intents.append(_make_combat_intent("move", "MOVE", "enemy.lancer.intent_stuck"))
		return intents
	if mode == "pierce" and target != null:
		var intents: Array = [_make_combat_intent("attack", "ATTACK", "enemy.lancer.intent_pierce")]
		if _unit_on_cell(battle_grid, _cell_behind(unit.grid_position, target.grid_position)) != null:
			intents.append(_make_combat_intent("pierce", "4", "enemy.lancer.intent_behind"))
		return intents
	if _align_cell(unit, player, battle_grid) != Vector2i(-999, -999) or not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var out: Array = []
	if not is_instance_valid(player):
		return out
	var target := _line_target(unit, player, battle_grid)
	var mode := _mode(unit, player, battle_grid)
	if mode == "close":
		var mark: Unit = target if target != null else player
		var light := unit.get_telegraphed_attack_damage(CLOSE_DAMAGE - unit.unit_data.attack_damage)
		out.append({"cell": mark.grid_position, "kind": "damage", "label": str(light)})
		var retreat := find_retreat_path(unit, unit.grid_position, mark.grid_position, battle_grid, RETREAT_STEPS)
		if retreat.size() > 1:
			out.append({"cell": retreat[retreat.size() - 1], "kind": "control"})
		return out
	if mode != "pierce" or target == null:
		return out
	var step := _step_toward(unit.grid_position, target.grid_position)
	if step == Vector2i.ZERO:
		return out
	var full := unit.get_telegraphed_attack_damage()
	var cursor := unit.grid_position
	while cursor != target.grid_position:
		cursor += step
		if not battle_grid.is_cell_active(cursor):
			break
		var threat := {"cell": cursor, "kind": "damage"}
		if cursor == target.grid_position:
			threat["label"] = str(full)
		out.append(threat)
	var behind := target.grid_position + step
	if battle_grid.is_cell_active(behind) and _unit_on_cell(battle_grid, behind) != null:
		var pierce := unit.get_telegraphed_attack_damage(PIERCE_DAMAGE - unit.unit_data.attack_damage)
		out.append({"cell": behind, "kind": "damage", "label": str(pierce)})
	return out

func _mode(unit: Unit, player: Unit, battle_grid: BattleGrid) -> String:
	if battle_grid.get_distance(unit.grid_position, player.grid_position) <= 1:
		return "close"
	var target := _line_target(unit, player, battle_grid)
	if target == null:
		return "align"
	var dist := battle_grid.get_distance(unit.grid_position, target.grid_position)
	if dist <= 1:
		return "close"
	if dist <= unit.unit_data.attack_range:
		return "pierce"
	return "align"

func _line_target(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Unit:
	if not _aligned(unit.grid_position, player.grid_position):
		return null
	var step := _step_toward(unit.grid_position, player.grid_position)
	if step == Vector2i.ZERO:
		return null
	var cursor := unit.grid_position
	for _i in unit.unit_data.attack_range:
		cursor += step
		if not battle_grid.is_cell_active(cursor):
			return null
		var occ := _unit_on_cell(battle_grid, cursor)
		if occ != null:
			return occ
		if cursor == player.grid_position:
			return null
	return null

func _aligned(a: Vector2i, b: Vector2i) -> bool:
	return a.x == b.x or a.y == b.y

func _step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	if from.x == to.x:
		return Vector2i(0, 1 if to.y > from.y else -1)
	if from.y == to.y:
		return Vector2i(1 if to.x > from.x else -1, 0)
	return Vector2i.ZERO

func _cell_behind(from: Vector2i, target: Vector2i) -> Vector2i:
	var step := _step_toward(from, target)
	if step == Vector2i.ZERO:
		return Vector2i(-999, -999)
	return target + step

func _unit_on_cell(battle_grid: BattleGrid, cell: Vector2i) -> Unit:
	var occ = battle_grid.get_object_on_cell(cell)
	if occ is Unit and occ.current_health > 0:
		return occ
	return null

func _align_cell(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	var best := Vector2i(-999, -999)
	var best_score := 999999
	for cell in get_reachable_cells(unit, battle_grid):
		if not _aligned(cell, player.grid_position):
			continue
		var dist := battle_grid.get_distance(cell, player.grid_position)
		var score := absi(dist - 3)
		if dist < 2 or dist > unit.unit_data.attack_range:
			score += 50
		if score < best_score:
			best_score = score
			best = cell
	return best
