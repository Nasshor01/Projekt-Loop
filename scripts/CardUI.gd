# ===================================================================
# Soubor: res://scripts/CardUI.gd
# ===================================================================
class_name CardUI
extends Control

## Shop / editor face — CardUI.tscn source of truth (320×400).
const DESIGN_SIZE: Vector2 = Vector2(320, 400)
## Battle hand + reward/deck — native 1.0 in matching slots (no Control.scale of glyphs).
const HAND_SIZE: Vector2 = Vector2(240, 300)
## Shop card face — same as hand; ShopScene LayoutSlot must fit face+price (~240×350).
const SHOP_SIZE: Vector2 = Vector2(240, 300)

## How the card is presented. Data still comes from CardData (.tres).
enum DisplayMode {
	FULL,    ## Hand — HAND_SIZE @ 1.0
	SHOP,    ## Shop — SHOP_SIZE @ 1.0 (slot must not downscale)
	REWARD,  ## Reward — HAND_SIZE @ 1.0
	DECK,    ## Deck viewer — HAND_SIZE @ 1.0
	COMPACT, ## Tiny grid tile
}

const SCALE_HAND := Vector2(1.0, 1.0)
const SCALE_SHOP := Vector2(1.0, 1.0)
const SCALE_REWARD := Vector2(1.0, 1.0)
const SCALE_DECK := Vector2(1.0, 1.0)
const SCALE_COMPACT := Vector2(1.0, 1.0)
const COMPACT_SIZE := Vector2(280, 350)

## StS-style face: fixed text slot, clamp lines.
const DESC_MAX_LINES_FULL := 5
const DESC_MAX_LINES_COMPACT := 4
const DESC_DENSE_LINE_THRESHOLD := 3
const DESC_VERY_DENSE_LINE_THRESHOLD := 5
const DESC_DENSE_SHRINK := 0 ## Pixeloid: stay on 9px grid.
const DESC_VERY_DENSE_SHRINK := 0

## Hand / reward / deck (240×300 @ 1.0) — Pixeloid Sans @ 16 (~2px under 18).
const HAND_NAME_FONT := 16
const HAND_DESC_FONT := 16
const HAND_COST_FONT := 16
const HAND_USAGE_FONT := 16
const HAND_DESC_MIN := 16
const HAND_NAME_MIN := 16
const HAND_OUTLINE_NAME := 1
const HAND_OUTLINE_COST := 1
const HAND_OUTLINE_DESC := 0 ## dark ink on white panel
const HAND_OUTLINE_USAGE := 1
const HAND_LINE_SEP := 2
## Pixeloid: keep glyph spacing 0 on the 9px grid.
const NAME_GLYPH_SPACING := 0
const HAND_GLYPH_SPACING := 0

## Shop (240×300 @ 1.0) — match hand face metrics.
const SHOP_NAME_FONT := 16
const SHOP_DESC_FONT := 16
const SHOP_COST_FONT := 16
const SHOP_USAGE_FONT := 16
const SHOP_DESC_MIN := 16
const SHOP_NAME_MIN := 16
const SHOP_OUTLINE_NAME := 1
const SHOP_OUTLINE_COST := 1
const SHOP_OUTLINE_DESC := 0
const SHOP_OUTLINE_USAGE := 1
const SHOP_LINE_SEP := 2
const SHOP_GLYPH_SPACING := 0

## Dark body text on white description panel (RichTextLabel outline is flaky).
const DESC_BODY_COLOR := Color(0.12, 0.1, 0.08, 1)
## Curse frame is dark gray/red — need light ink (same idea as tooltip).
const DESC_BODY_COLOR_CURSE := Color(0.95, 0.92, 0.88, 1)
const NAME_COLOR_CURSE := Color(1.0, 0.55, 0.55, 1)
const COST_COLOR_CURSE := Color(1.0, 0.85, 0.85, 1)

