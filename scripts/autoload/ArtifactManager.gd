# Soubor: scripts/autoload/ArtifactManager.gd
extends Node

signal artifact_triggered(artifact_name: String, effect_description: String)
signal artifact_gained(artifact: ArtifactsData)
signal artifact_lost(artifact: ArtifactsData)

var _passive_artifacts: Array[ArtifactsData] = []
var _triggered_artifacts: Dictionary = {}

func _ready():
	if PlayerData:
		PlayerData.artifacts_changed.connect(_refresh_artifact_cache)

func _refresh_artifact_cache():
	_passive_artifacts.clear()
	_triggered_artifacts.clear()
	
	for artifact in PlayerData.artifacts:
		if artifact.trigger_type == ArtifactsData.TriggerType.PASSIVE:
			_passive_artifacts.append(artifact)
		else:
			var trigger = artifact.trigger_type
			if not _triggered_artifacts.has(trigger):
				_triggered_artifacts[trigger] = []
			_triggered_artifacts[trigger].append(artifact)

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
	var results = trigger_artifacts(ArtifactsData.TriggerType.START_OF_COMBAT)
	for artifact in PlayerData.artifacts:
		artifact.reset_for_new_combat()
	return results

func on_turn_start():
	var context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"current_energy": PlayerData.current_energy,
		"hand_size": PlayerData.current_hand.size(),
		"target": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.START_OF_TURN, context)

func on_turn_end():
	var context = {
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp,
		"target": _get_player_unit(),
		"enemy_count": _get_enemy_count()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.END_OF_TURN, context)

func on_card_played(card_data: CardData):
	var context = {
		"card": card_data,
		"card_cost": card_data.cost,
		"target": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_CARD_PLAYED, context)

func on_damage_taken(amount: int, attacker: Node2D = null):
	var context = {
		"damage_amount": amount,
		"attacker": attacker,
		"target": _get_player_unit(),
		"current_hp": PlayerData.current_hp,
		"max_hp": PlayerData.max_hp
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_DAMAGE_TAKEN, context)

func on_damage_dealt(amount: int, target: Node2D, was_critical: bool = false):
	var context = {
		"damage_amount": amount,
		"target": target,
		"critical_hit": was_critical,
		"dealer": _get_player_unit()
	}
	return trigger_artifacts(ArtifactsData.TriggerType.ON_DAMAGE_DEALT, context)

func on_enemy_death(enemy: Node2D):
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

func _get_player_unit() -> Node2D:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_player_unit"):
		return current_scene.get_player_unit()
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
			# Srdce draka: blok = max HP, ale -10 max HP
			var player = _get_player_unit()
			if player:
				PlayerData.change_max_hp(artifact.secondary_value)  # -10 HP
				var block_amount = PlayerData.max_hp  # 100% current max HP
				if player.has_method("add_block"):
					player.add_block(block_amount)
			return true
			
		"cursed_ring_combo":
			# Prokletý prsten: +15 max HP (jednorázově), -1 energie každý tah
			if not artifact.has_property("hp_bonus_applied"):
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
			print("⚔️ Meč nekonečna: +%d poškození za zabití!" % artifact.get_effective_value())
			return true
		
		_:
			print("Neznámý custom efekt: %s" % artifact.custom_effect_id)
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
