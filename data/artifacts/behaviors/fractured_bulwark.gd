extends ArtifactBehavior

const MAX_DRAW_PER_TURN := 1
const DELAY_USES_PER_COMBAT := 1


func on_combat_start(_ctx: Dictionary = {}) -> void:
	runtime["delay_used"] = false
	runtime["delay_uses"] = 0
	runtime["delay_pending"] = false
	runtime["delayed_damage"] = 0
	runtime["drew_this_turn"] = false
	runtime["pending_draw"] = false


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	# Hits deferred during the enemy phase land here at the start of your next turn.
	_resolve_delayed_damage()
	runtime["drew_this_turn"] = false


func on_turn_end(_ctx: Dictionary = {}) -> void:
	if runtime.get("pending_draw", false) and PlayerData:
		PlayerData.draw_cards(1)
		runtime["pending_draw"] = false
	# Hits deferred during your own turn land at end of that turn.
	_resolve_delayed_damage()


func on_damage_taken(ctx: Dictionary = {}) -> void:
	super.on_damage_taken(ctx)
	var unblocked := int(ctx.get("unblocked_amount", 0))
	if unblocked <= 0:
		return
	if not runtime.get("drew_this_turn", false):
		runtime["pending_draw"] = true
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


func _resolve_delayed_damage() -> void:
	if not runtime.get("delay_pending", false):
		return
	var amount := int(runtime.get("delayed_damage", 0))
	runtime["delay_pending"] = false
	runtime["delayed_damage"] = 0
	if amount <= 0:
		return
	var player := _get_player_unit()
	if player and player.has_method("take_damage"):
		player.take_damage(amount, false, false, true, true)
