# ===================================================================
# Soubor: res://scripts/ai/BossAI.gd
# POPIS: Boss AI - multi-fázová, agresivní, unikátní schopnosti
#        Používá se pro Boss DemonGirl (a další bossy)
# ===================================================================
extends EnemyAIBase

# Fáze 1 (>50% HP): Normal aggression
const PHASE2_THRESHOLD = 0.5  # Pod 50% HP přejde do fáze 2
const DARK_SLASH_COOLDOWN = 3  # Každé 3. kolo: dark slash
const DARK_SLASH_RANGE = 2  # Dosah dark slash (line attack)
const DARK_SLASH_MULTIPLIER = 1.5  # 150% damage
const DEMON_AURA_RANGE = 2  # Dosah demon aury
const DEMON_AURA_DAMAGE = 2  # Damage demon aury za kolo

# Fáze 2 (<50% HP): Enraged
const PHASE2_DAMAGE_BONUS = 1.3  # +30% damage v fázi 2
const PHASE2_EXTRA_MOVEMENT = 1  # +1 pohyb v fázi 2
const SHADOW_DASH_RANGE = 6  # Dosah shadow dash (teleport + útok)
const SHADOW_DASH_MULTIPLIER = 1.5  # 150% damage po shadow dash
const HELLFIRE_COOLDOWN = 4  # Každé 4. kolo: hellfire
const HELLFIRE_RANGE = 2  # AoE dosah hellfire
const HELLFIRE_MULTIPLIER = 1.8  # 180% damage
const DARK_BARRIER_BLOCK = 8  # Block na začátku tahu v fázi 2

