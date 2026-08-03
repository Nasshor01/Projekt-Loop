extends ArtifactBehavior

const POISON_VALUE := 2
const POISON_THRESHOLD := 8
const BONUS_DAMAGE := 3


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if is_instance_valid(target):
		_apply_status(target, "poison", POISON_VALUE, 99)
		if _has_status(target, "poison"):
			var val: int = _status_value(target, "poison")
			if val >= POISON_THRESHOLD:
				ctx["ignore_block"] = true
				ctx["flat_damage_bonus"] = int(ctx.get("flat_damage_bonus", 0)) + BONUS_DAMAGE
