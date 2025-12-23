# ===================================================================
# Soubor: res://scripts/ai/MonkAI.gd
# POPIS: Monk - nedává poškození, ale buffuje spojence
# ===================================================================
extends EnemyAIBase

const BUFF_RANGE = 3  # Vzdálenost pro buffování
const BUFF_DAMAGE_BONUS = 2  # Bonus k poškození
const BUFF_DURATION = 3  # Trvání buffu

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# 1. BUFFOVÁNÍ SPOJENCŮ (priorita)
	var allies_to_buff = find_allies_in_range(enemy_unit, battle_grid, BUFF_RANGE)
	
	if not allies_to_buff.is_empty():
		# Vybereme nejbližšího spojence, který ještě nemá buff
		var target_ally = null
		for ally in allies_to_buff:
			if not ally.active_statuses.has("monk_blessing"):
				target_ally = ally
				break
		
		if target_ally:
			var buff_action = create_special_action({
				"type": "buff_ally",
				"target": target_ally,
				"damage_bonus": BUFF_DAMAGE_BONUS,
				"duration": BUFF_DURATION
			})
			enemy_unit.show_status_text("BLESSING!", "heal")
			return buff_action
	
	# 2. POHYB - přiblíží se ke spojencům nebo hráči
	var nearest_ally = find_nearest_ally(enemy_unit, battle_grid)
	if nearest_ally:
		var distance_to_ally = battle_grid.get_distance(enemy_unit.grid_position, nearest_ally.grid_position)
		if distance_to_ally > BUFF_RANGE:
			var path = find_path_to_adjacent(enemy_unit, nearest_ally, battle_grid)
			if not path.is_empty():
				return create_move_action(path)
	
	# 3. PASS (Monk neútočí)
	return create_pass_action()

func find_allies_in_range(unit: Unit, battle_grid: BattleGrid, range: int) -> Array[Unit]:
	var allies: Array[Unit] = []
	var all_units = battle_grid.get_all_objects_on_grid()
	
	for u in all_units:
		if u is Unit and u != unit:
			# Zkontrolujeme, jestli je to spojenec (stejná faction nebo enemy)
			if u.unit_data.faction == unit.unit_data.faction:
				var distance = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if distance <= range:
					allies.append(u)
	
	return allies

func find_nearest_ally(unit: Unit, battle_grid: BattleGrid) -> Unit:
	var all_units = battle_grid.get_all_objects_on_grid()
	var nearest: Unit = null
	var min_distance = INF
	
	for u in all_units:
		if u is Unit and u != unit:
			if u.unit_data.faction == unit.unit_data.faction:
				var distance = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if distance < min_distance:
					min_distance = distance
					nearest = u
	
	return nearest

