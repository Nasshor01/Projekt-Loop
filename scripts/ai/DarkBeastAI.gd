# ===================================================================
# Soubor: res://scripts/ai/DarkBeastAI.gd
# POPIS: DarkBeast - agresivní, pounce, bite (bleeding), howl
# ===================================================================
extends EnemyAIBase

const POUNCE_MIN_DISTANCE = 3  # Minimální vzdálenost pro pounce
const POUNCE_DAMAGE_MULTIPLIER = 1.5  # +50% damage za pounce
const BITE_BLEEDING_CHANCE = 25  # 25% šance na bleeding
const BITE_BLEEDING_DAMAGE = 2  # Damage za kolo bleeding
const BITE_BLEEDING_DURATION = 3  # Trvání bleeding (kola)
const HOWL_HP_THRESHOLD = 0.3  # Pod 30% HP: howl
const HOWL_BUFF_AMOUNT = 2  # +2 damage pro spojence
const HOWL_BUFF_DURATION = 3  # Trvání howl buffu

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	var health_pct = float(enemy_unit.current_health) / float(enemy_unit.unit_data.max_health)
	
	# Inicializace
	if not enemy_unit.has_meta("has_howled"):
		enemy_unit.set_meta("has_howled", false)
	
	# === 1. HOWL (pod 30% HP, jednorázové) ===
	if health_pct <= HOWL_HP_THRESHOLD and not enemy_unit.get_meta("has_howled"):
		enemy_unit.set_meta("has_howled", true)
		enemy_unit.show_status_text("HOWL!", "critical")
		var howl = create_special_action({
			"type": "howl",
			"buff_amount": HOWL_BUFF_AMOUNT,
			"duration": HOWL_BUFF_DURATION
		})
		actions.append(howl)
		
		# Po howlu: ještě zaútoč pokud jsi v dosahu
		if can_attack_target(enemy_unit, player_unit, battle_grid):
			actions.append(_create_bite_attack(enemy_unit, player_unit))
		
		return actions
	
	# === 2. POUNCE (skok z velké vzdálenosti) ===
	if distance_to_player >= POUNCE_MIN_DISTANCE:
		var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
		if attack_pos != Vector2i(-1, -1):
			var path = find_path(enemy_unit, attack_pos, battle_grid)
			if not path.is_empty():
				enemy_unit.show_status_text("POUNCE!", "critical")
				actions.append(create_move_action(path))
				# Pounce damage (zvýšený)
				var pounce_attack = create_attack_action(player_unit, POUNCE_DAMAGE_MULTIPLIER)
				pounce_attack.special_data["is_pounce"] = true
				actions.append(pounce_attack)
				return actions
		
		# Nemůže dosáhnout na hráče - přibliž se
		var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			return actions
	
	# === 3. BITE (normální útok v dosahu s šancí na bleeding) ===
	if can_attack_target(enemy_unit, player_unit, battle_grid):
		actions.append(_create_bite_attack(enemy_unit, player_unit))
		return actions
	
	# === 4. MOVE + BITE ===
	var attack_pos = find_attack_move_position(enemy_unit, player_unit, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			actions.append(_create_bite_attack(enemy_unit, player_unit))
			return actions
	
	# === 5. POHYB ===
	var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
		return actions
	
	return [create_pass_action()]

func _create_bite_attack(enemy_unit: Unit, target: Unit) -> AIAction:
	"""Vytvoří bite útok s šancí na bleeding"""
	var action = create_attack_action(target, 1.0)
	
	# Šance na bleeding
	var roll = randi_range(1, 100)
	if roll <= BITE_BLEEDING_CHANCE:
		action.special_data["apply_bleeding"] = true
		action.special_data["bleeding_damage"] = BITE_BLEEDING_DAMAGE
		action.special_data["bleeding_duration"] = BITE_BLEEDING_DURATION
		enemy_unit.show_status_text("BITE!", "critical")
	
	return action
