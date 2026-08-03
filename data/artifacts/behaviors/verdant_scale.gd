extends ArtifactBehavior

func on_unit_moved(ctx: Dictionary) -> void:
	if not ctx.get("is_player", false):
		return
	var steps := int(ctx.get("steps", 1))
	var u := player_unit()
	if u:
		u.add_block(maxi(1, steps))

func on_turn_end(ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null or not ("grid_position" in u):
		return
	var cell: Vector2i = u.grid_position
	var adj := 0
	var near: Array = []
	for e in ArtifactManager.get_enemies():
		if not ("grid_position" in e):
			continue
		var d: Vector2i = e.grid_position - cell
		if absi(d.x) + absi(d.y) == 1:
			adj += 1
			near.append(e)
	if adj >= 2:
		for e in near:
			ArtifactManager.apply_status_to_unit(e, "weakness", 1, 2)