## Compact face only.
const NAME_FONT_COMPACT := 16
const COST_FONT_SIZE := SHOP_COST_FONT ## legacy alias
const USAGE_FONT_SIZE := SHOP_USAGE_FONT
const DESC_FONT_MIN := SHOP_DESC_MIN
const NAME_FONT_MIN := SHOP_NAME_MIN
const DESC_LINE_SEP_NORMAL := SHOP_LINE_SEP
const DESC_LINE_SEP_DENSE := 0
const DESC_LINE_SEP_VERY_DENSE := -2

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
const COST_COLOR := Color(1.0, 0.95, 0.75, 1.0)
const USAGE_COLOR := Color(0.45, 0.28, 0.05, 1.0)
const PATH_SEAL_BADGE := "res://art/icons/artifact_fx/seal_badge.png"
const PATH_RETAIN_BADGE := "res://art/icons/artifact_fx/retain_badge.png"
const PATH_CARD_FONT := "res://art/fonts/PixeloidSans.ttf"
static var _frame_texture_cache: Dictionary = {}
static var _badge_texture_cache: Dictionary = {}
static var _card_font_spaced: Font = null
static var _card_font_name: Font = null
static var _card_font_path_cached: String = ""

@export var card_data: CardData:
	set(new_card_data):
		card_data = new_card_data
		if is_inside_tree() and _ui_nodes_ready:
			update_display()

@export var placeholder_artwork: Texture2D
@export var static_layout: bool = false
## Inspector defaults = shop face. Hand mode uses HAND_* constants (ignores these).
@export_range(8, 80, 1) var name_font_size: int = SHOP_NAME_FONT:
	set(value):
		name_font_size = value
		if is_inside_tree() and _ui_nodes_ready and card_data:
			update_display()
@export_range(8, 80, 1) var description_font_size: int = SHOP_DESC_FONT:
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
var _state_badge_row: HBoxContainer = null
var _seal_badge: TextureRect = null
var _retain_badge: TextureRect = null

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
var _drag_released: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_anchor_active: bool = false
var _drag_anchor_bottom_center: Vector2 = Vector2.ZERO
var _playability_tint: Color = Color.WHITE

const UNPLAYABLE_TINT := Color(0.5, 0.5, 0.55)
const NO_ENERGY_COST_TINT := Color(1.0, 0.35, 0.35)

signal drag_started(card_ui: CardUI, original_pos: Vector2)
signal drag_released(card_ui: CardUI, release_pos: Vector2)
signal card_clicked(card_data: CardData)
signal card_right_clicked(data: CardData)

func _ready():
	_ui_nodes_ready = true
	_usage_label = get_node_or_null("UsageLabel") as Label
	_ensure_state_badges()
	_cache_scene_layout()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_child_mouse_filters()
	target_position = position
	set_process(true)
	# Prefer apply_display_mode() from parent; default to hand face if already FULL.
	if display_mode == DisplayMode.FULL and not static_layout:
		_layout_full()
		_set_visual_scale(SCALE_HAND)
	else:
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

func _scale_rect(rect: Rect2, s: float) -> Rect2:
	return Rect2(rect.position * s, rect.size * s)

func _is_hand_face() -> bool:
	## Native small face (no LayoutSlot downscale) — hand, reward, deck.
	return display_mode == DisplayMode.FULL \
		or display_mode == DisplayMode.REWARD \
		or display_mode == DisplayMode.DECK

func _is_shop_face() -> bool:
	return display_mode == DisplayMode.SHOP

func _face_size() -> Vector2:
	if _is_hand_face():
		return HAND_SIZE
	if _is_shop_face():
		return SHOP_SIZE
	return DESIGN_SIZE

func _layout_scale_factor() -> float:
	## Map CardUI.tscn (DESIGN_SIZE) slots onto current face size.
	return _face_size().x / DESIGN_SIZE.x

func _restore_scene_layout() -> void:
	_cache_scene_layout()
	var s := _layout_scale_factor()
	_apply_rect(artwork_texture_rect, _scale_rect(_scene_art_rect, s))
	_apply_rect(name_label, _scale_rect(_scene_name_rect, s))
	_apply_rect(cost_label, _scale_rect(_scene_cost_rect, s))
	_apply_rect(description_label, _scale_rect(_scene_desc_rect, s))
	_apply_rect(_usage_label, _scale_rect(_scene_usage_rect, s))
	_update_badge_row_layout()

func _update_badge_row_layout() -> void:
	if not is_instance_valid(_state_badge_row):
		return
	var s := _layout_scale_factor()
	_state_badge_row.offset_left = -120.0 * s
	_state_badge_row.offset_top = 47.0 * s
	_state_badge_row.offset_right = -10.0 * s
	_state_badge_row.offset_bottom = 87.0 * s

func _name_font_base() -> int:
	if display_mode == DisplayMode.COMPACT:
		return NAME_FONT_COMPACT
	if _is_hand_face():
		return HAND_NAME_FONT
	if _is_shop_face():
		return SHOP_NAME_FONT
	return name_font_size if name_font_size > 0 else SHOP_NAME_FONT

