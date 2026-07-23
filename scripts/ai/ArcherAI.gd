# ===================================================================
# Soubor: res://scripts/ai/ArcherAI.gd
# POPIS: Pokročilý taktický Archer - pozicování, aiming, kryti, move+attack
# ===================================================================
extends EnemyAIBase

const MELEE_RANGE = 2  # Vzdálenost, kterou Archer považuje za "příliš blízko"
const PREFERRED_DISTANCE = 4  # Optimální vzdálenost pro boj
const COVER_BONUS_MULTIPLIER = 1.5  # Bonus za krytím
const AIM_DAMAGE_MULTIPLIER = 2.5  # Damage bonus po zaměření

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]

	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)

	# === PRIORITA 1: ÚTĚK Z MELEE ZÓNY + ÚTOK ===
	if distance_to_player <= MELEE_RANGE:
		var escape_move = find_escape_move(enemy_unit, player_unit, battle_grid)
		if not escape_move.path.is_empty():
			actions.append(create_move_action(escape_move.path))
			enemy_unit.set_aiming(false)
			
			# Po útěku: zaútoč pokud jsi v dosahu z nové pozice
			if escape_move.in_attack_range:
				actions.append(create_attack_action(player_unit, 0.9))
			
			return actions
		
		# Nemůže utéct - zaútoč zblízka
		if can_attack_target(enemy_unit, player_unit, battle_grid):
			enemy_unit.set_aiming(false)
			actions.append(create_attack_action(player_unit, 0.7))
			return actions

	# === PRIORITA 2: AIMED SHOT (po zaměření) ===
	if enemy_unit.is_aiming and can_attack_target(enemy_unit, player_unit, battle_grid):
		enemy_unit.set_aiming(false)
		var is_behind_cover = is_cell_behind_cover(enemy_unit.grid_position, player_unit.grid_position, battle_grid)
		var multiplier = (AIM_DAMAGE_MULTIPLIER * COVER_BONUS_MULTIPLIER) if is_behind_cover else AIM_DAMAGE_MULTIPLIER
		actions.append(create_attack_action(player_unit, multiplier))
		return actions

	# === PRIORITA 3: STŘELBA Z KRYTÍ ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var is_behind_cover = is_cell_behind_cover(enemy_unit.grid_position, player_unit.grid_position, battle_grid)
		
		if is_behind_cover:
			# Střílej z krytí s bonusem
			actions.append(create_attack_action(player_unit, COVER_BONUS_MULTIPLIER))
			return actions
		else:
			# Zaměř se pro příští tah (aiming)
			enemy_unit.set_aiming(true)
			enemy_unit.show_intent(int(enemy_unit.unit_data.attack_damage * AIM_DAMAGE_MULTIPLIER))
			return [create_pass_action()]

	# === PRIORITA 4: TAKTICKÝ POHYB + ÚTOK ===
	# Najdi nejlepší pozici kde můžeš zaútočit
	var best_move = find_best_tactical_move(enemy_unit, player_unit, battle_grid)
	
	if best_move.cell != enemy_unit.grid_position and not best_move.path.is_empty():
		enemy_unit.set_aiming(false)
		actions.append(create_move_action(best_move.path))
		
		# Po pohybu: zaútoč pokud jsi v dosahu z nové pozice
		if can_attack_from_position(best_move.cell, enemy_unit, player_unit, battle_grid):
			var is_behind_cover = is_cell_behind_cover(best_move.cell, player_unit.grid_position, battle_grid)
			var mult = COVER_BONUS_MULTIPLIER if is_behind_cover else 1.0
			actions.append(create_attack_action(player_unit, mult))
		
		return actions
	
	# === PRIORITA 5: PŘIBLIŽ SE ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		enemy_unit.set_aiming(false)
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

# === VYLEPŠENÁ TAKTICKÁ ANALÝZA ===

