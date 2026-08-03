extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	var u := player_unit()
	ArtifactManager.apply_status_to_unit(u, "thorns", 2, 99)

func on_turn_start(_ctx: Dictionary) -> void:
	runtime["thorns_block_count"] = 0

func on_thorns_damage(_ctx: Dictionary) -> void:
	var n := int(runtime.get("thorns_block_count", 0))
	if n >= 3:
		return
	runtime["thorns_block_count"] = n + 1
	var u := player_unit()
	if u:
		u.add_block(1)
