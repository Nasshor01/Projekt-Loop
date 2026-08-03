extends ArtifactBehavior

func on_turn_end(ctx: Dictionary) -> void:
	var cell: Vector2i = ctx.get("player_cell", Vector2i.ZERO)
	var u := player_unit()
	if u == null:
		return
	if ArtifactManager.is_edge_cell(cell):
		u.add_block(2)
	else:
		runtime["draw_next"] = true

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("draw_next", false):
		runtime["draw_next"] = false
		PlayerData.draw_cards(1)
