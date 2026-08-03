extends ArtifactBehavior


func on_move(ctx: Dictionary = {}) -> void:
	var steps := int(ctx.get("steps", ctx.get("distance", 1)))
	var player := _get_player_unit()
	if player and player.has_method("add_block"):
		player.add_block(steps)
	var grid := _find_battle_grid()
	if not player or not grid:
		return
	var adjacent_enemies := 0
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = player.grid_position + offset
		var unit := grid.get_object_on_cell(cell)
		if unit and unit.get("unit_data") and unit.unit_data.faction == UnitData.Faction.ENEMY:
			adjacent_enemies += 1
	if adjacent_enemies >= 2:
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var cell: Vector2i = player.grid_position + offset
			var unit := grid.get_object_on_cell(cell)
			if unit and unit.get("unit_data") and unit.unit_data.faction == UnitData.Faction.ENEMY:
				_apply_status(unit, "weakness", 1, 1)
