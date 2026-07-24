extends Control

@onready var portrait: TextureRect = %Portrait
@onready var initiative_label: Label = %InitiativeLabel
@onready var frame: Panel = %Frame

var unit: Unit
var _turn_manager: Node

var _unit_ref: Unit = null
var _turn_manager_ref: Node = null
var _is_setup_pending: bool = false
var _initiative_value: int = 0
var _is_hovered: bool = false


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(48, 48)
	size = custom_minimum_size
	clip_contents = true
	if is_instance_valid(portrait):
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(initiative_label):
		initiative_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		initiative_label.hide()
	if is_instance_valid(frame):
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tree_exiting.connect(clear_hover)
	if _is_setup_pending:
		_apply_setup_data()
		_is_setup_pending = false


func setup(unit_ref: Unit, turn_manager: Node):
	_unit_ref = unit_ref
	_turn_manager_ref = turn_manager
	if portrait == null:
		_is_setup_pending = true
	else:
		_apply_setup_data()


func _apply_setup_data():
	unit = _unit_ref
	_turn_manager = _turn_manager_ref

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
	else:
		portrait.texture = null
		_initiative_value = 0
		initiative_label.text = "?"

	initiative_label.hide()
	_is_hovered = false


func refresh_initiative():
	_update_initiative_value()
	if _is_hovered:
		initiative_label.text = str(_initiative_value)
		initiative_label.show()


func _update_initiative_value():
	if not is_instance_valid(unit) or not is_instance_valid(unit.unit_data):
		_initiative_value = 0
		initiative_label.text = "?"
		return
	var base_init = unit.unit_data.initiative
	var mod = 0
	if _turn_manager and _turn_manager.has_method("get_initiative_modifier_for_unit"):
		mod = _turn_manager.get_initiative_modifier_for_unit(unit)
	_initiative_value = base_init + mod
	initiative_label.text = str(_initiative_value)


func set_active(is_active: bool):
	"""Vizuálně zvýrazní ikonu, pokud je jednotka na tahu."""
	if is_active:
		self_modulate = Color(1.25, 1.15, 0.55)
	else:
		self_modulate = Color.WHITE


func _on_mouse_entered():
	_is_hovered = true
	_update_initiative_value()
	initiative_label.text = str(_initiative_value)
	initiative_label.show()
	_set_unit_hover(true)


func _on_mouse_exited():
	_is_hovered = false
	initiative_label.hide()
	_set_unit_hover(false)


func _set_unit_hover(hovered: bool) -> void:
	if is_instance_valid(unit) and unit.has_method("set_initiative_hover_visual"):
		unit.set_initiative_hover_visual(hovered)


func clear_hover() -> void:
	if _is_hovered:
		_is_hovered = false
		if is_instance_valid(initiative_label):
			initiative_label.hide()
		_set_unit_hover(false)
