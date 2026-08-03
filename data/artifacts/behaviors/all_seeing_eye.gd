extends ArtifactBehavior

const PREVIEW_USES_PER_COMBAT := 1


func on_combat_start(ctx: Dictionary = {}) -> void:
	runtime["preview_enabled"] = true
	runtime["deny_move_uses"] = 0


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	# Movement preview arrows — requires UI integration; flag for battle scene.
	ctx["show_enemy_move_preview"] = runtime.get("preview_enabled", true)


func on_hand_ready(ctx: Dictionary = {}) -> void:
	if int(runtime.get("deny_move_uses", 0)) >= PREVIEW_USES_PER_COMBAT:
		return
	var enemy := _random_living_enemy()
	if enemy:
		enemy.set_meta("artifact_deny_move_next_turn", true)
		runtime["deny_move_uses"] = int(runtime.get("deny_move_uses", 0)) + 1
