extends ArtifactBehavior

const FAR_DISTANCE := 3
const NEAR_DISTANCE := 1


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var player := _get_player_unit()
	var grid := _find_battle_grid()
	if not player or not grid:
		return
	var far_count := 0
	for enemy in _get_enemies():
		if not is_instance_valid(enemy):
			continue
		var dist := grid.get_distance(player.grid_position, enemy.grid_position)
		if dist >= FAR_DISTANCE:
			far_count += 1
			_apply_status(player, "monk_blessing", 1, 1)
		if dist <= NEAR_DISTANCE and player.has_method("take_damage"):
			player.take_damage(1, false, false, true)
