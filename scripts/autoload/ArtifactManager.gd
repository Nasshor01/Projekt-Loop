# Soubor: scripts/autoload/ArtifactManager.gd
extends Node
## Event bus + behavior registry for the artifact remake.

signal artifact_triggered(artifact_name: String, effect_description: String)
signal extra_turn_requested

var _behaviors: Array[ArtifactBehavior] = []
var _run_flags: Dictionary = {}  # once-per-run etc.
var combat_turn: int = 0
var attacks_this_turn: int = 0
var hp_lost_this_combat: int = 0
var cards_played_this_turn: Array = []
## Auto grid zones: {artifact_id: {cells: Array[Vector2i], charges: Dictionary, ...}}
var grid_zones: Dictionary = {}
var _status_hook_depth: int = 0

func _ready() -> void:
	if PlayerData:
		if not PlayerData.artifacts_changed.is_connected(_refresh_artifact_cache):
			PlayerData.artifacts_changed.connect(_refresh_artifact_cache)
	_refresh_artifact_cache()

func _refresh_artifact_cache() -> void:
	var old_runtime: Dictionary = {}
	for b in _behaviors:
		if b == null:
			continue
		old_runtime[b.get_id()] = b.runtime.duplicate(true)
	_behaviors.clear()
	if not PlayerData:
		return
	for artifact in PlayerData.artifacts:
		if artifact == null:
			continue
		var behavior := artifact.create_behavior()
		if behavior == null:
			continue
		var aid := behavior.get_id()
		if old_runtime.has(aid):
			behavior.runtime = old_runtime[aid]
		_behaviors.append(behavior)
	DebugLogger.log_debug("ArtifactManager: %d behaviors active" % _behaviors.size())

func _dispatch(method_name: String, ctx: Dictionary = {}) -> Array:
	var results: Array = []
	for behavior in _behaviors:
		if behavior == null:
			continue
		if not behavior.has_method(method_name):
			continue
		var ret = behavior.call(method_name, ctx)
		results.append({"behavior": behavior, "result": ret, "id": behavior.get_id()})
	return results

func _base_ctx() -> Dictionary:
	return {
		"current_hp": PlayerData.current_hp if PlayerData else 0,
		"max_hp": PlayerData.max_hp if PlayerData else 1,
		"current_energy": PlayerData.current_energy if PlayerData else 0,
		"hand_size": PlayerData.current_hand.size() if PlayerData else 0,
		"target": get_player_unit(),
		"combat_turn": combat_turn,
		"attacks_this_turn": attacks_this_turn,
		"hp_lost_this_combat": hp_lost_this_combat,
	}

# --- Public API used by battle / shop / player ---

func on_artifact_acquired(artifact: ArtifactsData) -> void:
	_refresh_artifact_cache()
	for b in _behaviors:
		if b.get_id() == artifact.artifact_id:
			b.on_acquired(_base_ctx())
			break

func on_combat_start() -> Array:
	combat_turn = 0
	attacks_this_turn = 0
	hp_lost_this_combat = 0
	cards_played_this_turn.clear()
	grid_zones.clear()
	_refresh_artifact_cache()
	for artifact in PlayerData.artifacts:
		if artifact:
			artifact.reset_for_new_combat()
	var ctx := _base_ctx()
	ctx["is_combat_start"] = true
	return _dispatch("on_combat_start", ctx)

func on_combat_end() -> Array:
	var results := _dispatch("on_combat_end", _base_ctx())
	grid_zones.clear()
	return results

func on_turn_start() -> Array:
	combat_turn += 1
	attacks_this_turn = 0
	cards_played_this_turn.clear()
	var ctx := _base_ctx()
	ctx["current_turn"] = combat_turn
	ctx["turn_number"] = combat_turn
	return _dispatch("on_turn_start", ctx)

func on_turn_end() -> Array:
	var ctx := _base_ctx()
	ctx["current_turn"] = combat_turn
	ctx["enemy_count"] = get_enemy_count()
	var player := get_player_unit()
	if player and "grid_position" in player:
		ctx["player_cell"] = player.grid_position
	return _dispatch("on_turn_end", ctx)

