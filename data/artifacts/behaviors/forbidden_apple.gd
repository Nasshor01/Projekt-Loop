extends ArtifactBehavior

const MAX_HP_BONUS := 7


func get_passive_max_hp_bonus() -> int:
	var stacks: int = 1
	if artifact != null:
		stacks = maxi(1, artifact.current_stacks)
	return MAX_HP_BONUS * stacks