func _desc_font_base() -> int:
	if _is_hand_face():
		return HAND_DESC_FONT
	if _is_shop_face():
		return SHOP_DESC_FONT
	return description_font_size if description_font_size > 0 else SHOP_DESC_FONT

func _desc_font_min() -> int:
	if _is_hand_face():
		return HAND_DESC_MIN
	return SHOP_DESC_MIN

func _name_font_min() -> int:
	if _is_hand_face():
		return HAND_NAME_MIN
	return SHOP_NAME_MIN

func _cost_font_size() -> int:
	if _is_hand_face():
		return HAND_COST_FONT
	return SHOP_COST_FONT

func _usage_font_size() -> int:
	if _is_hand_face():
		return HAND_USAGE_FONT
	return SHOP_USAGE_FONT

func _outline_name() -> int:
	if _is_hand_face():
		return HAND_OUTLINE_NAME
	return SHOP_OUTLINE_NAME

func _outline_cost() -> int:
	if _is_hand_face():
		return HAND_OUTLINE_COST
	return SHOP_OUTLINE_COST

func _outline_desc() -> int:
	if _is_curse_card():
		return 3
	if _is_hand_face():
		return HAND_OUTLINE_DESC
	return SHOP_OUTLINE_DESC

func _outline_usage() -> int:
	if _is_hand_face():
		return HAND_OUTLINE_USAGE
	return SHOP_OUTLINE_USAGE

func _line_sep_normal() -> int:
	if _is_hand_face():
		return HAND_LINE_SEP
	return SHOP_LINE_SEP

func _glyph_spacing() -> int:
	return HAND_GLYPH_SPACING if _is_hand_face() else SHOP_GLYPH_SPACING

func _get_card_font_spaced() -> Font:
	## Body / cost / usage — plain Ithaca (same as tooltip).
	if _card_font_spaced != null and _card_font_path_cached == PATH_CARD_FONT:
		return _card_font_spaced
	var base := load(PATH_CARD_FONT) as Font
	if base == null:
		return null
	_card_font_spaced = base
	_card_font_path_cached = PATH_CARD_FONT
	_card_font_name = null ## force rebuild name variant when base path changes
	return _card_font_spaced

func _get_card_font_name() -> Font:
	## Titles only — positive glyph spacing = letters farther apart.
	## Rebuild each apply so Inspector/hot-reload picks up NAME_GLYPH_SPACING changes.
	var base := _get_card_font_spaced()
	if base == null:
		return null
	if _card_font_name != null and _card_font_path_cached == PATH_CARD_FONT:
		if _card_font_name is FontVariation:
			(_card_font_name as FontVariation).set_spacing(TextServer.SPACING_GLYPH, NAME_GLYPH_SPACING)
			return _card_font_name
	var fv := FontVariation.new()
	fv.base_font = base
	fv.set_spacing(TextServer.SPACING_GLYPH, NAME_GLYPH_SPACING)
	_card_font_name = fv
	return _card_font_name

func _apply_card_font_to_labels() -> void:
	var body := _get_card_font_spaced()
	var title := _get_card_font_name()
	if body == null:
		return
	if name_label:
		name_label.add_theme_font_override("font", title if title else body)
	if cost_label:
		cost_label.add_theme_font_override("font", body)
	if _usage_label:
		_usage_label.add_theme_font_override("font", body)
	if description_label:
		description_label.add_theme_font_override("normal_font", body)
		description_label.add_theme_font_override("bold_font", body)
		description_label.add_theme_font_override("italics_font", body)
		description_label.add_theme_font_override("bold_italics_font", body)
		description_label.add_theme_font_override("mono_font", body)

func _apply_readability_theme() -> void:
	_apply_card_font_to_labels()
	clip_contents = false
	if description_label:
		description_label.fit_content = false
		description_label.scroll_active = false
		description_label.clip_contents = false
		description_label.bbcode_enabled = false
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.add_theme_color_override("default_color", _face_body_color())
		description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		description_label.add_theme_constant_override("outline_size", _outline_desc())
	if name_label:
		name_label.clip_text = true
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		name_label.add_theme_constant_override("outline_size", _outline_name())
		name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		name_label.add_theme_constant_override("shadow_offset_x", 1)
		name_label.add_theme_constant_override("shadow_offset_y", 1)
		name_label.add_theme_constant_override("shadow_outline_size", 2)
	if cost_label:
		cost_label.clip_text = true
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.add_theme_color_override("font_color", _face_cost_color())
		cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		cost_label.add_theme_constant_override("outline_size", _outline_cost())
		cost_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		cost_label.add_theme_constant_override("shadow_offset_x", 1)
		cost_label.add_theme_constant_override("shadow_offset_y", 1)
	if _usage_label:
		_usage_label.add_theme_color_override("font_color", USAGE_COLOR)
		_usage_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_usage_label.add_theme_constant_override("outline_size", _outline_usage())
		_usage_label.add_theme_font_size_override("font_size", _usage_font_size())

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

