# ===================================================================
# Soubor: res://scripts/ai/HealerAI.gd
# POPIS: Healer/Cleric - smart support, heal + attack, protection, pozicování
# ===================================================================
extends EnemyAIBase

const HEAL_RANGE = 4  # Vzdálenost pro léčení
const HEAL_AMOUNT = 8  # Množství léčení
const HOLY_DAMAGE_MULTIPLIER = 1.5  # Bonus k holy damage
const LOW_HEALTH_THRESHOLD = 0.5  # 50% HP = nízké zdraví
const PROTECTION_BLOCK = 4  # Block z protection schopnosti
const HOLY_NOVA_RANGE = 3  # Dosah holy nova
const HOLY_NOVA_HEAL = 4  # Heal za holy nova (na každého spojence)
const SAFE_DISTANCE = 3  # Healer se drží v bezpečné vzdálenosti

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	var allies = get_all_enemies(enemy_unit, battle_grid)
	
	# Najdi nejzraněnějšího spojence
	var most_injured = _find_most_injured_ally(enemy_unit, battle_grid)
	
	# === 1. EMERGENCY HEAL (spojenec pod 30% HP) ===
	if most_injured != null:
		var hp_pct = float(most_injured.current_health) / float(most_injured.unit_data.max_health)
		if hp_pct < 0.3:
			var dist_to_ally = battle_grid.get_distance(enemy_unit.grid_position, most_injured.grid_position)
			
			# Pokud jsme v dosahu, healni okamžitě
			if dist_to_ally <= HEAL_RANGE:
				var heal = create_special_action({
					"type": "heal_ally",
					"target": most_injured,
					"heal_amount": HEAL_AMOUNT + 3  # Bonus heal za emergency
				})
				enemy_unit.show_status_text("EMERGENCY HEAL!", "heal")
				actions.append(heal)
				return actions
			else:
				# Pohni se ke spojenci a healuj
				var path = find_path_to_adjacent(enemy_unit, most_injured, battle_grid)
				if not path.is_empty():
					actions.append(create_move_action(path))
					# Po pohybu: pokud je v dosahu, healuj
					actions.append(create_special_action({
						"type": "heal_ally",
						"target": most_injured,
						"heal_amount": HEAL_AMOUNT + 3
					}))
					return actions
	
	# === 2. HOLY NOVA (pokud 2+ spojenců je zraněných a v blízkosti) ===
	var injured_allies_nearby = _count_injured_allies_in_range(enemy_unit, battle_grid, HOLY_NOVA_RANGE)
	if injured_allies_nearby >= 2:
		var nova = create_special_action({
			"type": "holy_nova",
			"heal_amount": HOLY_NOVA_HEAL,
			"range": HOLY_NOVA_RANGE
		})
		enemy_unit.show_status_text("HOLY NOVA!", "heal")
		actions.append(nova)
		return actions
	
	# === 3. NORMÁLNÍ HEAL (spojenec pod 50% HP) ===
	if most_injured != null:
		var hp_pct = float(most_injured.current_health) / float(most_injured.unit_data.max_health)
		if hp_pct < LOW_HEALTH_THRESHOLD:
			var dist_to_ally = battle_grid.get_distance(enemy_unit.grid_position, most_injured.grid_position)
			if dist_to_ally <= HEAL_RANGE:
				var heal = create_special_action({
					"type": "heal_ally",
					"target": most_injured,
					"heal_amount": HEAL_AMOUNT
				})
				enemy_unit.show_status_text("HEAL!", "heal")
				actions.append(heal)
				
				# Po healu: pokud jsme příliš blízko hráči, ustup
				if distance_to_player <= SAFE_DISTANCE - 1:
					var escape = _find_safe_position(enemy_unit, player_unit, battle_grid)
					if not escape.is_empty():
						actions.append(create_move_action(escape))
				
				return actions
	
	# === 4. PROTECTION (dej block nejbližšímu spojenci) ===
	var closest_ally = _find_closest_ally(enemy_unit, battle_grid)
	if closest_ally != null:
		var dist_to_ally = battle_grid.get_distance(enemy_unit.grid_position, closest_ally.grid_position)
		if dist_to_ally <= HEAL_RANGE:
			# Dej protection pokud má spojenec <80% HP nebo je blízko hráči
			var ally_hp_pct = float(closest_ally.current_health) / float(closest_ally.unit_data.max_health)
			var ally_dist_to_player = battle_grid.get_distance(closest_ally.grid_position, player_unit.grid_position)
			
			if ally_hp_pct < 0.8 or ally_dist_to_player <= 2:
				var protection = create_special_action({
					"type": "protection",
					"target": closest_ally,
					"block_amount": PROTECTION_BLOCK
				})
				enemy_unit.show_status_text("PROTECTION!", "heal")
				actions.append(protection)
				return actions
	
	# === 5. ÚTOK S HOLY DAMAGE ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var damage_multiplier = 1.0
		if player_unit.unit_data.unit_type == UnitData.UnitType.UNDEAD or player_unit.unit_data.unit_type == UnitData.UnitType.DEMON:
			damage_multiplier = HOLY_DAMAGE_MULTIPLIER
		
		var action = create_attack_action(player_unit, damage_multiplier)
		action.special_data["holy_damage"] = true
		actions.append(action)
		return actions
	
	# === 6. POHYB + ÚTOK ===
	# Healer se drží za ostatními - preferuje pozice dál od hráče
	var safe_attack_pos = find_safe_attack_position(enemy_unit, player_unit, battle_grid, SAFE_DISTANCE)
	if safe_attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, safe_attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			var action = create_attack_action(player_unit, 1.0)
			action.special_data["holy_damage"] = true
			actions.append(action)
			return actions
	
	# Přibliž se k hráči pokud není jiná možnost
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

