extends ArtifactBehavior

func on_exhaust(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	if card == null:
		return
	if not ArtifactManager._card_is_attack(card):
		return
	# Return to bottom of draw pile
	PlayerData.exhaust_pile.erase(card)
	PlayerData.draw_pile.append(card)
	notify_triggered("Blade of Infinity recycled attack")
