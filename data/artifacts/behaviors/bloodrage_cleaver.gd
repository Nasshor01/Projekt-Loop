extends ArtifactBehavior

const HP_PER_STRENGTH := 5
const COST_REDUCTION := 1


func on_combat_start(_ctx: Dictionary = {}) -> void:
	runtime["hp_lost_this_combat"] = 0
	runtime["strength_stacks"] = 0
	runtime["next_attack_discount"] = 0
	runtime["defer_discount_consume"] = false


func on_damage_taken(ctx: Dictionary = {}) -> void:
	super.on_damage_taken(ctx)
	var lost := int(runtime.get("hp_lost_this_combat", 0))
	@warning_ignore("integer_division")
	var stacks := lost / HP_PER_STRENGTH
	var applied := int(runtime.get("strength_stacks", 0))
	if stacks > applied:
		_add_combat_damage_bonus(stacks - applied)
		runtime["strength_stacks"] = stacks


func on_enemy_death(_ctx: Dictionary = {}) -> void:
	if PlayerData:
		PlayerData.gain_energy(1)
	runtime["next_attack_discount"] = COST_REDUCTION
	# Kill during card resolution: on_card_played follows — don't let that play consume the new discount.
	if _is_card_play_in_progress():
		runtime["defer_discount_consume"] = true


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
	if runtime.get("defer_discount_consume", false):
		runtime["defer_discount_consume"] = false
		return
	runtime["next_attack_discount"] = 0


func _is_card_play_in_progress() -> bool:
	var battle := _find_battle_scene()
	if battle == null:
		return false
	return bool(battle.get("_card_play_in_progress"))
