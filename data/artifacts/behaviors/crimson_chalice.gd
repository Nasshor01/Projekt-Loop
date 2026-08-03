extends ArtifactBehavior

const SELF_DAMAGE := 3
const DRAW_AMOUNT := 2


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if not PlayerData or PlayerData.current_hp <= SELF_DAMAGE:
		return
	var player := _get_player_unit()
	if player and player.has_method("take_damage"):
		player.take_damage(SELF_DAMAGE, false, false, true)
	if not PlayerData.current_hand.is_empty():
		var discard: CardData = PlayerData.current_hand.pick_random()
		PlayerData.current_hand.erase(discard)
		PlayerData.add_card_to_discard_pile(discard)
	PlayerData.draw_cards(DRAW_AMOUNT)
