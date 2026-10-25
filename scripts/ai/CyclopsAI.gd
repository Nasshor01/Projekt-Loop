# Kyklop: v kontaktu označí pole. Příští tah 22 na něm a 11 na sousedy. Pak jeden obyčejný tah.
class_name CyclopsAI
extends "res://scripts/ai/EnemyAIBase.gd"

const BLOW := 22
const SPLASH := 11

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	if enemy_unit.windup_kind() == "crush":
		return [create_special_action({"type": "resolve_windup"})]
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if enemy_unit.has_meta("crush_rest") and bool(enemy_unit.get_meta("crush_rest")):
		enemy_unit.set_meta("crush_rest", false)
		return _plain(enemy_unit, player_unit, battle_grid)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		enemy_unit.set_combat_windup({
			"kind": "crush",
			"cx": player_unit.grid_position.x,
			"cy": player_unit.grid_position.y,
			"interruptible": false,
			"banner": "ui.banner.crush",
		})
		return [create_special_action({"type": "begin_windup", "banner": "ui.banner.crush"})]
	var step := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not step.is_empty():
		return [create_move_action(step)]
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if unit.windup_kind() == "crush":
		return [_make_combat_intent("windup", "22", "enemy.cyclops.intent_go")]
	if unit.has_meta("crush_rest") and bool(unit.get_meta("crush_rest")):
		return _plain_preview(unit, player, battle_grid)
	if is_instance_valid(player) and can_attack_target(unit, player, battle_grid):
		var prep := _make_combat_intent("windup", "ui.banner.crush", "enemy.cyclops.intent_prep")
		prep["countdown"] = 1
		return [prep]
	if is_instance_valid(player) and not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var cell := Vector2i(-999, -999)
	if unit.windup_kind() == "crush":
		var data := unit.combat_windup()
		cell = Vector2i(int(data.get("cx", -999)), int(data.get("cy", -999)))
	elif is_instance_valid(player) and can_attack_target(unit, player, battle_grid) and not (unit.has_meta("crush_rest") and bool(unit.get_meta("crush_rest"))):
		cell = player.grid_position
	else:
		return []
	if not battle_grid.is_cell_active(cell):
		return []
	var out: Array = [{"cell": cell, "kind": "ember", "label": str(BLOW)}]
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next: Vector2i = cell + offset
		if next == unit.grid_position:
			continue
		if battle_grid.is_cell_active(next):
			out.append({"cell": next, "kind": "ember", "label": str(SPLASH)})
	return out

func _plain(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array[AIAction]:
	if is_instance_valid(player) and can_attack_target(unit, player, battle_grid):
		return [create_attack_action(player)]
	if is_instance_valid(player):
		var path := find_path_to_adjacent(unit, player, battle_grid)
		if not path.is_empty():
			return [create_move_action(path)]
	return [create_pass_action()]

func _plain_preview(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if is_instance_valid(player) and can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
	if is_instance_valid(player) and not find_path_to_adjacent(unit, player, battle_grid).is_empty():
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []
