extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target and target.has_method("apply_status"):
		target.apply_status("poison", 1, 99)

func on_turn_start(_ctx: Dictionary) -> void:
	for e in ArtifactManager.get_enemies():
		if status_value(e, "poison") >= 5:
			e.take_damage(2, true, false, false)
			PlayerData.gain_energy(1)
