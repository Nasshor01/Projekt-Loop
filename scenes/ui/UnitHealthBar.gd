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

const PREVIEW_FILL_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const PREVIEW_DAMAGE_COLOR := Color(1.0, 0.35, 0.3, 1.0)
const PREVIEW_BLOCKED_COLOR := Color(0.55, 0.85, 1.0, 1.0)
const PREVIEW_LETHAL_COLOR := Color(1.0, 0.85, 0.2, 1.0)

var _current_hp: int = 0
var _max_hp: int = 1
## -1 = no preview shown.
var _preview_hp_loss: int = -1
var _preview_lethal: bool = false
## False when the targeting arrow already shows this number at its tip.
var _preview_show_label: bool = true
var _preview_fill: ColorRect = null
var _preview_label: Label = null
var _preview_tween: Tween = null

const STATUS_ICON_SIZE := 18.0
const STATUS_ROW_GAP := 3.0
## More statuses than this collapse into a "+N" marker so the row stays near bar width.
const STATUS_MAX_ICONS := 5
const PREVIEW_LABEL_Y := -30.0
var _status_row: HBoxContainer = null
var _status_fingerprint: String = ""

func _ready() -> void:
	add_to_group("unit_health_bars")
	_build_damage_preview_nodes()
	_build_status_row()
	_force_mouse_passthrough()
	_hp_track.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_hp_track.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

func _build_damage_preview_nodes() -> void:
	_preview_fill = ColorRect.new()
	_preview_fill.name = "DamagePreviewFill"
	_preview_fill.color = PREVIEW_FILL_COLOR
	_preview_fill.visible = false
	_hp_track.add_child(_preview_fill)

	_preview_label = Label.new()
	_preview_label.name = "DamagePreviewLabel"
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.add_theme_font_override("font", _hp_label.get_theme_font("font"))
	_preview_label.add_theme_font_size_override("font_size", 26)
	_preview_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_preview_label.add_theme_constant_override("outline_size", 6)
	_preview_label.position = Vector2(-BAR_WIDTH * 0.5, PREVIEW_LABEL_Y)
	_preview_label.size = Vector2(BAR_WIDTH * 2.0, 28.0)
	_preview_label.visible = false
	add_child(_preview_label)

func _build_status_row() -> void:
	_status_row = HBoxContainer.new()
	_status_row.name = "StatusRow"
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.add_theme_constant_override("separation", 3)
	_status_row.position = Vector2(-BAR_WIDTH * 0.5, -STATUS_ICON_SIZE - STATUS_ROW_GAP)
	_status_row.size = Vector2(BAR_WIDTH * 2.0, STATUS_ICON_SIZE)
	_status_row.visible = false
	add_child(_status_row)

## Small icon + stack row directly above the bar; rebuilt only when ids/counts change.
func update_statuses(statuses: Dictionary) -> void:
	if not is_instance_valid(_status_row):
		return
	var fingerprint := ""
	for status_id in statuses:
		fingerprint += "%s:%d|" % [status_id, StatusIcons.get_stack_count(status_id, statuses[status_id])]
	if fingerprint == _status_fingerprint:
		return
	_status_fingerprint = fingerprint
	for child in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()
	var shown := 0
	for status_id in statuses:
		if shown >= STATUS_MAX_ICONS:
			break
		_status_row.add_child(_make_status_chip(status_id, StatusIcons.get_stack_count(status_id, statuses[status_id])))
		shown += 1
	if statuses.size() > shown:
		_status_row.add_child(_make_status_count_label("+%d" % (statuses.size() - shown)))
	_status_row.visible = not statuses.is_empty()
	var row_min := _status_row.get_combined_minimum_size()
	var row_width := maxf(BAR_WIDTH * 2.0, row_min.x)
	var row_height := maxf(STATUS_ICON_SIZE, row_min.y)
	_status_row.size = Vector2(row_width, row_height)
	_status_row.position = Vector2(BAR_WIDTH * 0.5 - row_width * 0.5, -row_height - STATUS_ROW_GAP)
	_update_preview_label_offset()

func _make_status_chip(status_id: String, count: int) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 0)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = StatusIcons.get_icon(status_id)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(icon)
	if count > 0:
		chip.add_child(_make_status_count_label(str(count)))
	return chip

func _make_status_count_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _hp_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Damage preview number moves above the status row instead of covering it.
func _update_preview_label_offset() -> void:
	if not is_instance_valid(_preview_label):
		return
	var lift := _status_row.size.y + STATUS_ROW_GAP if is_instance_valid(_status_row) and _status_row.visible else 0.0
	_preview_label.position.y = PREVIEW_LABEL_Y - lift

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
	_current_hp = current_hp
	_max_hp = max_hp
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
	if _preview_hp_loss >= 0:
		_apply_damage_preview()

## Shows predicted HP loss: pulsing segment on the bar + number (or lethal marker) above it.
func set_damage_preview(hp_loss: int, lethal: bool, show_label: bool = true) -> void:
	_preview_hp_loss = maxi(0, hp_loss)
	_preview_lethal = lethal
	_preview_show_label = show_label
	_apply_damage_preview()

func clear_damage_preview() -> void:
	_preview_hp_loss = -1
	_preview_lethal = false
	if _preview_tween and _preview_tween.is_valid():
		_preview_tween.kill()
	_preview_tween = null
	if is_instance_valid(_preview_fill):
		_preview_fill.visible = false
	if is_instance_valid(_preview_label):
		_preview_label.visible = false

func _apply_damage_preview() -> void:
	if not is_instance_valid(_preview_fill) or not is_instance_valid(_preview_label):
		return
	var safe_max = max(_max_hp, 1)
	var hp_after = maxi(0, _current_hp - _preview_hp_loss)
	var x_from = BAR_WIDTH * clampf(float(hp_after) / float(safe_max), 0.0, 1.0)
	var x_to = BAR_WIDTH * clampf(float(_current_hp) / float(safe_max), 0.0, 1.0)
	_preview_fill.position = Vector2(x_from, 0.0)
	_preview_fill.size = Vector2(maxf(0.0, x_to - x_from), BAR_HEIGHT)
	_preview_fill.visible = _preview_hp_loss > 0

	if _preview_lethal:
		_preview_label.text = tr("battle.preview_lethal")
		_preview_label.add_theme_color_override("font_color", PREVIEW_LETHAL_COLOR)
	elif _preview_hp_loss == 0:
		_preview_label.text = "-0"
		_preview_label.add_theme_color_override("font_color", PREVIEW_BLOCKED_COLOR)
	else:
		_preview_label.text = "-%d" % _preview_hp_loss
		_preview_label.add_theme_color_override("font_color", PREVIEW_DAMAGE_COLOR)
	_preview_label.visible = _preview_show_label

	if _preview_tween == null or not _preview_tween.is_valid():
		_preview_fill.modulate.a = 1.0
		_preview_tween = create_tween().set_loops()
		_preview_tween.tween_property(_preview_fill, "modulate:a", 0.25, 0.35).set_trans(Tween.TRANS_SINE)
		_preview_tween.tween_property(_preview_fill, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)

func _hp_color_for_ratio(ratio: float) -> Color:
	if ratio > 0.55:
		return Color(0.22, 0.78, 0.32, 1.0) # green
	if ratio > 0.3:
		return Color(0.92, 0.72, 0.18, 1.0) # yellow
	return Color(0.9, 0.22, 0.22, 1.0) # red
