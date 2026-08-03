extends ArtifactBehavior

const MAX_HP_BONUS := 7


func on_acquired(ctx: Dictionary = {}) -> void:
	if PlayerData:
		PlayerData.change_max_hp(MAX_HP_BONUS)
