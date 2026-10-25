# Soubor: scripts/autoload/ArtifactManager.gd
extends Node

signal artifact_triggered(artifact_name: String, effect_description: String)
@warning_ignore("unused_signal")
signal extra_turn_requested
## Tablet: GlobalUI opens deck pick for a permanent seal.
signal permanent_seal_pick_requested

const SEAL_COST_REDUCTION := 1
const SEAL_BLOCK_BONUS := 2

var _passive_artifacts: Array[ArtifactsData] = []
var _triggered_artifacts: Dictionary = {}
## artifact identity -> ArtifactBehavior instance (runtime preserved across cache refresh)
var _behavior_instances: Dictionary = {}
## Cross-system flags (e.g. skip_enemy_round). Cleared on combat end.
var _run_flags: Dictionary = {}
## Queued player-facing prompts from behaviors (resolved by BattleScene).
var _pending_prompts: Array = []


func request_player_prompt(prompt: Dictionary) -> void:
	if prompt.is_empty():
		return
	_pending_prompts.append(prompt)


func has_pending_prompts() -> bool:
	return not _pending_prompts.is_empty()


func pop_pending_prompt() -> Dictionary:
	if _pending_prompts.is_empty():
		return {}
	return _pending_prompts.pop_front()


func clear_pending_prompts() -> void:
	_pending_prompts.clear()


func get_sealed_card_id() -> String:
	if PlayerData and not PlayerData.sealed_card_id.is_empty():
		return PlayerData.sealed_card_id
	return ""


func is_card_sealed(card: CardData) -> bool:
	"""Seal is per CardData instance (meta), never by card_id — duplicates stay unsealed."""
	if card == null:
		return false
	return card.has_meta("artifact_sealed") and bool(card.get_meta("artifact_sealed"))


func request_permanent_seal_pick() -> void:
	if permanent_seal_pick_requested.get_connections().is_empty():
		# Fallback if GlobalUI has not connected yet (rare startup race).
		if has_node("/root/GameManager"):
			var gui = GameManager.global_ui_instance
			if is_instance_valid(gui) and gui.has_method("begin_permanent_seal_pick"):
				gui.call_deferred("begin_permanent_seal_pick")
				return
	permanent_seal_pick_requested.emit()


func apply_permanent_seal(card: CardData) -> bool:
	"""Stamp seal on one chosen master_deck instance. Tablet stays equipped."""
	if card == null or not PlayerData:
		return false
	PlayerData.ensure_unique_master_deck_instances()
	var idx: int = PlayerData.master_deck.find(card)
	if idx < 0:
		# Picker may hold a stale ref after uniquify — match by card_id once among unsealed.
		for i in PlayerData.master_deck.size():
			var candidate: CardData = PlayerData.master_deck[i]
			if candidate == null:
				continue
			if candidate.card_id == card.card_id and not is_card_sealed(candidate):
				idx = i
				card = candidate
				break
	if idx < 0:
		return false
	# Only one sealed card per run.
	for other_v in PlayerData.master_deck:
		var other: CardData = other_v as CardData
		if other != null and other != card and other.has_meta("artifact_sealed"):
			other.remove_meta("artifact_sealed")
	card.set_meta("artifact_sealed", true)
	PlayerData.sealed_card_id = card.card_id
	var src := card.resource_path
	if src.is_empty() and card.has_meta("source_path"):
		src = str(card.get_meta("source_path"))
	PlayerData.sealed_card_source_path = src
	return true


func get_behavior_runtime(artifact_id: String) -> Dictionary:
	if _behavior_instances.has(artifact_id):
		var behavior: ArtifactBehavior = _behavior_instances[artifact_id]
		if behavior != null:
			return behavior.runtime
	return {}


## Patch live behavior.runtime after Continue (e.g. Oathbreaker applied). Does not call on_acquired.
func restore_behavior_runtime(artifact_id: String, runtime_values: Dictionary) -> bool:
	if artifact_id.is_empty() or runtime_values.is_empty():
		return false
	if not _behavior_instances.has(artifact_id) and PlayerData:
		for artifact in PlayerData.artifacts:
			if _artifact_key(artifact) == artifact_id:
				_ensure_behavior(artifact)
				break
	if not _behavior_instances.has(artifact_id):
		return false
	var behavior: ArtifactBehavior = _behavior_instances[artifact_id]
	if behavior == null:
		return false
	for k in runtime_values.keys():
		behavior.runtime[k] = runtime_values[k]
	return true


