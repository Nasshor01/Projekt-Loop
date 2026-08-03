extends ArtifactBehavior

const CHILL_VALUE := 1
const CHILL_THRESHOLD := 3
const BONUS_DAMAGE := 4
const HEAL_AMOUNT := 2


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target")
	if not is_instance_valid(target):
		return
	_apply_status(target, "chilled", CHILL_VALUE, 2)
	if target.active_statuses.has("chilled"):
		var chill := int(target.active_statuses["chilled"].get("value", 0))
		if chill >= CHILL_THRESHOLD:
			ctx["flat_damage_bonus"] = int(ctx.get("flat_damage_bonus", 0)) + BONUS_DAMAGE
			var player := _get_player_unit()
			if player and player.has_method("heal"):
				player.heal(HEAL_AMOUNT)
