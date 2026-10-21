# Slay-the-Spire style card targeting arrow (screen-space): bezier body, head and damage readout at the tip.
class_name TargetingArrow
extends Node2D

const BODY_WIDTH := 12.0
const OUTLINE_EXTRA := 6.0
const HEAD_LENGTH := 30.0
const HEAD_WIDTH := 36.0
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const READOUT_FONT := preload("res://art/fonts/Ithaca-LVB75.ttf")
const READOUT_SIZE := Vector2(220.0, 40.0)
## Readout sits above the tip so it never lands under the cursor.
const READOUT_OFFSET := Vector2(0.0, -58.0)

const PREVIEW_DAMAGE_COLOR := Color(1.0, 0.35, 0.3, 1.0)
const PREVIEW_BLOCKED_COLOR := Color(0.55, 0.85, 1.0, 1.0)
const PREVIEW_LETHAL_COLOR := Color(1.0, 0.85, 0.2, 1.0)

var _curve := Curve2D.new()
var _outline: Line2D
var _body: Line2D
var _head_outline: Polygon2D
var _head: Polygon2D
var _readout: Label
var _readout_hp_loss: int = -1
var _readout_lethal: bool = false

func _ready() -> void:
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.35))
	taper.add_point(Vector2(1.0, 1.0))
	# Both outlines first, so the head outline doesn't paint a black band over the shaft.
	_outline = _make_line(BODY_WIDTH + OUTLINE_EXTRA, OUTLINE_COLOR, taper)
	_head_outline = Polygon2D.new()
	_head_outline.color = OUTLINE_COLOR
	add_child(_head_outline)
	_body = _make_line(BODY_WIDTH, Color.WHITE, taper)
	_head = Polygon2D.new()
	add_child(_head)

	_readout = Label.new()
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_readout.add_theme_font_override("font", READOUT_FONT)
	_readout.add_theme_font_size_override("font_size", 34)
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_readout.add_theme_constant_override("outline_size", 8)
	_readout.size = READOUT_SIZE
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.visible = false
	add_child(_readout)
	visible = false

func _make_line(width: float, color: Color, taper: Curve) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.width_curve = taper
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	add_child(line)
	return line

## [param from] = card edge, [param to] = tip (screen coords of the CanvasLayer).
func update_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	visible = true
	if from.distance_to(to) < HEAD_LENGTH * 1.5:
		_body.clear_points()
		_outline.clear_points()
		_head.polygon = PackedVector2Array()
		_head_outline.polygon = PackedVector2Array()
		_place_readout(to)
		return
	# Leaves the card vertically, then bends toward the target.
	var control := Vector2(lerpf(from.x, to.x, 0.15), lerpf(from.y, to.y, 0.85))
	var dir := (to - control).normalized()
	if dir == Vector2.ZERO:
		dir = (to - from).normalized()
	var head_base := to - dir * HEAD_LENGTH
	_curve.clear_points()
	_curve.add_point(from, Vector2.ZERO, (control - from) * (2.0 / 3.0))
	_curve.add_point(head_base, (control - head_base) * (2.0 / 3.0), Vector2.ZERO)
	var points := _curve.tessellate(5, 3.0)
	_body.points = points
	_outline.points = points
	_body.default_color = color

	var perp := Vector2(-dir.y, dir.x)
	_head.color = color
	_head.polygon = PackedVector2Array([to, head_base + perp * HEAD_WIDTH * 0.5, head_base - perp * HEAD_WIDTH * 0.5])
	var o_tip := to + dir * OUTLINE_EXTRA
	var o_base := head_base - dir * (OUTLINE_EXTRA * 0.5)
	var o_half := (HEAD_WIDTH + OUTLINE_EXTRA * 2.0) * 0.5
	_head_outline.polygon = PackedVector2Array([o_tip, o_base + perp * o_half, o_base - perp * o_half])
	_place_readout(to)

func _place_readout(tip: Vector2) -> void:
	_readout.position = tip + READOUT_OFFSET - READOUT_SIZE * 0.5

## Same wording/colors as the HP bar preview. hp_loss < 0 hides the readout.
func set_damage_readout(hp_loss: int, lethal: bool) -> void:
	if hp_loss == _readout_hp_loss and lethal == _readout_lethal:
		return
	_readout_hp_loss = hp_loss
	_readout_lethal = lethal
	if hp_loss < 0:
		_readout.visible = false
		return
	if lethal:
		_readout.text = tr("battle.preview_lethal")
		_readout.add_theme_color_override("font_color", PREVIEW_LETHAL_COLOR)
	elif hp_loss == 0:
		_readout.text = "-0"
		_readout.add_theme_color_override("font_color", PREVIEW_BLOCKED_COLOR)
	else:
		_readout.text = "-%d" % hp_loss
		_readout.add_theme_color_override("font_color", PREVIEW_DAMAGE_COLOR)
	_readout.visible = true

func hide_arrow() -> void:
	visible = false
	_readout.visible = false
	_readout_hp_loss = -1
	_readout_lethal = false
