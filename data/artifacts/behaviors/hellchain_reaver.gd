extends ArtifactBehavior

const STRENGTH_BONUS := 2
const COST_REDUCTION := 1


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_melee_attack(card):
		return
	var player := _get_player_unit()
	if player:
		_apply_status(player, "monk_blessing", STRENGTH_BONUS, 1)
	if runtime.get("attacked_this_turn", false) and PlayerData:
		runtime["next_attack_discount"] = COST_REDUCTION
	runtime["attacked_this_turn"] = true


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["attacked_this_turn"] = false
	runtime["next_attack_discount"] = 0


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var card: CardData = ctx.get("card") as CardData
	if card and _card_is_attack(card) and int(runtime.get("next_attack_discount", 0)) > 0:
		runtime["next_attack_discount"] = 0
		return maxi(0, cost - COST_REDUCTION)
	return cost
