# ===================================================================
# Soubor: res://scripts/ai/AssassinAI.gd
# POPIS: Assassin - rychlý, flanking, shadow strike, double attack, disengage
# ===================================================================
extends EnemyAIBase

const DOUBLE_ATTACK_CHANCE = 25  # 25% šance na double attack
const DOUBLE_ATTACK_DAMAGE_MULTIPLIER = 0.75  # 75% damage při double attack
const SHADOW_STRIKE_MIN_DISTANCE = 4  # Minimální vzdálenost pro shadow strike bonus
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
	
	# === SHADOW STRIKE: Přiblíž se z velké vzdálenosti a zaútoč s bonusem ===
	if distance_to_player >= SHADOW_STRIKE_MIN_DISTANCE:
		# Zkus najít flank pozici (za hráčem)
		var flank_pos = _find_flank_position(enemy_unit, player_unit, battle_grid)
		if flank_pos != Vector2i(-1, -1):
			var path = find_path(enemy_unit, flank_pos, battle_grid)
			if not path.is_empty():
				var attack = _create_assassin_attack(enemy_unit, player_unit, distance_to_player, true, true)
				actions.append(create_move_action(path))
				actions.append(attack)
				return actions
		
		# Zkus normální attack pozici pokud flank nefunguje
		var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
		if attack_pos != Vector2i(-1, -1):
			var path = find_path(enemy_unit, attack_pos, battle_grid)
			if not path.is_empty():
				var attack = _create_assassin_attack(enemy_unit, player_unit, distance_to_player, true, false)
				actions.append(create_move_action(path))
				actions.append(attack)
				return actions
	
	# === NORMÁLNÍ PŘIBLÍŽENÍ + ÚTOK ===
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			var attack = _create_assassin_attack(enemy_unit, player_unit, distance_to_player)
			actions.append(create_move_action(path))
			actions.append(attack)
			return actions
	
	# === POKUD NEMŮŽEME DOSÁHNOUT - PŘIBLIŽ SE ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

func _create_assassin_attack(enemy_unit: Unit, target: Unit, distance: int, is_shadow_strike: bool = false, is_flanking: bool = false) -> AIAction:
	var damage_multiplier = 1.0
	var will_double_attack = false
	
	# Shadow strike bonus (útok z velké vzdálenosti)
	if is_shadow_strike and distance >= SHADOW_STRIKE_MIN_DISTANCE:
		damage_multiplier *= SHADOW_STRIKE_MULTIPLIER
		enemy_unit.show_status_text("SHADOW STRIKE!", "critical")
	
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

func _find_flank_position(assassin: Unit, target: Unit, battle_grid: BattleGrid) -> Vector2i:
	"""Najde pozici za cílem (flanking)"""
	var reachable = get_reachable_cells(assassin, battle_grid)
	var best_cell = Vector2i(-1, -1)
	var best_score = -INF
	
	# Preferujeme pozice, které jsou na opačné straně od ostatních nepřátel
	var allies = get_all_enemies(assassin, battle_grid)
	var avg_ally_direction = Vector2i.ZERO
	for ally in allies:
		var dir = ally.grid_position - target.grid_position
		avg_ally_direction += dir
	
	for cell in reachable:
		if not can_attack_from_position(cell, assassin, target, battle_grid):
			continue
		
		var score = 0.0
		var cell_dir = cell - target.grid_position
		
		# Bonus za pozici na opačné straně od spojenců (flanking)
		if avg_ally_direction != Vector2i.ZERO:
			# Opačný směr = lepší flank
			if cell_dir.x * avg_ally_direction.x < 0 or cell_dir.y * avg_ally_direction.y < 0:
				score += 50.0
		
		# Bonus za diagonální pozice
		if abs(cell_dir.x) > 0 and abs(cell_dir.y) > 0:
			score += 20.0
		
		if score > best_score:
			best_score = score
			best_cell = cell
	
	return best_cell

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
