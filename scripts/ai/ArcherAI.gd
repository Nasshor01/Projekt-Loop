# ===================================================================
# Soubor: res://scripts/ai/ArcherAI.gd
# POPIS: Taktická AI, která vyhledává krytí a hodnotí pozice.
# ===================================================================
extends EnemyAIBase

const MELEE_RANGE = 2 # Vzdálenost, kterou Archer považuje za "příliš blízko"

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()

	var archer_range = enemy_unit.unit_data.attack_range

	# === FÁZE 1: HODNOCENÍ POZIC ===
	var best_move = find_best_tactical_move(enemy_unit, player_unit, battle_grid)
	
	# Pokud jsme nenašli vůbec žádný platný pohyb
	if best_move.path.is_empty() and best_move.cell == enemy_unit.grid_position:
		# Zkusíme alespoň zaútočit, pokud je to možné
		if can_attack_target(enemy_unit, player_unit, battle_grid):
			print("🏹 Archer je v pasti, ale může střílet!")
			return create_attack_action(player_unit)
		else:
			print("🤔 Archer je v pasti a nemůže nic dělat.")
			return create_pass_action()
	
	# === FÁZE 2: ROZHODNUTÍ O AKCI ===

	# Pokud je nejlepší zůstat na místě
	if best_move.cell == enemy_unit.grid_position:
		if enemy_unit.is_aiming:
			enemy_unit.set_aiming(false)
			print("🎯 Archer pálí zaměřený výstřel z výhodné pozice!")
			return create_attack_action(player_unit, 2.5)
		else:
			# Stojí na dobrém místě, má výhled a je v bezpečí -> zamíří
			print("⏳ Archer je v dobré pozici a zaměřuje.")
			enemy_unit.set_aiming(true)
			enemy_unit.show_intent(int(enemy_unit.unit_data.attack_damage * 2.5))
			return create_pass_action()
	else:
		# Pokud je nejlepší se pohnout
		print("🚶 Archer se přesouvá na taktickou pozici: %s" % str(best_move.cell))
		return create_move_action(best_move.path)

# --- Hlavní mozek AI ---

# Najde nejlepší možné pole, kam se pohnout, a vrátí ho i s cestou.
func find_best_tactical_move(archer: Unit, player: Unit, battle_grid: BattleGrid) -> Dictionary:
	var reachable_cells = get_reachable_cells(archer, battle_grid)
	reachable_cells.append(archer.grid_position)

	var best_cell = archer.grid_position
	var best_score = -INF
	
	for cell in reachable_cells:
		var unit_on_cell = battle_grid.get_object_on_cell(cell)
		if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
			continue

		var score = evaluate_position_score(cell, archer, player, battle_grid)
		if score > best_score:
			best_score = score
			best_cell = cell
			
	# --- NOUZOVÝ PLÁN: POKUD NENÍ ŽÁDNÁ DOBRÁ MOŽNOST ---
	# Pokud je nejlepší skóre stále velmi nízké (např. pod 0), znamená to,
	# že Archer nenašel žádnou pozici, kterou by považoval za výhodnou.
	if best_score < 0:
		print("!!! Archer aktivuje nouzový plán: Přiblížit se za každou cenu.")
		var min_distance = battle_grid.get_distance(best_cell, player.grid_position)
		# Projdeme všechny možnosti a najdeme tu, která nás dostane nejblíže.
		for cell in reachable_cells:
			var unit_on_cell = battle_grid.get_object_on_cell(cell)
			if is_instance_valid(unit_on_cell) and unit_on_cell != archer:
				continue
			
			var distance = battle_grid.get_distance(cell, player.grid_position)
			if distance < min_distance:
				min_distance = distance
				best_cell = cell
	# --- KONEC NOUZOVÉHO PLÁNU ---
			
	var best_path = []
	if best_cell != archer.grid_position:
		best_path = find_path(archer, best_cell, battle_grid)
		if best_path.is_empty() and best_cell != archer.grid_position:
			best_cell = archer.grid_position
			
	return {"cell": best_cell, "path": best_path, "score": best_score}

