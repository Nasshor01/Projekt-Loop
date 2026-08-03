extends ArtifactBehavior

func on_combat_start(_ctx: Dictionary) -> void:
	_reroll()
	runtime["hits"] = 0

func _reroll() -> void:
	if randf() < 0.5:
		runtime["axis"] = "row"
		runtime["index"] = randi() % 5
	else:
		runtime["axis"] = "col"
		runtime["index"] = randi() % 8
	notify_triggered("Gilded line %s %d" % [runtime["axis"], runtime["index"]])

func _on_line(cell: Vector2i) -> bool:
	if runtime.get("axis") == "row":
		return cell.y == int(runtime.get("index", -1))
	return cell.x == int(runtime.get("index", -1))

func modify_card_cost(card: CardData, cost: int, ctx: Dictionary = {}) -> int:
	# Cost reduction applied when targeting — approximate: if any enemy on line
	for e in ArtifactManager.get_enemies():
		if "grid_position" in e and _on_line(e.grid_position) and ArtifactManager._card_is_attack(card):
			return maxi(0, cost - 1)
	return cost

func on_damage_dealt(ctx: Dictionary) -> void:
	var target = ctx.get("target")
	if target == null or not ("grid_position" in target):
		return
	if not _on_line(target.grid_position):
		return
	ArtifactManager.apply_status_to_unit(target, "weakness", 1, 2)
	runtime["hits"] = int(runtime.get("hits", 0)) + 1
	if int(runtime["hits"]) >= 3:
		runtime["hits"] = 0
		_reroll()

func on_turn_start(ctx: Dictionary) -> void:
	var turn := int(ctx.get("combat_turn", 0))
	if turn > 0 and turn % 3 == 0:
		_reroll()
