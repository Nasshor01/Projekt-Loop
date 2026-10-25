# Banshee: v dosahu začne nářek. Příští tah 8 a slabost, pokud ji mezitím nikdo netrefí do života.
class_name BansheeAI
extends "res://scripts/ai/EnemyAIBase.gd"

const WAIL_DAMAGE := 8

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	if enemy_unit.windup_kind() == "wail":
		return [create_special_action({"type": "resolve_windup"})]
	var actions := _choose(enemy_unit, all_player_units, battle_grid)
	_tick_lock(enemy_unit)
	return actions

func _choose(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	if _lock(enemy_unit) <= 0 and battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position) <= enemy_unit.unit_data.attack_range:
		enemy_unit.set_combat_windup({
			"kind": "wail",
			"interruptible": true,
			"lock_turns": 1,
			"banner": "ui.banner.wail",
		})
		enemy_unit.set_meta("windup_target", player_unit)
		return [create_special_action({"type": "begin_windup", "banner": "ui.banner.wail"})]
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		return [create_attack_action(player_unit)]
	var path := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		return [create_move_action(path)]
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if unit.windup_kind() == "wail":
		return [_make_combat_intent("aiming", "8", "enemy.banshee.intent_go")]
	if not is_instance_valid(player) or battle_grid == null:
		return []
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if _lock(unit) <= 0 and dist <= unit.unit_data.attack_range:
		var prep := _make_combat_intent("aiming", "ui.banner.wail", "enemy.banshee.intent_prep")
		prep["countdown"] = 1
		return [prep]
	if can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
	if not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var target: Unit = player
	if unit.windup_kind() == "wail" and unit.has_meta("windup_target") and unit.get_meta("windup_target") is Unit:
		target = unit.get_meta("windup_target")
	if not is_instance_valid(target) or target.current_health <= 0:
		return []
	var dist := battle_grid.get_distance(unit.grid_position, target.grid_position)
	if unit.windup_kind() != "wail" and (_lock(unit) > 0 or dist > unit.unit_data.attack_range):
		return []
	if unit.windup_kind() != "wail" and dist > unit.unit_data.attack_range:
		return []
	var threat := {"cell": target.grid_position, "kind": "ember"}
	if unit.windup_kind() == "wail":
		threat["label"] = str(WAIL_DAMAGE)
	return [threat]

func _lock(unit: Unit) -> int:
	return int(unit.get_meta("windup_lock")) if unit.has_meta("windup_lock") else 0

func _tick_lock(unit: Unit) -> void:
	var cd := _lock(unit)
	if cd > 0:
		unit.set_meta("windup_lock", cd - 1)
