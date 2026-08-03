extends ArtifactBehavior

const BURN_VALUE := 1
const BURN_DURATION := 3
const DEATH_BURST_DAMAGE := 4


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	var card: CardData = ctx.get("card") as CardData
	if card and not _card_is_attack(card):
		return
	var target: Node = ctx.get("target")
	if is_instance_valid(target):
		_apply_status(target, "burning", BURN_VALUE, BURN_DURATION)


func on_enemy_death(ctx: Dictionary = {}) -> void:
	var dead: Node = ctx.get("dead_enemy")
	if not is_instance_valid(dead):
		return
	if not dead.active_statuses.has("burning"):
		return
	var grid := _find_battle_grid()
	if grid == null:
		return
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = dead.grid_position + offset
		var unit := grid.get_object_on_cell(cell) if grid.has_method("get_object_on_cell") else null
		if unit and unit != dead and unit.get("unit_data"):
			var faction = unit.unit_data.faction
			if faction == UnitData.Faction.ENEMY and unit.has_method("take_damage"):
				unit.take_damage(DEATH_BURST_DAMAGE, true, false, false)
