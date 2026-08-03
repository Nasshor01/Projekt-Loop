extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null or not ("grid_position" in u):
		return
	var cell: Vector2i = u.grid_position
	var far := 0
	var near := 0
	for e in ArtifactManager.get_enemies():
		if not ("grid_position" in e):
			continue
		var d: Vector2i = e.grid_position - cell
		var dist: int = absi(d.x) + absi(d.y)
		if dist >= 3:
			far += 1
		if dist == 1:
			near += 1
	if far > 0:
		ArtifactManager.apply_status_to_unit(u, "strength", far, 1)
	if near > 0:
		u.take_damage(near, true, false, false)
