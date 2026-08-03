extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	var bonus := int(ArtifactManager.hp_lost_this_combat / 5)
	runtime["str_bonus"] = bonus
	if bonus > 0:
		ArtifactManager.apply_status_to_unit(player_unit(), "strength", bonus, 1)

func on_enemy_death(_ctx: Dictionary) -> void:
	PlayerData.gain_energy(1)
	runtime["discount_next"] = true
	notify_triggered("Bloodrage Cleaver")

func modify_card_cost(card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	if runtime.get("discount_next", false) and ArtifactManager._card_is_attack(card):
		runtime["discount_next"] = false
		return maxi(0, cost - 1)
	return cost
