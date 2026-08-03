extends ArtifactBehavior


func on_damage_taken(ctx: Dictionary = {}) -> void:
	super.on_damage_taken(ctx)
	var amount := int(ctx.get("damage_amount", 0))
	if amount <= 0:
		return
	_add_combat_damage_bonus(1)
	_add_combat_thorns(1)


func on_enemy_death(ctx: Dictionary = {}) -> void:
	var lost := int(runtime.get("hp_lost_this_combat", 0))
	if lost <= 0:
		return
	var heal_amount := int(float(lost) * 0.5)
	var player := _get_player_unit()
	if player and player.has_method("heal"):
		player.heal(heal_amount)
