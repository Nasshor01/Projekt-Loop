extends ArtifactBehavior

func on_hand_ready(_ctx: Dictionary) -> void:
	if PlayerData.current_hp <= 3:
		return
	var u := player_unit()
	if u and u.has_method("take_damage"):
		u.take_damage(3, true, false, false)
	if not PlayerData.current_hand.is_empty():
		var c = PlayerData.current_hand.pick_random()
		PlayerData.current_hand.erase(c)
		PlayerData.add_card_to_discard_pile(c)
	PlayerData.draw_cards(2)
	notify_triggered("Crimson Chalice")
