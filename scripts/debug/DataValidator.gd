# res://scripts/debug/DataValidator.gd
class_name DataValidator
extends RefCounted

# Tato třída obsahuje pouze statické funkce, nevytváří se z ní instance.

static func validate_player_data() -> bool:
	var errors = []
	if not PlayerData:
		errors.append("PlayerData is null")
		return false
	if PlayerData.current_hp < 0: errors.append("HP is negative: %d" % PlayerData.current_hp)
	if PlayerData.current_hp > PlayerData.max_hp * 2: errors.append("HP suspiciously high: %d/%d" % [PlayerData.current_hp, PlayerData.max_hp])
	if PlayerData.current_energy < 0: errors.append("Energy is negative: %d" % PlayerData.current_energy)
	if PlayerData.gold < 0: errors.append("Gold is negative: %d" % PlayerData.gold)
	var total_cards = PlayerData.current_hand.size() + PlayerData.draw_pile.size() + PlayerData.discard_pile.size() + PlayerData.exhaust_pile.size()
	if total_cards != PlayerData.master_deck.size() and PlayerData.master_deck.size() > 0: errors.append("Card count mismatch! Total: %d, Master: %d" % [total_cards, PlayerData.master_deck.size()])
	var artifact_names = {}
	for artifact in PlayerData.artifacts:
		if artifact_names.has(artifact.artifact_name): errors.append("Duplicate artifact: %s" % artifact.artifact_name)
		artifact_names[artifact.artifact_name] = true
	if not errors.is_empty():
		DebugLogger.log_error("=== DATA VALIDATION FAILED ===", "VALIDATOR")
		for error in errors: DebugLogger.log_error(error, "VALIDATOR")
		DebugLogger.log_error("=== END VALIDATION ERRORS ===", "VALIDATOR")
		return false
	return true

static func validate_battle_state(battle_scene) -> bool:
	if not battle_scene: return false
	var errors = []
	if "player_units" in battle_scene:
		for unit in battle_scene.player_units:
			if not is_instance_valid(unit): errors.append("Invalid player unit detected")
			elif unit.current_health < 0: errors.append("Player unit with negative HP: %s" % unit.unit_data.unit_name)
	if "enemy_units" in battle_scene:
		for unit in battle_scene.enemy_units:
			if not is_instance_valid(unit): errors.append("Invalid enemy unit detected")
			elif unit.current_health < 0 and unit.visible: errors.append("Visible enemy unit with negative HP: %s" % unit.unit_data.unit_name)
	if not errors.is_empty():
		DebugLogger.log_error("Battle validation errors: %s" % str(errors), "VALIDATOR")
		return false
	return true
