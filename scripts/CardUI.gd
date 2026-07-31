# ===================================================================
# Soubor: res://scripts/CardUI.gd
# ===================================================================
class_name CardUI
extends Control

## Design size in CardUI.tscn — contexts scale from this, don't crush below ~0.8 for readable text.
## Warrior frames are 64×80 → displayed at 3× = 192×240.
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

## StS-style face: fixed text slot, clamp lines.
## Name + description sizes: edit @export on CardUI root (not child Theme Overrides).
const DESC_MAX_LINES_FULL := 4
const DESC_MAX_LINES_COMPACT := 3
## After packing, shrink only if still very tall (never below 10). Prefer spacing over font.
const DESC_DENSE_LINE_THRESHOLD := 3
const DESC_DENSE_SHRINK := 1
const DESC_FONT_MIN := 10
const DESC_LINE_SEP_NORMAL := 2
const DESC_LINE_SEP_DENSE := 0
const COST_FONT_SIZE := 22
## Compact face only — full face uses name_font_size export.
const NAME_FONT_COMPACT := 14
const NAME_FONT_MIN := 10
const USAGE_FONT_SIZE := 12

## Modular Warrior frames by rarity (curses use curse.png).
## Live set: Basic / Common / Rare / Epic / Legendary. Uncommon cancelled.
const FRAME_CURSE_PATH := "res://art/sprites/cards/warrior/curse.png"
const FRAME_PATHS := {
	CardData.CardRarity.BASIC: "res://art/sprites/cards/warrior/Warrior basic.png",
	CardData.CardRarity.COMMON: "res://art/sprites/cards/warrior/Warrior common.png",
	CardData.CardRarity.UNCOMMON: "res://art/sprites/cards/warrior/Warrior common.png", ## deprecated
	CardData.CardRarity.RARE: "res://art/sprites/cards/warrior/Warrior rare.png",
	CardData.CardRarity.EPIC: "res://art/sprites/cards/warrior/Warrior epic.png",
	CardData.CardRarity.LEGENDARY: "res://art/sprites/cards/warrior/Warrior legendary.png",
}
const NAME_COLOR_NORMAL := Color(1, 1, 1, 1)
const NAME_COLOR_UPGRADED := Color(0.45, 1.0, 0.45, 1)
## Name/cost keep stronger outline (sit on colored banner/orb).
## Description outline comes from DescriptionLabel in CardUI.tscn — do not hardcode here.
const OUTLINE_NAME := 6
const OUTLINE_COST := 6
const OUTLINE_USAGE := 4
## Cost sits on blue energy orb — cream is fine there.
const COST_COLOR := Color(1.0, 0.95, 0.75, 1.0)
## Usage badge on frame edge — avoid pure yellow; use dark amber.
const USAGE_COLOR := Color(0.45, 0.28, 0.05, 1.0)
static var _frame_texture_cache: Dictionary = {}

@export var card_data: CardData:
	set(new_card_data):
		card_data = new_card_data
		if is_inside_tree() and _ui_nodes_ready:
			update_display()

@export var placeholder_artwork: Texture2D
@export var static_layout: bool = false
## Font sizes: CardUI ROOT in Inspector. Outline/colors: DescriptionLabel Theme Overrides (script does not overwrite them).
@export_range(8, 48, 1) var name_font_size: int = 22:
	set(value):
		name_font_size = value
		if is_inside_tree() and _ui_nodes_ready and card_data:
			update_display()
@export_range(8, 48, 1) var description_font_size: int = 24:
	set(value):
		description_font_size = value
		if is_inside_tree() and _ui_nodes_ready and card_data:
			update_display()

var display_mode: DisplayMode = DisplayMode.FULL
var initial_scale: Vector2 = Vector2.ZERO

var _ui_nodes_ready = false
@onready var artwork_texture_rect: TextureRect = $ArtworkTextureRect
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var description_label: RichTextLabel = $DescriptionLabel
@onready var card_template: TextureRect = $CardTemplateImage
var _usage_label: Label = null

## Scene (CardUI.tscn) slots — never hardcode full-face positions in code.
var _scene_art_rect: Rect2
var _scene_name_rect: Rect2
var _scene_cost_rect: Rect2
var _scene_desc_rect: Rect2
var _scene_usage_rect: Rect2
var _scene_layout_cached: bool = false

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
	_cache_scene_layout()
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
	_restore_scene_layout()
	if card_data:
		update_display()

	if static_layout:
		target_position = position
		target_scale = scale

func _cache_scene_layout() -> void:
	"""Remember editor positions from CardUI.tscn so code never fights the scene.
	Only mark cached when UI nodes are ready — apply_display_mode before add_child must not lock empty rects."""
	if _scene_layout_cached:
		return
	if description_label == null:
		return
	if artwork_texture_rect:
		_scene_art_rect = Rect2(artwork_texture_rect.position, artwork_texture_rect.size)
	if name_label:
		_scene_name_rect = Rect2(name_label.position, name_label.size)
	if cost_label:
		_scene_cost_rect = Rect2(cost_label.position, cost_label.size)
	_scene_desc_rect = Rect2(description_label.position, description_label.size)
	if _usage_label:
		_scene_usage_rect = Rect2(_usage_label.position, _usage_label.size)
	_scene_layout_cached = true

