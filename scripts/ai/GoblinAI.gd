# ===================================================================
# Goblin — pack tactics: +1 attack per other living goblin ally.
# ===================================================================
class_name GoblinAI
extends "res://scripts/ai/FighterAI.gd"

static func refresh_pack_bonus(unit: Unit, battle_grid: BattleGrid) -> void:
	if not is_instance_valid(unit) or unit.unit_data == null or battle_grid == null:
		return
	var uid := String(unit.unit_data.unit_id)
	if uid != "goblin" and not uid.begins_with("goblin"):
		unit.pack_attack_bonus = 0
		return
	var allies := 0
	for obj in battle_grid.get_all_objects_on_grid():
		if obj is Unit and obj != unit and is_instance_valid(obj) and obj.current_health > 0:
			if obj.unit_data.faction != unit.unit_data.faction:
				continue
			var ally_id := String(obj.unit_data.unit_id)
			if ally_id == "goblin" or ally_id.begins_with("goblin"):
				allies += 1
	unit.pack_attack_bonus = allies
