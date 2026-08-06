@tool
extends Control
class_name LayoutSlot

## Place-slot: drag to move, set slot_size in Inspector to resize (don't fight Scale tool).
## Runtime: content scales to this Control's size.

enum SlotKind { CARD, ARTIFACT, SHOP_ITEM }

## Suggested sizes (natural card = HAND 240×300):
##   Reward card → HAND_SIZE
##   Shop card+price → 240×350
##   Artifact icon → 72×72
const SUGGESTED_CARD := Vector2(240, 300)
const SUGGESTED_SHOP := Vector2(240, 350)
const SUGGESTED_ARTIFACT := Vector2(72, 72)

@export var slot_kind: SlotKind = SlotKind.CARD:
	set(value):
		slot_kind = value
		_refresh_preview()

@export var preview_label: String = "Slot":
	set(value):
		preview_label = value
		_refresh_preview()

## Edit THIS in Inspector to change size. Avoid Scale tool (S) — it blows up Controls.
@export var slot_size: Vector2 = Vector2(134, 168):
	set(value):
		var v := Vector2(clampf(value.x, 24.0, 800.0), clampf(value.y, 24.0, 800.0))
		if slot_size.is_equal_approx(v):
			return
		slot_size = v
		if _updating:
			return
		_apply_slot_size_to_control()

@export var uniform_fit: bool = true

var _preview: ColorRect
var _label: Label
var _mounted: Control = null
var _updating: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Tiny minimum so editor resize handles can shrink freely.
	custom_minimum_size = Vector2(24, 24)
	_cache_preview_nodes()
	_sync_slot_size_from_control()
	_refresh_preview()
	if not Engine.is_editor_hint():
		_hide_preview()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)


func _on_resized() -> void:
	if _updating:
		return
	# Guard against editor Scale-tool meltdown.
	if size.x > 900.0 or size.y > 900.0 or size.x < 8.0 or size.y < 8.0:
		return
	_updating = true
	slot_size = size
	_updating = false
	if is_instance_valid(_mounted):
		fit_mounted()


func _sync_slot_size_from_control() -> void:
	if size.x >= 24.0 and size.y >= 24.0 and size.x <= 900.0 and size.y <= 900.0:
		_updating = true
		slot_size = size
		_updating = false


func _apply_slot_size_to_control() -> void:
	_updating = true
	custom_minimum_size = Vector2(24, 24)
	# Keep top-left, change width/height via offsets (stable in editor).
	offset_right = offset_left + slot_size.x
	offset_bottom = offset_top + slot_size.y
	size = slot_size
	_updating = false


func _cache_preview_nodes() -> void:
	_preview = get_node_or_null("Preview") as ColorRect
	_label = get_node_or_null("PreviewLabel") as Label
	if _preview:
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _label:
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _refresh_preview() -> void:
	if not is_inside_tree():
		return
	_cache_preview_nodes()
	if _preview == null:
		return
	var color := Color(0.25, 0.7, 1.0, 0.3)
	match slot_kind:
		SlotKind.CARD:
			color = Color(0.25, 0.7, 1.0, 0.3)
		SlotKind.ARTIFACT:
			color = Color(1.0, 0.75, 0.2, 0.35)
		SlotKind.SHOP_ITEM:
			color = Color(0.4, 0.9, 0.45, 0.3)
	_preview.color = color
	if _label:
		_label.text = preview_label
		_label.add_theme_font_size_override("font_size", 20)
		_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("outline_size", 3)
	if Engine.is_editor_hint():
		_preview.visible = true
		if _label:
			_label.visible = true
	else:
		_hide_preview()


func _hide_preview() -> void:
	if _preview:
		_preview.visible = false
	if _label:
		_label.visible = false


func clear_mounted() -> void:
	if is_instance_valid(_mounted):
		if _mounted.get_parent() == self:
			remove_child(_mounted)
		_mounted.queue_free()
	_mounted = null
	for child in get_children():
		if child.name == "Preview" or child.name == "PreviewLabel":
			continue
		if child == _preview or child == _label:
			continue
		child.queue_free()


func get_mounted() -> Control:
	return _mounted if is_instance_valid(_mounted) else null


func is_empty() -> bool:
	return get_mounted() == null


func mount(child: Control) -> void:
	clear_mounted()
	if not is_instance_valid(child):
		return
	add_child(child)
	_mounted = child
	call_deferred("fit_mounted")


func fit_mounted() -> void:
	if not is_instance_valid(_mounted):
		return
	var natural := _get_natural_size(_mounted)
	if natural.x < 1.0 or natural.y < 1.0:
		return
	var target := size
	if target.x < 1.0 or target.y < 1.0:
		target = slot_size
	var fit_scale: Vector2
	if uniform_fit:
		var s := minf(target.x / natural.x, target.y / natural.y)
		# Prefer exact 1.0 when nearly matching — avoids mushy non-integer glyph scale.
		if absf(s - 1.0) <= 0.04:
			s = 1.0
		elif absf(s - 0.5) <= 0.03:
			s = 0.5
		fit_scale = Vector2(s, s)
	else:
		fit_scale = Vector2(target.x / natural.x, target.y / natural.y)

	# Scale from top-left (no center pivot) so visual rect == mouse hitbox.
	_mounted.pivot_offset = Vector2.ZERO
	_mounted.scale = fit_scale
	_mounted.size = natural
	_mounted.custom_minimum_size = natural
	var drawn := natural * fit_scale
	_mounted.position = Vector2(
		(target.x - drawn.x) * 0.5,
		(target.y - drawn.y) * 0.5
	)

	if _mounted is CardUI:
		var card := _mounted as CardUI
		card.original_scale = fit_scale
		card.base_scale = fit_scale
		card.target_scale = fit_scale
	elif _mounted.has_method("set_slot_fit_scale"):
		_mounted.call("set_slot_fit_scale", fit_scale)


func _get_natural_size(node: Control) -> Vector2:
	if node.has_method("get_layout_natural_size"):
		var n: Variant = node.call("get_layout_natural_size")
		if n is Vector2 and (n as Vector2).x > 1.0 and (n as Vector2).y > 1.0:
			return n as Vector2
	if node is CardUI:
		var card := node as CardUI
		var face := card.custom_minimum_size
		if face.x > 1.0 and face.y > 1.0:
			return face
		return card.get_layout_natural_size()
	var ms := node.custom_minimum_size
	if ms.x > 1.0 and ms.y > 1.0:
		return ms
	if node.size.x > 1.0 and node.size.y > 1.0:
		return node.size
	return CardUI.HAND_SIZE
