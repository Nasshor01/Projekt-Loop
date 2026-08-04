extends ArtifactBehavior

const PICK_COUNT := 2
const COST_REDUCTION := 1


func on_acquired(_ctx: Dictionary = {}) -> void:
	if not PlayerData or PlayerData.master_deck.is_empty():
		return
	# Already applied this run (artifact can stay equipped — don't re-roll).
	if runtime.get("applied", false):
		return
	PlayerData.ensure_unique_master_deck_instances()
	var pool: Array[CardData] = []
	for card_v in PlayerData.master_deck:
		var card: CardData = card_v as CardData
		if card == null:
			continue
		# Don't stack with Tablet seal on the same physical card.
		if card.has_meta("artifact_sealed") and bool(card.get_meta("artifact_sealed")):
			continue
		if card.has_meta("artifact_oathbroken") and bool(card.get_meta("artifact_oathbroken")):
			continue
		pool.append(card)
	if pool.is_empty():
		return
	pool.shuffle()
	var picks: Array[CardData] = []
	for i in mini(PICK_COUNT, pool.size()):
		picks.append(pool[i])
	var pick_ids: Array[String] = []
	for card in picks:
		card.cost = maxi(0, card.cost - COST_REDUCTION)
		card.set_meta("artifact_retain", true)
		card.set_meta("artifact_oathbroken", true)
		pick_ids.append(card.card_id)
	runtime["applied"] = true
	runtime["oathbroken_card_ids"] = pick_ids
