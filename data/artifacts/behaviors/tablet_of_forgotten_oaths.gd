extends ArtifactBehavior

## On acquire: pick one deck card to seal forever. Artifact stays (not consumed).
## Cost (−1) and Block (+2 on play) are applied by ArtifactManager permanent seal helpers.


func on_acquired(_ctx: Dictionary = {}) -> void:
	if not _root_has_node("/root/ArtifactManager"):
		return
	if PlayerData == null or PlayerData.master_deck.is_empty():
		return
	# Already sealed a card this run — keep Tablet, no second pick.
	if not PlayerData.sealed_card_id.is_empty():
		return
	for card_v in PlayerData.master_deck:
		var card: CardData = card_v as CardData
		if card != null and card.has_meta("artifact_sealed") and bool(card.get_meta("artifact_sealed")):
			return
	ArtifactManager.request_permanent_seal_pick()
