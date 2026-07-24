# ===================================================================
# Soubor: res://scripts/CardUI.gd
# ===================================================================
class_name CardUI
extends Control

## Design size in CardUI.tscn — contexts scale from this, don't crush below ~0.8 for readable text.
const DESIGN_SIZE: Vector2 = Vector2(192, 240)

## How the card is presented. Data still comes from CardData (.tres).
enum DisplayMode {
	FULL,    ## Hand — animated, ~0.88 scale
	SHOP,    ## Shop slot — 1.0 scale, full face
	REWARD,  ## Reward / rest pick — ~0.95 scale
	DECK,    ## Deck / pile viewer — ~0.85 scale, still full face
	COMPACT, ## Tiny grid tile: cost + name + short line (no art crush)
}

const SCALE_HAND := Vector2(0.88, 0.88)
const SCALE_SHOP := Vector2(1.0, 1.0)
const SCALE_REWARD := Vector2(0.95, 0.95)
const SCALE_DECK := Vector2(0.85, 0.85)
const SCALE_COMPACT := Vector2(1.0, 1.0)
const COMPACT_SIZE := Vector2(168, 210)

## StS-style face: fixed text slot, clamp lines, shrink font before overflowing the frame.
const DESC_MAX_LINES_FULL := 4
const DESC_MAX_LINES_COMPACT := 3
const DESC_FONT_COMFORTABLE := 16
const DESC_FONT_DENSE := 14
const COST_FONT_SIZE := 30
const NAME_FONT_FULL := 17
const NAME_FONT_COMPACT := 18

@export var card_data: CardData:
	set(new_card_data):
		card_data = new_card_data
		if is_inside_tree() and _ui_nodes_ready:
			update_display()

@export var placeholder_artwork: Texture2D
@export var static_layout: bool = false

var display_mode: DisplayMode = DisplayMode.FULL
var initial_scale: Vector2 = Vector2.ZERO

var _ui_nodes_ready = false
@onready var artwork_texture_rect: TextureRect = $ArtworkTextureRect
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var description_label: RichTextLabel = $DescriptionLabel
@onready var card_template: TextureRect = $CardTemplateImage
var _usage_label: Label = null

var original_scale: Vector2 = SCALE_HAND
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
	target_position = position
	set_process(true)
	custom_minimum_size = DESIGN_SIZE
	size = DESIGN_SIZE

	if not static_layout and display_mode == DisplayMode.FULL:
		if initial_scale != Vector2.ZERO:
			original_scale = initial_scale
		else:
			original_scale = SCALE_HAND
		scale = original_scale
		base_scale = scale
		target_scale = scale
	else:
		if base_scale == Vector2.ONE and target_scale == Vector2.ONE:
			base_scale = scale
			target_scale = scale
			original_scale = scale

	_apply_readability_theme()
	if card_data:
		update_display()

	if static_layout:
		target_position = position
		target_scale = scale

func _apply_readability_theme() -> void:
	if description_label:
		# Keep text inside the fixed face slot (fit_content grows past the frame).
		description_label.fit_content = false
		description_label.scroll_active = false
		description_label.clip_contents = true
		description_label.bbcode_enabled = true
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_constant_override("line_separation", 2)
		description_label.add_theme_color_override("default_color", Color(1, 1, 1, 1))
		description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		description_label.add_theme_constant_override("outline_size", 3)
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if name_label:
		name_label.clip_text = true
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("outline_size", 5)
	if cost_label:
		# Fixed gem slot: always centered, never wraps.
		cost_label.clip_text = true
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
		cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		cost_label.add_theme_constant_override("outline_size", 5)

## Call after instantiate / before or after add_child. Sets scale + layout for context.
func apply_display_mode(mode: DisplayMode) -> void:
	display_mode = mode
	if mode == DisplayMode.FULL:
		static_layout = false
		is_draggable = true
	else:
		static_layout = true
		is_draggable = false

	match mode:
		DisplayMode.FULL:
			_layout_full()
			_set_visual_scale(SCALE_HAND)
		DisplayMode.SHOP:
			_layout_full()
			_set_visual_scale(SCALE_SHOP)
		DisplayMode.REWARD:
			_layout_full()
			_set_visual_scale(SCALE_REWARD)
		DisplayMode.DECK:
			_layout_full()
			_set_visual_scale(SCALE_DECK)
		DisplayMode.COMPACT:
			_layout_compact()
			_set_visual_scale(SCALE_COMPACT)

	if card_data and _ui_nodes_ready:
		update_display()

func get_scaled_size() -> Vector2:
	return custom_minimum_size * scale

func _set_visual_scale(s: Vector2) -> void:
	original_scale = s
	base_scale = s
	target_scale = s
	scale = s

func _layout_full() -> void:
	custom_minimum_size = DESIGN_SIZE
	size = DESIGN_SIZE
	if card_template:
		card_template.custom_minimum_size = DESIGN_SIZE
		card_template.size = DESIGN_SIZE
		card_template.visible = true
	if artwork_texture_rect:
		artwork_texture_rect.visible = true
		artwork_texture_rect.position = Vector2(48, 40)
		artwork_texture_rect.size = Vector2(99, 52)
	if name_label:
		# Slightly tighter name band → more room for effect lines.
		name_label.position = Vector2(28, 94)
		name_label.size = Vector2(136, 24)
		name_label.add_theme_font_size_override("font_size", NAME_FONT_FULL)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if cost_label:
		# Sit inside the template cost gem (top-left).
		cost_label.position = Vector2(16, 12)
		cost_label.size = Vector2(36, 36)
		cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	if description_label:
		description_label.visible = true
		# Reclaim side padding; keep clear of usage counter at bottom-right.
		description_label.position = Vector2(26, 118)
		description_label.size = Vector2(140, 88)
	if _usage_label:
		_usage_label.position = Vector2(130, 208)