func card_has_retain(card: CardData) -> bool:
	return card != null and card.has_retain()


func card_is_alchemy_temp(card: CardData) -> bool:
	return card != null and card.has_meta("alchemy_temp") and bool(card.get_meta("alchemy_temp"))


func apply_prompt_result(result: Dictionary) -> void:
	var prompt_id: String = String(result.get("prompt_id", ""))
	if prompt_id.is_empty():
		return
	for key in _behavior_instances:
		var behavior: ArtifactBehavior = _behavior_instances[key]
		if behavior != null and behavior.has_method("on_prompt_result"):
			behavior.call("on_prompt_result", prompt_id, result)


func _ready():
	if PlayerData:
		PlayerData.artifacts_changed.connect(_refresh_artifact_cache)


func get_run_flag(key: String, default_value = null):
	return _run_flags.get(key, default_value)


func set_run_flag(key: String, value) -> void:
	_run_flags[key] = value


func clear_run_flags() -> void:
	_run_flags.clear()


func get_player_unit() -> Node:
	return _get_player_unit()


func get_enemy_count() -> int:
	return _get_enemy_count()


func get_card_cost(card: CardData, target: Node = null) -> int:
	if card == null:
		return 0
	return modify_card_cost(card, card.cost, target)


func _artifact_key(artifact: ArtifactsData) -> String:
	if artifact == null:
		return ""
	if not artifact.artifact_id.is_empty():
		return artifact.artifact_id
	if artifact.has_meta("source_path"):
		return str(artifact.get_meta("source_path"))
	if not artifact.resource_path.is_empty():
		return artifact.resource_path
	return artifact.artifact_name


func _has_behavior(artifact: ArtifactsData) -> bool:
	return artifact != null and artifact.behavior_script != null


func _ensure_behavior(artifact: ArtifactsData) -> ArtifactBehavior:
	if not _has_behavior(artifact):
		return null
	var key := _artifact_key(artifact)
	if key.is_empty():
		return null
	if _behavior_instances.has(key):
		var existing: ArtifactBehavior = _behavior_instances[key]
		existing.artifact = artifact
		return existing
	var script: Script = artifact.behavior_script
	var instance = script.new()
	if instance == null or not (instance is ArtifactBehavior):
		push_error("ArtifactManager: behavior_script for '%s' is not ArtifactBehavior" % artifact.artifact_name)
		return null
	var behavior: ArtifactBehavior = instance
	behavior.setup(artifact)
	_behavior_instances[key] = behavior
	return behavior


func _dispatch_behaviors(method_name: String, ctx: Dictionary = {}) -> void:
	if not PlayerData:
		return
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior == null:
			continue
		if behavior.has_method(method_name):
			behavior.call(method_name, ctx)


func on_artifact_acquired(artifact: ArtifactsData) -> void:
	var behavior := _ensure_behavior(artifact)
	if behavior:
		behavior.on_acquired({})


func on_artifact_removed(artifact: ArtifactsData) -> void:
	var key := _artifact_key(artifact)
	if _behavior_instances.has(key):
		var behavior: ArtifactBehavior = _behavior_instances[key]
		behavior.on_removed({})
		_behavior_instances.erase(key)


## Dev/test: load every behavior .gd under data/artifacts/behaviors and report failures.
func validate_all_behavior_scripts() -> Dictionary:
	var ok: Array[String] = []
	var failed: Array[String] = []
	var dir := DirAccess.open("res://data/artifacts/behaviors")
	if dir == null:
		return {"ok": ok, "failed": failed, "error": "behaviors dir missing"}
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gd") and file_name != "ArtifactBehavior.gd":
			var path := "res://data/artifacts/behaviors/%s" % file_name
			var script = load(path)
			if script == null:
				failed.append("%s (load null)" % file_name)
			else:
				var inst = script.new()
				if inst == null:
					failed.append("%s (new null)" % file_name)
				elif not (inst is ArtifactBehavior):
					failed.append("%s (not ArtifactBehavior)" % file_name)
				else:
					ok.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return {"ok": ok, "failed": failed}


