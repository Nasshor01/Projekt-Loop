extends ArtifactBehavior

const SELF_DAMAGE := 3
const DRAW_AMOUNT := 2
const PROMPT_ID := "crimson_chalice"


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["prompted_this_turn"] = false


func on_hand_ready(_ctx: Dictionary = {}) -> void:
	if runtime.get("prompted_this_turn", false):
		return
	if not PlayerData or PlayerData.current_hp <= SELF_DAMAGE:
		return
	if not _root_has_node("/root/ArtifactManager"):
		return
	runtime["prompted_this_turn"] = true
	ArtifactManager.set_run_flag("pending_chalice", true)


func on_prompt_result(prompt_id: String, result: Dictionary) -> void:
	if prompt_id != PROMPT_ID:
		return
	if not bool(result.get("accepted", false)):
		return
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
