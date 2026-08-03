extends ArtifactBehavior


func on_card_played(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_moves_unit(card):
		return
	var player: Node = _get_player_unit()
	if player != null and player.has_method("add_block"):
		player.call("add_block", 1)
	var enemy: Node = _random_living_enemy()
	if enemy != null:
		_apply_status(enemy, "weakness", 1, 1)
	var grid: Node = _find_battle_grid()
	if grid != null and player != null and _is_grid_edge(grid, _unit_grid_pos(player)):
		if player.has_method("add_block"):
			player.call("add_block", 1)
		if enemy != null:
			_apply_status(enemy, "weakness", 1, 1)
