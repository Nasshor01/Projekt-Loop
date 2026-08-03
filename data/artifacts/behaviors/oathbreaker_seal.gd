extends ArtifactBehavior

func on_acquired(_ctx: Dictionary = {}) -> void:
	if PlayerData.master_deck.is_empty():
		return
	var indices: Array[int] = []
	for i in range(PlayerData.master_deck.size()):
		indices.append(i)
	indices.shuffle()
	var n := mini(2, indices.size())
	for i in range(n):
		var card: CardData = PlayerData.master_deck[indices[i]]
		if card == null:
			continue
		card.cost = maxi(0, card.cost - 1)
		card.set_meta("oathbreaker_retain", true)
	notify_triggered("Oathbreaker Seal marked %d cards" % n)
	PlayerData.emit_signal("deck_changed")
