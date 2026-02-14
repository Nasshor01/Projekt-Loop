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
@export var static_layout: bool = false

var initial_scale: Vector2 = Vector2.ZERO

var _ui_nodes_ready = false
@onready var artwork_texture_rect: TextureRect = $ArtworkTextureRect
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var description_label: RichTextLabel = $DescriptionLabel
@onready var card_template: TextureRect = $CardTemplateImage
var _usage_label: Label = null

var original_scale: Vector2 = Vector2(0.7, 0.7)
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
signal card_clicked(card_data: CardData)
signal card_right_clicked(data: CardData)

func _ready():
	_ui_nodes_ready = true
	_usage_label = get_node_or_null("UsageLabel") as Label
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_child_mouse_filters()
	
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
		description_label.fit_content = true
		description_label.scroll_active = false
		description_label.add_theme_constant_override("line_separation", 6)
		# Ensure font size at least 18px and default color for readability
		if description_label.get_theme_font_size("normal_font_size") < 18:
			description_label.add_theme_font_size_override("normal_font_size", 18)
		description_label.add_theme_color_override("default_color", Color(1, 1, 1, 1))

	if static_layout:
		target_position = position
		target_scale = scale

func _set_child_mouse_filters():
	# Umožní parentu zachytit hover/click přes celý obsah karty
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_display():
	if not _ui_nodes_ready or not card_data: return

	name_label.text = card_data.get_localized_name()
	cost_label.text = str(card_data.cost)
	
	# Použijeme dynamický popis s BBCode shorthand (center-aligned)
	var desc := card_data.get_display_description()
	description_label.text = "[center]%s[/center]" % desc if not desc.is_empty() else ""
	
	if artwork_texture_rect and card_data.artwork:
		artwork_texture_rect.texture = card_data.artwork
	
	# Usage x/x – zobrazit jen když má karta max_uses_before_removal > 0
	if _usage_label:
		if card_data.max_uses_before_removal > 0:
			var used: int = 0
			if not Engine.is_editor_hint() and PlayerData:
				used = PlayerData.get_card_usage_count(card_data.card_id)
			_usage_label.text = "%d/%d" % [used, card_data.max_uses_before_removal]
			_usage_label.visible = true
		else:
			_usage_label.visible = false
	
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
	if static_layout:
		return
	# Aktualizovat usage x/x (aby ostatní kopie v ruce ukázaly aktuální počet)
	if _usage_label and _usage_label.visible and card_data and card_data.max_uses_before_removal > 0 and not Engine.is_editor_hint() and PlayerData:
		_usage_label.text = "%d/%d" % [PlayerData.get_card_usage_count(card_data.card_id), card_data.max_uses_before_removal]
	if is_dragging:
		var mouse_pos = get_viewport().get_mouse_position()
		scale = scale.lerp(target_scale, delta * 12.0)
		var visual_size = custom_minimum_size * scale
		var target_global_pos = mouse_pos - visual_size / 2
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
	# 1. LEVÝ KLIK
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_modulate_click_feedback()
			# Pokud karta není draggable (Shop/Rewards), emitujeme klik a končíme
			if not is_draggable:
				card_clicked.emit(card_data)
				accept_event()
				return
			
			# Pokud je draggable (Boj), připravíme drag
			_drag_released = false
			_start_drag()
		else:
			if is_draggable:
				_end_drag()

	# 2. PRAVÝ KLIK (Vždy zkusí ukázat tooltip)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			# SIGNÁL PRO TOOLTIP (Tohle je nejčistší cesta)
			# Pokud máš CardTooltip jako globální/nadřazený uzel, napoj se na tento signál
			card_right_clicked.emit(card_data) 
			
			# Alternativně tvoje stará logika, pokud uzel existuje:
			if has_node("TooltipComponent"):
				get_node("TooltipComponent").show_tooltip()
			
			accept_event()

func _start_drag():
	is_dragging = true
	_drag_start_pos = global_position
	target_scale = Vector2(0.5, 0.5)
	scale = target_scale
	var mouse_pos = get_viewport().get_mouse_position()
	var visual_size = custom_minimum_size * scale
	global_position = mouse_pos - visual_size / 2
	modulate.a = 0.8
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_started.emit(self, _drag_start_pos)

func _end_drag():
	if is_dragging:
		is_dragging = false
		target_scale = base_scale
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		_drag_released = true
		drag_released.emit(self, global_position)

func cancel_drag():
	if is_dragging:
		is_dragging = false
		target_scale = base_scale
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		_drag_released = false

func consume_drag_release() -> bool:
	if _drag_released:
		_drag_released = false
		return true
	return false

func _modulate_click_feedback():
	modulate = Color.RED
	await get_tree().process_frame
	if is_inside_tree():
		modulate = Color(1, 1, 1, 0.8) if is_dragging else Color.WHITE
