class_name ArtifactBehavior
extends RefCounted

const PLAYER_HALF_COLUMNS := 3

var artifact: ArtifactsData
var runtime: Dictionary = {}


func setup(data: ArtifactsData) -> void:
	artifact = data
	runtime.clear()


func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	return loop as SceneTree


func _root_has_node(path: NodePath) -> bool:
	var tree := _scene_tree()
	if tree == null:
		return false
	return tree.root.has_node(path)


func _root_get_node_or_null(path: NodePath) -> Node:
	var tree := _scene_tree()
	if tree == null or not tree.root.has_node(path):
		return null
	return tree.root.get_node(path)


func _find_battle_scene() -> Node:
	var tree := _scene_tree()
	if tree == null:
		return null
	var current := tree.current_scene
	if _is_battle_scene(current):
		return current
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if _is_battle_scene(node):
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func _is_battle_scene(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node.name == "BattleScene":
		return true
	var script := node.get_script()
	if script and String(script.resource_path).ends_with("BattleScene.gd"):
		return true
	if node.has_method("get_player_unit") and node.has_method("get_enemy_count"):
		return true
	return false


func _find_battle_grid() -> Node:
	var battle := _find_battle_scene()
	if battle == null:
		return null
	if battle.get("battle_grid_instance"):
		return battle.battle_grid_instance as Node
	for child in battle.get_children():
		if child is BattleGrid:
			return child
	return battle.find_child("BattleGrid", true, false)


func _get_player_unit() -> Node:
	var battle := _find_battle_scene()
	if battle and battle.has_method("get_player_unit"):
		return battle.get_player_unit()
	var tree := _scene_tree()
	if tree == null:
		return null
	var players := tree.get_nodes_in_group("player")
	if not players.is_empty():
		return players[0]
	return null


func _get_enemies() -> Array:
	var battle := _find_battle_scene()
	if battle and battle.has_method("get_all_enemies"):
		return battle.get_all_enemies()
	return []


func _player_half_cells(grid: Node) -> Array[Vector2i]:
	"""Player half = left half of grid (x < columns/2), matching BattleScene enemy-half split."""
	var cells: Array[Vector2i] = []
	if grid == null:
		return cells
	var columns := int(grid.get("grid_columns")) if grid.get("grid_columns") != null else 0
	var rows := int(grid.get("grid_rows")) if grid.get("grid_rows") != null else 0
	if columns <= 0 or rows <= 0:
		if grid.has_method("get_player_spawn_points"):
			return grid.get_player_spawn_points(PLAYER_HALF_COLUMNS)
		return cells
	var half_x := columns / 2.0
	for y in range(rows):
		for x in range(columns):
			if float(x) >= half_x:
				continue
			var cell := Vector2i(x, y)
			if grid.has_method("is_cell_active") and not grid.is_cell_active(cell):
				continue
			cells.append(cell)
	return cells


func _random_player_half_cell(grid: Node) -> Vector2i:
	var cells := _player_half_cells(grid)
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[randi_range(0, cells.size() - 1)]


func _is_grid_edge(grid: Node, cell: Vector2i) -> bool:
	if grid == null or not grid.has_method("is_cell_active"):
		return false
	for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := cell + offset
		if not grid.is_cell_active(neighbor):
			return true
	return false


func _deal_unblockable_damage(amount: int) -> void:
	if amount <= 0:
		return
	var player := _get_player_unit()
	if player and "current_health" in player:
		player.current_health = maxi(0, player.current_health - amount)
		if player.has_method("_update_stats_and_emit_signal"):
			player._update_stats_and_emit_signal()
	if PlayerData:
		PlayerData.take_damage(amount)


func _apply_status(unit: Node, status_id: String, value: int, duration: int = 1) -> void:
	if unit and unit.has_method("apply_status"):
		unit.apply_status(status_id, value, duration)


func _random_living_enemy() -> Node:
	var enemies := _get_enemies()
	var living: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.get("current_health") > 0:
			living.append(e)
	if living.is_empty():
		return null
	return living[randi_range(0, living.size() - 1)]


func _card_moves_unit(card: CardData) -> bool:
	if card == null:
		return false
	if card.tags.has(CardData.CardTag.MOVE):
		return true
	for effect in card.effects:
		if effect.effect_type == CardEffectData.EffectType.GAIN_EXTRA_MOVE:
			return true
	return false


func _card_is_melee_attack(card: CardData) -> bool:
	if card == null:
		return false
	if not card.tags.has(CardData.CardTag.ATTACK):
		return false
	return card.range_type == CardData.EffectRangeType.MELEE or card.range_type == CardData.EffectRangeType.SELF


func _card_is_attack(card: CardData) -> bool:
	return card != null and card.tags.has(CardData.CardTag.ATTACK)


func _get_turn_number(ctx: Dictionary) -> int:
	if ctx.has("current_turn"):
		return int(ctx["current_turn"])
	if ctx.has("turn_number"):
		return int(ctx["turn_number"])
	var battle := _find_battle_scene()
	if battle and battle.get("_current_turn_number"):
		return int(battle._current_turn_number)
	return int(runtime.get("turn_counter", 0))


func _track_combat_hp_lost(amount: int) -> void:
	runtime["hp_lost_this_combat"] = int(runtime.get("hp_lost_this_combat", 0)) + amount


func _add_combat_thorns(amount: int) -> void:
	if amount <= 0:
		return
	runtime["thorns_added"] = int(runtime.get("thorns_added", 0)) + amount
	if PlayerData:
		PlayerData.thorns_damage += amount


func _add_combat_damage_bonus(amount: int) -> void:
	if amount <= 0:
		return
	runtime["damage_bonus_added"] = int(runtime.get("damage_bonus_added", 0)) + amount
	if PlayerData:
		PlayerData.global_card_damage_bonus += amount


func _cleanup_combat_stat_bonuses() -> void:
	if not PlayerData:
		return
	var thorns := int(runtime.get("thorns_added", 0))
	if thorns > 0:
		PlayerData.thorns_damage = maxi(0, PlayerData.thorns_damage - thorns)
	var dmg := int(runtime.get("damage_bonus_added", 0))
	if dmg > 0:
		PlayerData.global_card_damage_bonus = maxi(0, PlayerData.global_card_damage_bonus - dmg)
	runtime.erase("thorns_added")
	runtime.erase("damage_bonus_added")


func on_acquired(ctx: Dictionary = {}) -> void:
	pass


func on_removed(ctx: Dictionary = {}) -> void:
	pass


func on_combat_start(ctx: Dictionary = {}) -> void:
	pass


func on_combat_end(ctx: Dictionary = {}) -> void:
	_cleanup_combat_stat_bonuses()


func on_turn_start(ctx: Dictionary = {}) -> void:
	runtime["turn_counter"] = int(runtime.get("turn_counter", 0)) + 1


func on_turn_end(ctx: Dictionary = {}) -> void:
	pass


func on_hand_ready(ctx: Dictionary = {}) -> void:
	pass


func on_card_played(ctx: Dictionary = {}) -> void:
	pass


func on_damage_dealt(ctx: Dictionary = {}) -> void:
	pass


func on_damage_taken(ctx: Dictionary = {}) -> void:
	var amount := int(ctx.get("damage_amount", 0))
	if amount > 0:
		_track_combat_hp_lost(amount)


func on_unblocked_damage(ctx: Dictionary = {}) -> void:
	pass


func on_enemy_death(ctx: Dictionary = {}) -> void:
	pass


func on_move(ctx: Dictionary = {}) -> void:
	pass


func on_exhaust(ctx: Dictionary = {}) -> void:
	pass


func on_before_death(ctx: Dictionary = {}) -> void:
	pass


func on_status_applied(ctx: Dictionary = {}) -> void:
	pass


func on_thorns_damage(ctx: Dictionary = {}) -> void:
	pass


func modify_card_cost(ctx: Dictionary, cost: int) -> int:
	return cost


func modify_shop_price(ctx: Dictionary, price: int) -> int:
	return price


func modify_gold_reward(ctx: Dictionary, gold: int) -> int:
	return gold
