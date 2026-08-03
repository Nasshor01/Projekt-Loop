extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["used"] = false
	ArtifactManager.set_run_flag("all_seeing_eye_preview", true)

func on_combat_end(_ctx: Dictionary) -> void:
	ArtifactManager.set_run_flag("all_seeing_eye_preview", false)
