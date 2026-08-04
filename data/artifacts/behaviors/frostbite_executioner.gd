extends ArtifactBehavior

const CHILL_VALUE := 1
const CHILL_THRESHOLD := 3
const BONUS_MULT := 1.5


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return
	_apply_status(target, "chilled", CHILL_VALUE, 2)
	if _status_value(target, "chilled") >= CHILL_THRESHOLD:
		_apply_status(target, "weakness", 1, 1)


func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target: Node = ctx.get("target") as Node
	if is_instance_valid(target) and _status_value(target, "chilled") >= CHILL_THRESHOLD:
		return int(round(float(damage) * BONUS_MULT))
	return damage
