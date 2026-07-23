# ===================================================================
# Soubor: res://scripts/ai/BerserkerAI.gd
# POPIS: Berserker - agresivní, rostoucí zuřivost, rush, tremor
# ===================================================================
extends EnemyAIBase

const MAX_MOVEMENT_RANGE = 2  # Berserker má pohyb 2 (zvýšeno z 1)
const RAGE_TURNS_REQUIRED = 3  # Po 3 kolech bez útoku aktivuje rush (sníženo z 5)
const RUSH_DAMAGE_MULTIPLIER = 1.8  # 180% damage při rush útoku (sníženo z 300%)
const FRUSTRATION_DAMAGE_BONUS = 0.10  # +10% damage za každé kolo frustrace (sníženo z 15%)
const LOW_HP_THRESHOLD = 0.5  # Pod 50% HP: rage boost
const LOW_HP_DAMAGE_BONUS = 1.25  # +25% damage pod 50% HP (sníženo z 50%)
const LOW_HP_EXTRA_MOVEMENT = 1  # +1 pohyb pod 50% HP
const TREMOR_RANGE = 2  # Dosah tremor útoku
const TREMOR_DAMAGE_MULTIPLIER = 0.5  # 50% damage pro tremor
const MAX_DAMAGE_MULTIPLIER = 3.0  # Tvrdý cap na celkový multiplikátor

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]

	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	var health_percent = float(enemy_unit.current_health) / float(enemy_unit.unit_data.max_health)
	var is_low_hp = health_percent < LOW_HP_THRESHOLD
	
	# Zjistíme rage stav
	if enemy_unit.berserker_frustration >= RAGE_TURNS_REQUIRED:
		if not enemy_unit.is_permanently_enraged:
			enemy_unit.show_status_text("RAGE!", "critical")
		enemy_unit.is_permanently_enraged = true
	
	# Low HP auto-rage
	if is_low_hp and not enemy_unit.is_permanently_enraged:
		enemy_unit.is_permanently_enraged = true
		enemy_unit.show_status_text("BLOOD RAGE!", "critical")
	
	# Vypočítej damage multiplikátor
	var damage_mult = _get_damage_multiplier(enemy_unit, is_low_hp)

	# === 1. RUSH ÚTOK (v rage módu, na přímce) ===
	if enemy_unit.is_permanently_enraged:
		var same_line = (enemy_unit.grid_position.x == player_unit.grid_position.x)
		var same_column = (enemy_unit.grid_position.y == player_unit.grid_position.y)
		
		if same_line or same_column:
			var rush_path = _find_rush_path(enemy_unit, player_unit, battle_grid)
			if not rush_path.is_empty():
				return [create_rush_action(player_unit, rush_path, RUSH_DAMAGE_MULTIPLIER * damage_mult)]

	# === 2. MELEE ÚTOK (pokud v dosahu) ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		actions.append(create_attack_action(player_unit, damage_mult))
		return actions

	# === 3. MOVE + ATTACK (pohyb a pak útok) ===
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			actions.append(create_attack_action(player_unit, damage_mult))
			return actions

	# === 4. TREMOR - pokud nemůže dosáhnout hráče ale je blízko ===
	if distance_to_player <= TREMOR_RANGE + MAX_MOVEMENT_RANGE and enemy_unit.berserker_frustration >= 2:
		# Pohni se co nejblíže
		var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
		
		# Tremor útok (AoE kolem sebe)
		var tremor = create_special_action({
			"type": "tremor",
			"damage_multiplier": TREMOR_DAMAGE_MULTIPLIER * damage_mult,
			"range": TREMOR_RANGE
		})
		actions.append(tremor)
		return actions

	# === 5. POHYB směrem k hráči ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions

	return [create_pass_action()]

func _get_damage_multiplier(enemy_unit: Unit, is_low_hp: bool) -> float:
	var mult = 1.0
	
	# Frustrace bonus (+10% za každé kolo bez útoku)
	mult += enemy_unit.berserker_frustration * FRUSTRATION_DAMAGE_BONUS
	
	# Low HP bonus
	if is_low_hp:
		mult *= LOW_HP_DAMAGE_BONUS
	
	# Rage mode bonus
	if enemy_unit.is_permanently_enraged:
		mult *= 1.3
	
	# Tvrdý cap aby damage neexplodoval
	return min(mult, MAX_DAMAGE_MULTIPLIER)

func _find_rush_path(from_unit: Unit, to_unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	var adjacent_cells = _get_adjacent_walkable_cells(to_unit, battle_grid)
	if adjacent_cells.is_empty():
		return []
	
	var rush_movement_range = 15
	var best_path: Array[Vector2i] = []
	var shortest_distance = INF
	
	for target_cell in adjacent_cells:
		var path = find_path_with_movement_limit(from_unit, target_cell, battle_grid, rush_movement_range)
		if not path.is_empty() and path.size() < shortest_distance:
			shortest_distance = path.size()
			best_path = path
	
	return best_path

func _get_adjacent_walkable_cells(unit: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
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
