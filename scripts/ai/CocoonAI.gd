# Cocoon: waits 2 of its own turns, then hatches. The lay-turn does not count.
class_name CocoonAI
extends EnemyAIBase

func get_actions(enemy_unit: Unit, _all_player_units: Array, _battle_grid: BattleGrid) -> Array[AIAction]:
	if enemy_unit.has_meta("just_laid") and bool(enemy_unit.get_meta("just_laid")):
		enemy_unit.set_meta("just_laid", false)
		return [create_pass_action()]
	var left := _turns(enemy_unit)
	if left <= 1:
		return [create_special_action({"type": "hatch_egg"})]
	enemy_unit.set_meta("hatch_turns", left - 1)
	return [create_pass_action()]

func preview_combat_intents(unit: Unit, _player: Unit, _battle_grid: BattleGrid) -> Array:
	var left := _turns(unit)
	if left <= 1:
		return [_make_combat_intent("windup", "ui.banner.hatch", "enemy.cocoon.intent_hatch")]
	var prep := _make_combat_intent("windup", str(left), "enemy.cocoon.intent_wait")
	prep["countdown"] = left
	return [prep]

func preview_threats(unit: Unit, _player: Unit, _battle_grid: BattleGrid) -> Array:
	return [{"cell": unit.grid_position, "kind": "ember", "label": str(_turns(unit))}]

func _turns(unit: Unit) -> int:
	return int(unit.get_meta("hatch_turns")) if unit.has_meta("hatch_turns") else 2
