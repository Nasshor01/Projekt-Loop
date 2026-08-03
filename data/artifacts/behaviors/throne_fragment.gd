extends ArtifactBehavior

const THRONE_COUNT := 2
const ZONE_CHARGES := 3
const COST_REDUCTION := 1


func on_combat_start(ctx: Dictionary = {}) -> void:
	_spawn_thrones()


func on_card_played(ctx: Dictionary = {}) -> void:
	_consume_throne_charge_if_standing()


func on_turn_end(ctx: Dictionary = {}) -> void:
	var player := _get_player_unit()
	if not player:
		return
	if _is_on_throne(player.grid_position) and PlayerData:
		PlayerData.draw_cards(1)


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var player := _get_player_unit()
	if player and _is_on_throne(player.grid_position):
		return maxi(0, cost - COST_REDUCTION)
	return cost


func _spawn_thrones() -> void:
	var grid := _find_battle_grid()
	if grid == null:
		return
	var cells := _player_half_cells(grid)
	cells.shuffle()
	var thrones: Array = []
	for i in mini(THRONE_COUNT, cells.size()):
		thrones.append({"cell": cells[i], "charges": ZONE_CHARGES})
	runtime["thrones"] = thrones


func _is_on_throne(cell: Vector2i) -> bool:
	for entry in runtime.get("thrones", []):
		if entry.get("cell") == cell:
			return true
	return false


func _consume_throne_charge_if_standing() -> void:
	var player := _get_player_unit()
	if not player:
		return
	var thrones: Array = runtime.get("thrones", [])
	for i in thrones.size():
		var entry: Dictionary = thrones[i]
		if entry.get("cell") != player.grid_position:
			continue
		var charges := int(entry.get("charges", 0)) - 1
		entry["charges"] = charges
		thrones[i] = entry
		if charges <= 0:
			var grid := _find_battle_grid()
			var new_cell := _random_player_half_cell(grid) if grid else Vector2i(-1, -1)
			entry["cell"] = new_cell
			entry["charges"] = ZONE_CHARGES
			thrones[i] = entry
		runtime["thrones"] = thrones
		break