func _apply_rect(node: Control, rect: Rect2) -> void:
	if node == null or rect.size == Vector2.ZERO:
		return
	node.position = rect.position
	node.size = rect.size

func _restore_scene_layout() -> void:
	_cache_scene_layout()
	_apply_rect(artwork_texture_rect, _scene_art_rect)
	_apply_rect(name_label, _scene_name_rect)
	_apply_rect(cost_label, _scene_cost_rect)
	_apply_rect(description_label, _scene_desc_rect)
	_apply_rect(_usage_label, _scene_usage_rect)

func _apply_readability_theme() -> void:
	if description_label:
		# Keep text inside the fixed face slot (fit_content grows past the frame).
		description_label.fit_content = false
		description_label.scroll_active = false
		description_label.clip_contents = true
		description_label.bbcode_enabled = true
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Do NOT override outline_size / font_outline_color — use DescriptionLabel from CardUI.tscn.
		var desc_font := description_label.get_theme_font("normal_font")
		if desc_font:
			description_label.add_theme_font_override("bold_font", desc_font)
			description_label.add_theme_font_override("italics_font", desc_font)
			description_label.add_theme_font_override("bold_italics_font", desc_font)
			description_label.add_theme_font_override("mono_font", desc_font)
		# horizontal/vertical_alignment: leave DescriptionLabel values from CardUI.tscn
	if name_label:
		name_label.clip_text = true
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("outline_size", OUTLINE_NAME)
	if cost_label:
		# Fixed gem slot: always centered, never wraps.
		cost_label.clip_text = true
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.add_theme_color_override("font_color", COST_COLOR)
		cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		cost_label.add_theme_constant_override("outline_size", OUTLINE_COST)
	if _usage_label:
		_usage_label.add_theme_color_override("font_color", USAGE_COLOR)
		_usage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_usage_label.add_theme_constant_override("outline_size", OUTLINE_USAGE)
		_usage_label.add_theme_font_size_override("font_size", USAGE_FONT_SIZE)

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
	"""Full face uses ONLY positions from CardUI.tscn — edit the scene, not this script."""
	custom_minimum_size = DESIGN_SIZE
	size = DESIGN_SIZE
	if card_template:
		card_template.custom_minimum_size = DESIGN_SIZE
		card_template.size = DESIGN_SIZE
		card_template.visible = true
	if artwork_texture_rect:
		artwork_texture_rect.visible = true
	if name_label:
		name_label.add_theme_font_size_override("font_size", name_font_size)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if cost_label:
		cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	if description_label:
		description_label.visible = true
	_restore_scene_layout()

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
	# Compact is a different face — keep local overrides; full mode uses scene.
	if cost_label:
		cost_label.position = Vector2(66, 4)
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
	var base := NAME_FONT_COMPACT if display_mode == DisplayMode.COMPACT else name_font_size
	var n := name_label.text.length()
	var size := base
	if n > 16:
		size = maxi(base - 2, NAME_FONT_MIN + 1)
	if n > 22:
		size = maxi(base - 4, NAME_FONT_MIN)
	name_label.add_theme_font_size_override("font_size", size)

func _apply_description_font(line_count: int) -> int:
	"""Effective face font size from description_font_size export (dense: −1)."""
	var font_size := description_font_size
	if line_count > DESC_DENSE_LINE_THRESHOLD:
		font_size = maxi(description_font_size - DESC_DENSE_SHRINK, DESC_FONT_MIN)
	return font_size

func _description_icon_px(font_size: int) -> int:
	"""BBCode [img] height ≈ glyph height so number + icon stay on one line."""
	return maxi(font_size, DESC_FONT_MIN)

func _set_description_text(desc: String, font_size: int) -> void:
	"""Render face description via push_font + add_text/add_image.
	Outline / colors from DescriptionLabel in CardUI.tscn; dense cards tighten line_separation."""
	if not description_label:
		return
	description_label.bbcode_enabled = true
	description_label.fit_content = false
	description_label.scroll_active = false
	description_label.clip_contents = true
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("normal_font_size", font_size)
	description_label.add_theme_font_size_override("bold_font_size", font_size)
	description_label.add_theme_font_size_override("italics_font_size", font_size)
	description_label.add_theme_font_size_override("bold_italics_font_size", font_size)
	description_label.add_theme_font_size_override("mono_font_size", font_size)

	var lines: PackedStringArray = [] if desc.is_empty() else desc.split("\n")
	var line_count := lines.size()
	var sep := DESC_LINE_SEP_DENSE if line_count >= DESC_DENSE_LINE_THRESHOLD else DESC_LINE_SEP_NORMAL
	description_label.add_theme_constant_override("line_separation", sep)

	var font: Font = description_label.get_theme_font("normal_font")
	description_label.clear()
	if font:
		description_label.push_font(font, font_size)
	else:
		description_label.push_font_size(font_size)

	if desc.is_empty():
		return

	for i in range(lines.size()):
		if i > 0:
			description_label.newline()
		_append_description_line(lines[i], font_size)

