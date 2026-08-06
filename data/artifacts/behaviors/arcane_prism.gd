extends ArtifactBehavior

const STATUS_POOL: Array[String] = ["monk_blessing", "aura_devotion", "draw_plus_one"]
const ENERGY_THRESHOLD_STATUSES := 2


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var player: Node = _get_player_unit()
	if player == null:
		return
	var pick: String = STATUS_POOL[randi_range(0, STATUS_POOL.size() - 1)]
	match pick:
		"monk_blessing":
			_apply_status(player, "monk_blessing", 1, 1)
		"aura_devotion":
			_apply_status(player, "aura_devotion", 1, 1)
		"draw_plus_one":
			# Duration 2: EOT ticks to 1 so next turn's process_turn_start_statuses can consume it.
			# (Artifacts run after start-of-turn status processing, so duration 1 never draws.)
			_apply_status(player, "draw_plus_one", 1, 2)
	var distinct: int = _count_distinct_statuses(player)
	if distinct >= ENERGY_THRESHOLD_STATUSES and PlayerData:
		PlayerData.gain_energy(1)


func _count_distinct_statuses(unit: Node) -> int:
	if unit == null:
		return 0
	var statuses: Variant = unit.get("active_statuses")
	if statuses == null or not (statuses is Dictionary):
		return 0
	return (statuses as Dictionary).size()