func on_card_played(card_data: CardData) -> Array:
	var ctx := _base_ctx()
	ctx["card"] = card_data
	ctx["card_cost"] = get_card_cost(card_data)
	ctx["card_id"] = card_data.card_id
	ctx["card_name"] = card_data.card_name
	cards_played_this_turn.append(card_data)
	if _card_is_attack(card_data):
		attacks_this_turn += 1
		ctx["is_attack"] = true
	else:
		ctx["is_attack"] = false
	ctx["attacks_this_turn"] = attacks_this_turn
	_dispatch("on_card_played", ctx)
	# Compat shape for old BattleScene logging
	var legacy: Array = []
	for behavior in _behaviors:
		if behavior and behavior.data:
			legacy.append({
				"artifact": behavior.data,
				"success": true,
				"description": behavior.data.get_formatted_description()
			})
	return legacy

func on_damage_taken(amount: int, attacker: Node = null) -> Array:
	# Prefer on_unblocked_damage for HP hits (tracks combat loss). This remains for fully-blocked hooks if needed.
	var ctx := _base_ctx()
	ctx["damage_amount"] = amount
	ctx["attacker"] = attacker
	return _dispatch("on_damage_taken", ctx)

func on_unblocked_damage(amount: int, attacker: Node = null) -> Array:
	if amount <= 0:
		return []
	hp_lost_this_combat += amount
	var ctx := _base_ctx()
	ctx["damage_amount"] = amount
	ctx["attacker"] = attacker
	ctx["unblocked"] = true
	var results := _dispatch("on_unblocked_damage", ctx)
	results.append_array(_dispatch("on_damage_taken", ctx))
	return results

func on_damage_dealt(amount: int, target: Node, was_critical: bool = false) -> Array:
	var ctx := _base_ctx()
	ctx["damage_amount"] = amount
	ctx["target"] = target
	ctx["critical_hit"] = was_critical
	ctx["dealer"] = get_player_unit()
	return _dispatch("on_damage_dealt", ctx)

func on_enemy_death(enemy: Node) -> Array:
	var ctx := _base_ctx()
	ctx["dead_enemy"] = enemy
	ctx["enemy_count"] = maxi(0, get_enemy_count() - 1)
	return _dispatch("on_enemy_death", ctx)

func on_heal(amount: int) -> Array:
	var ctx := _base_ctx()
	ctx["heal_amount"] = amount
	return _dispatch("on_heal", ctx)

func on_block_gained(amount: int) -> Array:
	var ctx := _base_ctx()
	ctx["block_amount"] = amount
	return _dispatch("on_block_gained", ctx)

func on_status_applied(unit: Node, status_id: String, value: int, duration: int) -> Array:
	if _status_hook_depth > 2:
		return []
	_status_hook_depth += 1
	var ctx := _base_ctx()
	ctx["unit"] = unit
	ctx["status_id"] = status_id
	ctx["status_value"] = value
	ctx["status_duration"] = duration
	ctx["applied_by_player"] = _is_player_unit(get_player_unit()) and unit != get_player_unit()
	var results := _dispatch("on_status_applied", ctx)
	_status_hook_depth -= 1
	return results

func on_unit_moved(unit: Node, from_cell: Vector2i, to_cell: Vector2i, steps: int) -> Array:
	var ctx := _base_ctx()
	ctx["unit"] = unit
	ctx["from_cell"] = from_cell
	ctx["to_cell"] = to_cell
	ctx["steps"] = steps
	ctx["is_player"] = unit == get_player_unit()
	return _dispatch("on_unit_moved", ctx)

func on_exhaust(card_data: CardData) -> Array:
	var ctx := _base_ctx()
	ctx["card"] = card_data
	return _dispatch("on_exhaust", ctx)

func on_thorns_damage(amount: int, attacker: Node) -> Array:
	var ctx := _base_ctx()
	ctx["damage_amount"] = amount
	ctx["attacker"] = attacker
	return _dispatch("on_thorns_damage", ctx)

func on_energy_spent(amount: int) -> Array:
	var ctx := _base_ctx()
	ctx["energy_spent"] = amount
	return _dispatch("on_energy_spent", ctx)

func on_draw_cards(cards_drawn: int, total_requested: int) -> Array:
	var ctx := _base_ctx()
	ctx["cards_drawn"] = cards_drawn
	ctx["total_cards_requested"] = total_requested
	return _dispatch("on_draw_cards", ctx)

func before_death(unit: Node) -> bool:
	if unit != get_player_unit():
		return false
	var ctx := _base_ctx()
	ctx["unit"] = unit
	for behavior in _behaviors:
		if behavior.before_death(ctx):
			return true
	return false

