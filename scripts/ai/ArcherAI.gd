# ===================================================================
# Soubor: res://scripts/ai/ArcherAI.gd
# POPIS: Pokročilý taktický Archer s vylepšeným AI
# ===================================================================
extends EnemyAIBase

const MELEE_RANGE = 2 # Vzdálenost, kterou Archer považuje za "příliš blízko"
const PREFERRED_DISTANCE = 4 # Optimální vzdálenost pro boj
const COVER_BONUS_MULTIPLIER = 1.5 # Bonus k přesnosti za krytím
const AIM_DAMAGE_MULTIPLIER = 2.5 # Damage bonus po zaměření

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()

	var _archer_range = enemy_unit.unit_data.attack_range
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)

	# === PRIORITA 1: ÚTĚK Z MELEE ZÓNY ===
	if distance_to_player <= MELEE_RANGE:
		print("🏃 Archer je příliš blízko! Couvá z melee zóny!")
		var escape_move = find_escape_move(enemy_unit, player_unit, battle_grid)
		if not escape_move.path.is_empty():
			return create_move_action(escape_move.path)
		
		# Pokud nemůže utéct, zaútočí z blízka (s penalizací)
		print("😰 Archer je v pasti! Útočí zblízka!")
		enemy_unit.set_aiming(false) # Ztratí zaměření
		return create_attack_action(player_unit, 0.7) # Snížený damage z blízka

	# === PRIORITA 2: ÚTOK KDYŽ MŮŽEME ===
	var is_behind_cover = is_cell_behind_cover(enemy_unit.grid_position, player_unit.grid_position, battle_grid)
	
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		# Pokud zaměřuje, vystřelí s bonusem
		if enemy_unit.is_aiming:
			enemy_unit.set_aiming(false)
			var multiplier = (AIM_DAMAGE_MULTIPLIER * COVER_BONUS_MULTIPLIER) if is_behind_cover else AIM_DAMAGE_MULTIPLIER
			print("🎯 Archer pálí zaměřený výstřel%s (%.1fx damage)" % [" z krytí!" if is_behind_cover else "!", multiplier])
			return create_attack_action(player_unit, multiplier)
		# Pokud je za krytím, střelí hned i bez zaměření (s cover bonusem)
		elif is_behind_cover:
			print("🛡️ Archer střílí z krytí!")
			return create_attack_action(player_unit, COVER_BONUS_MULTIPLIER)
		# Jinak se zaměří na příští tah
		else:
			print("⏳ Archer zaměřuje pro příští výstřel.")
			enemy_unit.set_aiming(true)
			enemy_unit.show_intent(int(enemy_unit.unit_data.attack_damage * AIM_DAMAGE_MULTIPLIER))
			return create_pass_action()

	# === PRIORITA 3: TAKTICKÝ POHYB ===
	var best_move = find_best_tactical_move(enemy_unit, player_unit, battle_grid)
	
	# Pokud je nejlepší pozice ta současná
	if best_move.cell == enemy_unit.grid_position:
		# Nemůže se zlepšit pozicí, takže pass (už jsme zkontrolovali útok výše)
		print("🤔 Archer zůstává na pozici (nemůže se zlepšit pohybem).")
		return create_pass_action()
	else:
		# Pohne se na lepší pozici
		print("🚶 Archer se přesouvá na taktickou pozici: %s (skóre: %.1f)" % [str(best_move.cell), best_move.score])
		enemy_unit.set_aiming(false) # Ztratí zaměření při pohybu
		return create_move_action(best_move.path)

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
		print("!!! Archer aktivuje nouzový plán: Přiblížit se za každou cenu.")
		var min_distance = battle_grid.get_distance(best_cell, player.grid_position)
		for cell in reachable_cells:
			var unit_on_cell = battle_grid.get_object_on_cell(cell)
			if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
				continue
			
			var distance = battle_grid.get_distance(cell, player.grid_position)
			if distance < min_distance:
				min_distance = distance
				best_cell = cell
			
	var best_path = []
	if best_cell != archer.grid_position:
		best_path = find_path(archer, best_cell, battle_grid)
		if best_path.is_empty():
			# Cesta neexistuje, zůstane na současné pozici
			best_cell = archer.grid_position
			
	return {"cell": best_cell, "path": best_path, "score": best_score}

