extends ArtifactBehavior

const CHILL_VALUE := 1
const CHILL_THRESHOLD := 3


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return
	_apply_status(target, "chilled", CHILL_VALUE, 2)
	if _has_status(target, "chilled"):
		var chill: int = _status_value(target, "chilled")
		if chill >= CHILL_THRESHOLD:
			_apply_status(target, "weakness", 1, 1)
			ctx["damage_multiplier"] = 1.5
