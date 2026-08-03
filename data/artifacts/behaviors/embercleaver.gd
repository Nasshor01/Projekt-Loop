extends ArtifactBehavior

const BURN_VALUE := 1
const BURN_DURATION := 3
const DEATH_BURST_DAMAGE := 4


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card != null and not _card_is_attack(card):
		return
	var target: Node = ctx.get("target") as Node
	if is_instance_valid(target):
		_apply_status(target, "burning", BURN_VALUE, BURN_DURATION)


func on_enemy_death(ctx: Dictionary = {}) -> void:
	var dead: Node = ctx.get("dead_enemy") as Node
	if not is_instance_valid(dead):
		return
	var statuses: Variant = dead.get("active_statuses")
	if statuses == null or not (statuses is Dictionary) or not (statuses as Dictionary).has("burning"):
		return
	var grid: Node = _find_battle_grid()
	if grid == null:
		return
	var dead_pos: Vector2i = dead.get("grid_position") as Vector2i
	var offsets: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for offset in offsets:
		var cell: Vector2i = dead_pos + offset
		var unit: Node = _grid_object_on_cell(grid, cell)
		if unit != null and unit != dead:
			var ud: Variant = unit.get("unit_data")
			if ud != null and ud.faction == UnitData.Faction.ENEMY and unit.has_method("take_damage"):
				unit.call("take_damage", DEATH_BURST_DAMAGE, true, false, false)
