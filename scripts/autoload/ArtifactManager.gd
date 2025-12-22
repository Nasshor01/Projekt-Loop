# Soubor: scripts/autoload/ArtifactManager.gd
extends Node

signal artifact_triggered(artifact_name: String, effect_description: String)

var _passive_artifacts: Array[ArtifactsData] = []
var _triggered_artifacts: Dictionary = {}

func _ready():
	if PlayerData:
		PlayerData.artifacts_changed.connect(_refresh_artifact_cache)

func _refresh_artifact_cache():
	_passive_artifacts.clear()
	_triggered_artifacts.clear()
	
	DebugLogger.log_debug("Refreshing artifact cache...")
	
	for artifact in PlayerData.artifacts:
		DebugLogger.log_debug("Artefakt '%s' má trigger_type: %d (%s)" % [
			artifact.artifact_name, 
			artifact.trigger_type,
			_get_trigger_type_name(artifact.trigger_type)
		])
		
		if artifact.trigger_type == ArtifactsData.TriggerType.PASSIVE:
			_passive_artifacts.append(artifact)
		else:
			var trigger = artifact.trigger_type
			if not _triggered_artifacts.has(trigger):
				_triggered_artifacts[trigger] = []
			_triggered_artifacts[trigger].append(artifact)
			DebugLogger.log_debug("Přidán do cache pro trigger %d" % trigger)

func _get_trigger_type_name(trigger_type: int) -> String:
	match trigger_type:
		0: return "PASSIVE"
		1: return "START_OF_COMBAT"  
		2: return "START_OF_TURN"
		3: return "END_OF_TURN"
		4: return "ON_CARD_PLAYED"
		5: return "ON_DAMAGE_TAKEN"
		6: return "ON_DAMAGE_DEALT"
		7: return "ON_BLOCK_GAINED"
		8: return "ON_HEAL"
		9: return "ON_ENEMY_DEATH"
		10: return "ON_HEALTH_LOW"
		11: return "ON_ENERGY_SPENT"
		12: return "ON_DRAW_CARDS"
		13: return "CONDITIONAL"
		_: return "UNKNOWN"

func trigger_artifacts(trigger_type: ArtifactsData.TriggerType, context: Dictionary = {}) -> Array:
	var results = []
	
	if not _triggered_artifacts.has(trigger_type):
		return results
	
	for artifact in _triggered_artifacts[trigger_type]:
		var effect = ArtifactEffect.new(artifact, context.get("target"), context)
		if effect.execute():
			results.append({
				"artifact": artifact,
				"success": true,
				"description": artifact.get_formatted_description()
			})
			emit_signal("artifact_triggered", artifact.artifact_name, artifact.get_formatted_description())
	
	return results

func get_passive_bonus(effect_type: ArtifactsData.EffectType) -> int:
	var total_bonus = 0
	for artifact in _passive_artifacts:
		if artifact.effect_type == effect_type:
			total_bonus += artifact.get_effective_value()
	return total_bonus

func get_conditional_bonus(effect_type: ArtifactsData.EffectType, context: Dictionary = {}) -> int:
	var total_bonus = 0
	for trigger_list in _triggered_artifacts.values():
		for artifact in trigger_list:
			if artifact.effect_type == effect_type and artifact.check_condition(context):
				total_bonus += artifact.get_effective_value()
	return total_bonus