func _find_most_injured_ally(unit: Unit, battle_grid: BattleGrid) -> Unit:
	"""Najde nejzraněnějšího spojence"""
	var all_units = battle_grid.get_all_objects_on_grid()
	var most_injured: Unit = null
	var lowest_hp_pct = 1.0
	
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.faction == unit.unit_data.faction:
				var hp_pct = float(u.current_health) / float(u.unit_data.max_health)
				if hp_pct < lowest_hp_pct and hp_pct < 1.0:  # Musí být zraněný
					lowest_hp_pct = hp_pct
					most_injured = u
	
	return most_injured

func _find_closest_ally(unit: Unit, battle_grid: BattleGrid) -> Unit:
	"""Najde nejbližšího spojence"""
	var all_units = battle_grid.get_all_objects_on_grid()
	var closest: Unit = null
	var min_dist = INF
	
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.faction == unit.unit_data.faction:
				var dist = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if dist < min_dist:
					min_dist = dist
					closest = u
	
	return closest

func _count_injured_allies_in_range(unit: Unit, battle_grid: BattleGrid, heal_range: int) -> int:
	"""Počet zraněných spojenců v dosahu"""
	var count = 0
	var all_units = battle_grid.get_all_objects_on_grid()
	
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.faction == unit.unit_data.faction:
				var dist = battle_grid.get_distance(unit.grid_position, u.grid_position)
				if dist <= heal_range:
					var hp_pct = float(u.current_health) / float(u.unit_data.max_health)
					if hp_pct < 1.0:
						count += 1
	return count

func _find_safe_position(unit: Unit, player: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	"""Najde bezpečnou pozici dál od hráče"""
	var reachable = get_reachable_cells(unit, battle_grid)
	var best_cell = unit.grid_position
	var best_distance = battle_grid.get_distance(unit.grid_position, player.grid_position)
	
	for cell in reachable:
		var obj = battle_grid.get_object_on_cell(cell)
		if obj != null and obj != unit:
			continue
		var dist = battle_grid.get_distance(cell, player.grid_position)
		if dist > best_distance:
			best_distance = dist
			best_cell = cell
	
	if best_cell != unit.grid_position:
		return find_path(unit, best_cell, battle_grid)
	return []
