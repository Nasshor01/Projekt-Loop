# ===================================================================
# Soubor: res://scripts/ai/DruidAI.gd
# POPIS: Druid - spawnuje spirity, 5% šance na spawn ochránce
# ===================================================================
extends EnemyAIBase

const SPIRIT_SPAWN_CHANCE = 30  # 30% šance na spawn spiritu každé kolo
const GUARDIAN_SPAWN_CHANCE = 5  # 5% šance na spawn ochránce
const MAX_SPIRITS = 3  # Maximální počet spiritů najednou

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# Počítáme existující spirity
	var spirit_count = count_allies_of_type(enemy_unit, battle_grid, "spirit")
	
	# 1. SPAWN SPIRITŮ (pokud máme méně než max)
	if spirit_count < MAX_SPIRITS:
		var spawn_roll = randi_range(1, 100)
		if spawn_roll <= SPIRIT_SPAWN_CHANCE:
			# 5% šance na ochránce, jinak normální spirit
			var is_guardian = (randi_range(1, 100) <= GUARDIAN_SPAWN_CHANCE)
			var spawn_action = create_special_action({
				"type": "spawn_spirit",
				"is_guardian": is_guardian
			})
			enemy_unit.show_status_text("SPAWN!", "heal")
			return spawn_action
	
	# 2. ÚTOK (pokud můžeme)
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		return create_attack_action(player_unit, 1.0)
	
	# 3. POHYB směrem k hráči
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		return create_move_action(path)
	
	# 4. PASS
	return create_pass_action()

func count_allies_of_type(unit: Unit, battle_grid: BattleGrid, unit_type: String) -> int:
	var count = 0
	var all_units = battle_grid.get_all_objects_on_grid()
	
	for u in all_units:
		if u is Unit and u != unit:
			# Zkontrolujeme, jestli je to spirit (podle unit_id nebo názvu)
			if u.unit_data.unit_id.contains(unit_type) or u.unit_data.unit_name.contains("Spirit"):
				count += 1
	
	return count
