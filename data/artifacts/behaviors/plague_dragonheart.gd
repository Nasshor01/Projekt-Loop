extends ArtifactBehavior

func on_status_applied(ctx: Dictionary) -> void:
	if ctx.get("status_id") != "poison":
		return
	var unit = ctx.get("unit")
	if unit == null:
		return
	var val: int = status_value(unit, "poison")
	var applied: int = int(ctx.get("status_value", 1))
	# Spread to row if target already had poison (stacks above this apply)
	if val > applied:
		var y: int = unit.grid_position.y if "grid_position" in unit else 0
		for e in ArtifactManager.get_enemies():
			if e == unit:
				continue
			if "grid_position" in e and e.grid_position.y == y:
				e.apply_status("poison", applied, 99)
	if runtime.get("doubled", false):
		return
	for e in ArtifactManager.get_enemies():
		if status_value(e, "poison") >= 8:
			runtime["doubled"] = true
			for e2 in ArtifactManager.get_enemies():
				var p: int = status_value(e2, "poison")
				if p > 0 and e2.active_statuses.has("poison"):
					e2.active_statuses["poison"]["value"] = p * 2
					if e2.has_method("_update_stats_and_emit_signal"):
						e2._update_stats_and_emit_signal()
			notify_triggered("Plague Dragonheart: poison doubled")
			break

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["doubled"] = false
