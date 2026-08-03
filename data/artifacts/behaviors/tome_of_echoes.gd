extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["used_draw"] = false

func on_card_played(ctx: Dictionary) -> void:
	var card: CardData = ctx.get("card")
	var cost := int(ctx.get("card_cost", card.cost if card else 0))
	if card == null or cost < 2:
		return
	# Mark for bottom-deck instead of discard — BattleScene checks meta
	card.set_meta("tome_to_bottom", true)

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("used_draw", false):
		return
	runtime["used_draw"] = true
	PlayerData.draw_cards(2)
	if not PlayerData.current_hand.is_empty():
		var c = PlayerData.current_hand.pick_random()
		PlayerData.current_hand.erase(c)
		PlayerData.add_card_to_discard_pile(c)
