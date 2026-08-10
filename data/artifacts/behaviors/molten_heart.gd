extends ArtifactBehavior

const STRENGTH_VALUE := 1


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var player := _get_player_unit()
	if player:
		_apply_status(player, "monk_blessing", STRENGTH_VALUE, 1)


func on_status_applied(ctx: Dictionary = {}) -> void:
	if String(ctx.get("status_id", "")) != "burning":
		return
	var target: Node = ctx.get("target") as Node
	if not is_instance_valid(target):
		return
	var ud: Variant = target.get("unit_data")
	if ud == null or ud.faction != UnitData.Faction.ENEMY:
		return
	var player := _get_player_unit()
	if player and player.has_method("heal"):
		player.heal(1)
