# ===================================================================
# Soubor: res://scripts/ai/MonkAI.gd
# POPIS: Monk - combat support, buff + ki strike + war cry + meditate
# ===================================================================
extends EnemyAIBase

const BUFF_RANGE = 3  # Vzdálenost pro buffování
const BUFF_DAMAGE_BONUS = 3  # Bonus k poškození (zvýšeno z 2)
const BUFF_DURATION = 3  # Trvání buffu
const WAR_CRY_RANGE = 2  # Dosah war cry (AoE buff)
const WAR_CRY_BONUS = 1  # Bonus z war cry
const WAR_CRY_DURATION = 2  # Trvání war cry
const WAR_CRY_COOLDOWN = 3  # Cooldown war cry
const KI_STRIKE_DAMAGE = 3  # Damage ki strike
const MEDITATE_HEAL = 5  # Self-heal z meditace

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	# Inicializace cooldownu
	if not enemy_unit.has_meta("war_cry_cooldown"):
		enemy_unit.set_meta("war_cry_cooldown", 0)
	var wc_cd = enemy_unit.get_meta("war_cry_cooldown")
	if wc_cd > 0:
		enemy_unit.set_meta("war_cry_cooldown", wc_cd - 1)
	
	var allies = get_all_enemies(enemy_unit, battle_grid)
	var allies_in_range = _find_allies_in_range(enemy_unit, battle_grid, BUFF_RANGE)
	var allies_in_wc_range = _find_allies_in_range(enemy_unit, battle_grid, WAR_CRY_RANGE)
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	
	# === 1. WAR CRY (AoE buff pokud 2+ spojenců v dosahu) ===
	if wc_cd <= 0 and allies_in_wc_range.size() >= 2:
		var war_cry = create_special_action({
			"type": "war_cry",
			"damage_bonus": WAR_CRY_BONUS,
			"duration": WAR_CRY_DURATION,
			"range": WAR_CRY_RANGE
		})
		enemy_unit.show_status_text("WAR CRY!", "critical")
		enemy_unit.set_meta("war_cry_cooldown", WAR_CRY_COOLDOWN)
		actions.append(war_cry)
		return actions
	
	# === 2. INDIVIDUAL BUFF (nejbližší spojenec bez buffu) ===
	var unbuffed_ally = _find_unbuffed_ally(allies_in_range)
	if unbuffed_ally != null:
		var buff = create_special_action({
			"type": "buff_ally",
			"target": unbuffed_ally,
			"damage_bonus": BUFF_DAMAGE_BONUS,
			"duration": BUFF_DURATION
		})
		enemy_unit.show_status_text("BLESSING!", "heal")
		actions.append(buff)
		
		# Po buffu: pohyb směrem ke spojencům nebo hráči
		if allies.size() > 0:
			var move = _move_toward_allies(enemy_unit, battle_grid)
			if not move.is_empty():
				actions.append(create_move_action(move))
		
		return actions
	
	# === 3. KI STRIKE (pokud nemáme koho buffovat a jsme v dosahu) ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		# Ki Strike je speciální útok
		var ki_strike = create_attack_action(player_unit, 1.0)
		ki_strike.special_data["ki_strike"] = true
		enemy_unit.show_status_text("KI STRIKE!", "critical")
		actions.append(ki_strike)
		return actions
	
	# === 4. MOVE + KI STRIKE (pokud můžeme dosáhnout hráče) ===
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1) and allies.is_empty():
		# Monk útočí jen pokud nemá žádné spojence k buffování
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			var ki_strike = create_attack_action(player_unit, 1.0)
			ki_strike.special_data["ki_strike"] = true
			actions.append(ki_strike)
			return actions
	
	# === 5. POHYB KE SPOJENCŮM (pokud jsou daleko) ===
	if not allies.is_empty():
		var move = _move_toward_allies(enemy_unit, battle_grid)
		if not move.is_empty():
			actions.append(create_move_action(move))
			return actions
	
	# === 6. MEDITATE (pokud je sám a nemůže nic dělat) ===
	if allies.is_empty():
		var meditate = create_special_action({
			"type": "meditate",
			"heal_amount": MEDITATE_HEAL
		})
		enemy_unit.show_status_text("MEDITATE!", "heal")
		actions.append(meditate)
		return actions
	
	# === 7. POHYB K HRÁČI (poslední možnost) ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

func _find_allies_in_range(unit: Unit, battle_grid: BattleGrid, range_limit: int) -> Array[Unit]:
	var allies: Array[Unit] = []
	var all_units = battle_grid.get_all_objects_on_grid()
	
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.faction == unit.unit_data.faction:
				var distance = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if distance <= range_limit:
					allies.append(u)
	
	return allies

func _find_unbuffed_ally(allies: Array[Unit]) -> Unit:
	"""Najde spojence bez monk_blessing"""
	for ally in allies:
		if is_instance_valid(ally) and not ally.active_statuses.has("monk_blessing"):
			return ally
	return null

func _move_toward_allies(unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	"""Pohyb směrem k nejbližšímu spojenci"""
	var all_units = battle_grid.get_all_objects_on_grid()
	var nearest: Unit = null
	var min_distance = INF
	
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.faction == unit.unit_data.faction:
				var dist = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if dist < min_distance:
					min_distance = dist
					nearest = u
	
	if nearest != null and min_distance > BUFF_RANGE:
		return find_path_to_adjacent(unit, nearest, battle_grid)
	
	return []
