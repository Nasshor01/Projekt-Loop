# ===================================================================
# Soubor: res://scripts/ai/DruidAI.gd
# POPIS: Druid - strategický summoner, terrain control, entangle
# ===================================================================
extends EnemyAIBase

const MAX_SPIRITS = 3  # Maximální počet spiritů
const GUARDIAN_SPAWN_CHANCE = 10  # 10% šance na guardian (zvýšeno z 5%)
const ENTANGLE_RANGE = 3  # Dosah entangle
const ENTANGLE_COOLDOWN = 3  # Cooldown entangle (v kolech)
const SAFE_DISTANCE = 3  # Druid se drží vzadu

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	# Inicializace cooldownu
	if not enemy_unit.has_meta("entangle_cooldown"):
		enemy_unit.set_meta("entangle_cooldown", 0)
	var entangle_cd = enemy_unit.get_meta("entangle_cooldown")
	if entangle_cd > 0:
		enemy_unit.set_meta("entangle_cooldown", entangle_cd - 1)
	
	var spirit_count = _count_spirits(enemy_unit, battle_grid)
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	
	# === 1. ENTANGLE (kořeny drží hráče na místě) ===
	if entangle_cd <= 0 and distance_to_player <= ENTANGLE_RANGE:
		var entangle = create_special_action({
			"type": "entangle",
			"target": player_unit,
			"duration": 1
		})
		enemy_unit.show_status_text("ENTANGLE!", "critical")
		enemy_unit.set_meta("entangle_cooldown", ENTANGLE_COOLDOWN)
		actions.append(entangle)
		
		# Po entangle: spawn spirita pokud máme místo
		if spirit_count < MAX_SPIRITS:
			actions.append(_create_spawn_action(enemy_unit))
			return actions
		
		return actions
	
	# === 2. STRATEGICKÝ SPAWN (když hráč je daleko nebo máme málo spiritů) ===
	if spirit_count < MAX_SPIRITS:
		var should_spawn = false
		
		# Vždy spawnuj pokud nemáme žádné spirity
		if spirit_count == 0:
			should_spawn = true
		# Spawnuj pokud hráč je daleko (máme čas)
		elif distance_to_player >= 4:
			should_spawn = true
		# Spawnuj pokud máme méně než 2 spirity
		elif spirit_count < 2:
			should_spawn = true
		
		if should_spawn:
			var spawn = _create_spawn_action(enemy_unit)
			actions.append(spawn)
			
			# Po spawnu: přesuň se na bezpečnou pozici
			if distance_to_player < SAFE_DISTANCE:
				var escape = _find_safe_position(enemy_unit, player_unit, battle_grid)
				if not escape.is_empty():
					actions.append(create_move_action(escape))
			
			return actions
	
	# === 3. NATURE'S GRASP (vytvoří mud terrain pod hráčem) ===
	if distance_to_player <= 4 and not enemy_unit.has_meta("natures_grasp_used"):
		var grasp = create_special_action({
			"type": "natures_grasp",
			"target_position": player_unit.grid_position
		})
		enemy_unit.show_status_text("NATURE'S GRASP!", "critical")
		enemy_unit.set_meta("natures_grasp_used", true)  # Jednorázové
		actions.append(grasp)
		return actions
	
	# === 4. ÚTOK (pokud je v dosahu) ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		actions.append(create_attack_action(player_unit, 1.0))
		
		# Po útoku: ustup pokud jsme blízko
		if distance_to_player < SAFE_DISTANCE:
			var escape = _find_safe_position(enemy_unit, player_unit, battle_grid)
			if not escape.is_empty():
				actions.append(create_move_action(escape))
		
		return actions
	
	# === 5. POHYB + ÚTOK ===
	var safe_pos = find_safe_attack_position(enemy_unit, player_unit, battle_grid, SAFE_DISTANCE)
	if safe_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, safe_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			actions.append(create_attack_action(player_unit, 1.0))
			return actions
	
	# === 6. POUZE POHYB (přiblíž se) ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

func _create_spawn_action(enemy_unit: Unit) -> AIAction:
	"""Vytvoří spawn akci (guardian nebo wolf)"""
	var is_guardian = (randi_range(1, 100) <= GUARDIAN_SPAWN_CHANCE)
	var spawn_action = create_special_action({
		"type": "spawn_spirit",
		"is_guardian": is_guardian
	})
	if is_guardian:
		enemy_unit.show_status_text("GUARDIAN!", "heal")
	else:
		enemy_unit.show_status_text("SUMMON!", "heal")
	return spawn_action

func _count_spirits(unit: Unit, battle_grid: BattleGrid) -> int:
	"""Počet spiritů na gridu"""
	var count = 0
	var all_units = battle_grid.get_all_objects_on_grid()
	for u in all_units:
		if u is Unit and u != unit and is_instance_valid(u):
			if u.unit_data.unit_id.contains("spirit") or u.unit_data.unit_name.contains("Spirit"):
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
