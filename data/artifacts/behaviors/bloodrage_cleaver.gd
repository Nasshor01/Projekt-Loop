extends ArtifactBehavior

const HP_PER_STRENGTH := 5
const COST_REDUCTION := 1


func on_damage_taken(ctx: Dictionary = {}) -> void:
	super.on_damage_taken(ctx)
	var lost := int(runtime.get("hp_lost_this_combat", 0))
	var stacks := lost / HP_PER_STRENGTH
	var applied := int(runtime.get("strength_stacks", 0))
	if stacks > applied:
		_add_combat_damage_bonus(stacks - applied)
		runtime["strength_stacks"] = stacks


func on_enemy_death(ctx: Dictionary = {}) -> void:
	if PlayerData:
		PlayerData.gain_energy(1)
	runtime["next_attack_discount"] = COST_REDUCTION


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var card: CardData = ctx.get("card") as CardData
	if card and _card_is_attack(card) and int(runtime.get("next_attack_discount", 0)) > 0:
		runtime["next_attack_discount"] = 0
		return maxi(0, cost - COST_REDUCTION)
	return cost
