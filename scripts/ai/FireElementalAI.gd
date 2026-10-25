# Ohnivý elementál: Fighter (krok + útok), zásah zapaluje. Výbuch řeší BattleScene při smrti.
class_name FireElementalAI
extends "res://scripts/ai/FighterAI.gd"

const BURN_VALUE := 2

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions := super.get_actions(enemy_unit, all_player_units, battle_grid)
	for action in actions:
		if action.type == AIAction.ActionType.ATTACK:
			action.special_data["burning_touch"] = true
			action.special_data["burn_value"] = BURN_VALUE
	return actions

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var out: Array = []
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = unit.grid_position + offset
		if battle_grid.is_cell_active(cell):
			out.append({"cell": cell, "kind": "ember"})
	if is_instance_valid(player) and can_move_then_attack_this_turn(unit, player, battle_grid):
		out.append({"cell": player.grid_position, "kind": "damage"})
	return out
