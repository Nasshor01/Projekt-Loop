extends ArtifactBehavior


func on_turn_end(_ctx: Dictionary = {}) -> void:
	var player: Node = _get_player_unit()
	var grid: Node = _find_battle_grid()
	if player == null or grid == null:
		return
	if _is_grid_edge(grid, _unit_grid_pos(player)):
		if player.has_method("add_block"):
			player.call("add_block", 2)
	else:
		runtime["draw_next_turn"] = true


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if runtime.get("draw_next_turn", false) and PlayerData:
		PlayerData.draw_cards(1)
		runtime["draw_next_turn"] = false
