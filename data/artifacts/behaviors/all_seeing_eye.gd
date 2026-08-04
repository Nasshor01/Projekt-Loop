extends ArtifactBehavior

const PREVIEW_USES_PER_COMBAT := 1
const PROMPT_ID := "all_seeing_deny"


func on_combat_start(_ctx: Dictionary = {}) -> void:
	runtime["preview_enabled"] = true
	runtime["deny_move_uses"] = 0
	runtime["deny_pending"] = true


func on_turn_start(ctx: Dictionary = {}) -> void:
	super.on_turn_start(ctx)
	ctx["show_enemy_move_preview"] = runtime.get("preview_enabled", true)
	if _root_has_node("/root/ArtifactManager"):
		ArtifactManager.set_run_flag("show_enemy_move_preview", true)


func on_hand_ready(_ctx: Dictionary = {}) -> void:
	if not runtime.get("deny_pending", false):
		return
	if int(runtime.get("deny_move_uses", 0)) >= PREVIEW_USES_PER_COMBAT:
		return
	runtime["deny_pending"] = false
	if not _root_has_node("/root/ArtifactManager"):
		return
	ArtifactManager.set_run_flag("pending_eye_deny", true)
	ArtifactManager.set_run_flag("artifact_pick_enemy_deny", true)


func on_prompt_result(prompt_id: String, result: Dictionary) -> void:
	if prompt_id != PROMPT_ID:
		return
	if _root_has_node("/root/ArtifactManager"):
		ArtifactManager.set_run_flag("artifact_pick_enemy_deny", false)
	if not bool(result.get("accepted", false)):
		return
	var enemy: Node = result.get("enemy") as Node
	if not is_instance_valid(enemy):
		return
	enemy.set_meta("artifact_deny_move_next_turn", true)
	runtime["deny_move_uses"] = int(runtime.get("deny_move_uses", 0)) + 1
	if enemy.has_method("show_status_text"):
		enemy.show_status_text("LOCKED!", "critical")
