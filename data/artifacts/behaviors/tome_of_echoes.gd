extends ArtifactBehavior

const MIN_ENERGY_COST := 2
const ECHO_USES_PER_COMBAT := 1


func on_card_played(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card == null or card.cost < MIN_ENERGY_COST:
		return
	if card.effects.any(func(e): return e.effect_type == CardEffectData.EffectType.EXHAUST):
		return
	ctx["send_to_deck_bottom"] = true


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if int(runtime.get("echo_uses", 0)) >= ECHO_USES_PER_COMBAT:
		return
	if PlayerData:
		PlayerData.draw_cards(2)
		if not PlayerData.current_hand.is_empty():
			var discard: CardData = PlayerData.current_hand.pick_random()
			PlayerData.current_hand.erase(discard)
			PlayerData.add_card_to_discard_pile(discard)
		runtime["echo_uses"] = int(runtime.get("echo_uses", 0)) + 1
