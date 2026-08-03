extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	runtime["draw_next"] = false
	_place()

func _place() -> void:
	var a := ArtifactManager.pick_random_player_half_cell()
	var b := ArtifactManager.pick_random_player_half_cell([a])
	runtime["cells"] = [a, b]
	runtime["charges"] = {str(a): 3, str(b): 3}
	ArtifactManager.grid_zones["throne_fragment"] = {"cells": [a, b]}

func modify_card_cost(_card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	var u := player_unit()
	if u == null:
		return cost
	var cells: Array = runtime.get("cells", [])
	if cells.has(u.grid_position):
		return maxi(0, cost - 1)
	return cost

func on_card_played(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u == null:
		return
	var key := str(u.grid_position)
	var charges: Dictionary = runtime.get("charges", {})
	if not charges.has(key):
		return
	charges[key] = int(charges[key]) - 1
	if int(charges[key]) <= 0:
		_place()

func on_turn_end(_ctx: Dictionary) -> void:
	var u := player_unit()
	if u and runtime.get("cells", []).has(u.grid_position):
		runtime["draw_next"] = true

func on_turn_start(_ctx: Dictionary) -> void:
	if runtime.get("draw_next", false):
		runtime["draw_next"] = false
		PlayerData.draw_cards(1)
