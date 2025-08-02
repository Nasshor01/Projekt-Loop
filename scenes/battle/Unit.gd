# Soubor: res://scenes/battle/Unit.gd (FINÁLNÍ VERZE S OPRAVOU BLOKU)
class_name Unit
extends Node2D

const FloatingTextScene = preload("res://scenes/ui/FloatingText.tscn")

signal died(unit_node)
signal unit_selected(unit_node)
signal stats_changed(unit_node)

@export var unit_data: UnitData

var current_health: int = 0
var current_block: int = 0
# --- PŘIDÁNO: Nová proměnná pro permanentní blok ---
var retained_block: int = 0

var grid_position: Vector2i
var is_selected: bool = false
var active_statuses: Dictionary = {}

var has_used_base_move: bool = false
var extra_moves: int = 0
var last_attacker: Unit = null

@onready var _sprite_node: Sprite2D = $Sprite2D
@onready var _intent_ui: Control = $IntentUI

func _ready():
	if unit_data:
		if unit_data.faction == UnitData.Faction.PLAYER:
			current_health = PlayerData.current_hp
		else:
			current_health = unit_data.max_health
	if _sprite_node and unit_data.sprite_texture:
		_sprite_node.texture = unit_data.sprite_texture
	_intent_ui.visible = false
	var clickable_area = Area2D.new(); var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	if _sprite_node.texture: rect_shape.size = _sprite_node.texture.get_size() * _sprite_node.scale
	else: rect_shape.size = Vector2(64,64)
	collision_shape.shape = rect_shape; clickable_area.add_child(collision_shape)
	add_child(clickable_area)
	clickable_area.input_event.connect(_on_input_event)
	await get_tree().process_frame
	emit_signal("stats_changed", self)

func set_last_attacker(attacker: Unit):
	last_attacker = attacker

func get_last_attacker() -> Unit:
	return last_attacker

