extends ArtifactBehavior

const TURN_INTERVAL := 3


func on_turn_end(ctx: Dictionary = {}) -> void:
	var turn := _get_turn_number(ctx)
	if turn <= 0 or turn % TURN_INTERVAL != 0:
		return
	if int(runtime.get("extra_fired_on_turn", -1)) == turn:
		return
	runtime["extra_fired_on_turn"] = turn
	ctx["extra_turn"] = true
	var player := _get_player_unit()
	if player and player.has_method("show_status_text"):
		player.show_status_text("TIME CRYSTAL!", "heal")
	var am := _root_get_node_or_null("/root/ArtifactManager")
	if am:
		am.extra_turn_requested.emit()
