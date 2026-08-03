extends ArtifactBehavior

const STATUS_POOL := ["monk_blessing", "aura_devotion", "draw_plus_one"]
const ENERGY_THRESHOLD_STATUSES := 2


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var player := _get_player_unit()
	if not player:
		return
	var pick := STATUS_POOL[randi_range(0, STATUS_POOL.size() - 1)]
	match pick:
		"monk_blessing":
			_apply_status(player, "monk_blessing", 1, 1)
		"aura_devotion":
			_apply_status(player, "aura_devotion", 1, 1)
		"draw_plus_one":
			_apply_status(player, "draw_plus_one", 1, 1)
	var distinct := _count_distinct_statuses(player)
	if distinct >= ENERGY_THRESHOLD_STATUSES and PlayerData:
		PlayerData.gain_energy(1)


func _count_distinct_statuses(unit: Node) -> int:
	if not unit or not unit.get("active_statuses"):
		return 0
	return unit.active_statuses.size()