func _refresh_artifact_cache():
	# Preserve behavior runtime across refresh
	var saved_runtime: Dictionary = {}
	for key in _behavior_instances.keys():
		var b: ArtifactBehavior = _behavior_instances[key]
		if b:
			saved_runtime[key] = b.runtime.duplicate(true)

	_passive_artifacts.clear()
	_triggered_artifacts.clear()

	var live_keys: Dictionary = {}
	DebugLogger.log_debug("Refreshing artifact cache...")

	if not PlayerData:
		return

	for artifact in PlayerData.artifacts:
		var key := _artifact_key(artifact)
		live_keys[key] = true
		if _has_behavior(artifact):
			var behavior := _ensure_behavior(artifact)
			if behavior and saved_runtime.has(key):
				behavior.runtime = saved_runtime[key]
			DebugLogger.log_debug("Artefakt '%s' používá BEHAVIOR script" % artifact.artifact_name)
			continue

		DebugLogger.log_debug("Artefakt '%s' má trigger_type: %d (%s)" % [
			artifact.artifact_name,
			artifact.trigger_type,
			_get_trigger_type_name(artifact.trigger_type)
		])

		if artifact.trigger_type == ArtifactsData.TriggerType.PASSIVE:
			_passive_artifacts.append(artifact)
		else:
			var trigger = artifact.trigger_type
			if not _triggered_artifacts.has(trigger):
				_triggered_artifacts[trigger] = []
			_triggered_artifacts[trigger].append(artifact)

	# Drop behaviors for removed artifacts
	for key in _behavior_instances.keys():
		if not live_keys.has(key):
			_behavior_instances.erase(key)


func _get_trigger_type_name(trigger_type: int) -> String:
	match trigger_type:
		0: return "PASSIVE"
		1: return "START_OF_COMBAT"
		2: return "START_OF_TURN"
		3: return "END_OF_TURN"
		4: return "ON_CARD_PLAYED"
		5: return "ON_DAMAGE_TAKEN"
		6: return "ON_DAMAGE_DEALT"
		7: return "ON_BLOCK_GAINED"
		8: return "ON_HEAL"
		9: return "ON_ENEMY_DEATH"
		10: return "ON_HEALTH_LOW"
		11: return "ON_ENERGY_SPENT"
		12: return "ON_DRAW_CARDS"
		13: return "CONDITIONAL"
		_: return "UNKNOWN"


func trigger_artifacts(trigger_type: ArtifactsData.TriggerType, context: Dictionary = {}) -> Array:
	var results = []

	if not _triggered_artifacts.has(trigger_type):
		return results

	for artifact in _triggered_artifacts[trigger_type]:
		if _has_behavior(artifact) or artifact.effect_type == ArtifactsData.EffectType.BEHAVIOR:
			continue
		var effect = ArtifactEffect.new(artifact, context.get("target"), context)
		if effect.execute():
			results.append({
				"artifact": artifact,
				"success": true,
				"description": artifact.get_formatted_description()
			})
			emit_signal("artifact_triggered", artifact.artifact_name, artifact.get_formatted_description())

	return results


func get_passive_bonus(effect_type: ArtifactsData.EffectType) -> int:
	var total_bonus = 0
	for artifact in _passive_artifacts:
		if artifact.effect_type == effect_type:
			total_bonus += artifact.get_effective_value()
	return total_bonus


func get_conditional_bonus(effect_type: ArtifactsData.EffectType, context: Dictionary = {}) -> int:
	var total_bonus = 0
	for trigger_list in _triggered_artifacts.values():
		for artifact in trigger_list:
			if artifact.effect_type == effect_type and artifact.check_condition(context):
				total_bonus += artifact.get_effective_value()
	return total_bonus


func on_combat_start():
	DebugLogger.log_info("ArtifactManager: Spouštím START_OF_COMBAT artefakty...")

	clear_run_flags()
	clear_pending_prompts()
	_refresh_artifact_cache()
	_dispatch_behaviors("on_combat_start", _base_ctx())
	refresh_combat_visuals()

	var results = trigger_artifacts(ArtifactsData.TriggerType.START_OF_COMBAT)

	for artifact in PlayerData.artifacts:
		artifact.reset_for_new_combat()

	return results


func refresh_combat_visuals() -> void:
	"""Re-paint throne/crown/grove/line markers (safe to call mid-combat / deferred)."""
	_dispatch_behaviors("refresh_combat_visuals", _base_ctx())


func on_combat_end():
	_dispatch_behaviors("on_combat_end", _base_ctx())
	clear_run_flags()
	clear_pending_prompts()


func on_turn_start():
	DebugLogger.log_info("ArtifactManager: Spouštím START_OF_TURN artefakty...")

	var context = _base_ctx()
	_enrich_battle_ctx(context)
	_dispatch_behaviors("on_turn_start", context)
	_apply_turn_start_side_effects(context)

	var results = trigger_artifacts(ArtifactsData.TriggerType.START_OF_TURN, context)
	return results


