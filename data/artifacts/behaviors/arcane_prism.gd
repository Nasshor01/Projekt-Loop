extends ArtifactBehavior

func on_turn_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null:
		return
	var opts := ["strength", "dexterity", "focus"]
	var pick: String = opts[randi() % opts.size()]
	ArtifactManager.apply_status_to_unit(u, pick, 1, 99)
	var distinct := 0
	for s in opts:
		if u.active_statuses.has(s):
			distinct += 1
	if distinct >= 2:
		PlayerData.gain_energy(1)
		notify_triggered("Arcane Prism: +1 Energy")
