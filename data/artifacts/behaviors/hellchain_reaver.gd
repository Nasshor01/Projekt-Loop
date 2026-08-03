extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["gave_str"] = false

func on_card_played(ctx: Dictionary) -> void:
	if not ctx.get("is_attack", false):
		return
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "strength", 2, 1)
	runtime["discount_next"] = int(ctx.get("attacks_this_turn", 1)) >= 1

func modify_card_cost(card: CardData, cost: int, ctx: Dictionary = {}) -> int:
	if runtime.get("discount_next", false) and ArtifactManager._card_is_attack(card) and ArtifactManager.attacks_this_turn >= 1:
		return maxi(0, cost - 1)
	return cost
