extends ArtifactBehavior

func on_card_played(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	if card == null:
		return
	var is_move := card.has_method("has_tag") and card.has_tag(CardData.CardTag.MOVE)
	if not is_move:
		return
	var block := 1
	var weak := 1
	var u := player_unit()
	if u and "grid_position" in u and ArtifactManager.is_edge_cell(u.grid_position):
		block *= 2
		weak *= 2
	if u:
		u.add_block(block)
	var enemies := ArtifactManager.get_enemies()
	if enemies.size() > 0:
		var t = enemies[randi() % enemies.size()]
		ArtifactManager.apply_status_to_unit(t, "weakness", weak, 2)
