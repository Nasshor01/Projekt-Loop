extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	ArtifactManager.apply_status_to_unit(player_unit(), "strength", 1, 99)

func on_status_applied(ctx: Dictionary) -> void:
	if ctx.get("status_id") == "burning":
		var u := player_unit()
		if u:
			u.heal(1)
