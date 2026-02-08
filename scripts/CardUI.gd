# ===================================================================
# Soubor: res://scripts/CardUI.gd
# ===================================================================
class_name CardUI
extends Control

@export var card_data: CardData:
	set(new_card_data):
		card_data = new_card_data
		if is_inside_tree() and _ui_nodes_ready:
			update_display()

@export var placeholder_artwork: Texture2D

var initial_scale: Vector2 = Vector2.ZERO

var _ui_nodes_ready = false
@onready var artwork_texture_rect: TextureRect = $ArtworkTextureRect
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var description_label: Label = $DescriptionLabel
@onready var card_template: TextureRect = $CardTemplateImage

var original_scale: Vector2 = Vector2(0.8, 0.8)
var base_scale: Vector2 = Vector2.ONE
var target_scale: Vector2 = Vector2.ONE
var target_position: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var is_draggable: bool = true
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_released: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO

signal drag_started(card_ui: CardUI, original_pos: Vector2)
signal drag_released(card_ui: CardUI, release_pos: Vector2)

func _ready():
	_ui_nodes_ready = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# ZMĚNA: Použijeme initial_scale, pokud je nastaveno
	if initial_scale != Vector2.ZERO:
		original_scale = initial_scale
	scale = original_scale
	base_scale = scale
	target_scale = scale
	target_position = position
	set_process(true)
	
	if card_data:
		update_display()
	
	if description_label:
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD

func update_display():
	if not _ui_nodes_ready or not card_data: return

	name_label.text = card_data.get_localized_name()
	cost_label.text = str(card_data.cost)
	
	# Použijeme dynamický popis s aktuálními hodnotami poškození
	description_label.text = card_data.get_display_description()
	
	if artwork_texture_rect and card_data.artwork:
		artwork_texture_rect.texture = card_data.artwork
	
	# Nastavíme barvu karty podle rarity
	_update_rarity_colors()

func _update_rarity_colors():
	"""Nastaví barvu karty podle rarity"""
	if not card_template or not card_data:
		return
	
	# Barevné rozlišení podle rarity (lehčí modulace pro zachování čitelnosti)
	var rarity_colors = {
		CardData.CardRarity.BASIC: Color(0.9, 0.9, 0.9, 1.0),      # Bílá/Šedá
		CardData.CardRarity.COMMON: Color(1.0, 1.0, 1.0, 1.0),     # Bílá
		CardData.CardRarity.UNCOMMON: Color(0.7, 1.0, 0.7, 1.0),   # Světle zelená
		CardData.CardRarity.RARE: Color(0.7, 0.7, 1.0, 1.0),       # Světle modrá
		CardData.CardRarity.EPIC: Color(1.0, 0.7, 1.0, 1.0),       # Světle fialová
		CardData.CardRarity.LEGENDARY: Color(1.0, 0.9, 0.5, 1.0)   # Zlatá
	}
	
	if rarity_colors.has(card_data.rarity):
		# Lehce změníme barvu pozadí karty (modulace)
		card_template.modulate = rarity_colors[card_data.rarity]
	else:
		card_template.modulate = Color.WHITE

func load_card(new_card_data: CardData):
	self.card_data = new_card_data

func _process(delta):
	if is_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		var target_global_pos = mouse_pos + _drag_offset
		global_position = global_position.lerp(target_global_pos, delta * 15.0)
		return
	
	if position.distance_to(target_position) < 1.0 and scale.distance_to(target_scale) < 0.01:
		return
	
	var next_scale = scale.lerp(target_scale, delta * 5.0)
	if next_scale.distance_to(target_scale) < 0.002:
		scale = target_scale
	else:
		scale = next_scale
	position = position.lerp(target_position, delta * 5.0)

func set_target_scale(new_scale: Vector2):
	target_scale = new_scale

func set_target_position(new_pos: Vector2):
	target_position = new_pos

func _gui_input(event: InputEvent):
	if not is_draggable:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			return
		if event is InputEventMouseMotion:
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_released = false
			_start_drag()
		else:
			_end_drag()

func _start_drag():
	is_dragging = true
	_drag_start_pos = global_position
	_drag_offset = global_position - get_viewport().get_mouse_position()
	target_scale = base_scale * 0.6
	modulate.a = 0.7
	drag_started.emit(self, _drag_start_pos)

func _end_drag():
	if is_dragging:
		is_dragging = false
		target_scale = base_scale
		modulate.a = 1.0
		_drag_released = true
		drag_released.emit(self, global_position)

func consume_drag_release() -> bool:
	if _drag_released:
		_drag_released = false
		return true
	return false