func get_actions(enemy_unit: Unit, all_player_units: Array, battle_grid: BattleGrid) -> Array[AIAction]:
	var actions: Array[AIAction] = []
	var player_unit = find_closest_player(enemy_unit, all_player_units)
	if not is_instance_valid(player_unit):
		return [create_pass_action()]
	
	# Inicializace
	if not enemy_unit.has_meta("boss_turn_count"):
		enemy_unit.set_meta("boss_turn_count", 0)
	if not enemy_unit.has_meta("boss_phase"):
		enemy_unit.set_meta("boss_phase", 1)
	
	var turn_count = enemy_unit.get_meta("boss_turn_count")
	turn_count += 1
	enemy_unit.set_meta("boss_turn_count", turn_count)
	
	var health_pct = float(enemy_unit.current_health) / float(enemy_unit.unit_data.max_health)
	var current_phase = enemy_unit.get_meta("boss_phase")
	var distance_to_player = battle_grid.get_distance(enemy_unit.grid_position, player_unit.grid_position)
	
	# Fáze přechod
	if health_pct <= PHASE2_THRESHOLD and current_phase == 1:
		current_phase = 2
		enemy_unit.set_meta("boss_phase", 2)
		enemy_unit.show_status_text("ENRAGED!", "critical")
	
	# === FÁZE 2: DARK BARRIER na začátku tahu ===
	if current_phase == 2:
		var barrier = create_special_action({
			"type": "dark_barrier",
			"block_amount": DARK_BARRIER_BLOCK
		})
		actions.append(barrier)
	
	# === DEMON AURA (pasivní damage pokud hráč je blízko) ===
	if distance_to_player <= DEMON_AURA_RANGE:
		var aura = create_special_action({
			"type": "demon_aura",
			"target": player_unit,
			"damage": DEMON_AURA_DAMAGE + (2 if current_phase == 2 else 0)
		})
		actions.append(aura)
	
	# === FÁZE-SPECIFICKÉ SCHOPNOSTI ===
	if current_phase == 1:
		actions.append_array(_phase1_actions(enemy_unit, player_unit, battle_grid, turn_count, distance_to_player))
	else:
		actions.append_array(_phase2_actions(enemy_unit, player_unit, battle_grid, turn_count, distance_to_player))
	
	# Pokud jsme nepřidali žádnou útočnou/pohybovou akci
	if actions.size() <= (2 if current_phase == 2 else 1):
		# Alespoň se pohni k hráči
		var path = find_path_to_adjacent(enemy_unit, player_unit, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
	
	if actions.is_empty():
		return [create_pass_action()]
	
	return actions

func _phase1_actions(enemy_unit: Unit, player: Unit, battle_grid: BattleGrid, turn_count: int, distance: int) -> Array[AIAction]:
	"""Fáze 1: Normální agrese - move+attack, dark slash"""
	var actions: Array[AIAction] = []
	
	# Dark Slash (každé 3. kolo)
	if turn_count % DARK_SLASH_COOLDOWN == 0 and distance <= DARK_SLASH_RANGE:
		enemy_unit.show_status_text("DARK SLASH!", "critical")
		var slash = create_special_action({
			"type": "dark_slash",
			"target": player,
			"damage_multiplier": DARK_SLASH_MULTIPLIER,
			"range": DARK_SLASH_RANGE
		})
		actions.append(slash)
		return actions
	
	# Normální útok pokud v dosahu
	if can_attack_target(enemy_unit, player, battle_grid):
		actions.append(create_attack_action(player, 1.0))
		return actions
	
	# Move + Attack
	var attack_pos = find_attack_move_position(enemy_unit, player, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			actions.append(create_attack_action(player, 1.0))
			return actions
	
	# Pouze pohyb
	var path = find_path_to_adjacent(enemy_unit, player, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
	
	return actions

func _phase2_actions(enemy_unit: Unit, player: Unit, battle_grid: BattleGrid, turn_count: int, distance: int) -> Array[AIAction]:
	"""Fáze 2: Zuřivost - shadow dash, hellfire, zvýšený damage"""
	var actions: Array[AIAction] = []
	
	# Hellfire (každé 4. kolo, AoE kolem sebe)
	if turn_count % HELLFIRE_COOLDOWN == 0:
		# Pokud jsme blízko hráči, hellfire
		if distance <= HELLFIRE_RANGE + 1:
			enemy_unit.show_status_text("HELLFIRE!", "critical")
			var hellfire = create_special_action({
				"type": "hellfire",
				"damage_multiplier": HELLFIRE_MULTIPLIER,
				"range": HELLFIRE_RANGE
			})
			actions.append(hellfire)
			return actions
		else:
			# Pohni se blíž a pak hellfire
			var attack_pos = find_attack_move_position(enemy_unit, player, battle_grid)
			if attack_pos != Vector2i(-1, -1):
				var path = find_path(enemy_unit, attack_pos, battle_grid)
				if not path.is_empty():
					actions.append(create_move_action(path))
			
			enemy_unit.show_status_text("HELLFIRE!", "critical")
			var hellfire = create_special_action({
				"type": "hellfire",
				"damage_multiplier": HELLFIRE_MULTIPLIER,
				"range": HELLFIRE_RANGE
			})
			actions.append(hellfire)
			return actions
	
	# Shadow Dash (teleport + útok pokud je hráč daleko)
	if distance > 2:
		var dash_pos = _find_shadow_dash_position(enemy_unit, player, battle_grid)
		if dash_pos != Vector2i(-1, -1):
			enemy_unit.show_status_text("SHADOW DASH!", "critical")
			var dash = create_special_action({
				"type": "shadow_dash",
				"target_position": dash_pos
			})
			actions.append(dash)
			actions.append(create_attack_action(player, SHADOW_DASH_MULTIPLIER * PHASE2_DAMAGE_BONUS))
			return actions
	
	# Normální útok s damage bonusem
	if can_attack_target(enemy_unit, player, battle_grid):
		actions.append(create_attack_action(player, PHASE2_DAMAGE_BONUS))
		return actions
	
	# Move + Attack s bonusem
	var attack_pos = find_attack_move_position(enemy_unit, player, battle_grid)
	if attack_pos != Vector2i(-1, -1):
		var path = find_path(enemy_unit, attack_pos, battle_grid)
		if not path.is_empty():
			actions.append(create_move_action(path))
			actions.append(create_attack_action(player, PHASE2_DAMAGE_BONUS))
			return actions
	
	# Pohyb
	var path = find_path_to_adjacent(enemy_unit, player, battle_grid)
	if not path.is_empty():
		actions.append(create_move_action(path))
	
	return actions

func _find_shadow_dash_position(boss: Unit, player: Unit, battle_grid: BattleGrid) -> Vector2i:
	"""Najde pozici vedle hráče pro shadow dash (teleport)"""
	var best_cell = Vector2i(-1, -1)
	
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell = player.grid_position + offset
		if battle_grid.is_cell_active(cell):
			var obj = battle_grid.get_object_on_cell(cell)
			if obj == null or obj == boss:
				var terrain = battle_grid.get_terrain_on_cell(cell)
				if not terrain or terrain.is_walkable:
					var dist = battle_grid.get_distance(boss.grid_position, cell)
					if dist <= SHADOW_DASH_RANGE:
						best_cell = cell
						break
	
	return best_cell
