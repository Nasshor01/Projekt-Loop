extends ArtifactBehavior


func on_turn_end(ctx: Dictionary = {}) -> void:
	var player := _get_player_unit()
	var grid := _find_battle_grid()
	if not player or not grid:
		return
	if _is_grid_edge(grid, player.grid_position):
		if player.has_method("add_block"):
			player.add_block(2)
	else:
		runtime["draw_next_turn"] = true


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if runtime.get("draw_next_turn", false) and PlayerData:
		PlayerData.draw_cards(1)
		runtime["draw_next_turn"] = false
