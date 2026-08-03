extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	_relocate()

func _relocate() -> void:
	var cell := ArtifactManager.pick_random_player_half_cell()
	runtime["cell"] = cell
	runtime["charges"] = 3
	ArtifactManager.grid_zones["crown_of_dominion"] = {"cells": [cell], "charges": 3}
	notify_triggered("Crown cell %s" % str(cell))

func modify_card_cost(_card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	var u := player_unit()
	if u == null or not ("grid_position" in u):
		return cost
	if u.grid_position != runtime.get("cell", Vector2i(-99, -99)):
		return cost
	if int(runtime.get("charges", 0)) <= 0:
		return cost
	return maxi(0, cost - 1)

func on_card_played(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null or u.grid_position != runtime.get("cell", Vector2i(-99, -99)):
		return
	runtime["charges"] = int(runtime.get("charges", 0)) - 1
	if int(runtime["charges"]) <= 0:
		_relocate()
