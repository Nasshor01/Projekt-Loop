extends ArtifactBehavior

const MAX_ROOTS := 3
const ROOT_TERRAIN := preload("res://data/terrain/living_grove_root.tres")


func setup(data: ArtifactsData) -> void:
	super.setup(data)
	runtime["roots"] = []


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	_spawn_root()


func on_turn_end(ctx: Dictionary = {}) -> void:
	var player := _get_player_unit()
	if not is_instance_valid(player):
		return
	var pos: Vector2i = player.grid_position
	var roots: Array = runtime.get("roots", [])
	var on_root := false
	for cell in roots:
		if cell == pos:
			on_root = true
			break
	if on_root:
		if PlayerData:
			PlayerData.draw_cards(1)
	else:
		_deal_unblockable_damage(1)


func on_combat_end(ctx: Dictionary = {}) -> void:
	_clear_roots()
	super.on_combat_end(ctx)


func _spawn_root() -> void:
	var grid := _find_battle_grid()
	if grid == null:
		return
	var cells := _player_half_cells(grid)
	if cells.is_empty():
		return
	cells.shuffle()
	var cell: Vector2i = cells[0]
	var roots: Array = runtime.get("roots", [])
	if roots.size() >= MAX_ROOTS:
		var oldest: Vector2i = roots[0]
		_remove_root_at(oldest)
		roots.remove_at(0)
	roots.append(cell)
	runtime["roots"] = roots
	if grid.has_method("place_terrain") and ROOT_TERRAIN:
		grid.place_terrain(cell, ROOT_TERRAIN.duplicate())


func _remove_root_at(cell: Vector2i) -> void:
	var grid := _find_battle_grid()
	if grid and grid.has_method("remove_terrain"):
		grid.remove_terrain(cell)


func _clear_roots() -> void:
	var roots: Array = runtime.get("roots", [])
	for cell in roots:
		_remove_root_at(cell)
	runtime["roots"] = []
