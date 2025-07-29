# ===================================================================
# Soubor: res://scenes/battle/Unit.gd
# ===================================================================
class_name Unit
extends Node2D

const FloatingTextScene = preload("res://scenes/ui/FloatingText.tscn")

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
	# ZMĚNA: Pokud status již existuje, přičteme novou hodnotu.
	if active_statuses.has(status_id):
		active_statuses[status_id].value += value
		# Můžeme případně i obnovit dobu trvání, pokud by to bylo potřeba
		# active_statuses[status_id].duration = max(active_statuses[status_id].duration, duration)
		print("DEBUG: Status '%s' na jednotce %s byl posílen na hodnotu %d." % [status_id, unit_data.unit_name, active_statuses[status_id].value])
	else:
		# Pokud status neexistuje, vytvoříme ho.
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
		# --- PŘIDANÁ VÝJIMKA PRO PERMANENTNÍ STATUSY ---
		# Pokud status nemá mít omezenou dobu trvání, přeskočíme ho.
		if status_id == "aura_devotion":
			continue # Přeskočí zbytek cyklu a jde na další status

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
	# Pokud má jednotka status "Slow", aplikuje se postih.
	# Vaše logika s přičítáním záporné hodnoty je zde zachována.
	if active_statuses.has("Slow"):
		current_range += active_statuses["Slow"].value
	
	# Zajistíme, aby pohyb nikdy neklesl pod 1 (pokud má jednotka vůbec nějaký pohyb).
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
		var duration = terrain_data.effect_duration # Získáváme dobu trvání z .tres souboru
		if status_id != "":
			# Předáváme všechny tři parametry
			apply_status(status_id, value, duration)


func heal_to_full():
	if not is_instance_valid(unit_data):
		return

	# Uložíme si, kolik HP bylo před léčením
	var health_before = current_health
	var max_hp_target = unit_data.max_health # Výchozí cíl

	# Pokud je to hráč, cíl je jeho maximální HP z PlayerData
	if unit_data.faction == UnitData.Faction.PLAYER and is_instance_valid(PlayerData):
		max_hp_target = PlayerData.max_hp

	# Nastavíme zdraví na maximum
	current_health = max_hp_target
	
	# Vypočítáme, kolik se reálně vyléčilo
	var amount_healed = current_health - health_before
	
	# Zobrazíme plovoucí text s touto hodnotou
	_show_floating_text(amount_healed, "heal")

	_update_stats_and_emit_signal()

func _die():
	emit_signal("died", self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# Soubor: scenes/battle/Unit.gd

func take_damage(amount: int) -> void:
	var damage_to_deal = amount
	var block_before = current_block
	
	var absorbed_by_block = min(amount, block_before)
	
	# Zobrazíme ztrátu bloku s typem "block_loss"
	if absorbed_by_block > 0:
		_show_floating_text(absorbed_by_block, "block_loss")

	# Odečteme pohlcené poškození
	current_block -= absorbed_by_block
	damage_to_deal -= absorbed_by_block
	
	# Pauza mezi zobrazením bloku a poškození
	if absorbed_by_block > 0 and damage_to_deal > 0:
		await get_tree().create_timer(0.3).timeout

	# Zobrazíme a aplikujeme poškození zdraví
	if damage_to_deal > 0:
		current_health -= damage_to_deal
		_show_floating_text(damage_to_deal, "damage")
		if current_health < 0:
			current_health = 0
	
	_update_stats_and_emit_signal()
	if current_health <= 0:
		_die()

func heal(amount: int):
	var health_to_restore = min(amount, unit_data.max_health - current_health)
	current_health += health_to_restore
	
	_show_floating_text(health_to_restore, "heal") # Zavoláme naši funkci

	_update_stats_and_emit_signal()

func add_block(amount: int):
	current_block += amount
	
	# Použijeme nový typ "block_gain"
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

func attack(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"): return
	# Přidáme 'await', protože take_damage nyní může obsahovat pauzu
	await target.take_damage(unit_data.attack_damage)

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
		"block_gain": # Nový typ pro zisk bloku
			text_to_display = "+" + str(amount)
			color = Color.LIGHT_SKY_BLUE
		"block_loss": # Nový typ pro ztrátu bloku
			text_to_display = "-" + str(amount)
			color = Color.SLATE_GRAY # Šedá barva pro ztrátu
	
	add_child(instance)
	instance.position = Vector2(0, -80)
	
	instance.start(text_to_display, color)