# Ohodnotí dané pole z pohledu Archera.
func evaluate_position_score(cell: Vector2i, archer: Unit, player: Unit, battle_grid: BattleGrid) -> float:
	var distance = battle_grid.get_distance(cell, player.grid_position)
	var player_movement = 3 # Předpoklad
	var score = 0.0
	
	# Podmínka č. 1: MUSÍ být možné odsud zaútočit. Pokud ne, pole je bezcenné.
	if distance > archer.unit_data.attack_range:
		return -INF # Vrací "minus nekonečno", aby toto pole nikdy nebylo vybráno.
		
	# Bonus za bezpečnost: Je hráč dost daleko, aby se příští kolo nedostal do melee?
	if (distance - player_movement) > MELEE_RANGE:
		score += 50
	
	# Obrovský bonus za krytí!
	if is_cell_behind_cover(cell, player.grid_position, battle_grid):
		score += 100
		
	# Malus za to, že je příliš blízko (v melee zóně).
	if distance <= MELEE_RANGE:
		score -= 200
		
	# Bonus za optimální vzdálenost (chce být co nejdál, ale v dosahu).
	score += distance * 2.0
	
	return score

func is_cell_behind_cover(cell: Vector2i, target_cell: Vector2i, battle_grid: BattleGrid) -> bool:
	# Použijeme funkci z BattleGrid, kterou jsme přidali.
	var line_points = battle_grid.get_line(cell, target_cell)
	if line_points.size() <= 2: return false
	
	for i in range(1, line_points.size() - 1):
		var point = line_points[i]
		var terrain = battle_grid.get_terrain_on_cell(point)
		if terrain and not terrain.is_walkable:
			return true
	return false

# --- Univerzální A* pathfinding ---
func find_path(from_unit: Unit, to_cell: Vector2i, battle_grid: BattleGrid) -> Array[Vector2i]:
	var astar_grid = AStar2D.new()
	update_astar_grid(astar_grid, from_unit, battle_grid)
	var start_id = get_point_id(from_unit.grid_position, battle_grid)
	var end_id = get_point_id(to_cell, battle_grid)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return [] # První cesta, která vrací hodnotu

	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	for p in path_vectors:
		result_path.append(Vector2i(p))
		
	return result_path # Druhá (a poslední) cesta, která teď správně vrací hodnotu

func update_astar_grid(astar_grid: AStar2D, moving_unit: Unit, battle_grid: BattleGrid):
	astar_grid.clear()
	var grid_size = Vector2i(battle_grid.grid_columns, battle_grid.grid_rows)
	var all_units = battle_grid.get_all_objects_on_grid()
	var occupied_cells: Dictionary = {}
	for unit in all_units:
		if unit != moving_unit and is_instance_valid(unit): occupied_cells[unit.grid_position] = true
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = Vector2i(x, y); var point_id = get_point_id(cell, battle_grid)
			if battle_grid.is_cell_active(cell):
				astar_grid.add_point(point_id, cell)
				var terrain = battle_grid.get_terrain_on_cell(cell)
				if occupied_cells.has(cell) or (terrain and not terrain.is_walkable): astar_grid.set_point_disabled(point_id, true)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var from_cell = Vector2i(x, y); var from_id = get_point_id(from_cell, battle_grid)
			if astar_grid.has_point(from_id) and not astar_grid.is_point_disabled(from_id):
				for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var to_cell = from_cell + offset; var to_id = get_point_id(to_cell, battle_grid)
					if astar_grid.has_point(to_id) and not astar_grid.is_point_disabled(to_id): astar_grid.connect_points(from_id, to_id)

func get_point_id(cell: Vector2i, battle_grid: BattleGrid) -> int:
	return cell.y * battle_grid.grid_columns + cell.x
