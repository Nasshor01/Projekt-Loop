extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["last_fired_turn"] = -1

func on_turn_end(ctx: Dictionary) -> void:
	var turn := int(ctx.get("combat_turn", ArtifactManager.combat_turn))
	if turn > 0 and turn % 3 == 0 and int(runtime.get("last_fired_turn", -1)) != turn:
		runtime["last_fired_turn"] = turn
		ArtifactManager.request_extra_turn()
		notify_triggered("Time Crystal: extra turn")
