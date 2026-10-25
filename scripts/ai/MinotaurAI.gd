# Minotaur: v přímce do 3 polí začne výpad. Příští tah projede 3 pole. Náraz výpad zastaví.
class_name MinotaurAI
extends "res://scripts/ai/EnemyAIBase.gd"

const RUSH_LEN := 3
const RUSH_DAMAGE := 13

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	if enemy_unit.windup_kind() == "bull_rush":
		return [create_special_action({"type": "resolve_windup"})]
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var dir := _charge_dir(enemy_unit, player_unit, battle_grid)
	if dir != Vector2i.ZERO:
		enemy_unit.set_combat_windup({
			"kind": "bull_rush",
			"dx": dir.x,
			"dy": dir.y,
			"interruptible": false,
			"banner": "ui.banner.bull_rush",
		})
		return [create_special_action({"type": "begin_windup", "banner": "ui.banner.bull_rush"})]
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
	if unit.windup_kind() == "bull_rush":
		return [_make_combat_intent("rush", "13", "enemy.minotaur.intent_go")]
	if not is_instance_valid(player) or battle_grid == null:
		return []
	if _charge_dir(unit, player, battle_grid) != Vector2i.ZERO:
		var prep := _make_combat_intent("rush", "ui.banner.bull_rush", "enemy.minotaur.intent_prep")
		prep["countdown"] = 1
		return [prep]
	if _align_cell(unit, player, battle_grid) != Vector2i(-999, -999) or not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var dir := Vector2i.ZERO
	if unit.windup_kind() == "bull_rush":
		var data := unit.combat_windup()
		dir = Vector2i(int(data.get("dx", 0)), int(data.get("dy", 0)))
	elif is_instance_valid(player):
		dir = _charge_dir(unit, player, battle_grid)
	var out: Array = []
	if dir == Vector2i.ZERO:
		return out
	var cursor := unit.grid_position
	for i in RUSH_LEN:
		cursor += dir
		if not battle_grid.is_cell_active(cursor):
			break
		var threat := {"cell": cursor, "kind": "ember"}
		if i == RUSH_LEN - 1 or _occupied(battle_grid, cursor):
			threat["label"] = str(RUSH_DAMAGE)
		out.append(threat)
		if _occupied(battle_grid, cursor):
			break
	return out

func _charge_dir(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	if unit.grid_position.x != player.grid_position.x and unit.grid_position.y != player.grid_position.y:
		return Vector2i.ZERO
	var dist := battle_grid.get_distance(unit.grid_position, player.grid_position)
	if dist < 1 or dist > RUSH_LEN:
		return Vector2i.ZERO
	if unit.grid_position.x == player.grid_position.x:
		return Vector2i(0, 1 if player.grid_position.y > unit.grid_position.y else -1)
	return Vector2i(1 if player.grid_position.x > unit.grid_position.x else -1, 0)

func _occupied(battle_grid: BattleGrid, cell: Vector2i) -> bool:
	var occ = battle_grid.get_object_on_cell(cell)
	return occ is Unit and occ.current_health > 0

func _align_cell(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	var best := Vector2i(-999, -999)
	var best_score := 999999
	for cell in get_reachable_cells(unit, battle_grid):
		if cell.x != player.grid_position.x and cell.y != player.grid_position.y:
			continue
		var dist := battle_grid.get_distance(cell, player.grid_position)
		if dist < 1 or dist > RUSH_LEN:
			continue
		var score := absi(dist - 2)
		if score < best_score:
			best_score = score
			best = cell
	return best