func evaluate_position_score(cell: Vector2i, archer: Unit, player: Unit, battle_grid: BattleGrid) -> float:
	var distance = battle_grid.get_distance(cell, player.grid_position)
	var score = 0.0
	
	# ZÁKLADNÍ POŽADAVEK: Musí být možné odsud útočit
	if distance > archer.unit_data.attack_range:
		return -INF

	# BEZPEČNOSTNÍ HODNOCENÍ
	var player_movement = 3 # Předpokládaný pohyb hráče
	var safety_distance = distance - player_movement
	
	if safety_distance > MELEE_RANGE:
		score += 60 # Dobrá bezpečnost
	elif safety_distance > 0:
		score += 30 # Částečná bezpečnost
	else:
		score -= 100 # Nebezpečná zóna

	# KRYTÍ - největší bonus
	if is_cell_behind_cover(cell, player.grid_position, battle_grid):
		score += 150

	# OPTIMÁLNÍ VZDÁLENOST
	if distance == PREFERRED_DISTANCE:
		score += 40
	elif distance == PREFERRED_DISTANCE + 1 or distance == PREFERRED_DISTANCE - 1:
		score += 20
	
	# Bonus za větší vzdálenost (ale stále v dosahu)
	score += (distance - MELEE_RANGE) * 5.0
	
	# TERÉNNÍ VÝHODY
	var terrain = battle_grid.get_terrain_on_cell(cell)
	if terrain:
		if terrain.terrain_name == "HighGround":
			score += 25 # Bonus za vyvýšené místo
		elif terrain.terrain_name == "Forest":
			score += 15 # Částečné krytí
	
	# PENALTY za melee zónu
	if distance <= MELEE_RANGE:
		score -= 200
		
	return score

# === ÚNIKOVÉ MANÉVRY ===

func find_escape_move(archer: Unit, player: Unit, battle_grid: BattleGrid) -> Dictionary:
	var reachable_cells = get_reachable_cells(archer, battle_grid)
	var best_cell = archer.grid_position
	var best_score = -INF
	
	for cell in reachable_cells:
		var unit_on_cell = battle_grid.get_object_on_cell(cell)
		if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
			continue
			
		var distance = battle_grid.get_distance(cell, player.grid_position)
		
		# Priorita: co nejdál od hráče, ale ideálně stále v útočném dosahu
		var score = distance
		if distance <= archer.unit_data.attack_range:
			score += 100  # Bonus za zůstání v dosahu
		if distance <= MELEE_RANGE:
			score -= 200  # Penalty za zůstání v melee zóně
		
		if score > best_score:
			best_score = score
			best_cell = cell
	
	var path = []
	if best_cell != archer.grid_position:
		path = find_path(archer, best_cell, battle_grid)
		
	return {"cell": best_cell, "path": path, "distance": battle_grid.get_distance(best_cell, player.grid_position)}

# === VYLEPŠENÉ KRYTÍ ===

func is_cell_behind_cover(cell: Vector2i, target_cell: Vector2i, battle_grid: BattleGrid) -> bool:
	var line_points = battle_grid.get_line(cell, target_cell)
	if line_points.size() <= 2: # Příliš blízko pro krytí
		return false
	
	# Zkontrolujeme body mezi střelcem a cílem
	for i in range(1, line_points.size() - 1):
		var point = line_points[i]
		
		# Neprůchodný terén poskytuje krytí
		var terrain = battle_grid.get_terrain_on_cell(point)
		if terrain and not terrain.is_walkable:
			return true
			
		# Jiné jednotky také poskytují krytí
		var unit_on_cell = battle_grid.get_object_on_cell(point)
		if is_instance_valid(unit_on_cell):
			return true
	
	return false
