extends ArtifactBehavior

const CHILL_VALUE := 1
const CHILL_THRESHOLD := 3
const BONUS_DAMAGE := 4
const HEAL_AMOUNT := 2


func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	# Bonus applies when the target already has 3+ Chill (next hits after freeze threshold).
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return damage
	var attacker: Node = ctx.get("attacker") as Node
	var player: Node = _get_player_unit()
	if player != null and is_instance_valid(attacker) and attacker != player:
		return damage
	if _status_value(target, "chilled") >= CHILL_THRESHOLD:
		return damage + BONUS_DAMAGE
	return damage


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return
	_apply_status(target, "chilled", CHILL_VALUE, 2)
	# Heal when this hit pushes Chill to 3+ (Unit also freezes at 3 Chill).
	if _status_value(target, "chilled") >= CHILL_THRESHOLD:
		var player: Node = _get_player_unit()
		if player != null and player.has_method("heal"):
			player.call("heal", HEAL_AMOUNT)
