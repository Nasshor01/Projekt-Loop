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
	# After the first melee this turn, the next attack costs -1 (set now; consumed on next play).
	if not runtime.get("attacked_this_turn", false):
		runtime["next_attack_discount"] = COST_REDUCTION
		# on_damage_dealt runs before on_card_played for the same card — don't let that play eat it.
		runtime["defer_discount_consume"] = true
	runtime["attacked_this_turn"] = true


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["attacked_this_turn"] = false
	runtime["next_attack_discount"] = 0
	runtime["defer_discount_consume"] = false


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var card: CardData = ctx.get("card") as CardData
	if card and _card_is_attack(card) and int(runtime.get("next_attack_discount", 0)) > 0:
		return maxi(0, cost - COST_REDUCTION)
	return cost


func on_card_played(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not (card and _card_is_attack(card)):
		return
	if int(runtime.get("next_attack_discount", 0)) <= 0:
		return
	# Skip consume once when this same card just armed the discount in on_damage_dealt.
	if runtime.get("defer_discount_consume", false):
		runtime["defer_discount_consume"] = false
		return
	runtime["next_attack_discount"] = 0
