extends ArtifactBehavior

const POISON_VALUE := 1
const POISON_THRESHOLD := 5
const BONUS_DAMAGE := 2


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card != null and not _card_is_melee_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if is_instance_valid(target):
		_apply_status(target, "poison", POISON_VALUE, 99)


func on_enemy_turn_start(ctx: Dictionary = {}) -> void:
	var enemy: Node = ctx.get("enemy") as Node
	if not is_instance_valid(enemy):
		return
	if not _has_status(enemy, "poison"):
		return
	var poison_val: int = _status_value(enemy, "poison")
	if poison_val >= POISON_THRESHOLD and enemy.has_method("take_damage"):
		enemy.call("take_damage", BONUS_DAMAGE, true, false, false)
		if PlayerData:
			PlayerData.gain_energy(1)
