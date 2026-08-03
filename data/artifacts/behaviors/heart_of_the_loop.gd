extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	PlayerData.gain_energy(1)
	runtime["panic_used"] = false
	runtime["attacks"] = []

func on_card_played(ctx: Dictionary) -> void:
	if ctx.get("is_attack", false):
		var arr: Array = runtime.get("attacks", [])
		arr.append(ctx.get("card"))
		runtime["attacks"] = arr

func on_turn_end(ctx: Dictionary) -> void:
	var turn := int(ctx.get("combat_turn", ArtifactManager.combat_turn))
	if turn > 0 and turn % 4 == 0:
		var arr: Array = runtime.get("attacks", [])
		if arr.size() > 0:
			notify_triggered("Heart of the Loop: echo attack")
			# Echo is visual/log for now; full replay needs BattleScene support
	runtime["attacks"] = []

func on_unblocked_damage(_ctx: Dictionary) -> void:
	if runtime.get("panic_used", false):
		return
	if PlayerData.max_hp <= 0:
		return
	var pct := float(PlayerData.current_hp) / float(PlayerData.max_hp)
	if pct <= 0.25:
		runtime["panic_used"] = true
		ArtifactManager.set_run_flag("skip_enemy_round", true)
		notify_triggered("Heart of the Loop: skip enemy turn")