func get_card_cost(card: CardData, ctx: Dictionary = {}) -> int:
	if card == null:
		return 0
	var cost: int = card.cost
	var full_ctx := _base_ctx()
	for k in ctx:
		full_ctx[k] = ctx[k]
	for behavior in _behaviors:
		cost = behavior.modify_card_cost(card, cost, full_ctx)
	return maxi(0, cost)

func modify_shop_price(price: int, item = null) -> int:
	var p := price
	for behavior in _behaviors:
		p = behavior.modify_shop_price(p, item)
	return maxi(0, p)

func modify_gold_reward(gold: int) -> int:
	var g := gold
	for behavior in _behaviors:
		g = behavior.modify_gold_reward(g)
	return maxi(0, g)

func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var d := damage
	var full := _base_ctx()
	for k in ctx:
		full[k] = ctx[k]
	for behavior in _behaviors:
		d = behavior.modify_outgoing_damage(d, full)
	return maxi(0, d)

func get_max_hp_bonus() -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_max_hp_bonus()
	return total

func get_max_energy_bonus() -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_max_energy_bonus()
	return total

func get_card_damage_bonus(context: Dictionary = {}) -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_card_damage_bonus(context)
	return total

func get_block_bonus() -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_block_bonus()
	return total

func get_heal_bonus() -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_heal_bonus()
	return total

func get_critical_chance() -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_critical_chance()
	return total

func get_thorns_damage() -> int:
	var total := 0
	for b in _behaviors:
		total += b.get_thorns_damage()
	var player := get_player_unit()
	if player and "active_statuses" in player and player.active_statuses.has("thorns"):
		total += int(player.active_statuses["thorns"].get("value", 0))
	return total

func get_artifact_count() -> int:
	return PlayerData.artifacts.size() if PlayerData else 0

func get_behavior(artifact_id: String) -> ArtifactBehavior:
	for b in _behaviors:
		if b.get_id() == artifact_id:
			return b
	return null

func has_artifact_id(artifact_id: String) -> bool:
	return get_behavior(artifact_id) != null

func get_run_flag(key: String, default_value = null):
	return _run_flags.get(key, default_value)

func set_run_flag(key: String, value) -> void:
	_run_flags[key] = value

func clear_run_flags() -> void:
	_run_flags.clear()

func queue_remove_artifact(artifact: ArtifactsData) -> void:
	if artifact and PlayerData:
		PlayerData.remove_artifact(artifact)

func request_extra_turn() -> void:
	emit_signal("extra_turn_requested")

# Compat shims used by old call sites
func trigger_artifacts(trigger_type: ArtifactsData.TriggerType, context: Dictionary = {}) -> Array:
	match trigger_type:
		ArtifactsData.TriggerType.ON_ENERGY_SPENT:
			return on_energy_spent(int(context.get("energy_spent", 0)))
		ArtifactsData.TriggerType.ON_DRAW_CARDS:
			return on_draw_cards(int(context.get("cards_drawn", 0)), int(context.get("total_cards_requested", 0)))
		_:
			return []

func check_conditional_artifacts() -> Array:
	return []

func check_conditional_artifacts_with_context(context: Dictionary = {}) -> Array:
	# Legacy hook from BattleScene discard-finished. Must NOT re-fire on_turn_end
	# (that already ran in _on_end_turn_button_pressed). Only sync turn counter.
	if context.has("current_turn") or context.has("turn_number"):
		combat_turn = int(context.get("current_turn", context.get("turn_number", combat_turn)))
	return []

func on_hand_ready() -> Array:
	## After opening hand is drawn — for artifacts that need cards in hand.
	return _dispatch("on_hand_ready", _base_ctx())

func reset_scaling_damage_after_boss() -> void:
	pass  # Old Infinity Sword removed

func get_passive_bonus(_effect_type: ArtifactsData.EffectType) -> int:
	return 0

func get_conditional_bonus(_effect_type: ArtifactsData.EffectType, _context: Dictionary = {}) -> int:
	return 0

func handle_custom_effect(_artifact: ArtifactsData, _context: Dictionary = {}) -> bool:
	return false

func has_artifact_with_effect(_effect_type: ArtifactsData.EffectType) -> bool:
	return false

# --- Helpers ---

func get_player_unit() -> Node:
	var current_scene = get_tree().current_scene if get_tree() else null
	if current_scene and current_scene.has_method("get_player_unit"):
		var player = current_scene.get_player_unit()
		if player != null:
			return player
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	if players.size() > 0:
		return players[0] as Node
	return null

func get_enemy_count() -> int:
	var current_scene = get_tree().current_scene if get_tree() else null
	if current_scene and current_scene.has_method("get_enemy_count"):
		return current_scene.get_enemy_count()
	return 0

