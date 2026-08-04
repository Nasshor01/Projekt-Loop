extends ArtifactBehavior

const START_STRENGTH := 3
const START_DEX := 3
const MAX_HP_LOSS_PER_TURN := 1


func on_combat_start(_ctx: Dictionary = {}) -> void:
	var player: Node = _get_player_unit()
	if player != null:
		_apply_status(player, "monk_blessing", START_STRENGTH, 99)
		_apply_status(player, "aura_devotion", START_DEX, 99)
	runtime["max_hp_lost"] = 0


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	if not PlayerData:
		return
	PlayerData.change_max_hp(-MAX_HP_LOSS_PER_TURN)
	runtime["max_hp_lost"] = int(runtime.get("max_hp_lost", 0)) + MAX_HP_LOSS_PER_TURN
	var player: Node = _get_player_unit()
	if player != null:
		var hp_v: Variant = player.get("current_health")
		if hp_v != null:
			player.set("current_health", mini(int(hp_v), PlayerData.current_hp))


func on_combat_end(ctx: Dictionary = {}) -> void:
	var lost: int = int(runtime.get("max_hp_lost", 0))
	if lost > 0 and PlayerData:
		PlayerData.change_max_hp(lost)
	super.on_combat_end(ctx)
