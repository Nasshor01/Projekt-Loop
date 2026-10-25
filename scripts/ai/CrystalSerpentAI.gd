# Křišťálový had: Fighter. Střepy klade BattleScene na projetá pole. Kousnutí na střepu je +25 %.
class_name CrystalSerpentAI
extends "res://scripts/ai/FighterAI.gd"

const BITE_EXTRA := 1

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions := super.get_actions(enemy_unit, all_player_units, battle_grid)
	for action in actions:
		if action.type != AIAction.ActionType.ATTACK or not is_instance_valid(action.target_unit):
			continue
		if battle_grid.has_method("has_shard") and battle_grid.has_shard(action.target_unit.grid_position):
			action.special_data["crystal_bite"] = true
			action.special_data["flat_extra"] = BITE_EXTRA
	return actions

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var intents: Array = super.preview_combat_intents(unit, player, battle_grid)
	if intents.is_empty() or not is_instance_valid(player) or battle_grid == null:
		return intents
	if not battle_grid.has_method("has_shard") or not battle_grid.has_shard(player.grid_position):
		return intents
	if str(intents[0].get("id", "")) == "attack":
		intents[0]["id"] = "bite"
		intents[0]["text"] = tr("enemy.serpent.intent_bite")
	return intents

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	var out: Array = []
	if not is_instance_valid(player):
		return out
	if not can_move_then_attack_this_turn(unit, player, battle_grid):
		return out
	var extra := BITE_EXTRA if battle_grid.has_method("has_shard") and battle_grid.has_shard(player.grid_position) else 0
	var shown := unit.get_telegraphed_attack_damage(extra)
	out.append({"cell": player.grid_position, "kind": "damage", "label": str(shown)})
	return out