func attack(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"): return
	if target.has_method("set_last_attacker"):
		target.set_last_attacker(self)
	await target.take_damage(unit_data.attack_damage)

# --- UPRAVENÁ FUNKCE TAKE_DAMAGE ---
func take_damage(amount: int) -> void:
	if unit_data.faction == UnitData.Faction.PLAYER:
		var attacker = get_last_attacker()
		if is_instance_valid(attacker):
			for artifacts in PlayerData.artifacts:
				if artifacts.effect_id == "thorns_damage":
					print("Artefakt '%s' vrací %d poškození." % [artifacts.artifact_name, artifacts.value])
					await attacker.take_damage(artifacts.value)

	var damage_to_deal = amount
	var absorbed_by_block = min(amount, current_block)
	
	if absorbed_by_block > 0:
		_show_floating_text(absorbed_by_block, "block_loss")

	current_block -= absorbed_by_block
	damage_to_deal -= absorbed_by_block
	
	# PŘIDÁNO: Pokud se spotřeboval i permanentní blok, snížíme ho
	retained_block = min(retained_block, current_block)
	
	if absorbed_by_block > 0 and damage_to_deal > 0:
		await get_tree().create_timer(0.3).timeout

	if damage_to_deal > 0:
		current_health -= damage_to_deal
		_show_floating_text(damage_to_deal, "damage")
		if current_health < 0:
			current_health = 0
		
		if unit_data.faction == UnitData.Faction.PLAYER:
			PlayerData.take_damage(damage_to_deal)
	
	_update_stats_and_emit_signal()
	
	if current_health <= 0:
		_die()

# --- UPRAVENÁ FUNKCE RESET_FOR_NEW_TURN ---
func reset_for_new_turn():
	# Dočasný blok zmizí, ale permanentní základ zůstane.
	current_block = retained_block
	
	has_used_base_move = false
	extra_moves = 0
	_update_stats_and_emit_signal()

func can_move() -> bool:
	return not has_used_base_move or extra_moves > 0

func use_move_action():
	if extra_moves > 0:
		extra_moves -= 1
	elif not has_used_base_move:
		has_used_base_move = true

func gain_extra_move():
	extra_moves += 1

func apply_status(status_id: String, value: int, duration: int = 1):
	if active_statuses.has(status_id):
		active_statuses[status_id].value += value
		print("DEBUG: Status '%s' na jednotce %s byl posílen na hodnotu %d." % [status_id, unit_data.unit_name, active_statuses[status_id].value])
	else:
		active_statuses[status_id] = { "id": status_id, "value": value, "duration": duration }
		print("DEBUG: Jednotka %s získala status '%s' s hodnotou %d na %d kola." % [unit_data.unit_name, status_id, value, duration])
		
	_update_stats_and_emit_signal()

# --- UPRAVENÁ FUNKCE PROCESS_TURN_START_STATUSES ---
func process_turn_start_statuses() -> int:
	var extra_draw = 0
	if active_statuses.is_empty(): return extra_draw
	
	# Nejdříve zpracujeme aury, které ovlivňují blok
	if active_statuses.has("aura_devotion_plus"):
		var status_data = active_statuses["aura_devotion_plus"]
		# Nastavíme (přičteme) hodnotu permanentního bloku
		retained_block = status_data.value
		# A na začátku kola ho rovnou přičteme i k aktuálnímu bloku
		add_block(status_data.value)
	
	if active_statuses.has("aura_devotion"):
		var status_data = active_statuses["aura_devotion"]
		# Běžná aura dává jen dočasný blok
		add_block(status_data.value)
		
	# Zpracujeme ostatní statusy
	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		var status_data = active_statuses[status_id]
		match status_id:
			"draw_plus_one":
				extra_draw += status_data.value
				statuses_to_remove.append(status_id)
				
	for status_id in statuses_to_remove:
		active_statuses.erase(status_id)
		
	if not statuses_to_remove.is_empty():
		_update_stats_and_emit_signal()
		
	return extra_draw

# --- UPRAVENÁ FUNKCE PROCESS_TURN_END_STATUSES ---
func process_turn_end_statuses():
	if active_statuses.is_empty():
		return

	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		# Aura (permanentní buffy) a pomocné statusy neztrácí trvání
		if status_id == "aura_devotion" or status_id == "aura_devotion_plus":
			continue

		active_statuses[status_id].duration -= 1
		
		if active_statuses[status_id].duration <= 0:
			statuses_to_remove.append(status_id)
			print("DEBUG: Status '%s' na jednotce %s vypršel." % [status_id, unit_data.unit_name])

	if statuses_to_remove.is_empty():
		return

	for status_id in statuses_to_remove:
		active_statuses.erase(status_id)

	_update_stats_and_emit_signal()

func get_current_movement_range() -> int:
	var current_range = unit_data.movement_range
	if active_statuses.has("Slow"):
		current_range += active_statuses["Slow"].value
	
	if unit_data.movement_range > 0:
		return max(1, current_range)
	else:
		return 0

func process_terrain_effects(terrain_data: TerrainData):
	if not terrain_data or terrain_data.effect_type == TerrainData.TerrainEffect.NONE:
		return

	if terrain_data.effect_type == TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
		var status_id = terrain_data.effect_string_value
		var value = terrain_data.effect_numeric_value
		var duration = terrain_data.effect_duration
		if status_id != "":
			apply_status(status_id, value, duration)

func heal_to_full():
	if not is_instance_valid(unit_data):
		return
	var health_before = current_health
	var max_hp_target = unit_data.max_health
	if unit_data.faction == UnitData.Faction.PLAYER and is_instance_valid(PlayerData):
		max_hp_target = PlayerData.max_hp
	current_health = max_hp_target
	var amount_healed = current_health - health_before
	_show_floating_text(amount_healed, "heal")
	
	if unit_data.faction == UnitData.Faction.PLAYER and amount_healed > 0:
		PlayerData.heal(amount_healed)
		
	_update_stats_and_emit_signal()

func _die():
	emit_signal("died", self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func heal(amount: int):
	var health_to_restore = min(amount, unit_data.max_health - current_health)
	current_health += health_to_restore
	_show_floating_text(health_to_restore, "heal")
	
	if unit_data.faction == UnitData.Faction.PLAYER and health_to_restore > 0:
		PlayerData.heal(health_to_restore)
		
	_update_stats_and_emit_signal()

func add_block(amount: int):
	current_block += amount
	_show_floating_text(amount, "block_gain")
	_update_stats_and_emit_signal()

func get_unit_data() -> UnitData: return unit_data

func _update_stats_and_emit_signal(): emit_signal("stats_changed", self)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("unit_selected", self)

func set_selected_visual(selected: bool):
	is_selected = selected
	_sprite_node.modulate = Color(1.3, 1.3, 1.0) if selected else Color.WHITE

func show_intent(attack_damage: int = 0):
	var label = _intent_ui.get_node_or_null("Label")
	if label:
		label.text = str(attack_damage) if attack_damage > 0 else ""
		_intent_ui.visible = attack_damage > 0

func hide_intent():
	_intent_ui.visible = false

func _show_floating_text(amount: int, type: String):
	if amount <= 0:
		return
	var instance = FloatingTextScene.instantiate()
	var text_to_display: String
	var color: Color

	match type:
		"damage":
			text_to_display = "-" + str(amount)
			color = Color.CRIMSON
		"heal":
			text_to_display = "+" + str(amount)
			color = Color.PALE_GREEN
		"block_gain":
			text_to_display = "+" + str(amount)
			color = Color.LIGHT_SKY_BLUE
		"block_loss":
			text_to_display = "-" + str(amount)
			color = Color.SLATE_GRAY
	
	add_child(instance)
	instance.position = Vector2(0, -80)
	
	instance.start(text_to_display, color)
