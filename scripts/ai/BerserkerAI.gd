# ===================================================================
# Soubor: res://scripts/ai/BerserkerAI.gd
# POPIS: Berserker - malý pohyb, silný dmg, rush mechanika po 5 kolech
# ===================================================================
extends EnemyAIBase

const MAX_MOVEMENT_RANGE = 2 # Berserker má omezený pohyb na 2 pole
const RUSH_TRIGGER_TURN = 3 # Po 3 kolech bez dosažení hráče aktivuje rush
const RUSH_DAMAGE_MULTIPLIER = 3.0 # 300% damage při rush útoku


func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	print("=== BERSERKER AI VOLÁN ===")
	
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		print("❌ Player unit nenalezen!")
		return create_pass_action()

	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	print("📍 Berserker pozice: %s, Player pozice: %s, Vzdálenost: %d" % [enemy_unit.grid_position, player_unit.grid_position, distance_to_player])
	print("⏰ Turns bez dosažení: %d, Rage mode: %s" % [enemy_unit.turns_without_reaching_player, enemy_unit.is_permanently_enraged])
	
	# === PERMANENTNÍ RAGE MODE PO 3 KOLECH ===
	if enemy_unit.turns_without_reaching_player >= RUSH_TRIGGER_TURN:
		enemy_unit.is_permanently_enraged = true
		print("🔥 BERSERKER VSTUPUJE DO PERMANENTNÍHO RAGE MÓDU!")
	
	# === RUSH KONTROLA (v rage mode) ===
	if enemy_unit.is_permanently_enraged:
		# Zkontroluj, zda je hráč na stejné linii nebo sloupci
		var same_line = (enemy_unit.grid_position.x == player_unit.grid_position.x)
		var same_column = (enemy_unit.grid_position.y == player_unit.grid_position.y)
		
		print("🔍 Same line: %s, Same column: %s" % [same_line, same_column])
		
		if same_line or same_column:
			print("💥 BERSERKER RUSH! Na stejné linii/sloupci - ÚTOK!")
			
			# Najdi nejkratší cestu k hráči s neomezeným pohybem
			var rush_path = find_rush_path_to_player(enemy_unit, player_unit, battle_grid)
			if not rush_path.is_empty():
				print("⚡ Berserker se řítí k hráči s %.1fx damage!" % RUSH_DAMAGE_MULTIPLIER)
				return create_rush_action(player_unit, rush_path, RUSH_DAMAGE_MULTIPLIER)
			else:
				print("❌ Rush path nenalezen!")
	
	# === NORMÁLNÍ LOGIKA ===
	
	# 1. Může zaútočit?
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var damage_multiplier = 1.0
		
		# V rage mode útočí se zvýšeným damage
		if enemy_unit.is_permanently_enraged:
			damage_multiplier = RUSH_DAMAGE_MULTIPLIER
			print("🔥 BERSERKER RAGE ÚTOK! %.1fx damage!" % damage_multiplier)
		else:
			print("⚔️ Berserker útočí!")
		
		# Reset počítadla při úspěšném útoku
		enemy_unit.turns_without_reaching_player = 0
		print("✅ RESET frustrace - úspěšný útok!")
		return create_attack_action(player_unit, damage_multiplier)
		
	# 2. Nemůže útočit, pokusí se přiblížit (s omezeným pohybem)
	var path_to_player = find_limited_path_to_player(enemy_unit, player_unit, battle_grid)
	if not path_to_player.is_empty():
		# Zkontroluj, zda se dostane do útočného dosahu
		var final_position = path_to_player[-1]
		var new_distance = battle_grid.get_distance(final_position, player_unit.grid_position)
		
		print("📊 Po pohybu: final_pos=%s, new_distance=%d, attack_range=%d" % [final_position, new_distance, enemy_unit.unit_data.attack_range])
		
		# Reset frustraci pouze pokud se dostane do útočného dosahu (1 pole)
		if new_distance <= enemy_unit.unit_data.attack_range:
			enemy_unit.turns_without_reaching_player = 0
			print("✅ RESET frustrace - dosažen útočný dosah!")
		else:
			# POUZE pokud ještě není v rage mode
			if not enemy_unit.is_permanently_enraged:
				enemy_unit.turns_without_reaching_player += 1
				print("⬆️ ZVÝŠENA frustrace na: %d" % enemy_unit.turns_without_reaching_player)
			else:
				print("🔥 V RAGE MODE - frustrace se nezvyšuje")
		
		var status_text = "RAGE" if enemy_unit.is_permanently_enraged else "normál"
		print("🚶 Berserker se pohybuje (%s, kol bez dosažení: %d, vzdálenost: %d)" % [status_text, enemy_unit.turns_without_reaching_player, new_distance])
		return create_move_action(path_to_player)
		
	# 3. Nemůže se pohnout - zvyš počítadlo frustrace (jen pokud není v rage)
	if not enemy_unit.is_permanently_enraged:
		enemy_unit.turns_without_reaching_player += 1
		print("⬆️ ZVÝŠENA frustrace (nemůže se pohnout) na: %d" % enemy_unit.turns_without_reaching_player)
	else:
		print("🔥 V RAGE MODE - frustrace se nezvyšuje")
	
	var status_text = "RAGE" if enemy_unit.is_permanently_enraged else "frustrace"
	print("⏳ Berserker čeká! (%s, kol bez dosažení: %d)" % [status_text, enemy_unit.turns_without_reaching_player])
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