func on_hand_ready(extra_ctx: Dictionary = {}) -> void:
	var context = _base_ctx()
	_enrich_battle_ctx(context)
	for k in extra_ctx:
		context[k] = extra_ctx[k]
	_dispatch_behaviors("on_hand_ready", context)


func on_turn_end():
	var context = _base_ctx()
	_enrich_battle_ctx(context)
	context["enemy_count"] = _get_enemy_count()
	_dispatch_behaviors("on_turn_end", context)
	return trigger_artifacts(ArtifactsData.TriggerType.END_OF_TURN, context)


func on_card_played(card_data: CardData):
	var context = _base_ctx()
	_enrich_battle_ctx(context)
	context["card"] = card_data
	context["card_cost"] = card_data.cost if card_data else 0
	context["card_id"] = card_data.card_id if card_data else ""
	context["card_name"] = card_data.card_name if card_data else ""
	_dispatch_behaviors("on_card_played", context)
	_apply_permanent_seal_on_play(card_data)
	if bool(context.get("send_to_deck_bottom", false)) and card_data:
		card_data.set_meta("tome_to_bottom", true)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_CARD_PLAYED, context)


func _apply_permanent_seal_on_play(card_data: CardData) -> void:
	if not is_card_sealed(card_data):
		return
	var player := _get_player_unit()
	if player and player.has_method("add_block"):
		player.add_block(SEAL_BLOCK_BONUS)


func on_damage_taken(amount: int, attacker: Node = null) -> Dictionary:
	var context = _base_ctx()
	_enrich_battle_ctx(context)
	context["damage_amount"] = amount
	context["unblocked_amount"] = amount
	context["attacker"] = attacker
	context["damage_deferred"] = false
	_dispatch_behaviors("on_damage_taken", context)
	if amount > 0:
		_dispatch_behaviors("on_unblocked_damage", context)
	trigger_artifacts(ArtifactsData.TriggerType.ON_DAMAGE_TAKEN, context)
	return context


func on_unblocked_damage(amount: int, attacker: Node = null) -> Dictionary:
	return on_damage_taken(amount, attacker)


func on_damage_dealt(amount: int, target: Node, was_critical: bool = false, card: CardData = null):
	var context = {
		"damage_amount": amount,
		"target": target,
		"critical_hit": was_critical,
		"dealer": _get_player_unit(),
		"card": card
	}
	_enrich_battle_ctx(context)
	_dispatch_behaviors("on_damage_dealt", context)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_DAMAGE_DEALT, context)


func on_enemy_death(enemy: Node):
	var context = {
		"dead_enemy": enemy,
		"enemy": enemy,
		"target": _get_player_unit(),
		"enemy_count": _get_enemy_count() - 1
	}
	_enrich_battle_ctx(context)
	_dispatch_behaviors("on_enemy_death", context)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_ENEMY_DEATH, context)


func on_heal(amount: int):
	var context = _base_ctx()
	context["heal_amount"] = amount
	_dispatch_behaviors("on_heal", context)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_HEAL, context)


func on_block_gained(amount: int):
	var context = {
		"block_amount": amount,
		"target": _get_player_unit()
	}
	_dispatch_behaviors("on_block_gained", context)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_BLOCK_GAINED, context)


func modify_card_cost(card: CardData, cost: int, target: Node = null) -> int:
	var result := cost
	var ctx := {"card": card, "cost": cost}
	if is_instance_valid(target):
		ctx["target"] = target
	if not PlayerData:
		return result
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior:
			result = behavior.modify_card_cost(ctx, result)
	if is_card_sealed(card):
		result = maxi(0, result - SEAL_COST_REDUCTION)
	return result


func on_enemy_turn_start(enemy: Node = null) -> void:
	var context = _base_ctx()
	_enrich_battle_ctx(context)
	if is_instance_valid(enemy):
		context["enemy"] = enemy
		context["target"] = enemy
	_dispatch_behaviors("on_enemy_turn_start", context)


func modify_shop_price(price: int, item = null) -> int:
	var result := price
	var ctx := {"price": price, "item": item}
	if not PlayerData:
		return result
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior:
			result = behavior.modify_shop_price(ctx, result)
	return result


