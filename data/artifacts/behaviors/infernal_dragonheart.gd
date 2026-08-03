extends ArtifactBehavior

const BURN_VALUE := 1
const BURN_DURATION := 3


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return
	_apply_status(target, "burning", BURN_VALUE, BURN_DURATION)
	_try_step_toward(target)


func _try_step_toward(target: Node) -> void:
	var player: Node = _get_player_unit()
	var grid: Node = _find_battle_grid()
	if player == null or grid == null:
		return
	var from: Vector2i = player.get("grid_position") as Vector2i
	var to: Vector2i = target.get("grid_position") as Vector2i
	var best_cell: Vector2i = from
	var best_dist: int = _grid_distance(grid, from, to)
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in offsets:
		var cell: Vector2i = from + offset
		if grid.has_method("is_cell_active") and not bool(grid.is_cell_active(cell)):
			continue
		if _grid_object_on_cell(grid, cell) != null:
			continue
		var dist: int = _grid_distance(grid, cell, to)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	if best_cell != from and grid.has_method("place_object_on_cell"):
		if grid.has_method("remove_object_by_instance"):
			grid.call("remove_object_by_instance", player)
		grid.call("place_object_on_cell", player, best_cell, true, 0.15)
		if best_dist <= 1:
			_apply_status(target, "burning", BURN_VALUE, BURN_DURATION)
