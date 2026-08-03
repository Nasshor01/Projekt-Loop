extends ArtifactBehavior

const SEALED_COST_REDUCTION := 1
const SEAL_BLOCK_BONUS := 2


func on_combat_start(ctx: Dictionary = {}) -> void:
	runtime["sealed_card_id"] = ""
	runtime["seal_pick_pending"] = true


func on_hand_ready(ctx: Dictionary = {}) -> void:
	if not runtime.get("seal_pick_pending", false):
		return
	runtime["seal_pick_pending"] = false
	# UI seal pick not wired — seal first master_deck card as best-effort fallback.
	if PlayerData and not PlayerData.master_deck.is_empty():
		var card: CardData = PlayerData.master_deck[0]
		if card:
			runtime["sealed_card_id"] = card.card_id


func on_card_played(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card == null:
		return
	if runtime.get("sealed_card_id", "") == card.card_id:
		var player := _get_player_unit()
		if player and player.has_method("add_block"):
			player.add_block(SEAL_BLOCK_BONUS)


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var card: CardData = ctx.get("card") as CardData
	if card and runtime.get("sealed_card_id", "") == card.card_id:
		return maxi(0, cost - SEALED_COST_REDUCTION)
	return cost
