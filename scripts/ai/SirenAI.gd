# Siréna: píseň je příprava (3 poškození a ticho). Další tah přitáhne o 1, pokud cíl není v kontaktu.
class_name SirenAI
extends "res://scripts/ai/EnemyAIBase.gd"

const SONG_DAMAGE := 3

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	if enemy_unit.windup_kind() == "song":
		return [create_special_action({"type": "resolve_windup"})]
	var actions := _choose(enemy_unit, all_player_units, battle_grid)
	_tick_lock(enemy_unit)
	return actions

func _choose(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var dist := battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	if dist > enemy_unit.unit_data.attack_range:
		var path := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
		if not path.is_empty():
			return [create_move_action(path)]
		return [create_pass_action()]
	if _lock(enemy_unit) <= 0 and _step(enemy_unit) == "song":
		enemy_unit.set_combat_windup({
			"kind": "song",
			"interruptible": true,
			"lock_turns": 1,
			"banner": "ui.banner.song",
		})
		enemy_unit.set_meta("windup_target", player_unit)
		enemy_unit.set_meta("siren_step", "pull")
		return [create_special_action({"type": "begin_windup", "banner": "ui.banner.song"})]
	if _step(enemy_unit) == "pull" and dist > 1:
		var pull := _pull_cell(player_unit.grid_position, enemy_unit.grid_position, battle_grid)
		if pull.x > -900:
			var action := create_special_action({"type": "temptation", "dest": pull})
			action.target_unit = player_unit
			enemy_unit.set_meta("siren_step", "song")
			return [action]
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		enemy_unit.set_meta("siren_step", "song")
		return [create_attack_action(player_unit)]
	enemy_unit.set_meta("siren_step", "song")
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if unit.windup_kind() == "song":
		return [_make_combat_intent("aiming", "3", "enemy.siren.intent_song")]
	if not is_instance_valid(player) or battle_grid == null:
		return []
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if dist > unit.unit_data.attack_range:
		if not find_path_to_adjacent(unit, player, battle_grid).is_empty():
			return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
		return []
	if _lock(unit) <= 0 and _step(unit) == "song":
		var prep := _make_combat_intent("aiming", "ui.banner.song", "enemy.siren.intent_prep")
		prep["countdown"] = 1
		return [prep]
	if _step(unit) == "pull" and dist > 1 and _pull_cell(player.grid_position, unit.grid_position, battle_grid).x > -900:
		return [_make_combat_intent("gust", "1", "enemy.siren.intent_pull")]
	if can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var target: Unit = player
	if unit.windup_kind() == "song" and unit.has_meta("windup_target") and unit.get_meta("windup_target") is Unit:
		target = unit.get_meta("windup_target")
	if not is_instance_valid(target):
		return []
	if unit.windup_kind() == "song":
		return [{"cell": target.grid_position, "kind": "damage", "label": str(SONG_DAMAGE)}]
	if not is_instance_valid(player):
		return []
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if _step(unit) == "pull":
		var pull := _pull_cell(player.grid_position, unit.grid_position, battle_grid)
		if pull.x > -900:
			return [{"cell": pull, "kind": "control"}]
		return []
	if dist > unit.unit_data.attack_range or _lock(unit) > 0 or _step(unit) != "song":
		return []
	return [{"cell": player.grid_position, "kind": "damage"}]

func _step(unit: Unit) -> String:
	if unit.has_meta("siren_step"):
		return str(unit.get_meta("siren_step"))
	return "song"

func _lock(unit: Unit) -> int:
	return int(unit.get_meta("windup_lock")) if unit.has_meta("windup_lock") else 0

func _tick_lock(unit: Unit) -> void:
	var cd := _lock(unit)
	if cd > 0:
		unit.set_meta("windup_lock", cd - 1)

func _pull_cell(from_cell: Vector2i, toward: Vector2i, battle_grid: BattleGrid) -> Vector2i:
	var invalid := Vector2i(-999, -999)
	var best := invalid
	var best_dist := battle_grid.get_distance(from_cell, toward)
	if best_dist <= 1:
		return invalid
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var nxt: Vector2i = from_cell + offset
		if not battle_grid.is_cell_active(nxt):
			continue
		if is_instance_valid(battle_grid.get_object_on_cell(nxt)):
			continue
		var terrain = battle_grid.get_terrain_on_cell(nxt)
		if terrain and not terrain.is_walkable:
			continue
		var dist := battle_grid.get_distance(nxt, toward)
		if dist < best_dist:
			best_dist = dist
			best = nxt
	return best
