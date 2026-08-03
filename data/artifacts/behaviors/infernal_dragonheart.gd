extends ArtifactBehavior

const BURN_VALUE := 1
const BURN_DURATION := 3


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target")
	if not is_instance_valid(target):
		return
	_apply_status(target, "burning", BURN_VALUE, BURN_DURATION)
	_try_step_toward(target)


func _try_step_toward(target: Node) -> void:
	var player := _get_player_unit()
	var grid := _find_battle_grid()
	if not player or not grid:
		return
	var from: Vector2i = player.grid_position
	var to: Vector2i = target.grid_position
	var best_cell := from
	var best_dist := grid.get_distance(from, to)
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = from + offset
		if not grid.is_cell_active(cell):
			continue
		if grid.get_object_on_cell(cell):
			continue
		var dist := grid.get_distance(cell, to)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	if best_cell != from and grid.has_method("place_object_on_cell"):
		grid.remove_object_by_instance(player)
		grid.place_object_on_cell(player, best_cell, true, 0.15)
		if best_dist <= 1:
			_apply_status(target, "burning", BURN_VALUE, BURN_DURATION)
