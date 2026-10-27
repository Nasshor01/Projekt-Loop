# Broodmother: lays up to 2 cocoons on an open neighboring tile, then bites.
class_name BroodmotherAI
extends EnemyAIBase

const MAX_EGGS := 2

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var player_unit := find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	var egg_cell := _egg_cell(enemy_unit, battle_grid)
	if _owned_eggs(enemy_unit, battle_grid) < MAX_EGGS and egg_cell.x > -900:
		return [create_special_action({"type": "lay_egg", "cell": egg_cell})]
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		return [create_attack_action(player_unit)]
	var attack_pos := find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path := find_path(enemy_unit, attack_pos, battle_grid)
		if path.size() > 1:
			return [create_move_action(path), create_attack_action(player_unit)]
	var approach := find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if approach.size() > 1:
		return [create_move_action(approach)]
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if battle_grid == null:
		return []
	var egg_cell := _egg_cell(unit, battle_grid)
	if _owned_eggs(unit, battle_grid) < MAX_EGGS and egg_cell.x > -900:
		return [_make_combat_intent("windup", "ui.banner.egg", "enemy.brood.intent_egg")]
	if not is_instance_valid(player):
		return []
	if can_attack_target(unit, player, battle_grid):
		return [_make_combat_intent("attack", "ATTACK", "Next Move: Attack")]
	if not find_path_to_adjacent(unit, player, battle_grid).is_empty() or find_attack_move_position(unit, player, battle_grid) != Vector2i(-1, -1):
		return [_make_combat_intent("move", "MOVE", "Next Move: Move")]
	return []

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if battle_grid == null:
		return []
	var egg_cell := _egg_cell(unit, battle_grid)
	if _owned_eggs(unit, battle_grid) < MAX_EGGS and egg_cell.x > -900:
		return [{"cell": egg_cell, "kind": "ember", "label": "2"}]
	if is_instance_valid(player) and can_attack_target(unit, player, battle_grid):
		return [{"cell": player.grid_position, "kind": "damage"}]
	return []

func _owned_eggs(owner: Unit, battle_grid: BattleGrid) -> int:
	var count := 0
	var owner_id := owner.get_instance_id()
	for obj in battle_grid.get_all_objects_on_grid():
		if obj is Unit and obj.current_health > 0 and obj.unit_data and obj.unit_data.unit_id == "cocoon":
			if obj.has_meta("owner_id") and int(obj.get_meta("owner_id")) == owner_id:
				count += 1
	return count

func _egg_cell(unit: Unit, battle_grid: BattleGrid) -> Vector2i:
	var invalid := Vector2i(-999, -999)
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = unit.grid_position + offset
		if not battle_grid.is_cell_active(cell) or is_instance_valid(battle_grid.get_object_on_cell(cell)):
			continue
		if battle_grid.has_method("blocks_ethereal") and battle_grid.blocks_ethereal(cell):
			continue
		return cell
	return invalid
