# Bouřný elementál: drží odstup 3–5, každý druhý tah je nabitý (9). Přeskok řeší BattleScene.
class_name StormElementalAI
extends "res://scripts/ai/EnemyAIBase.gd"

const CHAIN_RANGE := 2

static func is_charged(unit: Unit) -> bool:
	return is_instance_valid(unit) and unit.has_meta("storm_charged") and bool(unit.get_meta("storm_charged"))

static func shot_damage(unit: Unit) -> int:
	return 9 if is_charged(unit) else 6

static func chain_damage(unit: Unit) -> int:
	return int(round(float(shot_damage(unit)) * 0.6))

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	var actions := _plan(enemy_unit, player_unit, battle_grid)
	enemy_unit.set_meta("storm_charged", not is_charged(enemy_unit))
	return actions

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if not is_instance_valid(unit) or not is_instance_valid(player) or battle_grid == null:
		return []
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if dist <= 1:
		if find_retreat_path(unit, unit.grid_position, player.grid_position, battle_grid, unit.get_current_movement_range()).size() > 1:
			return [_make_combat_intent("move", "MOVE", "enemy.storm.intent_kite")]
		return []
	if dist <= unit.unit_data.attack_range:
		var intents: Array = [_make_combat_intent("attack", "ATTACK", "enemy.storm.intent_shot")]
		if _chain_unit(unit, player, battle_grid) != null and intents.size() < 2:
			intents.append(_make_combat_intent("pierce", str(chain_damage(unit)), "enemy.storm.intent_chain"))
		return intents
	if _kite_cell(unit, player, battle_grid) != Vector2i(-999, -999) or not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var out: Array = []
	if not is_instance_valid(player):
		return out
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if dist <= 1 or dist > unit.unit_data.attack_range:
		return out
	out.append({"cell": player.grid_position, "kind": "damage", "label": str(shot_damage(unit))})
	var other := _chain_unit(unit, player, battle_grid)
	if other != null:
		out.append({"cell": other.grid_position, "kind": "damage", "label": str(chain_damage(unit))})
	return out

func _plan(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array[AIAction]:
	if not is_instance_valid(player):
		return [create_pass_action()]
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if dist <= 1:
		var retreat := find_retreat_path(unit, unit.grid_position, player.grid_position, battle_grid, unit.get_current_movement_range())
		if retreat.size() > 1:
			return [create_move_action(retreat)]
		return [create_pass_action()]
	if dist <= unit.unit_data.attack_range:
		var shot := create_attack_action(player)
		shot.special_data["flat_extra"] = shot_damage(unit) - unit.unit_data.attack_damage
		shot.special_data["chain_lightning"] = true
		shot.special_data["chain_damage"] = chain_damage(unit)
		return [shot]
	var kite := _kite_cell(unit, player, battle_grid)
	if kite != Vector2i(-999, -999):
		var path := find_path(unit, kite, battle_grid)
		if not path.is_empty():
			return [create_move_action(path)]
	var approach := find_path_to_adjacent(unit, player, battle_grid)
	if not approach.is_empty():
		return [create_move_action(approach)]
	return [create_pass_action()]

func _kite_cell(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	var best := Vector2i(-999, -999)
	var best_score := 999999
	for cell in get_reachable_cells(unit, battle_grid):
		var dist := battle_grid.get_distance(cell, player.grid_position)
		if dist < 3 or dist > 5:
			continue
		var score := absi(dist - 4)
		if score < best_score:
			best_score = score
			best = cell
	return best

func _chain_unit(attacker: Unit, primary: Unit, battle_grid: BattleGrid) -> Unit:
	var best: Unit = null
	var best_dist := 99
	for node in battle_grid.get_all_objects_on_grid():
		if not (node is Unit) or node == attacker or node == primary or node.current_health <= 0:
			continue
		if node.unit_data == null or node.unit_data.faction == attacker.unit_data.faction:
			continue
		var dist := battle_grid.get_distance(primary.grid_position, node.grid_position)
		if dist >= 1 and dist <= CHAIN_RANGE and dist < best_dist:
			best_dist = dist
			best = node
	return best
