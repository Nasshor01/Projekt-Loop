# ===================================================================
# Soubor: res://scripts/ai/MageAI.gd
# POPIS: Mage - bojuje z dálky, elementální poškození, meteorit po 10 kolech
# ===================================================================
extends EnemyAIBase

const METEOR_TURNS_REQUIRED = 10  # Po 10 kolech hodí meteorit
const METEOR_DAMAGE_MULTIPLIER = 2.0  # Poškození meteoritu
const PREFERRED_DISTANCE = 5  # Preferovaná vzdálenost

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# Inicializace turn counteru
	if not enemy_unit.has_meta("mage_turn_count"):
		enemy_unit.set_meta("mage_turn_count", 0)
	
	var turn_count = enemy_unit.get_meta("mage_turn_count")
	turn_count += 1
	enemy_unit.set_meta("mage_turn_count", turn_count)
	
	# 1. KONTROLA METEORITU (po 10 kolech)
	if turn_count >= METEOR_TURNS_REQUIRED:
		enemy_unit.show_status_text("METEORIT!", "critical")
		var meteor_action = create_special_action({
			"type": "meteor",
			"damage_multiplier": METEOR_DAMAGE_MULTIPLIER
		})
		enemy_unit.set_meta("mage_turn_count", 0)  # Reset counteru
		return meteor_action
	
	# 2. ÚTOK Z DÁLKY (elementální poškození)
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		# Elementální poškození - aplikuje burning
		var action = create_attack_action(player_unit, 1.0)
		action.special_data["elemental_damage"] = true
		action.special_data["element_type"] = "fire"  # Může být fire, ice, lightning
		return action
	
	# 3. POHYB - udržuje vzdálenost
	if distance_to_player < PREFERRED_DISTANCE:
		# Příliš blízko, couvne
		var escape_path = find_escape_move(enemy_unit, player_unit, battle_grid)
		if not escape_path.path.is_empty():
			return create_move_action(escape_path.path)
	
	# 4. PASS pokud nemůže nic udělat
	return create_pass_action()

func find_escape_move(mage: Unit, player: Unit, battle_grid: BattleGrid) -> Dictionary:
	var reachable_cells = get_reachable_cells(mage, battle_grid)
	var best_cell = mage.grid_position
	var best_distance = battle_grid.get_distance(mage.grid_position, player.grid_position)
	
	for cell in reachable_cells:
		var unit_on_cell = battle_grid.get_object_on_cell(cell)
		if is_instance_valid(unit_on_cell) and unit_on_cell != mage:
			continue
		
		var distance = battle_grid.get_distance(cell, player.grid_position)
		if distance > best_distance:
			best_distance = distance
			best_cell = cell
	
	var path = []
	if best_cell != mage.grid_position:
		path = find_path(mage, best_cell, battle_grid)
	
	return {"cell": best_cell, "path": path, "distance": best_distance}

