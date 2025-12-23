# ===================================================================
# Soubor: res://scripts/ai/HealerAI.gd
# POPIS: Healer/Cleric - holy damage, léčí spojence
# ===================================================================
extends EnemyAIBase

const HEAL_RANGE = 4  # Vzdálenost pro léčení
const HEAL_AMOUNT = 8  # Množství léčení
const HOLY_DAMAGE_MULTIPLIER = 1.5  # Bonus k holy damage (proti undead)
const LOW_HEALTH_THRESHOLD = 0.5  # 50% HP = nízké zdraví

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# 1. LÉČENÍ SPOJENCŮ (priorita - pokud má někdo nízké zdraví)
	var allies_to_heal = find_allies_in_range(enemy_unit, battle_grid, HEAL_RANGE)
	
	for ally in allies_to_heal:
		var health_percent = float(ally.current_health) / float(ally.unit_data.max_health)
		if health_percent < LOW_HEALTH_THRESHOLD:
			var heal_action = create_special_action({
				"type": "heal_ally",
				"target": ally,
				"heal_amount": HEAL_AMOUNT
			})
			enemy_unit.show_status_text("HEAL!", "heal")
			return heal_action
	
	# 2. ÚTOK S HOLY DAMAGE (pokud můžeme)
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var damage_multiplier = 1.0
		# Bonus k holy damage proti undead
		if player_unit.unit_data.unit_id.contains("undead") or player_unit.unit_data.unit_id.contains("skeleton"):
			damage_multiplier = HOLY_DAMAGE_MULTIPLIER
		
		var action = create_attack_action(player_unit, damage_multiplier)
		action.special_data["holy_damage"] = true
		return action
	
	# 3. POHYB - přiblíží se k hráči nebo ke zraněným spojencům
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		return create_move_action(path)
	
	# 4. PASS
	return create_pass_action()

func find_allies_in_range(unit: Unit, battle_grid: BattleGrid, range: int) -> Array[Unit]:
	var allies: Array[Unit] = []
	var all_units = battle_grid.get_all_objects_on_grid()
	
	for u in all_units:
		if u is Unit and u != unit:
			if u.unit_data.faction == unit.unit_data.faction:
				var distance = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if distance <= range:
					allies.append(u)
	
	return allies

