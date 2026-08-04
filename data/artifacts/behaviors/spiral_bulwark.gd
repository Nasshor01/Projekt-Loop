extends ArtifactBehavior

const START_THORNS := 2
const MAX_BLOCK_PER_TURN := 3


func on_combat_start(_ctx: Dictionary = {}) -> void:
	_add_combat_thorns(START_THORNS)
	runtime["block_this_turn"] = 0


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	runtime["block_this_turn"] = 0


func on_thorns_damage(_ctx: Dictionary = {}) -> void:
	if int(runtime.get("block_this_turn", 0)) >= MAX_BLOCK_PER_TURN:
		return
	var player := _get_player_unit()
	if player and player.has_method("add_block"):
		player.add_block(1)
		runtime["block_this_turn"] = int(runtime.get("block_this_turn", 0)) + 1
