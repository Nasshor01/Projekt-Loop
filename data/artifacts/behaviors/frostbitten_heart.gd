extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target == null:
		return
	target.apply_status("chilled", 1, 3)
	if status_value(target, "chilled") >= 3:
		var u := player_unit()
		if u:
			u.heal(2)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target = ctx.get("target")
	if target and status_value(target, "chilled") >= 3:
		return damage + 4
	return damage
