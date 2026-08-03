extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["pending_draw"] = false
	if PlayerData.has_meta("aether_retained_energy"):
		PlayerData.remove_meta("aether_retained_energy")

func on_turn_end(_ctx: Dictionary) -> void:
	var energy := int(PlayerData.current_energy)
	var retain := mini(2, energy)
	if retain > 0:
		PlayerData.set_meta("aether_retained_energy", retain)
		PlayerData.current_energy = 0
		PlayerData.emit_signal("energy_changed", PlayerData.current_energy)
	# Spent all energy this turn → +1 card next turn (after discard)
	if energy == 0:
		runtime["pending_draw"] = true

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("pending_draw", false):
		runtime["pending_draw"] = false
		PlayerData.draw_cards(1)
		notify_triggered("Aether Crystal: +1 card")
	if PlayerData.has_meta("aether_retained_energy"):
		var r := int(PlayerData.get_meta("aether_retained_energy"))
		PlayerData.remove_meta("aether_retained_energy")
		if r > 0:
			PlayerData.gain_energy(r)
