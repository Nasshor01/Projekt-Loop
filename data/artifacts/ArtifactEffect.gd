
class_name ArtifactEffect
extends RefCounted

var artifact_data: ArtifactsData
var target_unit: Node2D
var context: Dictionary

func _init(artifact: ArtifactsData, target: Node2D = null, ctx: Dictionary = {}):
	artifact_data = artifact
	target_unit = target  
	context = ctx

func execute() -> bool:
	"""Vykoná efekt artefaktu"""
	if not artifact_data.can_trigger():
		return false
		
	if not artifact_data.check_condition(context):
		return false
	
	var success = _apply_effect()
	
	if success:
		artifact_data.use_artifact()
		
	return success

func _apply_effect() -> bool:
	"""Aplikuje konkrétní efekt podle typu"""
	match artifact_data.effect_type:
		ArtifactsData.EffectType.MODIFY_MAX_HP:
			if target_unit and target_unit.has_method("change_max_hp"):
				target_unit.change_max_hp(artifact_data.get_effective_value())
				return true
			elif target_unit == null:
				PlayerData.change_max_hp(artifact_data.get_effective_value())
				return true
				
		ArtifactsData.EffectType.GAIN_BLOCK:
			# NOVÉ: Pokud má custom efekt, použij ten místo standardního
			if not artifact_data.custom_effect_id.is_empty():
				print("🔧 GAIN_BLOCK s custom efektem: %s" % artifact_data.custom_effect_id)
				return _apply_custom_effect()
			var block_amount = artifact_data.get_effective_value()
			print("🛡️ Pokouším se přidat %d bloku z %s..." % [block_amount, artifact_data.artifact_name])
	
			if target_unit and target_unit.has_method("add_block"):
				target_unit.add_block(block_amount)
				print("🛡️ %s přidal %d bloku!" % [artifact_data.artifact_name, block_amount])
				return true
			else:
				print("❌ GAIN_BLOCK failed - target: %s" % str(target_unit))
				return false
				
		ArtifactsData.EffectType.GAIN_ENERGY:
			if PlayerData:
				PlayerData.gain_energy(artifact_data.get_effective_value())
				print("⚡ %s přidal %d energie!" % [artifact_data.artifact_name, artifact_data.get_effective_value()])
				return true
				
		ArtifactsData.EffectType.HEAL_HP:
			if target_unit and target_unit.has_method("heal"):
				target_unit.heal(artifact_data.get_effective_value())
				return true
			else:
				return false
				
		ArtifactsData.EffectType.DRAW_CARDS:
			if PlayerData:
				var cards_drawn = PlayerData.draw_cards(artifact_data.get_effective_value())
				print("🃏 %s dobral %d karet!" % [artifact_data.artifact_name, cards_drawn])
				return true
				
		ArtifactsData.EffectType.DEAL_DAMAGE:
			if target_unit and target_unit.has_method("take_damage"):
				target_unit.take_damage(artifact_data.get_effective_value())
				return true
				
		ArtifactsData.EffectType.CURSE_DRAW:
			if PlayerData:
				PlayerData.add_curse()
				return true
				
		ArtifactsData.EffectType.THORNS_DAMAGE:
			var attacker = context.get("attacker")
			var thorns_damage = artifact_data.get_effective_value()
			
			print("🌹 Pokouším se aplikovat %d thorns damage z %s..." % [thorns_damage, artifact_data.artifact_name])
			print("🌹 Attacker: %s" % str(attacker))
			
			if is_instance_valid(attacker) and attacker.has_method("take_damage"):
				print("🌹 %s vrací %d poškození útočníkovi!" % [artifact_data.artifact_name, thorns_damage])
				attacker.take_damage(thorns_damage)
				return true
			else:
				print("❌ THORNS_DAMAGE failed - attacker invalid")
				return false
			
		ArtifactsData.EffectType.EXTRA_TURN_DRAW:
			if PlayerData:
				PlayerData.starting_hand_size += artifact_data.get_effective_value()
				return true
				
		ArtifactsData.EffectType.RETAIN_ENERGY:
			if PlayerData:
				var energy_to_retain = min(artifact_data.get_effective_value(), PlayerData.current_energy)
				PlayerData.set_meta("retained_energy", energy_to_retain)
				return true
				
		ArtifactsData.EffectType.DUPLICATE_CARD:
			if context.has("card") and context.card is CardData:
				var card_to_duplicate = context.card
				PlayerData.current_hand.append(card_to_duplicate)
				print("🃏 Artefakt duplikoval kartu: %s" % card_to_duplicate.card_name)
				return true
				
		ArtifactsData.EffectType.REDUCE_HAND_SIZE:
			var cards_to_discard = artifact_data.get_effective_value()
			var actual_discarded = 0
			while actual_discarded < cards_to_discard and not PlayerData.current_hand.is_empty():
				var random_card = PlayerData.current_hand.pick_random()
				PlayerData.current_hand.erase(random_card)
				PlayerData.add_card_to_discard_pile(random_card)
				actual_discarded += 1
			print("🗑️ Artefakt přinutil odhodit %d karet" % actual_discarded)
			return true
			
		ArtifactsData.EffectType.ENERGY_LOSS:
			if PlayerData:
				var energy_to_lose = min(artifact_data.get_effective_value(), PlayerData.current_energy)
				PlayerData.current_energy -= energy_to_lose
				PlayerData.emit_signal("energy_changed", PlayerData.current_energy)
				print("⚡ Artefakt způsobil ztrátu %d energie" % energy_to_lose)
				return true
			
		_:
			return _apply_custom_effect()
	
	return false

func _apply_custom_effect() -> bool:
	"""Aplikuje custom efekty podle effect_id"""
	if artifact_data.custom_effect_id.is_empty():
		return false
		
	print("🔧 Aplikuji custom efekt: %s" % artifact_data.custom_effect_id)
	
	# OPRAVA: Přímý přístup na autoload ArtifactManager
	if ArtifactManager:
		return ArtifactManager.handle_custom_effect(artifact_data, context)
	else:
		print("❌ ArtifactManager nenalezen!")
		return false
