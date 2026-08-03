extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "strength", 3, 99)
	ArtifactManager.apply_status_to_unit(u, "dexterity", 3, 99)
	runtime["max_hp_penalty"] = 0

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["max_hp_penalty"] = int(runtime.get("max_hp_penalty", 0)) + 1
	# Combat-only max HP drain via meta
	PlayerData.set_meta("voidheart_max_hp_penalty", runtime["max_hp_penalty"])
	var u := player_unit()
	if u:
		u.current_health = mini(u.current_health, maxi(1, PlayerData.max_hp - runtime["max_hp_penalty"]))
		PlayerData.current_hp = u.current_health

func on_combat_end(_ctx: Dictionary) -> void:
	if PlayerData.has_meta("voidheart_max_hp_penalty"):
		PlayerData.remove_meta("voidheart_max_hp_penalty")
