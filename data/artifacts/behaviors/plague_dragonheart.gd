extends ArtifactBehavior

const POISON_DOUBLE_THRESHOLD := 8
const DOUBLE_USES_PER_COMBAT := 1


func on_status_applied(ctx: Dictionary = {}) -> void:
	var status_id := String(ctx.get("status_id", ""))
	if status_id != "poison":
		return
	var target: Node = ctx.get("target")
	if not is_instance_valid(target):
		return
	if not target.active_statuses.has("poison"):
		return
	var amount := int(ctx.get("value", 1))
	_spread_poison_row(target, amount)


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if int(runtime.get("double_uses", 0)) >= DOUBLE_USES_PER_COMBAT:
		return
	for unit in _all_units_on_grid():
		if not is_instance_valid(unit) or not unit.active_statuses.has("poison"):
			continue
		var val := int(unit.active_statuses["poison"].get("value", 0))
		if val >= POISON_DOUBLE_THRESHOLD:
			_double_all_poison()
			runtime["double_uses"] = int(runtime.get("double_uses", 0)) + 1
			break


func _spread_poison_row(source: Node, amount: int) -> void:
	var grid := _find_battle_grid()
	if grid == null:
		return
	var row_y := source.grid_position.y
	for unit in _all_units_on_grid():
		if unit.grid_position.y == row_y and unit != source:
			_apply_status(unit, "poison", amount, 99)


func _double_all_poison() -> void:
	for unit in _all_units_on_grid():
		if unit.active_statuses.has("poison"):
			var data: Dictionary = unit.active_statuses["poison"]
			data["value"] = int(data.get("value", 0)) * 2


func _all_units_on_grid() -> Array:
	var grid := _find_battle_grid()
	if grid and grid.has_method("get_all_objects_on_grid"):
		return grid.get_all_objects_on_grid()
	return []
