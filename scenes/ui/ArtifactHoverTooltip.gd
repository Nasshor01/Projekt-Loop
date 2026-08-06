# Instant STS-style relic tooltip (no Godot tooltip delay).
# Also used for shop card hover tips (name + description).
class_name ArtifactHoverTooltip
extends PanelContainer

const MAX_WIDTH := 320.0
const MAX_WIDTH_LARGE := 440.0
const FONT_SIZE := 20
const FONT_SIZE_LARGE := 24
const MARGIN := 12.0
const VIEW_PAD := 8.0
const H_PAD := 12.0
const V_PAD := 10.0
const LAYER_NAME := "ArtifactHoverTooltipLayer"
const LAYER_Z := 128

static var instance: ArtifactHoverTooltip

var _label: RichTextLabel
var _show_token: int = 0
var _max_width: float = MAX_WIDTH


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	style.border_color = Color(0.75, 0.78, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = H_PAD
	style.content_margin_top = V_PAD
	style.content_margin_right = H_PAD
	style.content_margin_bottom = V_PAD
	add_theme_stylebox_override("panel", style)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.97, 1))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_apply_size_style(false)


static func ensure(tree: SceneTree) -> ArtifactHoverTooltip:
	if is_instance_valid(instance) and instance.is_inside_tree():
		return instance
	instance = ArtifactHoverTooltip.new()
	instance.name = "ArtifactHoverTooltip"
	# Must live on a CanvasLayer so coords match GlobalUI / shop UI under stretch + editor embed.
	var layer := tree.root.get_node_or_null(LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = LAYER_NAME
		layer.layer = LAYER_Z
		tree.root.add_child(layer)
	layer.add_child(instance)
	return instance


func show_for(text: String, anchor: Control, large: bool = false) -> void:
	if text.is_empty() or not is_instance_valid(anchor):
		hide_tip()
		return
	_apply_size_style(large)
	_set_tip_bbcode(text)
	visible = true
	_show_token += 1
	var token := _show_token
	await get_tree().process_frame
	if token != _show_token or not visible or not is_instance_valid(anchor):
		return
	reset_size()
	var tip_size := get_combined_minimum_size()
	tip_size.x = clampf(tip_size.x, 120.0, _max_width)
	tip_size.y = maxf(tip_size.y, 40.0)
	size = tip_size
	global_position = _clamp_near_anchor(anchor.get_global_rect(), tip_size)


func _apply_size_style(large: bool) -> void:
	_max_width = MAX_WIDTH_LARGE if large else MAX_WIDTH
	var font_size := FONT_SIZE_LARGE if large else FONT_SIZE
	if _label == null:
		return
	# Leave room for horizontal padding + 2px borders on each side.
	_label.custom_minimum_size = Vector2(_max_width - (H_PAD * 2.0 + 4.0), 0)
	_label.add_theme_font_size_override("normal_font_size", font_size)


func _set_tip_bbcode(text: String) -> void:
	var lines := text.split("\n", false)
	if lines.is_empty():
		_label.text = text
		return
	var title := String(lines[0]).strip_edges()
	var body_parts: PackedStringArray = []
	for i in range(1, lines.size()):
		var line := String(lines[i]).strip_edges()
		if not line.is_empty():
			body_parts.append(line)
	var body := "\n".join(body_parts)
	if body.is_empty():
		_label.text = "[color=#e85a5a][b]%s[/b][/color]" % title
	else:
		_label.text = "[color=#e85a5a][b]%s[/b][/color]\n%s" % [title, body]


func _clamp_near_anchor(anchor_rect: Rect2, tip_size: Vector2) -> Vector2:
	var screen := get_viewport().get_visible_rect()
	var min_x := screen.position.x + VIEW_PAD
	var max_x := screen.end.x - tip_size.x - VIEW_PAD
	var min_y := screen.position.y + VIEW_PAD
	var max_y := screen.end.y - tip_size.y - VIEW_PAD
	if max_x < min_x:
		max_x = min_x
	if max_y < min_y:
		max_y = min_y

	# Prefer right of icon (artifact strip is top-left); fall back left, then below/above.
	var candidates: Array[Vector2] = [
		Vector2(anchor_rect.end.x + MARGIN, anchor_rect.position.y),
		Vector2(anchor_rect.position.x - tip_size.x - MARGIN, anchor_rect.position.y),
		Vector2(anchor_rect.position.x, anchor_rect.end.y + MARGIN),
		Vector2(anchor_rect.position.x, anchor_rect.position.y - tip_size.y - MARGIN),
	]
	var best := candidates[0]
	var best_score := -INF
	for pos in candidates:
		var clamped := Vector2(clampf(pos.x, min_x, max_x), clampf(pos.y, min_y, max_y))
		var dx := absf(clamped.x - pos.x)
		var dy := absf(clamped.y - pos.y)
		var score := -(dx + dy)
		# Prefer staying near the top of the screen (avoids editor-embed letterbox clip).
		score -= clamped.y * 0.001
		if score > best_score:
			best_score = score
			best = clamped
	return best


func hide_tip() -> void:
	_show_token += 1
	visible = false
	if _label:
		_label.text = ""