func on_combat_start():
	DebugLogger.log_info("ArtifactManager: Spouštím START_OF_COMBAT artefakty...")
	
	# NOVÉ: Reset Srdce draka counteru na začátku NOVÉHO souboje
	for artifact in PlayerData.artifacts:
		if artifact.custom_effect_id == "dragon_heart_combo":
			artifact.set_meta("uses_this_combat", 0)
			DebugLogger.log_debug("Srdce draka: Reset počítadla pro nový souboj")
	
	# OPRAVA: Vynucené refreshnutí cache
	_refresh_artifact_cache()
	
	# DEBUG: Zkontroluj cache
	if _triggered_artifacts.has(ArtifactsData.TriggerType.START_OF_COMBAT):
		var combat_artifacts = _triggered_artifacts[ArtifactsData.TriggerType.START_OF_COMBAT]
		DebugLogger.log_debug("START_OF_COMBAT artefakty v cache: %d" % combat_artifacts.size())
		for artifact in combat_artifacts:
			DebugLogger.log_debug("   - %s (can_trigger: %s)" % [artifact.artifact_name, str(artifact.can_trigger())])
	else:
		DebugLogger.log_debug("Žádné START_OF_COMBAT artefakty v cache")
	
	var results = trigger_artifacts(ArtifactsData.TriggerType.START_OF_COMBAT)
	
	if results.size() > 0:
		DebugLogger.log_info("Spuštěno %d START_OF_COMBAT artefaktů:" % results.size())
		for result in results:
			DebugLogger.log_debug("   - %s: %s" % [result["artifact"].artifact_name, "úspěch" if result["success"] else "selhání"])
	else:
		DebugLogger.log_debug("Žádné START_OF_COMBAT artefakty se nespustily")
	
	# Reset ostatních artefaktů (kromě Srdce draka)
	for artifact in PlayerData.artifacts:
		if artifact.custom_effect_id != "dragon_heart_combo":
			artifact.reset_for_new_combat()
	
	return results

func on_turn_start():
	DebugLogger.log_info("ArtifactManager: Spouštím START_OF_TURN artefakty...")
	
	var player_unit = _get_player_unit()
	DebugLogger.log_debug("Nalezený player unit: %s" % str(player_unit))
	
	if player_unit:
		DebugLogger.log_debug("Player unit má add_block: %s" % str(player_unit.has_method("add_block")))
	
	var context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"current_energy": PlayerData.current_energy,
		"hand_size": PlayerData.current_hand.size(),
		"target": player_unit
	}
	
	DebugLogger.log_debug("START_OF_TURN context:")
	DebugLogger.log_debug("   - Target: %s" % str(context["target"]))
	DebugLogger.log_debug("   - HP: %d/%d" % [context["current_hp"], context["max_hp"]])
	DebugLogger.log_debug("   - Energy: %d" % context["current_energy"])
	
	var results = trigger_artifacts(ArtifactsData.TriggerType.START_OF_TURN, context)
	
	if results.size() > 0:
		DebugLogger.log_info("Spuštěno %d START_OF_TURN artefaktů:" % results.size())
		for result in results:
			DebugLogger.log_debug("   - %s: %s" % [result["artifact"].artifact_name, "úspěch" if result["success"] else "selhání"])
	else:
		DebugLogger.log_debug("Žádné START_OF_TURN artefakty se nespustily")
		
		# DEBUG: Zjisti proč se nespustily
		if _triggered_artifacts.has(ArtifactsData.TriggerType.START_OF_TURN):
			var start_artifacts = _triggered_artifacts[ArtifactsData.TriggerType.START_OF_TURN]
			DebugLogger.log_debug("START_OF_TURN artefakty v cache: %d" % start_artifacts.size())
			for artifact in start_artifacts:
				DebugLogger.log_debug("   - %s (can_trigger: %s)" % [artifact.artifact_name, str(artifact.can_trigger())])
				# DEBUG pro Srdce draka
				if artifact.artifact_name == "Srdce draka":
					var uses_this_combat = artifact.get_meta("uses_this_combat", 0)
					DebugLogger.log_debug("     Použití v tomto souboji: %d/2" % uses_this_combat)
		else:
			DebugLogger.log_debug("Žádné START_OF_TURN artefakty v cache")
	
	return results

func on_turn_end():
	var context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"target": _get_player_unit(),
		"enemy_count": _get_enemy_count()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.END_OF_TURN, context)

func on_card_played(card_data: CardData):
	"""Volá se při zahrání jakékoliv karty"""
	var context = {
		"card": card_data,
		"card_cost": card_data.cost,
		"card_id": card_data.card_id,
		"card_name": card_data.card_name,
		"target": _get_player_unit()
	}
	
	DebugLogger.log_debug("Card played trigger: %s (ID: %s)" % [card_data.card_name, card_data.card_id])
	
	return trigger_artifacts(ArtifactsData.TriggerType.ON_CARD_PLAYED, context)

