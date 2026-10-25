# Ledový elementál: útok jen když už je v dosahu, jinak jen krok.
# Frostbite a Deep Freeze řeší BattleScene podle special_data na útoku.
class_name FrostElementalAI
extends "res://scripts/ai/FighterAI.gd"

const FROSTBITE_SLOW := -2
const FROSTBITE_TURNS := 2
const DEEP_FREEZE_BONUS := 3

static func bonus_if_slowed(target: Unit) -> int:
	if is_instance_valid(target) and target.active_statuses.has("Slow"):
		return DEEP_FREEZE_BONUS
	return 0

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]

	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var action := create_attack_action(player_unit)
		action.special_data = {
			"frostbite": true,
			"slow_value": FROSTBITE_SLOW,
			"slow_duration": FROSTBITE_TURNS,
			"deep_freeze_bonus": DEEP_FREEZE_BONUS,
		}
		return [action]

	var move_path: Array = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not move_path.is_empty():
		return [create_move_action(move_path)]

	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or not is_instance_valid(player) or battle_grid == null:
		return []
	if can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
	var approach_path := find_path_to_adjacent(unit, player, battle_grid)
	if not approach_path.is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []
