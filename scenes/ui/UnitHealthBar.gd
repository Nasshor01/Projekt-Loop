# World-anchored HP / block readout for battle units (screen-space).
extends Control

const BAR_WIDTH := 72.0
const BAR_HEIGHT := 10.0

@onready var _hp_fill: ColorRect = $BarRoot/HpTrack/HpFill
@onready var _hp_track: ColorRect = $BarRoot/HpTrack
@onready var _hp_label: Label = $BarRoot/HpLabel
@onready var _block_row: HBoxContainer = $BarRoot/BlockRow
@onready var _block_label: Label = $BarRoot/BlockRow/BlockLabel

var _screen_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("unit_health_bars")
	_force_mouse_passthrough()
	_hp_track.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_track.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

func _force_mouse_passthrough() -> void:
	# Labels default to STOP and would block hand cards under the bar.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_screen_position(pos: Vector2) -> void:
	_screen_position = pos
	# Center horizontally under the unit.
	global_position = pos - Vector2(BAR_WIDTH * 0.5, 0.0)

func update_values(current_hp: int, max_hp: int, block: int = 0) -> void:
	var safe_max = max(max_hp, 1)
	var ratio = clampf(float(current_hp) / float(safe_max), 0.0, 1.0)
	_hp_fill.size = Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)
	_hp_fill.color = _hp_color_for_ratio(ratio)
	_hp_label.text = "%d/%d" % [current_hp, max_hp]
	if block > 0:
		_block_label.text = str(block)
		_block_row.visible = true
	else:
		_block_label.text = ""
		_block_row.visible = false

func _hp_color_for_ratio(ratio: float) -> Color:
	if ratio > 0.55:
		return Color(0.22, 0.78, 0.32, 1.0) # green
	if ratio > 0.3:
		return Color(0.92, 0.72, 0.18, 1.0) # yellow
	return Color(0.9, 0.22, 0.22, 1.0) # red
