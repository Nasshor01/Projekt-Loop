extends ArtifactBehavior

const MAX_STORED_ENERGY := 2


func on_turn_end(_ctx: Dictionary = {}) -> void:
	if not PlayerData:
		return
	var leftover := PlayerData.current_energy
	if leftover > 0:
		var stored := mini(leftover, MAX_STORED_ENERGY)
		runtime["stored_energy"] = int(runtime.get("stored_energy", 0)) + stored
		runtime["stored_energy"] = mini(runtime["stored_energy"], MAX_STORED_ENERGY)
	if leftover == 0 and PlayerData.max_energy > 0:
		PlayerData.draw_cards(1)


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if not PlayerData:
		return
	var stored := int(runtime.get("stored_energy", 0))
	if stored > 0:
		PlayerData.gain_energy(stored)
		runtime["stored_energy"] = 0
