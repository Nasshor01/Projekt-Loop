extends ArtifactBehavior


func on_move(ctx: Dictionary = {}) -> void:
	var steps: int = int(ctx.get("steps", ctx.get("distance", 1)))
	var player: Node = _get_player_unit()
	if player != null and player.has_method("add_block"):
		player.call("add_block", steps)


func on_turn_end(_ctx: Dictionary = {}) -> void:
	var player: Node = _get_player_unit()
	var grid: Node = _find_battle_grid()
	if player == null or grid == null:
		return
	var adjacent_enemies: int = 0
	var player_pos: Vector2i = player.get("grid_position") as Vector2i
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in offsets:
		var cell: Vector2i = player_pos + offset
		var unit: Node = _grid_object_on_cell(grid, cell)
		if unit != null:
			var ud: Variant = unit.get("unit_data")
			if ud != null and ud.faction == UnitData.Faction.ENEMY:
				adjacent_enemies += 1
	if adjacent_enemies >= 2:
		for offset in offsets:
			var cell: Vector2i = player_pos + offset
			var unit: Node = _grid_object_on_cell(grid, cell)
			if unit != null:
				var ud: Variant = unit.get("unit_data")
				if ud != null and ud.faction == UnitData.Faction.ENEMY:
					_apply_status(unit, "weakness", 1, 1)
