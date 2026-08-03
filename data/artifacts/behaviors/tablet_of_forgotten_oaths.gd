extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	if PlayerData.master_deck.is_empty() and PlayerData.draw_pile.is_empty():
		return
	var pool: Array = []
	pool.append_array(PlayerData.draw_pile)
	pool.append_array(PlayerData.discard_pile)
	pool.append_array(PlayerData.current_hand)
	if pool.is_empty():
		pool.append_array(PlayerData.master_deck)
	if pool.is_empty():
		return
	var card: CardData = pool.pick_random()
	runtime["sealed_card_id"] = card.card_id
	card.set_meta("tablet_sealed", true)
	notify_triggered("Sealed: %s" % card.card_name)

func modify_card_cost(card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	if card and card.get_meta("tablet_sealed", false):
		return maxi(0, cost - 1)
	return cost

func on_card_played(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	if card and card.get_meta("tablet_sealed", false):
		var u := player_unit()
		if u and u.has_method("add_block"):
			u.add_block(2)
