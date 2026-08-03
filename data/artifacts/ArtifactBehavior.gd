class_name ArtifactBehavior
extends RefCounted
## Base class for remake artifact logic. One script per artifact.

var data: ArtifactsData
var stacks: int = 1
## Per-instance runtime (combat/run). Cleared on combat start unless marked persistent.
var runtime: Dictionary = {}

func setup(artifact_data: ArtifactsData) -> void:
	data = artifact_data
	stacks = maxi(1, artifact_data.current_stacks)

func get_id() -> String:
	return data.artifact_id if data else ""

func notify_triggered(detail: String = "") -> void:
	if data and Engine.get_main_loop() and Engine.get_main_loop().root.has_node("/root/ArtifactManager"):
		var desc := detail if not detail.is_empty() else data.get_formatted_description()
		ArtifactManager.emit_signal("artifact_triggered", data.artifact_name, desc)

# --- Lifecycle ---
func on_acquired(_ctx: Dictionary = {}) -> void:
	pass

func on_removed(_ctx: Dictionary = {}) -> void:
	pass

func on_combat_start(_ctx: Dictionary) -> void:
	pass

func on_combat_end(_ctx: Dictionary) -> void:
	pass

func on_turn_start(_ctx: Dictionary) -> void:
	pass

func on_turn_end(_ctx: Dictionary) -> void:
	pass

# --- Combat events ---
func on_card_played(_ctx: Dictionary) -> void:
	pass

func on_damage_taken(_ctx: Dictionary) -> void:
	pass

func on_damage_dealt(_ctx: Dictionary) -> void:
	pass

func on_enemy_death(_ctx: Dictionary) -> void:
	pass

func on_heal(_ctx: Dictionary) -> void:
	pass

func on_block_gained(_ctx: Dictionary) -> void:
	pass

func on_status_applied(_ctx: Dictionary) -> void:
	pass

func on_unit_moved(_ctx: Dictionary) -> void:
	pass

func on_exhaust(_ctx: Dictionary) -> void:
	pass

func on_unblocked_damage(_ctx: Dictionary) -> void:
	pass

func on_thorns_damage(_ctx: Dictionary) -> void:
	pass

func on_energy_spent(_ctx: Dictionary) -> void:
	pass

func on_hand_ready(_ctx: Dictionary) -> void:
	pass

## Return true if death was prevented (Phoenix).
func before_death(_ctx: Dictionary) -> bool:
	return false

# --- Modifiers (chainable; return modified value) ---
func modify_card_cost(_card: CardData, cost: int, _ctx: Dictionary = {}) -> int:
	return cost

func modify_shop_price(price: int, _item = null) -> int:
	return price

func modify_gold_reward(gold: int) -> int:
	return gold

func modify_outgoing_damage(damage: int, _ctx: Dictionary = {}) -> int:
	return damage

func modify_incoming_damage(damage: int, _ctx: Dictionary = {}) -> int:
	return damage

# --- Passive bonuses (queried during PlayerData.apply_passive_skills) ---
func get_max_hp_bonus() -> int:
	return 0

func get_max_energy_bonus() -> int:
	return 0

func get_card_damage_bonus(_ctx: Dictionary = {}) -> int:
	return 0

func get_block_bonus() -> int:
	return 0

func get_heal_bonus() -> int:
	return 0

func get_critical_chance() -> int:
	return 0

func get_thorns_damage() -> int:
	return 0

# --- Helpers ---
func player_unit() -> Node:
	if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("/root/ArtifactManager"):
		return ArtifactManager.get_player_unit()
	return null

func enemy_count() -> int:
	if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("/root/ArtifactManager"):
		return ArtifactManager.get_enemy_count()
	return 0

func status_value(unit: Node, status_id: String) -> int:
	if unit == null or not ("active_statuses" in unit):
		return 0
	if not unit.active_statuses.has(status_id):
		return 0
	return int(unit.active_statuses[status_id].get("value", 0))