func get_layout_natural_size() -> Vector2:
	## LayoutSlot must fit the active face, not always DESIGN_SIZE (320×400).
	if custom_minimum_size.x > 1.0 and custom_minimum_size.y > 1.0:
		return custom_minimum_size
	return _face_size()

func _set_visual_scale(s: Vector2) -> void:
	original_scale = s
	base_scale = s
	target_scale = s
	scale = s

func _layout_full() -> void:
	"""Full face: shop/hand use SHOP_SIZE / HAND_SIZE with scaled scene slots @ scale 1.0."""
	var face := _face_size()
	custom_minimum_size = face
	size = face
	if card_template:
		card_template.custom_minimum_size = face
		card_template.size = face
		card_template.visible = true
	if artwork_texture_rect:
		artwork_texture_rect.visible = true
	if name_label:
		name_label.add_theme_font_size_override("font_size", _name_font_base())
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if cost_label:
		cost_label.add_theme_font_size_override("font_size", _cost_font_size())
	if description_label:
		description_label.visible = true
	_restore_scene_layout()
	_apply_readability_theme()

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
		cost_label.position = Vector2(110, 7)
		cost_label.size = Vector2(60, 60)
		cost_label.add_theme_font_size_override("font_size", COST_FONT_SIZE)
	if name_label:
		name_label.position = Vector2(27, 87)
		name_label.size = Vector2(227, 67)
		name_label.add_theme_font_size_override("font_size", NAME_FONT_COMPACT)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if description_label:
		description_label.visible = true
		description_label.position = Vector2(27, 167)
		description_label.size = Vector2(227, 160)
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

func _is_verbal_keyword_face_line(line: String) -> bool:
	"""True for keyword-only lines (Holy / Exhaust), not N+icon effect lines."""
	var s := line.strip_edges()
	if s.is_empty() or s.contains("[img"):
		return false
	# Strip face BBCode wrappers for matching.
	s = s.replace("[b]", "").replace("[/b]", "")
	var color_re := RegEx.new()
	color_re.compile("\\[/?color(?:=[^\\]]*)?\\]")
	s = color_re.sub(s, "", true).strip_edges()
	return s in ["Holy", "Svaté", "Exhaust", "Vyčerpání", "Retain", "Ponechání", "Vulnerable", "Zranitelnost", "Poison", "Jed", "Block", "Blok"]

func _pack_face_description(desc: String, max_lines: int) -> String:
	"""Pack trailing verbal keywords onto one line (Holy · Exhaust) so 5-effect cards fit."""
	if desc.is_empty():
		return desc
	var lines: PackedStringArray = desc.split("\n")
	if lines.size() <= max_lines:
		return desc
	# Collect trailing keyword-only lines.
	var verbal_start := lines.size()
	while verbal_start > 0 and _is_verbal_keyword_face_line(lines[verbal_start - 1]):
		verbal_start -= 1
	if verbal_start >= lines.size() or verbal_start == 0:
		return _clamp_description_lines(desc, max_lines)
	var head: PackedStringArray = lines.slice(0, verbal_start)
	var verbal: PackedStringArray = lines.slice(verbal_start, lines.size())
	var packed_verbal := " · ".join(verbal)
	var packed: PackedStringArray = []
	packed.append_array(head)
	packed.append(packed_verbal)
	if packed.size() <= max_lines:
		return "\n".join(packed)
	return _clamp_description_lines("\n".join(packed), max_lines)