func get_enemies() -> Array:
	var current_scene = get_tree().current_scene if get_tree() else null
	if current_scene:
		if current_scene.has_method("get_all_enemies"):
			return current_scene.get_all_enemies()
		if current_scene.has_method("get_enemy_units"):
			return current_scene.get_enemy_units()
	var result: Array = []
	if get_tree():
		for n in get_tree().get_nodes_in_group("units"):
			if n.has_method("get_unit_data"):
				var ud = n.get_unit_data()
				if ud and ud.faction == UnitData.Faction.ENEMY and int(n.get("current_health")) > 0:
					result.append(n)
	return result

func is_edge_cell(cell: Vector2i, grid_size: Vector2i = Vector2i(8, 5)) -> bool:
	return cell.x <= 0 or cell.y <= 0 or cell.x >= grid_size.x - 1 or cell.y >= grid_size.y - 1

func is_center_cell(cell: Vector2i, grid_size: Vector2i = Vector2i(8, 5)) -> bool:
	return not is_edge_cell(cell, grid_size)

func player_half_cells(grid_size: Vector2i = Vector2i(8, 5)) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var max_x := int(grid_size.x / 2) - 1
	for x in range(0, maxi(1, max_x + 1)):
		for y in range(grid_size.y):
			cells.append(Vector2i(x, y))
	return cells

func pick_random_player_half_cell(exclude: Array = []) -> Vector2i:
	var cells := player_half_cells()
	var filtered: Array[Vector2i] = []
	for c in cells:
		if not exclude.has(c):
			filtered.append(c)
	if filtered.is_empty():
		return Vector2i(0, 0)
	return filtered[randi() % filtered.size()]

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1)
	]

func _card_is_attack(card: CardData) -> bool:
	if card == null:
		return false
	if card.has_method("has_tag") and card.has_tag(CardData.CardTag.ATTACK):
		return true
	for e in card.effects:
		if e and (e.effect_type == CardEffectData.EffectType.DEAL_DAMAGE \
			or e.effect_type == CardEffectData.EffectType.DEAL_DAMAGE_FROM_BLOCK \
			or e.effect_type == CardEffectData.EffectType.DEAL_DOUBLE_DAMAGE_FROM_BLOCK):
			return true
	return false

func _is_player_unit(unit: Node) -> bool:
	return unit != null and unit == get_player_unit()

func apply_status_to_unit(unit: Node, status_id: String, value: int, duration: int = 99) -> void:
	if unit and unit.has_method("apply_status"):
		unit.apply_status(status_id, value, duration)

func smoke_test(artifact_id: String) -> Dictionary:
	## Lightweight assertions for DevConsole `test_artifact`.
	var report := {"id": artifact_id, "ok": false, "messages": []}
	var path := "res://data/artifacts/catalog/%s.tres" % artifact_id
	# Try rarity folders
	var candidates := [
		path,
		"res://data/artifacts/catalog/common/%s.tres" % artifact_id,
		"res://data/artifacts/catalog/uncommon/%s.tres" % artifact_id,
		"res://data/artifacts/catalog/rare/%s.tres" % artifact_id,
		"res://data/artifacts/catalog/cursed/%s.tres" % artifact_id,
		"res://data/artifacts/catalog/legendary/%s.tres" % artifact_id,
		"res://data/artifacts/catalog/boss/%s.tres" % artifact_id,
	]
	var art: ArtifactsData = null
	for p in candidates:
		if ResourceLoader.exists(p):
			art = load(p) as ArtifactsData
			if art:
				break
	if art == null:
		report["messages"].append("Missing catalog resource for %s" % artifact_id)
		return report
	var behavior := art.create_behavior()
	if behavior == null:
		report["messages"].append("Behavior failed to instantiate")
		return report
	report["messages"].append("Behavior OK: %s" % art.behavior_script)
	# Forbidden Apple specific
	if artifact_id == "forbidden_apple":
		var bonus = behavior.get_max_hp_bonus()
		if bonus != 7:
			report["messages"].append("Expected max HP bonus 7, got %d" % bonus)
			return report
		art.current_stacks = 2
		behavior.setup(art)
		if behavior.get_max_hp_bonus() != 14:
			report["messages"].append("Expected stacked bonus 14, got %d" % behavior.get_max_hp_bonus())
			return report
		report["messages"].append("Forbidden Apple stack math OK")
	report["ok"] = true
	report["messages"].append("PASS")
	return report
