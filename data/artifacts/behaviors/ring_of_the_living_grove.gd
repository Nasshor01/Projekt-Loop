extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["roots"] = []
	runtime["draw_next"] = false

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("draw_next", false):
		runtime["draw_next"] = false
		PlayerData.draw_cards(1)
	var roots: Array = runtime.get("roots", [])
	var cell := ArtifactManager.pick_random_player_half_cell(roots)
	roots.append(cell)
	if roots.size() > 3:
		roots.pop_front()
	runtime["roots"] = roots
	ArtifactManager.grid_zones["ring_of_the_living_grove"] = {"cells": roots.duplicate()}

func on_turn_end(ctx: Dictionary) -> void:
	var cell: Vector2i = ctx.get("player_cell", Vector2i(-1, -1))
	var roots: Array = runtime.get("roots", [])
	if roots.has(cell):
		runtime["draw_next"] = true
	else:
		var u := player_unit()
		if u:
			u.current_health = maxi(0, int(u.current_health) - 1)
			PlayerData.current_hp = u.current_health
			if u.has_method("_update_stats_and_emit_signal"):
				u._update_stats_and_emit_signal()
			if u.current_health <= 0 and has_node("/root/ArtifactManager"):
				if not ArtifactManager.before_death(u):
					if u.has_method("_die"):
						u._die()
