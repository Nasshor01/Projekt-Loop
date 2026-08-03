extends ArtifactBehavior

func on_damage_dealt(_ctx: Dictionary) -> void:
	var target = _ctx.get("target")
	if target and target.has_method("apply_status"):
		target.apply_status("burning", 1, 3)

func on_enemy_death(ctx: Dictionary) -> void:
	var enemy = ctx.get("dead_enemy")
	if enemy == null or not ("active_statuses" in enemy):
		return
	if not enemy.active_statuses.has("burning"):
		return
	var cell: Vector2i = enemy.grid_position if "grid_position" in enemy else Vector2i.ZERO
	for e in ArtifactManager.get_enemies():
		if e == enemy:
			continue
		if not ("grid_position" in e):
			continue
		var d: Vector2i = e.grid_position - cell
		if absi(d.x) + absi(d.y) == 1:
			e.take_damage(4, true, false, false)
	notify_triggered("Embercleaver explosion")
