extends ArtifactBehavior

const THRONE_COUNT := 2
const ZONE_CHARGES := 3
const COST_REDUCTION := 1


func on_acquired(_ctx: Dictionary = {}) -> void:
	# Mid-combat console/reward acquire: spawn markers immediately.
	if _find_battle_grid() != null:
		_spawn_thrones()


func on_combat_start(_ctx: Dictionary = {}) -> void:
	_spawn_thrones()


func refresh_combat_visuals(_ctx: Dictionary = {}) -> void:
	if not (runtime.get("thrones", []) as Array).is_empty():
		_refresh_throne_visuals()


func on_combat_end(_ctx: Dictionary = {}) -> void:
	_clear_artifact_zones_of_kind("throne")
	super.on_combat_end(_ctx)


func on_card_played(_ctx: Dictionary = {}) -> void:
	_consume_throne_charge_if_standing()


func on_turn_end(_ctx: Dictionary = {}) -> void:
	var player: Node = _get_player_unit()
	if player == null:
		return
	if _is_on_throne(_unit_grid_pos(player)) and PlayerData:
		PlayerData.draw_cards(1)


func modify_card_cost(_ctx: Dictionary, cost: int) -> int:
	var player: Node = _get_player_unit()
	if player != null and _is_on_throne(_unit_grid_pos(player)):
		return maxi(0, cost - COST_REDUCTION)
	return cost


func _spawn_thrones() -> void:
	var grid: Node = _find_battle_grid()
	if grid == null:
		push_warning("Throne Fragment: BattleGrid not found — markers not spawned")
		return
	var cells: Array[Vector2i] = _player_half_cells(grid)
	if cells.is_empty():
		push_warning("Throne Fragment: no player-half cells — markers not spawned")
		return
	cells.shuffle()
	var thrones: Array = []
	for i in mini(THRONE_COUNT, cells.size()):
		thrones.append({"cell": cells[i], "charges": ZONE_CHARGES})
	runtime["thrones"] = thrones
	print("Throne Fragment: spawning %d thrones on %s" % [thrones.size(), str(thrones)])
	_refresh_throne_visuals()


func _refresh_throne_visuals() -> void:
	var zones: Array = []
	for entry_v in runtime.get("thrones", []):
		var entry: Dictionary = entry_v as Dictionary
		zones.append({
			"cell": entry.get("cell", Vector2i(-1, -1)),
			"kind": "throne",
			"charges": int(entry.get("charges", 0)),
			"max_charges": ZONE_CHARGES,
		})
	_sync_artifact_zones_to_grid(zones)


func _is_on_throne(cell: Vector2i) -> bool:
	for entry_v in runtime.get("thrones", []):
		var entry: Dictionary = entry_v as Dictionary
		if entry.get("cell") == cell:
			return true
	return false


func _consume_throne_charge_if_standing() -> void:
	var player: Node = _get_player_unit()
	if player == null:
		return
	var player_pos: Vector2i = _unit_grid_pos(player)
	var thrones: Array = runtime.get("thrones", []) as Array
	for i in thrones.size():
		var entry: Dictionary = thrones[i] as Dictionary
		if entry.get("cell") != player_pos:
			continue
		var charges: int = int(entry.get("charges", 0)) - 1
		entry["charges"] = charges
		thrones[i] = entry
		if charges <= 0:
			var grid: Node = _find_battle_grid()
			var new_cell: Vector2i = _random_player_half_cell(grid) if grid != null else Vector2i(-1, -1)
			entry["cell"] = new_cell
			entry["charges"] = ZONE_CHARGES
			thrones[i] = entry
		runtime["thrones"] = thrones
		_refresh_throne_visuals()
		break
