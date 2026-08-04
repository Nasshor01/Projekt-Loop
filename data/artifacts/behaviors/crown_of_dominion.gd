extends ArtifactBehavior

const ZONE_CHARGES := 3
const COST_REDUCTION := 1


func on_acquired(_ctx: Dictionary = {}) -> void:
	if _find_battle_grid() != null:
		_relocate_zone()


func on_combat_start(_ctx: Dictionary = {}) -> void:
	_relocate_zone()


func refresh_combat_visuals(_ctx: Dictionary = {}) -> void:
	if runtime.has("zone_cell"):
		_refresh_zone_visuals()


func on_combat_end(_ctx: Dictionary = {}) -> void:
	_clear_artifact_zones_of_kind("crown")
	super.on_combat_end(_ctx)


func on_card_played(_ctx: Dictionary = {}) -> void:
	var player: Node = _get_player_unit()
	if player == null:
		return
	if _unit_grid_pos(player) != runtime.get("zone_cell", Vector2i(-1, -1)):
		return
	var charges: int = int(runtime.get("zone_charges", 0))
	if charges > 0:
		runtime["zone_charges"] = charges - 1
		if int(runtime.get("zone_charges", 0)) <= 0:
			_relocate_zone()
		else:
			_refresh_zone_visuals()


func modify_card_cost(_ctx: Dictionary, cost: int) -> int:
	var player: Node = _get_player_unit()
	if player != null and _unit_grid_pos(player) == runtime.get("zone_cell", Vector2i(-1, -1)):
		return maxi(0, cost - COST_REDUCTION)
	return cost


func _relocate_zone() -> void:
	var grid: Node = _find_battle_grid()
	if grid == null:
		push_warning("Crown of Dominion: BattleGrid not found — zone not spawned")
		return
	var cell: Vector2i = _random_player_half_cell(grid)
	if cell.x < 0:
		push_warning("Crown of Dominion: no player-half cell — zone not spawned")
		return
	runtime["zone_cell"] = cell
	runtime["zone_charges"] = ZONE_CHARGES
	print("Crown of Dominion: zone at %s charges=%d" % [str(cell), ZONE_CHARGES])
	_refresh_zone_visuals()


func _refresh_zone_visuals() -> void:
	_sync_artifact_zones_to_grid([{
		"cell": runtime.get("zone_cell", Vector2i(-1, -1)),
		"kind": "crown",
		"charges": int(runtime.get("zone_charges", 0)),
		"max_charges": ZONE_CHARGES,
	}])
