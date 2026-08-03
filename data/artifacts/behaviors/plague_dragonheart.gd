extends ArtifactBehavior

const POISON_DOUBLE_THRESHOLD := 8
const DOUBLE_USES_PER_COMBAT := 1


func on_status_applied(ctx: Dictionary = {}) -> void:
	var status_id: String = String(ctx.get("status_id", ""))
	if status_id != "poison":
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return
	var statuses: Variant = target.get("active_statuses")
	if statuses == null or not (statuses is Dictionary) or not (statuses as Dictionary).has("poison"):
		return
	var amount: int = int(ctx.get("value", 1))
	_spread_poison_row(target, amount)


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if int(runtime.get("double_uses", 0)) >= DOUBLE_USES_PER_COMBAT:
		return
	for unit_v in _all_units_on_grid():
		var unit: Node = unit_v as Node
		if not is_instance_valid(unit):
			continue
		var statuses: Variant = unit.get("active_statuses")
		if statuses == null or not (statuses is Dictionary) or not (statuses as Dictionary).has("poison"):
			continue
		var poison_data: Dictionary = (statuses as Dictionary)["poison"]
		var val: int = int(poison_data.get("value", 0))
		if val >= POISON_DOUBLE_THRESHOLD:
			_double_all_poison()
			runtime["double_uses"] = int(runtime.get("double_uses", 0)) + 1
			break


func _spread_poison_row(source: Node, amount: int) -> void:
	var grid: Node = _find_battle_grid()
	if grid == null:
		return
	var source_pos: Vector2i = source.get("grid_position") as Vector2i
	var row_y: int = source_pos.y
	for unit_v in _all_units_on_grid():
		var unit: Node = unit_v as Node
		if not is_instance_valid(unit) or unit == source:
			continue
		var pos: Vector2i = unit.get("grid_position") as Vector2i
		if pos.y == row_y:
			_apply_status(unit, "poison", amount, 99)


func _double_all_poison() -> void:
	for unit_v in _all_units_on_grid():
		var unit: Node = unit_v as Node
		if not is_instance_valid(unit):
			continue
		var statuses: Variant = unit.get("active_statuses")
		if statuses == null or not (statuses is Dictionary):
			continue
		var status_dict: Dictionary = statuses as Dictionary
		if status_dict.has("poison"):
			var data: Dictionary = status_dict["poison"]
			data["value"] = int(data.get("value", 0)) * 2


func _all_units_on_grid() -> Array:
	var grid: Node = _find_battle_grid()
	if grid != null and grid.has_method("get_all_objects_on_grid"):
		return grid.call("get_all_objects_on_grid") as Array
	return []