func modify_gold_reward(gold: int) -> int:
	var result := gold
	var ctx := {"gold": gold}
	if not PlayerData:
		return result
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior:
			result = behavior.modify_gold_reward(ctx, result)
	return result


func modify_outgoing_damage(damage: int, ctx: Dictionary = {}) -> int:
	var result := damage
	if not PlayerData:
		return result
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior:
			result = behavior.modify_outgoing_damage(result, ctx)
	return maxi(0, result)


func attacks_ignore_block(target: Node, card: CardData = null) -> bool:
	if not PlayerData or not is_instance_valid(target):
		return false
	var ctx := {
		"target": target,
		"card": card,
		"attacker": _get_player_unit()
	}
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior != null and behavior.has_method("should_ignore_block") and behavior.should_ignore_block(ctx):
			return true
	return false


func modify_incoming_damage(damage: int, ctx: Dictionary = {}) -> int:
	var result := damage
	if not PlayerData:
		return result
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior := _ensure_behavior(artifact)
		if behavior:
			result = behavior.modify_incoming_damage(result, ctx)
	return maxi(0, result)


func on_before_death(ctx: Dictionary = {}) -> Dictionary:
	var merged := _base_ctx()
	for k in ctx:
		merged[k] = ctx[k]
	if not merged.has("prevent_death"):
		merged["prevent_death"] = false
	_dispatch_behaviors("on_before_death", merged)
	return merged


## Called by Unit on lethal damage. Returns true if an artifact prevented death (e.g. Phoenix).
func before_death(unit: Node = null) -> bool:
	var ctx := {}
	if unit != null:
		ctx["target"] = unit
	var result := on_before_death(ctx)
	return bool(result.get("prevent_death", false))


func on_move(steps: int = 1, from_cell: Vector2i = Vector2i.ZERO, to_cell: Vector2i = Vector2i.ZERO) -> void:
	_dispatch_behaviors("on_move", {
		"steps": steps,
		"distance": steps,
		"from": from_cell,
		"to": to_cell,
		"target": _get_player_unit()
	})


func on_unit_moved(unit: Node, from_cell: Vector2i = Vector2i.ZERO, to_cell: Vector2i = Vector2i.ZERO, steps: int = 1) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not _is_player_unit(unit):
		return
	_dispatch_behaviors("on_move", {
		"unit": unit,
		"steps": steps,
		"distance": steps,
		"from": from_cell,
		"to": to_cell,
		"target": unit
	})


func on_exhaust(card: CardData) -> Dictionary:
	var ctx := {"card": card, "target": _get_player_unit()}
	_dispatch_behaviors("on_exhaust", ctx)
	return ctx


func on_status_applied(target: Node, status_id: String, value: int, duration: int = 1) -> void:
	_dispatch_behaviors("on_status_applied", {
		"target": target,
		"status_id": status_id,
		"value": value,
		"duration": duration
	})


func on_thorns_damage(amount: int, target: Node = null) -> void:
	_dispatch_behaviors("on_thorns_damage", {
		"damage_amount": amount,
		"target": target
	})


func _apply_turn_start_side_effects(context: Dictionary) -> void:
	if bool(context.get("skip_enemy_turn", false)):
		set_run_flag("skip_enemy_round", true)
	if bool(context.get("show_enemy_move_preview", false)):
		set_run_flag("show_enemy_move_preview", true)


func _enrich_battle_ctx(context: Dictionary) -> void:
	var battle := _find_battle_scene()
	if battle == null:
		return
	var turn_v: Variant = battle.get("_current_turn_number")
	if turn_v != null:
		var turn_n := int(turn_v)
		context["current_turn"] = turn_n
		context["turn_number"] = turn_n


func _find_battle_scene() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var from_group: Node = tree.get_first_node_in_group("battle_scene")
	if is_instance_valid(from_group):
		return from_group
	if GameManager and is_instance_valid(GameManager.current_scene):
		var gm_scene: Node = GameManager.current_scene
		if gm_scene.name == "BattleScene" or gm_scene.has_method("get_player_unit"):
			return gm_scene
	var current_scene = tree.current_scene
	if current_scene and (current_scene.name == "BattleScene" or current_scene.has_method("get_player_unit")):
		return current_scene
	return null


func _is_player_unit(unit: Node) -> bool:
	if unit == null:
		return false
	if unit.is_in_group("player"):
		return true
	var ud: Variant = unit.get("unit_data")
	if ud != null and ud.faction == UnitData.Faction.PLAYER:
		return true
	return false


