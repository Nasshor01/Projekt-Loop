extends ArtifactBehavior

const HEAL_PERCENT := 50
const STRENGTH_BONUS := 2


func on_before_death(ctx: Dictionary = {}) -> void:
	if PlayerData and PlayerData.get_meta("phoenix_feather_used", false):
		return
	var player := _get_player_unit()
	if not player:
		return
	var heal_target := int(float(PlayerData.max_hp) * HEAL_PERCENT / 100.0)
	if player.has_method("heal"):
		player.heal(heal_target)
	_add_combat_damage_bonus(STRENGTH_BONUS)
	if PlayerData:
		PlayerData.set_meta("phoenix_feather_used", true)
	ctx["prevent_death"] = true
