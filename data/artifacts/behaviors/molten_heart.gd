extends ArtifactBehavior

const STRENGTH_VALUE := 1


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var player := _get_player_unit()
	if player:
		_apply_status(player, "monk_blessing", STRENGTH_VALUE, 1)


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target")
	if is_instance_valid(target):
		_apply_status(target, "burning", 1, 3)
		var player := _get_player_unit()
		if player and player.has_method("heal"):
			player.heal(1)
