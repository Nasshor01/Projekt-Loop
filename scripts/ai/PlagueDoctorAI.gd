# Plague Doctor marks on hit, and once every 3 turns cleanses an ally and gives block.
class_name PlagueDoctorAI
extends EnemyAIBase

const INOC_BLOCK := 6

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions := _choose(enemy_unit, all_player_units, battle_grid)
	if not actions.is_empty() and actions[0].type == AIAction.ActionType.SPECIAL and str(actions[0].special_data.get("type", "")) == "inoculate":
		enemy_unit.set_meta("inoculation_cd", 2)
	elif _cd(enemy_unit) > 0:
		enemy_unit.set_meta("inoculation_cd", _cd(enemy_unit) - 1)
	return actions

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if _cd(unit) <= 0 and _ally(unit, battle_grid) != null:
		return [_make_combat_intent("heal", str(INOC_BLOCK), "enemy.plague.intent_inoc")]
	if not is_instance_valid(player) or battle_grid == null:
		return []
	if can_attack_target(unit, player, battle_grid) or can_move_then_attack_this_turn(unit, player, battle_grid):
		var intents: Array = [_make_combat_intent("attack", "ATTACK", "enemy.plague.intent_mark")]
		if not can_attack_target(unit, player, battle_grid):
			intents.append(_make_combat_intent("move", "MOVE", "Next Move: Move"))
		return intents
	if not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if _cd(unit) <= 0 and _ally(unit, battle_grid) != null:
		return []
	if not is_instance_valid(player):
		return []
	if can_attack_target(unit, player, battle_grid) or can_move_then_attack_this_turn(unit, player, battle_grid):
		return [{"cell": player.grid_position, "kind": "damage"}]
	return []

func _choose(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if _cd(enemy_unit) <= 0:
		var ally := _ally(enemy_unit, battle_grid)
		if ally != null:
			var action := create_special_action({"type": "inoculate", "block": INOC_BLOCK})
			action.target_unit = ally
			return [action]
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		return [_mark(player_unit)]
	var attack_pos := find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path := find_path(enemy_unit, attack_pos, battle_grid)
		if path.size() > 1:
			return [create_move_action(path), _mark(player_unit)]
	var approach := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if approach.size() > 1:
		return [create_move_action(approach)]
	return [create_pass_action()]

func _mark(target: Unit) -> AIAction:
	var action := create_special_action({"type": "plague_mark"})
	action.target_unit = target
	return action

func _cd(unit: Unit) -> int:
	return int(unit.get_meta("inoculation_cd")) if unit.has_meta("inoculation_cd") else 0

func _ally(unit: Unit, battle_grid: BattleGrid) -> Unit:
	if battle_grid == null or unit.unit_data == null:
		return null
	var best: Unit = null
	var best_score := -1
	for obj in battle_grid.get_all_objects_on_grid():
		if not (obj is Unit) or obj == unit or obj.current_health <= 0 or obj.unit_data == null:
			continue
		if obj.unit_data.faction != unit.unit_data.faction:
			continue
		if battle_grid.get_distance(unit.grid_position, obj.grid_position) > unit.unit_data.attack_range:
			continue
		var score := 1
		if obj.active_statuses.has("plague") or obj.active_statuses.has("poison") or obj.active_statuses.has("burning"):
			score += 5
		if obj.current_health < obj.unit_data.max_health:
			score += 2
		if score > best_score:
			best_score = score
			best = obj
	return best
