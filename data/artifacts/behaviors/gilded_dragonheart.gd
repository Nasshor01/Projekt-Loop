extends ArtifactBehavior

const COST_REDUCTION := 1
const ATTACKS_BEFORE_SHIFT := 3
const SHIFT_EVERY_TURNS := 3


func on_acquired(_ctx: Dictionary = {}) -> void:
	if _find_battle_grid() != null:
		_pick_line()


func on_combat_start(_ctx: Dictionary = {}) -> void:
	_pick_line()


func refresh_combat_visuals(_ctx: Dictionary = {}) -> void:
	if not String(runtime.get("line_mode", "")).is_empty():
		_refresh_line_visuals()


func on_combat_end(_ctx: Dictionary = {}) -> void:
	_sync_artifact_line_to_grid([])
	super.on_combat_end(_ctx)


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var turn: int = _get_turn_number(ctx)
	if turn > 0 and turn % SHIFT_EVERY_TURNS == 0:
		_pick_line()


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target) or not _is_on_active_line(_unit_grid_pos(target)):
		return
	_apply_status(target, "weakness", 1, 1)
	runtime["line_attacks"] = int(runtime.get("line_attacks", 0)) + 1
	if int(runtime.get("line_attacks", 0)) >= ATTACKS_BEFORE_SHIFT:
		_pick_line()
		runtime["line_attacks"] = 0


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var target: Node = ctx.get("target") as Node
	if target != null and _is_on_active_line(_unit_grid_pos(target)):
		return maxi(0, cost - COST_REDUCTION)
	return cost


func _pick_line() -> void:
	var grid: Node = _find_battle_grid()
	if grid == null:
		push_warning("Gilded Dragonheart: BattleGrid not found — line not spawned")
		return
	var rows: int = int(grid.get("grid_rows"))
	var columns: int = int(grid.get("grid_columns"))
	if randf() < 0.5:
		runtime["line_mode"] = "row"
		runtime["line_index"] = randi_range(0, maxi(0, rows - 1))
	else:
		runtime["line_mode"] = "column"
		runtime["line_index"] = randi_range(0, maxi(0, columns - 1))
	print("Gilded Dragonheart: line mode=%s index=%d" % [
		String(runtime.get("line_mode", "")), int(runtime.get("line_index", -1))
	])
	_refresh_line_visuals()


func _refresh_line_visuals() -> void:
	var grid: Node = _find_battle_grid()
	if grid == null:
		return
	var cells: Array[Vector2i] = []
	var mode: String = String(runtime.get("line_mode", ""))
	var index: int = int(runtime.get("line_index", -1))
	var rows: int = int(grid.get("grid_rows"))
	var columns: int = int(grid.get("grid_columns"))
	if mode == "row":
		for x in range(columns):
			var cell := Vector2i(x, index)
			if grid.has_method("is_cell_active") and bool(grid.is_cell_active(cell)):
				cells.append(cell)
	elif mode == "column":
		for y in range(rows):
			var cell := Vector2i(index, y)
			if grid.has_method("is_cell_active") and bool(grid.is_cell_active(cell)):
				cells.append(cell)
	_sync_artifact_line_to_grid(cells)


func _is_on_active_line(cell: Vector2i) -> bool:
	var mode: String = String(runtime.get("line_mode", ""))
	if mode == "row":
		return cell.y == int(runtime.get("line_index", -1))
	if mode == "column":
		return cell.x == int(runtime.get("line_index", -1))
	return false
