# ===================================================================
# Soubor: res://scripts/ai/AssassinAI.gd
# POPIS: Assassin - rychlý, flanking, shadow strike, double attack, disengage
# ===================================================================
extends EnemyAIBase

const DOUBLE_ATTACK_CHANCE = 25  # 25% šance na double attack
const DOUBLE_ATTACK_DAMAGE_MULTIPLIER = 0.75  # 75% damage při double attack
const SHADOW_STRIKE_MIN_DISTANCE = 4  # Minimální vzdálenost pro shadow strike bonus
const SHADOW_STRIKE_BLINK_RANGE = 6  # Dosah blinku při Shadow Strike
const SHADOW_STRIKE_MULTIPLIER = 1.5  # +50% damage za shadow strike
const DISENGAGE_DISTANCE = 2  # Počet polí pro ústup po útoku
const FLANK_BONUS_MULTIPLIER = 1.3  # +30% damage za flanking

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	
	# === POKUD JSME V DOSAHU ÚTOKU ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var attack = _create_assassin_attack(enemy_unit, player_unit, distance_to_player)
		actions.append(attack)
		
		# Po útoku: pokus o disengage (ústup) - jako speciální akce, ne MOVE
		var disengage_path = _find_disengage_move(enemy_unit, player_unit, battle_grid)
		if not disengage_path.is_empty():
			var disengage = create_special_action({
				"type": "disengage",
				"move_path": disengage_path
			})
			actions.append(disengage)
		
		return actions
	
	# === SHADOW STRIKE: blink z dálky na flank / attack pozici ===
	if distance_to_player >= SHADOW_STRIKE_MIN_DISTANCE:
		var land_pos = _find_shadow_strike_land(enemy_unit, player_unit, battle_grid)
		if land_pos != Vector2i(-1, -1):
			var is_flank = _is_flank_cell(land_pos, player_unit, battle_grid, enemy_unit)
			enemy_unit.show_status_text("SHADOW STRIKE!", "critical")
			actions.append(create_special_action({
				"type": "shadow_strike",
				"target_position": land_pos
			}))
			actions.append(_create_assassin_attack(enemy_unit, player_unit, distance_to_player, true, is_flank))
			return actions
	
	# === NORMÁLNÍ PŘIBLÍŽENÍ + ÚTOK ===
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var move_path = find_path(enemy_unit, attack_pos, battle_grid)
		if not move_path.is_empty():
			var attack = _create_assassin_attack(enemy_unit, player_unit, distance_to_player)
			actions.append(create_move_action(move_path))
			actions.append(attack)
			return actions
	
	# === POKUD NEMŮŽEME DOSÁHNOUT - PŘIBLIŽ SE ===
	var approach_path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not approach_path.is_empty():
		actions.append(create_move_action(approach_path))
		return actions
	
	return [create_pass_action()]

func _find_shadow_strike_land(assassin: Unit, target: Unit, battle_grid: BattleGrid) -> Vector2i:
	"""Najde volnou buňku v dosahu útoku na target, v blink range od assassina."""
	var best_cell := Vector2i(-1, -1)
	var best_score := -INF
	var allies = get_all_enemies(assassin, battle_grid)
	var avg_ally_direction := Vector2i.ZERO
	for ally in allies:
		avg_ally_direction += ally.grid_position - target.grid_position

	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = target.grid_position + offset
		if not battle_grid.is_cell_active(cell):
			continue
		if battle_grid.get_object_on_cell(cell) != null:
			continue
		var terrain = battle_grid.get_terrain_on_cell(cell)
		if terrain and not terrain.is_walkable:
			continue
		var blink_dist = battle_grid.get_distance(assassin.grid_position, cell)
		if blink_dist > SHADOW_STRIKE_BLINK_RANGE:
			continue
		if not can_attack_from_position(cell, assassin, target, battle_grid):
			continue

		var score := 100.0 - float(blink_dist) * 5.0
		var cell_dir = cell - target.grid_position
		if avg_ally_direction != Vector2i.ZERO:
			if cell_dir.x * avg_ally_direction.x < 0 or cell_dir.y * avg_ally_direction.y < 0:
				score += 50.0
		if abs(cell_dir.x) > 0 and abs(cell_dir.y) > 0:
			score += 20.0
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell

func _is_flank_cell(cell: Vector2i, target: Unit, battle_grid: BattleGrid, assassin: Unit) -> bool:
	var allies = get_all_enemies(assassin, battle_grid)
	if allies.is_empty():
		return false
	var avg_ally_direction := Vector2i.ZERO
	for ally in allies:
		avg_ally_direction += ally.grid_position - target.grid_position
	if avg_ally_direction == Vector2i.ZERO:
		return false
	var cell_dir = cell - target.grid_position
	return cell_dir.x * avg_ally_direction.x < 0 or cell_dir.y * avg_ally_direction.y < 0

func _create_assassin_attack(enemy_unit: Unit, target: Unit, distance: int, is_shadow_strike: bool = false, is_flanking: bool = false) -> AIAction:
	var damage_multiplier = 1.0
	var will_double_attack = false
	
	# Shadow strike bonus (útok z velké vzdálenosti)
	if is_shadow_strike and distance >= SHADOW_STRIKE_MIN_DISTANCE:
		damage_multiplier *= SHADOW_STRIKE_MULTIPLIER
	
	# Flank bonus
	if is_flanking:
		damage_multiplier *= FLANK_BONUS_MULTIPLIER
	
	# Double attack šance
	var roll = randi_range(1, 100)
	if roll <= DOUBLE_ATTACK_CHANCE:
		will_double_attack = true
		damage_multiplier *= DOUBLE_ATTACK_DAMAGE_MULTIPLIER
		enemy_unit.show_status_text("DOUBLE STRIKE!", "critical")
	
	var action = create_attack_action(target, damage_multiplier)
	action.special_data["double_attack"] = will_double_attack
	return action

func _find_disengage_move(assassin: Unit, target: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	"""Po útoku se pokusí ustoupit od cíle"""
	var reachable = get_reachable_cells(assassin, battle_grid)
	var best_cell = assassin.grid_position
	var best_distance = battle_grid.get_distance(assassin.grid_position, target.grid_position)
	
	for cell in reachable:
		var dist = battle_grid.get_distance(cell, target.grid_position)
		var move_dist = battle_grid.get_distance(assassin.grid_position, cell)
		
		# Ustup max DISENGAGE_DISTANCE polí, co nejdál od cíle
		if move_dist <= DISENGAGE_DISTANCE and dist > best_distance:
			best_distance = dist
			best_cell = cell
	
	if best_cell != assassin.grid_position:
		return find_path(assassin, best_cell, battle_grid)
	
	return []