func find_path_with_movement_limit(from_unit: Unit, to_cell: Vector2i, battle_grid: BattleGrid, max_movement: int) -> Array[Vector2i]:
	var astar_grid = AStar2D.new()
	update_astar_grid(astar_grid, from_unit, battle_grid)
	
	var start_id = get_point_id(from_unit.grid_position, battle_grid)
	var end_id = get_point_id(to_cell, battle_grid)
	
	if not astar_grid.has_point(start_id) or not astar_grid.has_point(end_id) or astar_grid.is_point_disabled(end_id):
		return []

	var path_vectors: PackedVector2Array = astar_grid.get_point_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	# Omez cestu na maximální pohyb
	var steps_taken = 0
	for i in range(path_vectors.size()):
		result_path.append(Vector2i(path_vectors[i]))
		if i > 0: # Nepočítej startovní pozici
			steps_taken += 1
			if steps_taken >= max_movement:
				break
	
	return result_path

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

func update_astar_grid(astar_grid: AStar2D, moving_unit: Unit, battle_grid: BattleGrid):
	astar_grid.clear()
	var all_units = battle_grid.get_all_objects_on_grid()
	var occupied_cells: Dictionary = {}
	
	for unit in all_units:
		if unit != moving_unit and is_instance_valid(unit):
			occupied_cells[unit.grid_position] = true
			
	for y in range(battle_grid.grid_rows):
		for x in range(battle_grid.grid_columns):
			var cell = Vector2i(x, y)
			var point_id = get_point_id(cell, battle_grid)
			if battle_grid.is_cell_active(cell):
				astar_grid.add_point(point_id, cell)
				var terrain = battle_grid.get_terrain_on_cell(cell)
				if occupied_cells.has(cell) or (terrain and not terrain.is_walkable):
					astar_grid.set_point_disabled(point_id, true)

	for y in range(battle_grid.grid_rows):
		for x in range(battle_grid.grid_columns):
			var from_cell = Vector2i(x, y)
			var from_id = get_point_id(from_cell, battle_grid)
			if astar_grid.has_point(from_id) and not astar_grid.is_point_disabled(from_id):
				for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var to_cell = from_cell + offset
					var to_id = get_point_id(to_cell, battle_grid)
					if astar_grid.has_point(to_id) and not astar_grid.is_point_disabled(to_id):
						astar_grid.connect_points(from_id, to_id)

func get_point_id(cell: Vector2i, battle_grid: BattleGrid) -> int:
	return cell.y * battle_grid.grid_columns + cell.x
