extends Control

@onready var portrait: TextureRect = %Portrait
@onready var initiative_label: Label = %InitiativeLabel
@onready var frame: Panel = %Frame

var unit: Unit
var is_preview: bool = false
var _turn_manager: Node

var _unit_ref: Unit = null
var _turn_manager_ref: Node = null
var _is_setup_pending: bool = false
var _initiative_value: int = 0
var _pending_mod: int = 0
var _is_preview_ref: bool = false
var _initiative_override: int = -1
var _is_hovered: bool = false

const COLOR_PLAYER_BORDER := Color(0.35, 0.75, 1.0, 0.95)
const COLOR_ENEMY_BORDER := Color(0.95, 0.35, 0.28, 0.95)
const COLOR_NEUTRAL_BORDER := Color(0.72, 0.58, 0.28, 0.95)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64, 64)
	size = custom_minimum_size
	clip_contents = true
	if is_instance_valid(portrait):
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(initiative_label):
		initiative_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(frame):
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_exiting.connect(clear_hover)
	if _is_setup_pending:
		_apply_setup_data()
		_is_setup_pending = false


func setup(
	unit_ref: Unit,
	turn_manager: Node,
	preview: bool = false,
	initiative_override: int = -1,
	pending_mod: int = 0
) -> void:
	_unit_ref = unit_ref
	_turn_manager_ref = turn_manager
	_is_preview_ref = preview
	_initiative_override = initiative_override
	_pending_mod = pending_mod
	if portrait == null:
		_is_setup_pending = true
	else:
		_apply_setup_data()


func _apply_setup_data() -> void:
	unit = _unit_ref
	_turn_manager = _turn_manager_ref
	is_preview = _is_preview_ref

	if not is_instance_valid(portrait):
		printerr("InitiativeIcon: @onready var 'portrait' se nepodařilo načíst!")
		return
	if not is_instance_valid(initiative_label):
		printerr("InitiativeIcon: @onready var 'initiative_label' se nepodařilo načíst!")
		return

	if is_instance_valid(unit) and is_instance_valid(unit.unit_data):
		if unit.unit_data.sprite_texture != null:
			portrait.texture = unit.unit_data.sprite_texture
		else:
			portrait.texture = null
		_update_initiative_value()
		_apply_faction_frame()
	else:
		portrait.texture = null
		_initiative_value = 0
		initiative_label.text = "?"

	# Always show initiative number (BG3 clarity).
	initiative_label.show()
	_apply_preview_look()
	_is_hovered = false


func _apply_faction_frame() -> void:
	if not is_instance_valid(frame) or not is_instance_valid(unit) or not unit.unit_data:
		return
	var style := frame.get_theme_stylebox("panel")
	if style == null:
		style = StyleBoxFlat.new()
	else:
		style = style.duplicate()
	if style is StyleBoxFlat:
		var flat := style as StyleBoxFlat
		match unit.unit_data.faction:
			UnitData.Faction.PLAYER:
				flat.border_color = COLOR_PLAYER_BORDER
			UnitData.Faction.ENEMY:
				flat.border_color = COLOR_ENEMY_BORDER
			_:
				flat.border_color = COLOR_NEUTRAL_BORDER
		frame.add_theme_stylebox_override("panel", flat)


func _apply_preview_look() -> void:
	if is_preview:
		modulate = Color(1, 1, 1, 0.55)
		scale = Vector2(0.88, 0.88)
		custom_minimum_size = Vector2(56, 56)
	else:
		modulate = Color.WHITE
		scale = Vector2.ONE
		custom_minimum_size = Vector2(64, 64)


func refresh_initiative() -> void:
	_update_initiative_value()
	initiative_label.show()


func _update_initiative_value() -> void:
	if _initiative_override >= 0:
		_initiative_value = _initiative_override
	elif not is_instance_valid(unit) or not is_instance_valid(unit.unit_data):
		_initiative_value = 0
		initiative_label.text = "?"
		return
	elif is_preview and _turn_manager and _turn_manager.has_method("get_projected_initiative_for_unit"):
		_initiative_value = int(_turn_manager.get_projected_initiative_for_unit(unit))
	elif (not is_preview) and _turn_manager and _turn_manager.has_method("get_locked_initiative_for_unit"):
		_initiative_value = int(_turn_manager.get_locked_initiative_for_unit(unit))
	else:
		var base_init = unit.unit_data.initiative
		var mod = 0
		if _turn_manager and _turn_manager.has_method("get_initiative_modifier_for_unit"):
			mod = _turn_manager.get_initiative_modifier_for_unit(unit)
		_initiative_value = base_init + mod

	if is_preview and _pending_mod != 0:
		initiative_label.text = str(_initiative_value)
		initiative_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1))
	else:
		initiative_label.text = str(_initiative_value)
		initiative_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))


func set_active(is_active: bool) -> void:
	"""Vizuálně zvýrazní ikonu, pokud je jednotka na tahu (current-round slot only)."""
	if is_active:
		self_modulate = Color(1.3, 1.2, 0.55)
		if not is_preview:
			scale = Vector2(1.08, 1.08)
	else:
		self_modulate = Color.WHITE
		_apply_preview_look()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_set_unit_hover(true)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_set_unit_hover(false)


func _set_unit_hover(hovered: bool) -> void:
	if is_instance_valid(unit) and unit.has_method("set_initiative_hover_visual"):
		unit.set_initiative_hover_visual(hovered)


func clear_hover() -> void:
	if _is_hovered:
		_is_hovered = false
		_set_unit_hover(false)
