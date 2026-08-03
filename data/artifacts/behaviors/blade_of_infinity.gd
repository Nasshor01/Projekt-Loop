extends ArtifactBehavior


func on_exhaust(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card == null or not card.tags.has(CardData.CardTag.ATTACK):
		return
	ctx["return_to_deck_bottom"] = true
	ctx["cancel_exhaust"] = true
