
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
				
		ArtifactsData.EffectType.GAIN_BLOCK:
			if target_unit and target_unit.has_method("add_block"):
				target_unit.add_block(artifact_data.get_effective_value())
				return true
				
		ArtifactsData.EffectType.GAIN_ENERGY:
			if PlayerData:
				PlayerData.gain_energy(artifact_data.get_effective_value())
				return true
				
		ArtifactsData.EffectType.HEAL_HP:
			if target_unit and target_unit.has_method("heal"):
				target_unit.heal(artifact_data.get_effective_value())
				return true
				
		ArtifactsData.EffectType.DRAW_CARDS:
			if PlayerData:
				PlayerData.draw_cards(artifact_data.get_effective_value())
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
			# Tento efekt se aplikuje pasivně v Unit.gd
			return true
			
		ArtifactsData.EffectType.EXTRA_TURN_DRAW:
			if PlayerData:
				# Přidá extra dobírání na začátku tahu
				PlayerData.starting_hand_size += artifact_data.get_effective_value()
				return true
				
		ArtifactsData.EffectType.RETAIN_ENERGY:
			if PlayerData:
				# Ponechá část energie mezi tahy
				var energy_to_retain = min(artifact_data.get_effective_value(), PlayerData.current_energy)
				# Toto by se aplikovalo v reset_energy() funkci
				PlayerData.set_meta("retained_energy", energy_to_retain)
				return true
				
		ArtifactsData.EffectType.DUPLICATE_CARD:
			# Duplikuje poslední zahranou kartu
			if context.has("card") and context.card is CardData:
				var card_to_duplicate = context.card
				PlayerData.current_hand.append(card_to_duplicate)
				print("🃏 Artefakt duplikoval kartu: %s" % card_to_duplicate.card_name)
				return true
				
		ArtifactsData.EffectType.REDUCE_HAND_SIZE:
			# Sníží velikost ruky
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
			# Ztratí energii
			if PlayerData:
				var energy_to_lose = min(artifact_data.get_effective_value(), PlayerData.current_energy)
				PlayerData.current_energy -= energy_to_lose
				PlayerData.emit_signal("energy_changed", PlayerData.current_energy)
				print("⚡ Artefakt způsobil ztrátu %d energie" % energy_to_lose)
				return true
			
		_:
			# Pro custom efekty použijeme starý systém s effect_id
			return _apply_custom_effect()
	
	return false

func _apply_custom_effect() -> bool:
	"""Aplikuje custom efekty podle effect_id"""
	if artifact_data.custom_effect_id.is_empty():
		return false
		
	# Zde můžeme implementovat custom logiku
	print("Aplikuji custom efekt: %s" % artifact_data.custom_effect_id)
	return true
