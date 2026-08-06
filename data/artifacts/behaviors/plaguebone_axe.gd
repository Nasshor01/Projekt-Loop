extends ArtifactBehavior

const POISON_VALUE := 2
const POISON_THRESHOLD := 8
const BONUS_DAMAGE := 3


func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return damage
	var attacker: Node = ctx.get("attacker") as Node
	var player: Node = _get_player_unit()
	if player != null and is_instance_valid(attacker) and attacker != player:
		return damage
	if _status_value(target, "poison") >= POISON_THRESHOLD:
		return damage + BONUS_DAMAGE
	return damage


func should_ignore_block(ctx: Dictionary = {}) -> bool:
	var target: Node = ctx.get("target") as Node
	return is_instance_valid(target) and _status_value(target, "poison") >= POISON_THRESHOLD


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if is_instance_valid(target):
		_apply_status(target, "poison", POISON_VALUE, 99)
