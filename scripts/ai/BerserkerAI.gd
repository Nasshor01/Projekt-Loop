# ===================================================================
# Soubor: res://scripts/ai/BerserkerAI.gd
# POPIS: Berserker - malý pohyb, silný dmg, rush mechanika po 5 kolech
# ===================================================================
extends EnemyAIBase

const MAX_MOVEMENT_RANGE = 1 # Berserker má omezený pohyb na 1 pole
const RAGE_TURNS_REQUIRED = 5 # Po 5 kolech bez dosažení hráče aktivuje rush
const RUSH_DAMAGE_MULTIPLIER = 3.0 # 300% damage při rush útoku


func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	# Použijeme NOVÉ názvy proměnných
	print("=== BERSERKER AI VOLÁN (V2) ===")
	print("DEBUG: Konstanta limitu frustrace je: %d" % RAGE_TURNS_REQUIRED) # Nový debug výpis
	
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		print("❌ Player unit nenalezen!")
		return create_pass_action()

	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	# Použijeme NOVÝ název proměnné z Unit.gd
	print("📍 Berserker pozice: %s, Player pozice: %s, Vzdálenost: %d" % [enemy_unit.grid_position, player_unit.grid_position, distance_to_player])
	print("⏰ Frustrace: %d, Rage mode: %s" % [enemy_unit.berserker_frustration, enemy_unit.is_permanently_enraged])
	
	# Zjistíme, jestli se už může zbláznit (použijeme NOVÉ názvy)
	if enemy_unit.berserker_frustration >= RAGE_TURNS_REQUIRED:
		if not enemy_unit.is_permanently_enraged: # Vypíše hlášku jen jednou
			print("🔥 BERSERKER VSTUPUJE DO PERMANENTNÍHO RAGE MÓDU!")
			enemy_unit.show_status_text("ZUŘIVOST!", "critical")
		enemy_unit.is_permanently_enraged = true
	
	
	# === LOGIKA ROZHODOVÁNÍ ===

	# 1. KONTROLA RUSH ÚTOKU
	if enemy_unit.is_permanently_enraged:
		var same_line = (enemy_unit.grid_position.x == player_unit.grid_position.x)
		var same_column = (enemy_unit.grid_position.y == player_unit.grid_position.y)
		print("🔍 Rage Check: Same line: %s, Same column: %s" % [same_line, same_column])
		
		if same_line or same_column:
			var rush_path = find_rush_path_to_player(enemy_unit, player_unit, battle_grid)
			if not rush_path.is_empty():
				print("💥 BERSERKER RUSH! %.1fx damage!" % RUSH_DAMAGE_MULTIPLIER)
				return create_rush_action(player_unit, rush_path, RUSH_DAMAGE_MULTIPLIER)
			else:
				print("❌ Rage: Rush path nenalezen (někdo blokuje?).")
		else:
			print("🔥 V Rage, ale není na linii pro RUSH.")

	# 2. KONTROLA BĚŽNÉHO ÚTOKU
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var damage_multiplier = 1.0
		if enemy_unit.is_permanently_enraged:
			damage_multiplier = RUSH_DAMAGE_MULTIPLIER
			print("🔥 BERSERKER RAGE ÚTOK! %.1fx damage!" % damage_multiplier)
		else:
			print("⚔️ Berserker útočí!")
		
		return create_attack_action(player_unit, damage_multiplier)

	# 3. POHYB
	var path_to_player = find_limited_path_to_player(enemy_unit, player_unit, battle_grid)
	if not path_to_player.is_empty():
		print("🚶 Berserker se pohybuje.")
		return create_move_action(path_to_player)

	# 4. PASS
	print("⏳ Berserker čeká!")
	return create_pass_action()

func find_limited_path_to_player(from_unit: Unit, to_unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	var adjacent_cells = get_adjacent_walkable_cells(to_unit, battle_grid)
	if adjacent_cells.is_empty():
		return []
	
	var best_path: Array[Vector2i] = []
	var shortest_distance = INF
	
	for target_cell in adjacent_cells:
		var path = find_path_with_movement_limit(from_unit, target_cell, battle_grid, MAX_MOVEMENT_RANGE)
		if not path.is_empty() and path.size() < shortest_distance:
			shortest_distance = path.size()
			best_path = path
	
	return best_path

func find_rush_path_to_player(from_unit: Unit, to_unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	var adjacent_cells = get_adjacent_walkable_cells(to_unit, battle_grid)
	if adjacent_cells.is_empty():
		return []
	
	# V rush mode může se pohybovat po celém gridu
	var rush_movement_range = 15 # Prakticky neomezené
	
	var best_path: Array[Vector2i] = []
	var shortest_distance = INF
	
	for target_cell in adjacent_cells:
		var path = find_path_with_movement_limit(from_unit, target_cell, battle_grid, rush_movement_range)
		if not path.is_empty() and path.size() < shortest_distance:
			shortest_distance = path.size()
			best_path = path
	
	return best_path

func get_adjacent_walkable_cells(unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	var adjacent_cells: Array[Vector2i] = []
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = unit.grid_position + offset
		if battle_grid.is_cell_active(cell):
			var object_on_cell = battle_grid.get_object_on_cell(cell)
			if not object_on_cell:
				var terrain = battle_grid.get_terrain_on_cell(cell)
				if not terrain or terrain.is_walkable:
					adjacent_cells.append(cell)
	
	return adjacent_cells
