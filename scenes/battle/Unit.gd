# ===================================================================
# Soubor: res://scenes/battle/Unit.gd
# ===================================================================
class_name Unit
extends Node2D

signal died(unit_node)
signal unit_selected(unit_node)
signal stats_changed(unit_node)

@export var unit_data: UnitData

var current_health: int = 0
var current_block: int = 0
var grid_position: Vector2i
var is_selected: bool = false
var active_statuses: Dictionary = {}

var has_used_base_move: bool = false
var extra_moves: int = 0

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

func reset_for_new_turn():
	current_block = 0
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
	"""
	Aplikuje status na jednotku.
	Uloží jeho hodnotu (value) i dobu trvání (duration).
	"""
	# Pokud status už existuje, pro jednoduchost ho jen obnovíme
	active_statuses[status_id] = {
		"id": status_id,
		"value": value,
		"duration": duration
	}
	print("DEBUG: Jednotka %s získala status '%s' s hodnotou %d na %d kola." % [unit_data.unit_name, status_id, value, duration])
	_update_stats_and_emit_signal()

func process_turn_start_statuses() -> int:
	var extra_draw = 0
	if active_statuses.is_empty(): return extra_draw
	
	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		var status_data = active_statuses[status_id]
		match status_id:
			"aura_devotion":
				add_block(status_data.value)
			"draw_plus_one":
				extra_draw += status_data.value
				statuses_to_remove.append(status_id)
			# "Slow" zde záměrně není, jeho efekt se aplikuje pasivně
				
	for status_id in statuses_to_remove:
		active_statuses.erase(status_id)
		
	if not statuses_to_remove.is_empty():
		_update_stats_and_emit_signal()
		
	return extra_draw

func process_turn_end_statuses():
	"""
	Zpracuje statusy na konci kola. Sníží dobu trvání a odstraní ty, co vypršely.
	"""
	if active_statuses.is_empty():
		return

	var statuses_to_remove = []
	for status_id in active_statuses.keys():
		# Snížíme dobu trvání o 1
		active_statuses[status_id].duration -= 1
		# Pokud klesne na 0, označíme status k odstranění
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
	return max(0, current_range)

func process_terrain_effects(terrain_data: TerrainData):
	if not terrain_data or terrain_data.effect_type == TerrainData.TerrainEffect.NONE:
		return

	if terrain_data.effect_type == TerrainData.TerrainEffect.APPLY_STATUS_ON_ENTER:
		var status_id = terrain_data.effect_string_value
		var value = terrain_data.effect_numeric_value
		var duration = terrain_data.effect_duration # Získáváme dobu trvání z .tres souboru
		if status_id != "":
			# Předáváme všechny tři parametry
			apply_status(status_id, value, duration)

func heal(amount: int):
	current_health = min(current_health + amount, unit_data.max_health)
	_update_stats_and_emit_signal()

func heal_to_full():
	if not is_instance_valid(unit_data):
		return
	
	# Pokud je jednotka hráčova, vyléčí se na PlayerData.max_hp
	if unit_data.faction == UnitData.Faction.PLAYER:
		if is_instance_valid(PlayerData): # Ujistíme se, že PlayerData existuje
			current_health = PlayerData.max_hp
		else:
			# Fallback, pokud by PlayerData z nějakého důvodu nebylo dostupné
			current_health = unit_data.max_health
	else:
		# Pro ostatní jednotky se léčí na jejich vlastní max_health
		current_health = unit_data.max_health
	
	_update_stats_and_emit_signal()

func _die():
	emit_signal("died", self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func take_damage(amount: int):
	var damage_to_deal = amount
	if current_block > 0:
		var block_damage = min(current_block, damage_to_deal)
		current_block -= block_damage
		damage_to_deal -= block_damage
	if damage_to_deal > 0:
		current_health -= damage_to_deal
		if current_health < 0:
			current_health = 0
	_update_stats_and_emit_signal()
	if current_health <= 0:
		_die()
		
func get_unit_data() -> UnitData: return unit_data

func _update_stats_and_emit_signal(): emit_signal("stats_changed", self)

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("unit_selected", self)

func set_selected_visual(selected: bool):
	is_selected = selected
	_sprite_node.modulate = Color(1.3, 1.3, 1.0) if selected else Color.WHITE

func add_block(amount: int):
	current_block += amount
	_update_stats_and_emit_signal()

func show_intent(attack_damage: int = 0):
	var label = _intent_ui.get_node_or_null("Label")
	if label:
		label.text = str(attack_damage) if attack_damage > 0 else ""
		_intent_ui.visible = attack_damage > 0

func hide_intent():
	_intent_ui.visible = false

func attack(target: Node2D):
	if not is_instance_valid(target) or not target.has_method("take_damage"): return
	target.take_damage(unit_data.attack_damage)
