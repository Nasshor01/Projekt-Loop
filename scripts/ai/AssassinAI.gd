# ===================================================================
# Soubor: res://scripts/ai/AssassinAI.gd
# POPIS: Assassin - rychlý pohyb, double attack (25%), dodge (35%)
# ===================================================================
extends EnemyAIBase

const DOUBLE_ATTACK_CHANCE = 25  # 25% šance na double attack
const DOUBLE_ATTACK_DAMAGE_MULTIPLIER = 0.75  # 75% damage při double attack
const DODGE_CHANCE = 35  # 35% šance na dodge
const EXTRA_MOVEMENT = 2  # Bonusový pohyb

func get_next_action(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> AIAction:
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return create_pass_action()
	
	# 1. Pokud můžeme zaútočit, zaútočíme (s možností double attack)
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		var damage_multiplier = 1.0
		var will_double_attack = false
		
		# 25% šance na double attack
		var roll = randi_range(1, 100)
		if roll <= DOUBLE_ATTACK_CHANCE:
			will_double_attack = true
			damage_multiplier = DOUBLE_ATTACK_DAMAGE_MULTIPLIER
			enemy_unit.show_status_text("DVOJITÝ ÚTOK!", "critical")
		
		var action = create_attack_action(player_unit, damage_multiplier)
		action.special_data["double_attack"] = will_double_attack
		return action
	
	# 2. Pokud nemůžeme zaútočit, pokusíme se přiblížit (s bonusovým pohybem)
	# Použijeme find_path_to_adjacent, abychom našli cestu k sousednímu poli hráče
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		# find_path_to_adjacent vrací cestu k nejbližšímu sousednímu poli
		# Assassin má movement_range 5 + EXTRA_MOVEMENT 2 = 7, takže cesta by měla být vždy dosažitelná
		return create_move_action(path)
	
	# 3. Nemůžeme se pohnout ani zaútočit
	return create_pass_action()
