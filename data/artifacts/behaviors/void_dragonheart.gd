extends ArtifactBehavior

const FAR_DISTANCE := 3
const NEAR_DISTANCE := 1


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var player: Node = _get_player_unit()
	var grid: Node = _find_battle_grid()
	if player == null or grid == null:
		return
	var player_pos: Vector2i = player.get("grid_position") as Vector2i
	for enemy_v in _get_enemies():
		var enemy: Node = enemy_v as Node
		if not is_instance_valid(enemy):
			continue
		var enemy_pos: Vector2i = enemy.get("grid_position") as Vector2i
		var dist: int = _grid_distance(grid, player_pos, enemy_pos)
		if dist >= FAR_DISTANCE:
			_apply_status(player, "monk_blessing", 1, 1)
		if dist <= NEAR_DISTANCE and player.has_method("take_damage"):
			player.call("take_damage", 1, false, false, true)
