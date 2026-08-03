extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["drew_this_turn"] = false
	runtime["delay_used"] = false
	runtime["pending_draw"] = false

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["drew_this_turn"] = false
	if runtime.get("pending_draw", false):
		runtime["pending_draw"] = false
		PlayerData.draw_cards(1)
	if runtime.get("delayed_damage", 0) > 0:
		var dmg := int(runtime["delayed_damage"])
		runtime["delayed_damage"] = 0
		var u := player_unit()
		if u:
			u.take_damage(dmg, true, false, false)

func on_unblocked_damage(_ctx: Dictionary) -> void:
	if not runtime.get("drew_this_turn", false):
		runtime["drew_this_turn"] = true
		runtime["pending_draw"] = true
