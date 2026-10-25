# Trpasličí stráž: útočí jen v kontaktu. Jinak stojí u nejzranitelnějšího spojence.
# Štítová hradba je blok na začátku tahu, ne akce.
class_name DwarfGuardianAI
extends "res://scripts/ai/FighterAI.gd"

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions := _choose_actions(enemy_unit, all_player_units, battle_grid)
	_tick_interpose(enemy_unit)
	return actions

func _choose_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if is_instance_valid(player_unit) and can_attack_target(enemy_unit, player_unit, battle_grid):
		return [create_attack_action(player_unit)]
	var ally := _vulnerable_ally(enemy_unit, battle_grid)
	if ally != null and battle_grid.get_distance(enemy_unit.grid_position, ally.grid_position) > 1:
		var path := find_path_to_adjacent(enemy_unit, ally, battle_grid)
		if not path.is_empty():
			return [create_move_action(path)]
	if ally == null:
		return super.get_actions(enemy_unit, all_player_units, battle_grid)
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or battle_grid == null:
		return []
	if is_instance_valid(player) and can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
	var ally := _vulnerable_ally(unit, battle_grid)
	if ally != null and battle_grid.get_distance(unit.grid_position, ally.grid_position) > 1:
		if not find_path_to_adjacent(unit, ally, battle_grid).is_empty():
			return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
		return []
	if ally == null:
		return super.preview_combat_intents(unit, player, battle_grid)
	return []

func _vulnerable_ally(unit: Unit, battle_grid: BattleGrid) -> Unit:
	var best: Unit = null
	var best_pct := 2.0
	for ally in get_all_enemies(unit, battle_grid):
		if ally.current_health <= 0 or ally.unit_data == null or ally.unit_data.max_health <= 0:
			continue
		var pct := float(ally.current_health) / float(ally.unit_data.max_health)
		if pct < best_pct:
			best_pct = pct
			best = ally
	return best

func _tick_interpose(unit: Unit) -> void:
	var cd := int(unit.get_meta("interpose_cd")) if unit.has_meta("interpose_cd") else 0
	if cd > 0:
		unit.set_meta("interpose_cd", cd - 1)
