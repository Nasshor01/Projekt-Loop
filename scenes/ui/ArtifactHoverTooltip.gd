# Instant STS-style relic tooltip (no Godot tooltip delay).
class_name ArtifactHoverTooltip
extends PanelContainer

const MAX_WIDTH := 320.0
const MARGIN := 10.0
const VIEW_PAD := 8.0

static var instance: ArtifactHoverTooltip

var _label: Label
var _show_token: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	style.border_color = Color(0.75, 0.78, 0.85, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(MAX_WIDTH - 24.0, 0)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


static func ensure(tree: SceneTree) -> ArtifactHoverTooltip:
	if is_instance_valid(instance) and instance.is_inside_tree():
		return instance
	instance = ArtifactHoverTooltip.new()
	instance.name = "ArtifactHoverTooltip"
	tree.root.add_child(instance)
	return instance


func show_for(text: String, anchor: Control) -> void:
	if text.is_empty() or not is_instance_valid(anchor):
		hide_tip()
		return
	_label.text = text
	visible = true
	_show_token += 1
	var token := _show_token
	await get_tree().process_frame
	if token != _show_token or not visible or not is_instance_valid(anchor):
		return
	var tip_size := get_combined_minimum_size()
	tip_size.x = mini(tip_size.x, MAX_WIDTH)
	size = tip_size
	var screen := get_viewport().get_visible_rect()
	var anchor_rect := anchor.get_global_rect()
	var pos := Vector2(anchor_rect.position.x, anchor_rect.end.y + MARGIN)
	pos.x = clampf(pos.x, screen.position.x + VIEW_PAD, screen.end.x - tip_size.x - VIEW_PAD)
	pos.y = clampf(pos.y, screen.position.y + VIEW_PAD, screen.end.y - tip_size.y - VIEW_PAD)
	global_position = pos


func hide_tip() -> void:
	_show_token += 1
	visible = false
	if _label:
		_label.text = ""
