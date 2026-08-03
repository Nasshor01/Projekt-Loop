extends ArtifactBehavior

func before_death(_ctx: Dictionary) -> bool:
	if ArtifactManager.get_run_flag("phoenix_feather_used", false):
		return false
	ArtifactManager.set_run_flag("phoenix_feather_used", true)
	var target_hp := int(PlayerData.max_hp * 0.5)
	PlayerData.current_hp = maxi(1, target_hp)
	var u := player_unit()
	if u:
		u.current_health = PlayerData.current_hp
		ArtifactManager.apply_status_to_unit(u, "strength", 2, 99)
		if u.has_method("_update_stats_and_emit_signal"):
			u._update_stats_and_emit_signal()
	PlayerData.emit_signal("health_changed", PlayerData.current_hp, PlayerData.max_hp)
	notify_triggered("Phoenix Feather revived you!")
	# Defer removal so we don't rebuild behavior list mid before_death dispatch
	if data:
		ArtifactManager.call_deferred("queue_remove_artifact", data)
	return true