func _base_ctx() -> Dictionary:
	return {
		"current_hp": PlayerData.current_hp if PlayerData else 0,
		"max_hp": PlayerData.max_hp if PlayerData else 0,
		"current_energy": PlayerData.current_energy if PlayerData else 0,
		"hand_size": PlayerData.current_hand.size() if PlayerData else 0,
		"target": _get_player_unit()
	}


func _get_player_unit() -> Node:
	var current_scene = get_tree().current_scene

	if current_scene and current_scene.has_method("get_player_unit"):
		var player = current_scene.get_player_unit()
		if player != null:
			return player

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node

	var all_units = get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if unit.has_method("get_unit_data"):
			var unit_data = unit.get_unit_data()
			if unit_data and unit_data.faction == UnitData.Faction.PLAYER:
				return unit as Node

	return null


func _get_enemy_count() -> int:
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("get_enemy_count"):
		return current_scene.get_enemy_count()
	return 0


func get_max_hp_bonus() -> int:
	var total: int = get_passive_bonus(ArtifactsData.EffectType.MODIFY_MAX_HP)
	if not PlayerData:
		return total
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior: ArtifactBehavior = _ensure_behavior(artifact)
		if behavior != null:
			total += behavior.get_passive_max_hp_bonus()
	return total


func get_max_energy_bonus() -> int:
	var total: int = get_passive_bonus(ArtifactsData.EffectType.MODIFY_MAX_ENERGY)
	if not PlayerData:
		return total
	for artifact in PlayerData.artifacts:
		if not _has_behavior(artifact):
			continue
		var behavior: ArtifactBehavior = _ensure_behavior(artifact)
		if behavior != null:
			total += behavior.get_passive_max_energy_bonus()
	return total


func get_card_damage_bonus(context: Dictionary = {}) -> int:
	var passive_bonus = get_passive_bonus(ArtifactsData.EffectType.MODIFY_CARD_DAMAGE)
	var conditional_bonus = get_conditional_bonus(ArtifactsData.EffectType.MODIFY_CARD_DAMAGE, context)
	return passive_bonus + conditional_bonus


func get_block_bonus() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.MODIFY_BLOCK_GAIN)


func get_heal_bonus() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.MODIFY_HEAL_AMOUNT)


func get_critical_chance() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.CRITICAL_CHANCE)


func get_thorns_damage() -> int:
	return get_passive_bonus(ArtifactsData.EffectType.THORNS_DAMAGE)


func has_artifact_with_effect(effect_type: ArtifactsData.EffectType) -> bool:
	for artifact in PlayerData.artifacts:
		if artifact.effect_type == effect_type:
			return true
	return false


func get_artifact_count() -> int:
	return PlayerData.artifacts.size()


func handle_custom_effect(artifact: ArtifactsData, _context: Dictionary = {}) -> bool:
	# Legacy CZ custom_effect_id handlers removed — remake uses ArtifactBehavior scripts.
	if artifact and not artifact.custom_effect_id.is_empty():
		DebugLogger.log_warning("Unsupported custom_effect_id (legacy wiped): %s" % artifact.custom_effect_id)
	return false


func on_energy_spent(amount: int):
	var context = {
		"energy_spent": amount,
		"current_energy": PlayerData.current_energy if PlayerData else 0,
		"max_energy": PlayerData.max_energy if PlayerData else 0,
		"target": _get_player_unit()
	}
	_dispatch_behaviors("on_energy_spent", context)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_ENERGY_SPENT, context)


func on_draw_cards(cards_drawn: int, total_requested: int):
	var context = {
		"cards_drawn": cards_drawn,
		"total_cards_requested": total_requested,
		"hand_size": PlayerData.current_hand.size() if PlayerData else 0,
		"target": _get_player_unit()
	}
	_dispatch_behaviors("on_draw_cards", context)
	return trigger_artifacts(ArtifactsData.TriggerType.ON_DRAW_CARDS, context)


func check_conditional_artifacts():
	var context = _base_ctx()
	return trigger_artifacts(ArtifactsData.TriggerType.CONDITIONAL, context)


func check_conditional_artifacts_with_context(context: Dictionary = {}) -> Array:
	var full_context = _base_ctx()
	for key in context:
		full_context[key] = context[key]
	return trigger_artifacts(ArtifactsData.TriggerType.CONDITIONAL, full_context)


func reset_scaling_damage_after_boss():
	# Legacy infinity_sword scaling removed with CZ wipe.
	pass
