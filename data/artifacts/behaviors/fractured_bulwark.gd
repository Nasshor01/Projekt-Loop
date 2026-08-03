extends ArtifactBehavior

const MAX_DRAW_PER_TURN := 1
const DELAY_USES_PER_COMBAT := 1


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["drew_this_turn"] = false
	runtime["delay_pending"] = false


func on_turn_end(ctx: Dictionary = {}) -> void:
	if runtime.get("delay_pending", false):
		var amount := int(runtime.get("delayed_damage", 0))
		if amount > 0:
			var player := _get_player_unit()
			if player and player.has_method("take_damage"):
				player.take_damage(amount, false, false, true)
		runtime["delay_pending"] = false
		runtime["delayed_damage"] = 0


func on_damage_taken(ctx: Dictionary = {}) -> void:
	super.on_damage_taken(ctx)
	var unblocked := int(ctx.get("unblocked_amount", 0))
	if unblocked <= 0:
		return
	if not runtime.get("drew_this_turn", false) and PlayerData:
		PlayerData.draw_cards(1)
		runtime["drew_this_turn"] = true
	if runtime.get("delay_used", false):
		return
	if int(runtime.get("delay_uses", 0)) >= DELAY_USES_PER_COMBAT:
		return
	var amount := int(ctx.get("damage_amount", 0))
	if amount <= 0:
		return
	runtime["delayed_damage"] = amount
	runtime["delay_pending"] = true
	runtime["delay_used"] = true
	runtime["delay_uses"] = int(runtime.get("delay_uses", 0)) + 1
	ctx["damage_deferred"] = true
