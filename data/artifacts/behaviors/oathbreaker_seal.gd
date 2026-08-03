extends ArtifactBehavior

const PICK_COUNT := 2
const COST_REDUCTION := 1


func on_acquired(ctx: Dictionary = {}) -> void:
	if not PlayerData or PlayerData.master_deck.is_empty():
		return
	var picks: Array[CardData] = []
	var deck := PlayerData.master_deck.duplicate()
	deck.shuffle()
	for i in mini(PICK_COUNT, deck.size()):
		picks.append(deck[i])
	for card in picks:
		if card:
			card.cost = maxi(0, card.cost - COST_REDUCTION)
			if not card.tags.has(CardData.CardTag.POWER):
				# Retain via runtime tracking — full Retain tag not in CardTag enum.
				card.set_meta("artifact_retain", true)
	runtime["retain_cards"] = picks.map(func(c): return c.card_id)
