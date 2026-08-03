extends ArtifactBehavior

func on_unblocked_damage(_ctx: Dictionary) -> void:
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "strength", 1, 99)
	ArtifactManager.apply_status_to_unit(u, "thorns", 1, 99)

func on_enemy_death(_ctx: Dictionary) -> void:
	var heal_amt := int(ArtifactManager.hp_lost_this_combat * 0.5)
	if heal_amt <= 0:
		return
	var u := player_unit()
	if u:
		# Temporary max HP style heal — heal up to heal_amt even above current max visually via heal
		u.heal(heal_amt)
	notify_triggered("Bloodbound heal %d" % heal_amt)
