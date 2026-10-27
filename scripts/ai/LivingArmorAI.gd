# Living Armor fights like a Fighter. The core passes, then the armor returns.
class_name LivingArmorAI
extends "res://scripts/ai/FighterAI.gd"

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	if enemy_unit.has_meta("armor_core"):
		return [create_special_action({"type": "armor_restore"})]
	return super.get_actions(enemy_unit, all_player_units, battle_grid)

func preview_combat_intents(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if unit.has_meta("armor_core"):
		return [_make_combat_intent("heal", "ui.banner.restore", "enemy.armor.intent_restore")]
	return super.preview_combat_intents(unit, player, battle_grid)

func preview_threats(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array:
	if unit.has_meta("armor_core"):
		return [{"cell": unit.grid_position, "kind": "ember", "label": tr("ui.banner.core")}]
	if is_instance_valid(player) and can_attack_target(unit, player, battle_grid):
		return [{"cell": player.grid_position, "kind": "damage"}]
	if is_instance_valid(player) and can_move_then_attack_this_turn(unit, player, battle_grid):
		return [{"cell": player.grid_position, "kind": "damage"}]
	return []