func on_damage_taken(amount: int, attacker: Node = null):
	DebugLogger.log_debug("ArtifactManager: ON_DAMAGE_TAKEN trigger s %d poškozením" % amount)
	DebugLogger.log_debug("Attacker: %s" % str(attacker))
	
	var context = {
		"damage_amount": amount,
		"attacker": attacker,
		"target": _get_player_unit(),
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp
	}
	
	DebugLogger.log_debug("ON_DAMAGE_TAKEN context:")
	DebugLogger.log_debug("   - Damage: %d" % context["damage_amount"])
	DebugLogger.log_debug("   - Attacker: %s" % str(context["attacker"]))
	DebugLogger.log_debug("   - Target: %s" % str(context["target"]))
	
	var results = trigger_artifacts(ArtifactsData.TriggerType.ON_DAMAGE_TAKEN, context)
	
	if results.size() > 0:
		DebugLogger.log_info("Spuštěno %d ON_DAMAGE_TAKEN artefaktů:" % results.size())
		for result in results:
			DebugLogger.log_debug("   - %s: %s" % [result["artifact"].artifact_name, "úspěch" if result["success"] else "selhání"])
	else:
		DebugLogger.log_debug("Žádné ON_DAMAGE_TAKEN artefakty se nespustily")
		
		# DEBUG: Zjisti proč se nespustily
		if _triggered_artifacts.has(ArtifactsData.TriggerType.ON_DAMAGE_TAKEN):
			var damage_artifacts = _triggered_artifacts[ArtifactsData.TriggerType.ON_DAMAGE_TAKEN]
			DebugLogger.log_debug("ON_DAMAGE_TAKEN artefakty v cache: %d" % damage_artifacts.size())
			for artifact in damage_artifacts:
				DebugLogger.log_debug("   - %s (can_trigger: %s)" % [artifact.artifact_name, str(artifact.can_trigger())])
		else:
			DebugLogger.log_debug("Žádné ON_DAMAGE_TAKEN artefakty v cache")
	
	return results

func on_damage_dealt(amount: int, target: Node, was_critical: bool = false):
	var context = {
		"damage_amount": amount,
		"target": target,
		"critical_hit": was_critical,
		"dealer": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_DAMAGE_DEALT, context)

func on_enemy_death(enemy: Node):
	var context = {
		"dead_enemy": enemy,
		"target": _get_player_unit(),
		"enemy_count": _get_enemy_count() - 1
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_ENEMY_DEATH, context)

func on_heal(amount: int):
	var context = {
		"heal_amount": amount,
		"target": _get_player_unit(),
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_HEAL, context)

func on_block_gained(amount: int):
	var context = {
		"block_amount": amount,
		"target": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_BLOCK_GAINED, context)

func _get_player_unit() -> Node:
	var current_scene = get_tree().current_scene
	
	DebugLogger.log_debug("Hledám player unit...")
	
	# Metoda 1: Přímá metoda get_player_unit()
	if current_scene and current_scene.has_method("get_player_unit"):
		var player = current_scene.get_player_unit()
		if player != null:
			DebugLogger.log_debug("Player nalezen metodou 1: %s" % str(player))
			return player
	
	# Metoda 2: Hledání podle skupiny "player"
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		DebugLogger.log_debug("Player nalezen metodou 2: %s" % str(players[0]))
		return players[0] as Node
	
	# Metoda 3: Hledání podle faction v Unit nódech
	var all_units = get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if unit.has_method("get_unit_data"):
			var unit_data = unit.get_unit_data()
			if unit_data and unit_data.faction == UnitData.Faction.PLAYER:
				DebugLogger.log_debug("Player nalezen metodou 3: %s" % str(unit))
				return unit as Node
	
	DebugLogger.log_warning("Player unit nebyl nalezen!")
	return null

func _get_enemy_count() -> int:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_enemy_count"):
		return current_scene.get_enemy_count()
	return 0

func get_max_hp_bonus() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.MODIFY_MAX_HP)

func get_max_energy_bonus() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.MODIFY_MAX_ENERGY)

