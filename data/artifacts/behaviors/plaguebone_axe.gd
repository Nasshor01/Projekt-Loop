extends ArtifactBehavior

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target:
		target.apply_status("poison", 2, 99)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target = ctx.get("target")
	if target and status_value(target, "poison") >= 8:
		# Ignore block is handled via flag for BattleScene; add damage here
		ctx["ignore_block"] = true
		return damage + 3
	return damage
