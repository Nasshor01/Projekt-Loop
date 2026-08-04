extends ArtifactBehavior

const MAX_ROOTS := 3
const ROOT_TERRAIN := preload("res://data/terrain/living_grove_root.tres")


func setup(data: ArtifactsData) -> void:
	super.setup(data)
	runtime["roots"] = []


func on_acquired(_ctx: Dictionary = {}) -> void:
	# Mid-combat acquire: place first root immediately.
	if _find_battle_grid() != null and (runtime.get("roots", []) as Array).is_empty():
		_spawn_root()


func on_combat_start(_ctx: Dictionary = {}) -> void:
	# First root visible as soon as combat begins (not only after first turn_start).
	if (runtime.get("roots", []) as Array).is_empty():
		_spawn_root()


func refresh_combat_visuals(_ctx: Dictionary = {}) -> void:
	# Roots are terrain sprites; re-place if grid lost them somehow.
	var grid: Node = _find_battle_grid()
	if grid == null or ROOT_TERRAIN == null:
		return
	for cell_v in runtime.get("roots", []):
		var cell: Vector2i = cell_v as Vector2i
		if grid.has_method("get_terrain_on_cell"):
			var existing = grid.call("get_terrain_on_cell", cell)
			if existing != null:
				continue
		if grid.has_method("place_terrain"):
			grid.call("place_terrain", cell, ROOT_TERRAIN.duplicate())


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	# Turn 1 already has a root from combat_start; spawn additional roots on later turns.
	if int(runtime.get("turn_counter", 0)) > 1:
		_spawn_root()
	elif (runtime.get("roots", []) as Array).is_empty():
		_spawn_root()


func on_turn_end(_ctx: Dictionary = {}) -> void:
	var player: Node = _get_player_unit()
	if not is_instance_valid(player):
		return
	var pos: Vector2i = player.get("grid_position") as Vector2i
	var roots: Array = runtime.get("roots", []) as Array
	var on_root: bool = false
	for cell_v in roots:
		var cell: Vector2i = cell_v as Vector2i
		if cell == pos:
			on_root = true
			break
	if on_root:
		if PlayerData:
			PlayerData.draw_cards(1)
	else:
		_deal_unblockable_damage(1)


func on_combat_end(_ctx: Dictionary = {}) -> void:
	_clear_roots()
	super.on_combat_end(_ctx)


func _spawn_root() -> void:
	var grid: Node = _find_battle_grid()
	if grid == null:
		push_warning("Living Grove: BattleGrid not found — root not spawned")
		return
	var cells: Array[Vector2i] = _player_half_cells(grid)
	if cells.is_empty():
		push_warning("Living Grove: no player-half cells — root not spawned")
		return
	cells.shuffle()
	var cell: Vector2i = cells[0]
	var roots: Array = runtime.get("roots", []) as Array
	if roots.size() >= MAX_ROOTS:
		var oldest: Vector2i = roots[0] as Vector2i
		_remove_root_at(oldest)
		roots.remove_at(0)
	roots.append(cell)
	runtime["roots"] = roots
	print("Living Grove: root at %s (total %d)" % [str(cell), roots.size()])
	if grid.has_method("place_terrain") and ROOT_TERRAIN != null:
		grid.call("place_terrain", cell, ROOT_TERRAIN.duplicate())


func _remove_root_at(cell: Vector2i) -> void:
	var grid: Node = _find_battle_grid()
	if grid != null and grid.has_method("remove_terrain"):
		grid.call("remove_terrain", cell)


func _clear_roots() -> void:
	var roots: Array = runtime.get("roots", []) as Array
	for cell_v in roots:
		_remove_root_at(cell_v as Vector2i)
	runtime["roots"] = []
