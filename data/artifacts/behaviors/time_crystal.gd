extends ArtifactBehavior

const TURN_INTERVAL := 3


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	var turn := _get_turn_number(ctx)
	if turn > 0 and turn % TURN_INTERVAL == 0:
		ctx["extra_turn"] = true
		var am := _root_get_node_or_null("/root/ArtifactManager")
		if am:
			am.extra_turn_requested.emit()
