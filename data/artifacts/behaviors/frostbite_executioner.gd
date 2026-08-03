extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target == null:
		return
	target.apply_status("chilled", 1, 3)
	if status_value(target, "chilled") >= 3:
		ArtifactManager.apply_status_to_unit(target, "weakness", 1, 2)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target = ctx.get("target")
	if target and status_value(target, "chilled") >= 3:
		return int(damage * 1.5)
	return damage
