# Harpyje: střemhlav 120 % a ústup až o 2. Když ústup není, odstrčí cíl o 1.
class_name HarpyAI
extends "res://scripts/ai/EnemyAIBase.gd"

const DIVE_EXTRA := 1
const RETREAT_STEPS := 2

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var landing := _landing_cell(enemy_unit, player_unit, battle_grid)
	if landing == Vector2i(-999, -999):
		var approach := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
		if approach.is_empty():
			return [create_pass_action()]
		return [create_move_action(approach)]
	var actions: Array[AIAction] = []
	if landing == enemy_unit.grid_position:
		var hit := create_attack_action(player_unit, 1.2)
		hit.special_data["flat_extra"] = DIVE_EXTRA
		actions.append(hit)
	else:
		var path := find_path(enemy_unit, landing, battle_grid)
		var rush := create_rush_action(player_unit, path, 1.2)
		rush.special_data["flat_extra"] = DIVE_EXTRA
		actions.append(rush)
	var retreat := find_retreat_path(enemy_unit, landing, player_unit.grid_position, battle_grid, RETREAT_STEPS)
	if retreat.size() > 1:
		actions.append(create_special_action({"type": "disengage", "move_path": retreat}))
	else:
		var gust := find_push_cell(player_unit.grid_position, landing, battle_grid)
		if gust.x > -900:
			var push := create_special_action({"type": "wing_gust", "dest": gust})
			push.target_unit = player_unit
			actions.append(push)
	return actions

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or not is_instance_valid(player) or battle_grid == null:
		return []
	var landing := _landing_cell(unit, player, battle_grid)
	if landing == Vector2i(-999, -999):
		if find_path_to_adjacent(unit, player, battle_grid).is_empty():
			return []
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	var intents: Array = [_make_combat_intent("rush", "RUSH", "enemy.harpy.intent_dive")]
	var retreat := find_retreat_path(unit, landing, player.grid_position, battle_grid, RETREAT_STEPS)
	if retreat.size() > 1:
		intents.append(_make_combat_intent("move", "MOVE", "enemy.harpy.intent_retreat"))
	elif find_push_cell(player.grid_position, landing, battle_grid).x > -900:
		intents.append(_make_combat_intent("gust", "enemy.harpy.gust_short", "enemy.harpy.intent_gust"))
	return intents

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var out: Array = []
	if not is_instance_valid(player):
		return out
	var landing := _landing_cell(unit, player, battle_grid)
	if landing == Vector2i(-999, -999):
		return out
	var shown := unit.get_telegraphed_attack_damage(DIVE_EXTRA)
	out.append({"cell": player.grid_position, "kind": "damage", "label": str(shown)})
	var retreat := find_retreat_path(unit, landing, player.grid_position, battle_grid, RETREAT_STEPS)
	if retreat.size() > 1:
		out.append({"cell": retreat[retreat.size() - 1], "kind": "control"})
	else:
		var gust := find_push_cell(player.grid_position, landing, battle_grid)
		if gust.x > -900:
			out.append({"cell": gust, "kind": "control"})
	return out

func _landing_cell(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	if can_attack_target(unit, player, battle_grid):
		return unit.grid_position
	var attack_pos := find_attack_move_position(unit, player, battle_grid)
	if attack_pos == Vector2i(-1, -1):
		return Vector2i(-999, -999)
	if find_path(unit, attack_pos, battle_grid).is_empty():
		return Vector2i(-999, -999)
	return attack_pos