func _append_description_line(line: String, font_size: int) -> void:
	"""Split plain text / [color] / [img] into add_text / add_image calls (no size tags)."""
	# Strip [b][/b] — bold was fighting font size; outline carries weight.
	var s := line.replace("[b]", "").replace("[/b]", "")
	var img_re := RegEx.new()
	img_re.compile("\\[img=(\\d+)x(\\d+)\\]([^\\[]+)\\[/img\\]")
	var color_open_re := RegEx.new()
	color_open_re.compile("\\[color=([^\\]]+)\\]")
	var color_close_re := RegEx.new()
	color_close_re.compile("\\[/color\\]")

	var pos := 0
	var color_depth := 0
	while pos < s.length():
		var img_m := img_re.search(s, pos)
		var col_open := color_open_re.search(s, pos)
		var col_close := color_close_re.search(s, pos)

		var next_start := s.length()
		var kind := ""
		var match_m: RegExMatch = null
		if img_m and img_m.get_start() < next_start:
			next_start = img_m.get_start()
			kind = "img"
			match_m = img_m
		if col_open and col_open.get_start() < next_start:
			next_start = col_open.get_start()
			kind = "color_open"
			match_m = col_open
		if col_close and col_close.get_start() < next_start:
			next_start = col_close.get_start()
			kind = "color_close"
			match_m = col_close

		if kind.is_empty():
			var rest := s.substr(pos)
			if not rest.is_empty():
				description_label.add_text(rest)
			break

		if next_start > pos:
			description_label.add_text(s.substr(pos, next_start - pos))

		match kind:
			"img":
				var path := match_m.get_string(3)
				var tex: Texture2D = null
				if ResourceLoader.exists(path):
					tex = load(path) as Texture2D
				if tex:
					description_label.add_image(tex, font_size, font_size)
				pos = match_m.get_end()
			"color_open":
				var hex := match_m.get_string(1).strip_edges()
				var c := Color.WHITE
				if hex.begins_with("#") and hex.length() >= 7:
					c = Color(hex)
				description_label.push_color(c)
				color_depth += 1
				pos = match_m.get_end()
			"color_close":
				if color_depth > 0:
					description_label.pop()
					color_depth -= 1
				pos = match_m.get_end()
			_:
				pos = match_m.get_end()


func update_display():
	if not _ui_nodes_ready or not card_data:
		return

	name_label.text = card_data.get_localized_name()
	_fit_name_font()
	_apply_upgrade_name_style()
	cost_label.text = str(card_data.cost)

	# Line count is independent of icon px — generate once for density, then again with scaled icons.
	var max_lines := DESC_MAX_LINES_COMPACT if display_mode == DisplayMode.COMPACT else DESC_MAX_LINES_FULL
	var desc_for_lines := _clamp_description_lines(card_data.get_display_description(), max_lines)
	var line_count := 0 if desc_for_lines.is_empty() else desc_for_lines.split("\n").size()
	var font_size := _apply_description_font(line_count)
	var icon_px := _description_icon_px(font_size)
	var desc := _clamp_description_lines(card_data.get_display_description(icon_px), max_lines)
	_set_description_text(desc, font_size)

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

	_update_card_frame()

func _is_curse_card() -> bool:
	if not card_data:
		return false
	return "curse" in card_data.card_id.to_lower()

func _frame_path_for_card() -> String:
	if _is_curse_card():
		return FRAME_CURSE_PATH
	if FRAME_PATHS.has(card_data.rarity):
		return FRAME_PATHS[card_data.rarity]
	return FRAME_PATHS[CardData.CardRarity.COMMON]

func _get_frame_texture(path: String) -> Texture2D:
	if _frame_texture_cache.has(path):
		return _frame_texture_cache[path]
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_frame_texture_cache[path] = tex
	return tex

func _update_card_frame():
	"""Swap baked rarity frame texture — no modulate tinting."""
	if not card_template or not card_data:
		return
	card_template.modulate = Color.WHITE
	card_template.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := _get_frame_texture(_frame_path_for_card())
	if tex:
		card_template.texture = tex
		card_template.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_template.stretch_mode = TextureRect.STRETCH_SCALE

func _apply_upgrade_name_style() -> void:
	if not name_label or not card_data:
		return
	if card_data.is_upgraded:
		name_label.add_theme_color_override("font_color", NAME_COLOR_UPGRADED)
	else:
		name_label.add_theme_color_override("font_color", NAME_COLOR_NORMAL)

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