func _fit_name_font() -> void:
	if not name_label:
		return
	var base := _name_font_base()
	var min_sz := _name_font_min()
	var name_size := base
	var n := name_label.text.length()
	# Longer titles (Impenetrable Shield…) need more shrink than short ones.
	if n > 11:
		name_size = maxi(base - 1, min_sz)
	if n > 14:
		name_size = maxi(base - 2, min_sz)
	if n > 17:
		name_size = maxi(base - 3, min_sz)
	if n > 20:
		name_size = maxi(base - 4, min_sz)
	name_label.add_theme_font_size_override("font_size", name_size)
	# Hard fit against banner width so long names never clip mid-glyph.
	var font: Font = name_label.get_theme_font("font")
	if font == null:
		return
	var max_w := name_label.size.x - 6.0
	if max_w < 8.0:
		return
	while name_size > min_sz:
		var text_w := font.get_string_size(
			name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size
		).x
		if text_w <= max_w:
			break
		name_size -= 1
	name_label.add_theme_font_size_override("font_size", name_size)

func _apply_description_font(line_count: int) -> int:
	"""Effective face font size — hand uses HAND_DESC_*; shop uses export / SHOP_*."""
	var base := _desc_font_base()
	var min_sz := _desc_font_min()
	var font_size := base
	if line_count >= DESC_VERY_DENSE_LINE_THRESHOLD:
		font_size = maxi(base - DESC_VERY_DENSE_SHRINK, min_sz)
	elif line_count > DESC_DENSE_LINE_THRESHOLD:
		font_size = maxi(base - DESC_DENSE_SHRINK, min_sz)
	return font_size

func _description_icon_px(font_size: int) -> int:
	"""BBCode [img] height ≈ glyph height so number + icon stay on one line."""
	return maxi(font_size, _desc_font_min())

func _set_description_text(desc: String, font_size: int) -> void:
	"""Render face description via push_font + add_text/add_image."""
	if not description_label:
		return
	description_label.bbcode_enabled = false
	description_label.fit_content = false
	description_label.scroll_active = false
	description_label.clip_contents = false
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_color_override("default_color", _face_body_color())
	description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description_label.add_theme_constant_override("outline_size", _outline_desc())
	description_label.add_theme_font_size_override("normal_font_size", font_size)
	description_label.add_theme_font_size_override("bold_font_size", font_size)
	description_label.add_theme_font_size_override("italics_font_size", font_size)
	description_label.add_theme_font_size_override("bold_italics_font_size", font_size)
	description_label.add_theme_font_size_override("mono_font_size", font_size)

	var lines: PackedStringArray = PackedStringArray() if desc.is_empty() else desc.split("\n")
	var line_count := lines.size()
	var sep := _line_sep_normal()
	if line_count >= DESC_VERY_DENSE_LINE_THRESHOLD:
		sep = DESC_LINE_SEP_VERY_DENSE
	elif line_count >= DESC_DENSE_LINE_THRESHOLD:
		sep = DESC_LINE_SEP_DENSE
	description_label.add_theme_constant_override("line_separation", sep)

	var font: Font = description_label.get_theme_font("normal_font")
	description_label.clear()
	if font:
		description_label.push_font(font, font_size)
	else:
		description_label.push_font_size(font_size)
	# Dark ink on white panel; light ink on curse frame.
	description_label.push_color(_face_body_color())

	if desc.is_empty():
		return

	for i in range(lines.size()):
		if i > 0:
			description_label.newline()
		_append_description_line(lines[i], font_size)

func _strip_face_bold_tags(line: String) -> String:
	"""Remove [b][/b] without touching [/img] (plain replace of [/b] is fine; keep explicit)."""
	var re := RegEx.new()
	re.compile("\\[/?b\\]")
	return re.sub(line, "", true)

func _append_description_line(line: String, font_size: int) -> void:
	"""Split plain text / [color] / [img] into add_text / add_image calls (no size tags)."""
	var s := _strip_face_bold_tags(line)
	var img_re := RegEx.new()
	# Accept normal [/img] and broken [/] left by BBCode engine in older sessions.
	img_re.compile("\\[img=(\\d+)x(\\d+)\\]([^\\[]+)\\[/(?:img)?\\]")
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
				var path := match_m.get_string(3).strip_edges()
				var tex: Texture2D = null
				if ResourceLoader.exists(path):
					tex = load(path) as Texture2D
				if tex:
					description_label.add_image(tex, font_size, font_size)
				# Never dump raw [img] paths onto the face if load fails.
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
	cost_label.text = "—" if card_data.is_unplayable() else str(_display_energy_cost())

	# Pack keyword lines first, then scale icons to the dense font size.
	var max_lines := DESC_MAX_LINES_COMPACT if display_mode == DisplayMode.COMPACT else DESC_MAX_LINES_FULL
	var desc_for_lines := _pack_face_description(card_data.get_display_description(), max_lines)
	var line_count := 0 if desc_for_lines.is_empty() else desc_for_lines.split("\n").size()
	var font_size := _apply_description_font(line_count)
	var icon_px := _description_icon_px(font_size)
	var desc := _pack_face_description(card_data.get_display_description(icon_px), max_lines)
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

	_update_state_badges()
	_update_card_frame()

