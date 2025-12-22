# ===================================================================
# Soubor: res://scripts/ai/FighterAI.gd
# POPIS: Jednoduchá melee AI - jdi a zaútoč
# ===================================================================
extends EnemyAIBase

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# 1. Pokud můžeme zaútočit, zaútočíme
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		print("Fighter útočí na hráče!")
		return create_attack_action(player_unit)
	
	# 2. Pokud nemůžeme zaútočit, pokusíme se přiblížit
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		print("Fighter se pohybuje směrem k hráči")
		return create_move_action(path)
	
	# 3. Nemůžeme se pohnout ani zaútočit
	print("Fighter nemůže najít cestu k hráči")
	return create_pass_action()
