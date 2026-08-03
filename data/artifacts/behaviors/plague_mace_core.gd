extends ArtifactBehavior

const POISON_VALUE := 1
const POISON_THRESHOLD := 5
const BONUS_DAMAGE := 2


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card and not _card_is_melee_attack(card):
		return
	var target: Node = ctx.get("target")
	if is_instance_valid(target):
		_apply_status(target, "poison", POISON_VALUE, 99)


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	# Enemy turn poison bonus — tick when player turn starts (after enemy acted).
	for enemy in _get_enemies():
		if not is_instance_valid(enemy):
			continue
		if not enemy.active_statuses.has("poison"):
			continue
		var poison_val := int(enemy.active_statuses["poison"].get("value", 0))
		if poison_val >= POISON_THRESHOLD and enemy.has_method("take_damage"):
			enemy.take_damage(BONUS_DAMAGE, true, false, false)
			if PlayerData:
				PlayerData.gain_energy(1)