func get_card_damage_bonus(context: Dictionary = {}) -> int:
	var passive_bonus = get_passive_bonus(ArtifactsData.EffectType.MODIFY_CARD_DAMAGE)
	var conditional_bonus = get_conditional_bonus(ArtifactsData.EffectType.MODIFY_CARD_DAMAGE, context)
	return passive_bonus + conditional_bonus

func get_block_bonus() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.MODIFY_BLOCK_GAIN)

func get_heal_bonus() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.MODIFY_HEAL_AMOUNT)

func get_critical_chance() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.CRITICAL_CHANCE)

func get_thorns_damage() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.THORNS_DAMAGE)

func has_artifact_with_effect(effect_type: ArtifactsData.EffectType) -> bool:
	for artifact in PlayerData.artifacts:
		if artifact.effect_type == effect_type:
			return true
	return false

func get_artifact_count() -> int:
	return PlayerData.artifacts.size()


func handle_custom_effect(artifact: ArtifactsData, context: Dictionary = {}) -> bool:
	match artifact.custom_effect_id:
		"block_per_enemy":
			# Dračí šupina: blok za živé nepřátele
			var block_amount = _get_enemy_count() * artifact.get_effective_value()
			var player = _get_player_unit()
			if player and player.has_method("add_block"):
				player.add_block(block_amount)
			return true
			
		"dragon_heart_combo":
			# Srdce draka: blok podle aktuálních max HP (jen první 2 tahy)
			DebugLogger.log_debug("SRDCE DRAKA KONTROLA...")

			# Zkontroluj, kolikrát už byl použit v tomto souboji
			var uses_this_combat = artifact.get_meta("uses_this_combat", 0)
			var max_uses_per_combat = 2
			
			DebugLogger.log_debug("Debug: uses_this_combat = %d, max_uses = %d" % [uses_this_combat, max_uses_per_combat])
			
			if uses_this_combat >= max_uses_per_combat:
				DebugLogger.log_debug("Srdce draka už bylo použito %d/%d krát v tomto souboji" % [uses_this_combat, max_uses_per_combat])
				return false

			DebugLogger.log_info("SRDCE DRAKA AKTIVOVÁNO! (použití %d/%d)" % [uses_this_combat + 1, max_uses_per_combat])

			var player = _get_player_unit()
			if not player:
				DebugLogger.log_warning("Player unit nenalezen!")
				return false

			# Spočítej blok z AKTUÁLNÍCH max HP
			var current_max_hp = PlayerData.max_hp
			var block_amount = current_max_hp  # 100% aktuálních max HP
			DebugLogger.log_debug("Aktuální max HP: %d, přidávám %d bloku" % [current_max_hp, block_amount])

			# Přidej blok
			if player.has_method("add_block"):
				player.add_block(block_amount)
				DebugLogger.log_info("Srdce draka: Přidán blok %d" % block_amount)
				
				# Zvyš počítadlo použití v tomto souboji
				var new_uses = uses_this_combat + 1
				artifact.set_meta("uses_this_combat", new_uses)
				DebugLogger.log_debug("Debug: Nastavuji uses_this_combat na %d" % new_uses)
				
				# Pokud to bylo poslední použití, informuj hráče
				if new_uses >= max_uses_per_combat:
					DebugLogger.log_info("Srdce draka: Síla se vyčerpala pro zbytek souboje!")
				
				return true
			else:
				DebugLogger.log_error("Player nemá add_block metodu!")
				return false
			
		"cursed_ring_combo":
			# Prokletý prsten: +15 max HP (jednorázově), -1 energie každý tah
			if not artifact.has_meta("hp_bonus_applied"):
				PlayerData.change_max_hp(artifact.secondary_value)  # +15 HP
				artifact.set_meta("hp_bonus_applied", true)
			# -1 energie se aplikuje normálně přes ENERGY_LOSS
			return true
			
		"blood_chalice_combo":
			# Krvavý grál: -2 HP, +4 heal
			var player = _get_player_unit()
			if player:
				if player.has_method("take_damage"):
					player.take_damage(abs(artifact.secondary_value))  # 2 damage
				if player.has_method("heal"):
					player.heal(artifact.primary_value)  # 4 heal
			return true
			
		"mage_book_limit":
			# Mágova kniha s limitem 5 karet za tah
			var cards_drawn_this_turn = context.get("cards_drawn_this_turn", 0)
			if cards_drawn_this_turn < artifact.secondary_value:
				PlayerData.draw_cards(artifact.get_effective_value())
				context["cards_drawn_this_turn"] = cards_drawn_this_turn + 1
			return true
			
		"scaling_damage":
			# Meč nekonečna: +1 damage za zabitého nepřítele (jen tento souboj)
			PlayerData.global_card_damage_bonus += artifact.get_effective_value()
			DebugLogger.log_info("Meč nekonečna: +%d poškození za zabití!" % artifact.get_effective_value())
			return true
		
		"extra_turn":
			# Časový krystal efekt - označí že bude extra tah
			DebugLogger.log_info("Časový krystal: Extra tah bude aktivován!")
			# Efekt se realizuje v BattleScene, zde jen vracíme true
			return true
		
		"random_energy":
			# Záhadná kostka: 50% šance na +2 energie, jinak -1 energie
			var roll = randf()
			if roll < 0.5:
				# 50% šance - získá 2 energie
				PlayerData.gain_energy(2)
				DebugLogger.log_info("🎲 Záhadná kostka: Hodil jsi dobře! +2 energie")
			else:
				# 50% šance - ztratí 1 energii (ale ne méně než 0)
				var energy_to_lose = min(1, PlayerData.current_energy)
				PlayerData.current_energy -= energy_to_lose
				PlayerData.emit_signal("energy_changed", PlayerData.current_energy)
				DebugLogger.log_info("🎲 Záhadná kostka: Špatný hod! -%d energie" % energy_to_lose)
			return true
		
		_:
			DebugLogger.log_warning("Neznámý custom efekt: %s" % artifact.custom_effect_id)
			return false


