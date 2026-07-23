# ===================================================================
# Soubor: res://scripts/ai/MageAI.gd
# POPIS: Mage - spell rotation, elementální damage, meteorit (AoE grid-wide)
# ===================================================================
extends EnemyAIBase

const METEOR_TURNS_REQUIRED = 6  # Po 6 kolech hodí meteorit (sníženo z 10)
const METEOR_DAMAGE_MULTIPLIER = 2.0  # Poškození meteoritu (AoE na CELÝ GRID)
const PREFERRED_DISTANCE = 4  # Preferovaná vzdálenost
const MELEE_DANGER_RANGE = 2  # Pod tuto vzdálenost teleportuje
const ARCANE_SHIELD_AMOUNT = 5  # Block z arcane shield
const TELEPORT_DISTANCE = 4  # Vzdálenost teleportu

# Spell rotation: fire -> ice -> lightning -> arcane_shield -> fire -> ...
const SPELL_CYCLE = ["fire", "ice", "lightning", "arcane_shield"]

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	# Inicializace turn counteru a spell indexu
	if not enemy_unit.has_meta("mage_turn_count"):
		enemy_unit.set_meta("mage_turn_count", 0)
	if not enemy_unit.has_meta("spell_index"):
		enemy_unit.set_meta("spell_index", 0)
	
	var turn_count = enemy_unit.get_meta("mage_turn_count")
	turn_count += 1
	enemy_unit.set_meta("mage_turn_count", turn_count)
	
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	
	# === 1. METEORIT (po 6 kolech) - AoE na celý grid ===
	if turn_count >= METEOR_TURNS_REQUIRED:
		enemy_unit.show_status_text("METEORIT!", "critical")
		var meteor_action = create_special_action({
			"type": "meteor",
			"damage_multiplier": METEOR_DAMAGE_MULTIPLIER
		})
		enemy_unit.set_meta("mage_turn_count", 0)
		return [meteor_action]
	
	# === 2. ÚNIK Z MELEE ZÓNY (teleport) ===
	if distance_to_player <= MELEE_DANGER_RANGE:
		var teleport_pos = _find_teleport_position(enemy_unit, player_unit, battle_grid)
		if teleport_pos != Vector2i(-1, -1):
			enemy_unit.show_status_text("TELEPORT!", "critical")
			var teleport = create_special_action({
				"type": "teleport",
				"target_position": teleport_pos
			})
			actions.append(teleport)
			
			# Po teleportu: spell pokud je v dosahu
			if can_attack_from_position(teleport_pos, enemy_unit, player_unit, battle_grid):
				var spell = _get_current_spell(enemy_unit, player_unit)
				actions.append(spell)
			
			return actions
		
		# Nemůže teleportovat, zaútočí zblízka (panic cast)
		if can_attack_target(enemy_unit, player_unit, battle_grid):
			var action = create_attack_action(player_unit, 0.7)
			action.special_data["elemental_damage"] = true
			action.special_data["element_type"] = "fire"
			return [action]
	
	# === 3. SPELL Z DOSAHU ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var spell = _get_current_spell(enemy_unit, player_unit)
		
		# Pokud je příliš blízko, couvni po spellu
		if distance_to_player <= PREFERRED_DISTANCE - 1:
			actions.append(spell)
			var escape = _find_escape_move(enemy_unit, player_unit, battle_grid)
			if not escape.is_empty():
				actions.append(create_move_action(escape))
			return actions
		
		return [spell]
	
	# === 4. POHYB + SPELL ===
	# Najdi pozici v dosahu a s bezpečnou vzdáleností
	var safe_pos = find_safe_attack_position(enemy_unit, player_unit, battle_grid, MELEE_DANGER_RANGE)
	if safe_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, safe_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			var spell = _get_current_spell(enemy_unit, player_unit)
			actions.append(spell)
			return actions
	
	# Žádná bezpečná pozice - zkus alespoň přiblížit
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			var spell = _get_current_spell(enemy_unit, player_unit)
			actions.append(spell)
			return actions
	
	# === 5. POUZE POHYB ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

