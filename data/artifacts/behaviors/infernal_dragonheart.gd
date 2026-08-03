extends ArtifactBehavior

func on_status_applied(ctx: Dictionary) -> void:
	if ctx.get("status_id") != "burning":
		return
	var enemy = ctx.get("unit")
	var u := player_unit()
	if u == null or enemy == null or enemy == u:
		return
	if not ("grid_position" in u and "grid_position" in enemy):
		return
	var from: Vector2i = u.grid_position
	var to: Vector2i = enemy.grid_position
	var step := Vector2i(
		clampi(to.x - from.x, -1, 1),
		clampi(to.y - from.y, -1, 1)
	)
	if step == Vector2i.ZERO:
		return
	var dest := from + step
	var scene = ArtifactManager.get_tree().current_scene if ArtifactManager.get_tree() else null
	if scene != null and "battle_grid_instance" in scene:
		var grid = scene.battle_grid_instance
		if grid and grid.has_method("remove_object_by_instance") and grid.has_method("place_object_on_cell"):
			grid.remove_object_by_instance(u)
			grid.place_object_on_cell(u, dest, false, 0.0)
		else:
			u.grid_position = dest
	else:
		u.grid_position = dest
	ArtifactManager.on_unit_moved(u, from, dest, 1)
	var d: Vector2i = dest - to
	if absi(d.x) + absi(d.y) == 1:
		enemy.apply_status("burning", 1, 3)
