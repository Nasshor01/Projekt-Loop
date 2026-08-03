extends ArtifactBehavior


func on_card_played(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_moves_unit(card):
		return
	var player := _get_player_unit()
	if player and player.has_method("add_block"):
		player.add_block(1)
	var enemy := _random_living_enemy()
	if enemy:
		_apply_status(enemy, "weakness", 1, 1)
	var grid := _find_battle_grid()
	if grid and player and _is_grid_edge(grid, player.grid_position):
		if player.has_method("add_block"):
			player.add_block(1)
		if enemy:
			_apply_status(enemy, "weakness", 1, 1)