func _get_current_spell(enemy_unit: Unit, target: Unit) -> AIAction:
	"""Vrátí aktuální spell podle rotace"""
	var spell_index = enemy_unit.get_meta("spell_index", 0)
	var spell_type = SPELL_CYCLE[spell_index % SPELL_CYCLE.size()]
	
	# Posuň spell index pro příští tah
	enemy_unit.set_meta("spell_index", spell_index + 1)
	
	match spell_type:
		"fire":
			# Fireball: normální dmg + burning
			var action = create_attack_action(target, 1.0)
			action.special_data["elemental_damage"] = true
			action.special_data["element_type"] = "fire"
			return action
		
		"ice":
			# Ice Shard: normální dmg + chilled (zpomalení)
			var action = create_attack_action(target, 0.8)
			action.special_data["elemental_damage"] = true
			action.special_data["element_type"] = "ice"
			return action
		
		"lightning":
			# Lightning Bolt: zvýšený dmg + shocked
			var action = create_attack_action(target, 1.3)
			action.special_data["elemental_damage"] = true
			action.special_data["element_type"] = "lightning"
			return action
		
		"arcane_shield":
			# Arcane Shield: dá si block
			var shield_action = create_special_action({
				"type": "arcane_shield",
				"block_amount": ARCANE_SHIELD_AMOUNT
			})
			enemy_unit.show_status_text("ARCANE SHIELD!", "heal")
			return shield_action
	
	# Fallback
	return create_attack_action(target, 1.0)

func _find_teleport_position(mage: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	"""Najde pozici pro teleport - daleko od hráče, v dosahu útoku"""
	var best_cell = Vector2i(-1, -1)
	var best_score = -INF
	
	var grid_size = Vector2i(battle_grid.grid_columns, battle_grid.grid_rows)
	
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell = Vector2i(x, y)
			if not battle_grid.is_cell_active(cell):
				continue
			
			var obj = battle_grid.get_object_on_cell(cell)
			if obj != null and obj != mage:
				continue
			
			var terrain = battle_grid.get_terrain_on_cell(cell)
			if terrain and not terrain.is_walkable:
				continue
			
			var dist_to_player = battle_grid.get_distance(cell, player.grid_position)
			var dist_from_mage = battle_grid.get_distance(mage.grid_position, cell)
			
			# Teleport musí být v rozumném dosahu
			if dist_from_mage > TELEPORT_DISTANCE + 2:
				continue
			
			var score = 0.0
			
			# Preferuj pozice daleko od hráče
			score += dist_to_player * 10.0
			
			# Bonus pokud je v útočném dosahu
			if dist_to_player <= mage.unit_data.attack_range:
				score += 100.0
			
			# Penalizace za příliš blízko
			if dist_to_player <= MELEE_DANGER_RANGE:
				score -= 200.0
			
			if score > best_score:
				best_score = score
				best_cell = cell
	
	return best_cell

func _find_escape_move(mage: Unit, player: Unit, battle_grid: BattleGrid) -> Array[Vector2i]:
	"""Najde únikovou cestu dál od hráče"""
	var reachable = get_reachable_cells(mage, battle_grid)
	var best_cell = mage.grid_position
	var best_score = -INF
	
	for cell in reachable:
		var obj = battle_grid.get_object_on_cell(cell)
		if obj != null and obj != mage:
			continue
		
		var dist = battle_grid.get_distance(cell, player.grid_position)
		var score = dist * 10.0
		
		# Bonus pokud je stále v útočném dosahu
		if dist <= mage.unit_data.attack_range:
			score += 50.0
		
		if score > best_score:
			best_score = score
			best_cell = cell
	
	if best_cell != mage.grid_position:
		return find_path(mage, best_cell, battle_grid)
	return []
