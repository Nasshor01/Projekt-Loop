extends ArtifactBehavior

const ZONE_CHARGES := 3
const COST_REDUCTION := 1


func on_combat_start(ctx: Dictionary = {}) -> void:
	_relocate_zone()


func on_card_played(ctx: Dictionary = {}) -> void:
	var player := _get_player_unit()
	if not player:
		return
	if player.grid_position != runtime.get("zone_cell", Vector2i(-1, -1)):
		return
	var charges := int(runtime.get("zone_charges", 0))
	if charges > 0:
		runtime["zone_charges"] = charges - 1
		if int(runtime.get("zone_charges", 0)) <= 0:
			_relocate_zone()


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	var player := _get_player_unit()
	if player and player.grid_position == runtime.get("zone_cell", Vector2i(-1, -1)):
		return maxi(0, cost - COST_REDUCTION)
	return cost


func _relocate_zone() -> void:
	var grid := _find_battle_grid()
	if grid == null:
		return
	var cell := _random_player_half_cell(grid)
	if cell.x < 0:
		return
	runtime["zone_cell"] = cell
	runtime["zone_charges"] = ZONE_CHARGES