func on_energy_spent(amount: int):
	var context = {
		"energy_spent": amount,
		"current_energy": PlayerData.current_energy,
		"max_energy": PlayerData.max_energy,
		"target": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_ENERGY_SPENT, context)

func on_draw_cards(cards_drawn: int, total_requested: int):
	var context = {
		"cards_drawn": cards_drawn,
		"total_cards_requested": total_requested,
		"hand_size": PlayerData.current_hand.size(),
		"target": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_DRAW_CARDS, context)

func check_conditional_artifacts():
	"""Zkontroluje a spustí conditional artefakty podle aktuálního stavu"""
	var context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"current_energy": PlayerData.current_energy,
		"hand_size": PlayerData.current_hand.size(),
		"target": _get_player_unit()
	}
	
	DebugLogger.log_debug("Kontroluji conditional artefakty...")
	DebugLogger.log_debug("   - HP: %d/%d (%d%%)" % [context["current_hp"], context["max_hp"], context["current_hp"] * 100 / context["max_hp"]])
	
	var results = trigger_artifacts(ArtifactsData.TriggerType.CONDITIONAL, context)
	
	if results.size() > 0:
		DebugLogger.log_info("Aktivováno %d conditional artefaktů:" % results.size())
		for result in results:
			DebugLogger.log_debug("   - %s: %s" % [result["artifact"].artifact_name, result["description"]])
	
	return results

func check_conditional_artifacts_with_context(context: Dictionary = {}) -> Array:
	"""Zkontroluje conditional artefakty s custom contextem"""
	# Přidej základní context
	var full_context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"current_energy": PlayerData.current_energy,
		"hand_size": PlayerData.current_hand.size(),
		"target": _get_player_unit()
	}
	
	# Zkombinuj s custom contextem
	for key in context:
		full_context[key] = context[key]
	
	DebugLogger.log_debug("Kontroluji conditional artefakty s contextem...")
	DebugLogger.log_debug("   - Turn: %d" % full_context.get("current_turn", 0))
	
	var results = trigger_artifacts(ArtifactsData.TriggerType.CONDITIONAL, full_context)
	
	if results.size() > 0:
		DebugLogger.log_info("Aktivováno %d conditional artefaktů:" % results.size())
		for result in results:
			DebugLogger.log_debug("   - %s: %s" % [result["artifact"].artifact_name, result["description"]])
	
	return results
