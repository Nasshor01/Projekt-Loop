extends ArtifactBehavior

func on_hand_ready(_ctx: Dictionary) -> void:
	if PlayerData.current_hand.is_empty():
		return
	var c = PlayerData.current_hand.pick_random()
	PlayerData.current_hand.erase(c)
	PlayerData.add_card_to_discard_pile(c)
	var roll := randi() % 4
	match roll:
		0:
			PlayerData.draw_cards(1)
		1:
			var u := player_unit()
			if u:
				u.add_block(3)
		2:
			var u2 := player_unit()
			if u2:
				u2.heal(3)
		3:
			PlayerData.gain_energy(1)
	notify_triggered("Alchemist's Tools")