func find_best_tactical_move(archer: Unit, player: Unit, battle_grid: BattleGrid) -> Dictionary:
	var reachable_cells = get_reachable_cells(archer, battle_grid)
	reachable_cells.append(archer.grid_position)

	var best_cell = archer.grid_position
	var best_score = evaluate_position_score(archer.grid_position, archer, player, battle_grid)
	
	for cell in reachable_cells:
		var unit_on_cell = battle_grid.get_object_on_cell(cell)
		if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
			continue

		var score = evaluate_position_score(cell, archer, player, battle_grid)
		if score > best_score:
			best_score = score
			best_cell = cell
			
	# Nouzový plán pokud není žádná dobrá pozice
	if best_score < -50:
		var min_distance = battle_grid.get_distance(best_cell, player.grid_position)
		for cell in reachable_cells:
			var unit_on_cell = battle_grid.get_object_on_cell(cell)
			if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
				continue
			
			var distance = battle_grid.get_distance(cell, player.grid_position)
			if distance < min_distance:
				min_distance = distance
				best_cell = cell
			
	var best_path: Array[Vector2i] = []
	if best_cell != archer.grid_position:
		best_path = find_path(archer, best_cell, battle_grid)
		if best_path.is_empty():
			best_cell = archer.grid_position
			
	return {"cell": best_cell, "path": best_path, "score": best_score}

func evaluate_position_score(cell: Vector2i, archer: Unit, player: Unit, battle_grid: BattleGrid) -> float:
	var distance = battle_grid.get_distance(cell, player.grid_position)
	var score = 0.0
	
	# ZÁKLADNÍ POŽADAVEK: Musí být možné odsud útočit
	if distance > archer.unit_data.attack_range:
		return -INF

	# BEZPEČNOSTNÍ HODNOCENÍ
	var player_movement = 3
	var safety_distance = distance - player_movement
	
	if safety_distance > MELEE_RANGE:
		score += 60
	elif safety_distance > 0:
		score += 30
	else:
		score -= 100

	# KRYTÍ - největší bonus
	if is_cell_behind_cover(cell, player.grid_position, battle_grid):
		score += 150

	# OPTIMÁLNÍ VZDÁLENOST
	if distance == PREFERRED_DISTANCE:
		score += 40
	elif distance == PREFERRED_DISTANCE + 1 or distance == PREFERRED_DISTANCE - 1:
		score += 20
	
	score += (distance - MELEE_RANGE) * 5.0
	
	# TERÉNNÍ VÝHODY
	var terrain = battle_grid.get_terrain_on_cell(cell)
	if terrain:
		if terrain.terrain_name == "HighGround":
			score += 25
		elif terrain.terrain_name == "Forest":
			score += 15
	
	# PENALTY za melee zónu
	if distance <= MELEE_RANGE:
		score -= 200
		
	return score

# === ÚNIKOVÉ MANÉVRY ===

func find_escape_move(archer: Unit, player: Unit, battle_grid: BattleGrid) -> Dictionary:
	var reachable_cells = get_reachable_cells(archer, battle_grid)
	var best_cell = archer.grid_position
	var best_score = -INF
	var in_attack_range = false
	
	for cell in reachable_cells:
		var unit_on_cell = battle_grid.get_object_on_cell(cell)
		if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
			continue
			
		var distance = battle_grid.get_distance(cell, player.grid_position)
		
		var score = distance * 10.0
		if distance <= archer.unit_data.attack_range:
			score += 100  # Bonus za zůstání v dosahu
		if distance <= MELEE_RANGE:
			score -= 200
		
		if score > best_score:
			best_score = score
			best_cell = cell
			in_attack_range = (distance <= archer.unit_data.attack_range)
	
	var path: Array[Vector2i] = []
	if best_cell != archer.grid_position:
		path = find_path(archer, best_cell, battle_grid)
		
	return {"cell": best_cell, "path": path, "distance": battle_grid.get_distance(best_cell, player.grid_position), "in_attack_range": in_attack_range}

# === VYLEPŠENÉ KRYTÍ ===

func is_cell_behind_cover(cell: Vector2i, target_cell: Vector2i, battle_grid: BattleGrid) -> bool:
	var line_points = battle_grid.get_line(cell, target_cell)
	if line_points.size() <= 2:
		return false
	
	for i in range(1, line_points.size() - 1):
		var point = line_points[i]
		
		var terrain = battle_grid.get_terrain_on_cell(point)
		if terrain and not terrain.is_walkable:
			return true
			
		var unit_on_cell = battle_grid.get_object_on_cell(point)
		if is_instance_valid(unit_on_cell):
			return true
	
	return false
