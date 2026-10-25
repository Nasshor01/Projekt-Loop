# Kamenný golem: v dosahu Slam (cooldown 3), jinak útok. Mimo dosah jen krok.
# Kamenný postoj čte BattleScene/Unit ze značky earth_moved_last — tenhle skript ji jen zapisuje.
class_name EarthGolemAI
extends "res://scripts/ai/EnemyAIBase.gd"

const SLAM_DAMAGE := 5
const SLAM_COOLDOWN := 3

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	var decision := _decide(enemy_unit, player_unit, battle_grid)
	var actions: Array[AIAction] = []
	var moved := false
	match decision:
		"slam":
			var slam := create_special_action({
				"type": "seismic_slam",
				"damage": SLAM_DAMAGE,
			})
			actions.append(slam)
			enemy_unit.set_meta("slam_cooldown", SLAM_COOLDOWN)
		"attack":
			actions.append(create_attack_action(player_unit))
			_tick_cooldown(enemy_unit)
		"move":
			var path := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
			actions.append(create_move_action(path))
			moved = true
			_tick_cooldown(enemy_unit)
		_:
			actions.append(create_pass_action())
			_tick_cooldown(enemy_unit)
	enemy_unit.set_meta("earth_moved_last", moved)
	return actions

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or not is_instance_valid(player) or battle_grid == null:
		return []
	var decision := _decide(unit, player, battle_grid)
	var intents: Array = []
	match decision:
		"slam":
			intents.append(_make_combat_intent("slam", "5", "enemy.earth.intent_slam"))
		"attack":
			var attack := _make_combat_intent("attack", "ATTACK", "Next Move: Attack")
			var cd := _cooldown(unit)
			if cd > 0:
				attack["countdown"] = cd
			intents.append(attack)
		"move":
			intents.append(_make_combat_intent("move", "MOVE", "Next Move: Move"))
		_:
			return []
	if decision != "move" and not _moved_last(unit) and intents.size() < 2:
		intents.append(_make_combat_intent("block", "+6", "enemy.earth.intent_stance"))
	return intents

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var decision := _decide(unit, player, battle_grid)
	var out: Array = []
	if decision == "slam":
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var cell: Vector2i = unit.grid_position + offset
			if battle_grid.is_cell_active(cell):
				out.append({"cell": cell, "kind": "damage", "label": str(SLAM_DAMAGE)})
	elif decision == "attack" and is_instance_valid(player):
		out.append({"cell": player.grid_position, "kind": "damage"})
	return out

func _decide(unit: Unit, player: Unit, battle_grid: BattleGrid) -> String:
	if not is_instance_valid(player) or battle_grid == null:
		return "pass"
	if can_attack_target(unit, player, battle_grid):
		if _cooldown(unit) <= 0:
			return "slam"
		return "attack"
	if not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return "move"
	return "pass"

func _cooldown(unit: Unit) -> int:
	if unit.has_meta("slam_cooldown"):
		return int(unit.get_meta("slam_cooldown"))
	return 0

func _moved_last(unit: Unit) -> bool:
	return unit.has_meta("earth_moved_last") and bool(unit.get_meta("earth_moved_last"))

func _tick_cooldown(unit: Unit) -> void:
	var cd := _cooldown(unit)
	if cd > 0:
		unit.set_meta("slam_cooldown", cd - 1)