func _ensure_state_badges() -> void:
	if is_instance_valid(_state_badge_row):
		return
	_state_badge_row = HBoxContainer.new()
	_state_badge_row.name = "StateBadgeRow"
	_state_badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_badge_row.alignment = BoxContainer.ALIGNMENT_END
	_state_badge_row.add_theme_constant_override("separation", 3)
	_state_badge_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_state_badge_row.offset_left = -120
	_state_badge_row.offset_top = 47
	_state_badge_row.offset_right = -10
	_state_badge_row.offset_bottom = 87
	add_child(_state_badge_row)
	_seal_badge = _make_badge_icon(PATH_SEAL_BADGE)
	_retain_badge = _make_badge_icon(PATH_RETAIN_BADGE)
	_state_badge_row.add_child(_seal_badge)
	_state_badge_row.add_child(_retain_badge)

func _make_badge_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	if not _badge_texture_cache.has(path):
		_badge_texture_cache[path] = load(path) as Texture2D
	icon.texture = _badge_texture_cache.get(path)
	icon.custom_minimum_size = Vector2(37, 37)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	return icon

func _update_state_badges() -> void:
	_ensure_state_badges()
	if display_mode == DisplayMode.COMPACT or card_data == null:
		_state_badge_row.visible = false
		return
	_state_badge_row.visible = true
	var sealed := false
	var retain := false
	if not Engine.is_editor_hint() and has_node("/root/ArtifactManager"):
		sealed = ArtifactManager.is_card_sealed(card_data)
		retain = ArtifactManager.card_has_retain(card_data)
	else:
		retain = card_data.has_meta("artifact_retain") and bool(card_data.get_meta("artifact_retain"))
	_seal_badge.visible = sealed
	_retain_badge.visible = retain

func _display_energy_cost() -> int:
	if not card_data:
		return 0
	if Engine.is_editor_hint():
		return card_data.cost
	if has_node("/root/ArtifactManager"):
		return ArtifactManager.get_card_cost(card_data)
	return card_data.cost

func _is_curse_card() -> bool:
	if not card_data:
		return false
	return "curse" in card_data.card_id.to_lower()


func _face_body_color() -> Color:
	return DESC_BODY_COLOR_CURSE if _is_curse_card() else DESC_BODY_COLOR


func _face_name_color() -> Color:
	if _is_curse_card():
		return NAME_COLOR_CURSE
	if card_data and card_data.is_upgraded:
		return NAME_COLOR_UPGRADED
	return NAME_COLOR_NORMAL


func _face_cost_color() -> Color:
	return COST_COLOR_CURSE if _is_curse_card() else COST_COLOR

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
	name_label.add_theme_color_override("font_color", _face_name_color())

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
		if _drag_anchor_active:
			target_global_pos = _drag_anchor_bottom_center - Vector2(visual_size.x * 0.5, visual_size.y)
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

## While dragging, park the card (bottom-center at [param bottom_center], global) instead of following the mouse.
func set_drag_anchor(bottom_center: Vector2) -> void:
	_drag_anchor_bottom_center = bottom_center
	_drag_anchor_active = true

func clear_drag_anchor() -> void:
	_drag_anchor_active = false

func has_drag_anchor() -> bool:
	return _drag_anchor_active

func _end_drag():
	_drag_anchor_active = false
	if is_dragging:
		is_dragging = false
		target_scale = base_scale
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		_drag_released = true
		drag_released.emit(self, global_position)

func cancel_drag():
	_drag_anchor_active = false
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
		_apply_playability_modulate()

## Dims the card face when it can't be played right now; [param reason] matches BattleScene._evaluate_card_playability.
func set_playability_visual(playable: bool, reason: String = "") -> void:
	_playability_tint = Color.WHITE if playable else UNPLAYABLE_TINT
	_apply_playability_modulate()
	if is_instance_valid(cost_label):
		cost_label.self_modulate = NO_ENERGY_COST_TINT if (not playable and reason == "energy") else Color.WHITE

func _apply_playability_modulate() -> void:
	modulate = Color(_playability_tint, 0.8 if is_dragging else 1.0)