func _layout_compact() -> void:
	"""Readable tile without scaling text to mush: no art, bigger name + short effects."""
	custom_minimum_size = COMPACT_SIZE
	size = COMPACT_SIZE
	if card_template:
		card_template.custom_minimum_size = COMPACT_SIZE
		card_template.size = COMPACT_SIZE
		card_template.visible = true
	if artwork_texture_rect:
		artwork_texture_rect.visible = false
	if cost_label:
		cost_label.position = Vector2(14, 10)
		cost_label.size = Vector2(36, 36)
		cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	if name_label:
		name_label.position = Vector2(16, 52)
		name_label.size = Vector2(136, 40)
		name_label.add_theme_font_size_override("font_size", NAME_FONT_COMPACT)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if description_label:
		description_label.visible = true
		description_label.position = Vector2(16, 100)
		description_label.size = Vector2(136, 96)
	if _usage_label:
		_usage_label.visible = false

func _set_child_mouse_filters():
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _clamp_description_lines(desc: String, max_lines: int) -> String:
	if desc.is_empty() or max_lines < 1:
		return desc
	var lines := desc.split("\n")
	if lines.size() <= max_lines:
		return desc
	var kept: PackedStringArray = []
	for i in range(max_lines):
		kept.append(lines[i])
	return "\n".join(kept)

func _fit_name_font() -> void:
	if not name_label:
		return
	var base := NAME_FONT_COMPACT if display_mode == DisplayMode.COMPACT else NAME_FONT_FULL
	var n := name_label.text.length()
	var size := base
	if n > 16:
		size = maxi(base - 2, 13)
	if n > 22:
		size = maxi(base - 4, 12)
	name_label.add_theme_font_size_override("font_size", size)

func _apply_description_font(line_count: int) -> void:
	if not description_label:
		return
	var font_size := DESC_FONT_COMFORTABLE if line_count <= 3 else DESC_FONT_DENSE
	description_label.add_theme_font_size_override("normal_font_size", font_size)
	description_label.add_theme_font_size_override("bold_font_size", font_size)

func update_display():
	if not _ui_nodes_ready or not card_data:
		return

	name_label.text = card_data.get_localized_name()
	_fit_name_font()
	cost_label.text = str(card_data.cost)

	var desc := card_data.get_display_description()
	var max_lines := DESC_MAX_LINES_COMPACT if display_mode == DisplayMode.COMPACT else DESC_MAX_LINES_FULL
	desc = _clamp_description_lines(desc, max_lines)
	var line_count := 0 if desc.is_empty() else desc.split("\n").size()
	_apply_description_font(line_count)
	description_label.text = "[center]%s[/center]" % desc if not desc.is_empty() else ""

	if artwork_texture_rect and artwork_texture_rect.visible and card_data.artwork:
		artwork_texture_rect.texture = card_data.artwork

	if _usage_label and display_mode != DisplayMode.COMPACT:
		if card_data.max_uses_before_removal > 0:
			var used: int = 0
			if not Engine.is_editor_hint() and PlayerData:
				used = PlayerData.get_card_usage_count(card_data.card_id)
			_usage_label.text = "%d/%d" % [used, card_data.max_uses_before_removal]
			_usage_label.visible = true
		else:
			_usage_label.visible = false

	_update_rarity_colors()

func _update_rarity_colors():
	if not card_template or not card_data:
		return
	var rarity_colors = {
		CardData.CardRarity.BASIC: Color(0.9, 0.9, 0.9, 1.0),
		CardData.CardRarity.COMMON: Color(1.0, 1.0, 1.0, 1.0),
		CardData.CardRarity.UNCOMMON: Color(0.7, 1.0, 0.7, 1.0),
		CardData.CardRarity.RARE: Color(0.7, 0.7, 1.0, 1.0),
		CardData.CardRarity.EPIC: Color(1.0, 0.7, 1.0, 1.0),
		CardData.CardRarity.LEGENDARY: Color(1.0, 0.9, 0.5, 1.0)
	}
	if rarity_colors.has(card_data.rarity):
		card_template.modulate = rarity_colors[card_data.rarity]
	else:
		card_template.modulate = Color.WHITE

func load_card(new_card_data: CardData):
	self.card_data = new_card_data

func _process(delta):
	if static_layout:
		return
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_modulate_click_feedback()
			if not is_draggable:
				card_clicked.emit(card_data)
				accept_event()
				return
			_drag_released = false
			_start_drag()
		else:
			if is_draggable:
				_end_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			card_right_clicked.emit(card_data)
			if has_node("TooltipComponent"):
				get_node("TooltipComponent").show_tooltip()
			accept_event()

func _start_drag():
	is_dragging = true
	_drag_start_pos = global_position
	target_scale = original_scale * 0.75
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
