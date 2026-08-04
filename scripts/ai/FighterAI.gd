# ===================================================================
# Soubor: res://scripts/ai/FighterAI.gd
# POPIS: Melee AI - pohyb + útok v jednom tahu, taktické rozhodování
# ===================================================================
extends EnemyAIBase

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	# 1. Pokud jsme v dosahu útoku - zaútoč rovnou
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		actions.append(create_attack_action(player_unit))
		return actions
	
	# 2. Pokud nejsme v dosahu - pohni se a pak zaútoč
	# Najdi pozici, ze které můžeme zaútočit
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	var move_path: Array = []
	
	if attack_pos != Vector2i(-1, -1):
		# Můžeme se přesunout na pozici, odkud dosáhneme na hráče
		move_path = find_path(enemy_unit, attack_pos, battle_grid)
		if not move_path.is_empty():
			actions.append(create_move_action(move_path))
			actions.append(create_attack_action(player_unit))
			return actions
	
	# 3. Nemůžeme dosáhnout na hráče tento tah - přibliž se co nejvíc
	move_path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not move_path.is_empty():
		actions.append(create_move_action(move_path))
		return actions
	
	# 4. Nemůžeme se pohnout ani zaútočit
	return [create_pass_action()]
