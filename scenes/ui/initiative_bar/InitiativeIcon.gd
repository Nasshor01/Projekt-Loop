extends PanelContainer

@onready var portrait: TextureRect = $Portrait
@onready var tooltip: PanelContainer = $Tooltip
@onready var tooltip_label: Label = $Tooltip/Label

var unit: Unit
var _turn_manager: Node

func setup(unit_ref: Unit, turn_manager: Node):
	unit = unit_ref
	_turn_manager = turn_manager

	if is_instance_valid(unit) and is_instance_valid(unit.unit_data):
		if unit.unit_data.has("portrait") and unit.unit_data.portrait != null:
			portrait.texture = unit.unit_data.portrait
		else:
			portrait.texture = null # Fallback, pokud portrét chybí

		# Vypočítáme celkovou iniciativu
		var base_init = unit.unit_data.initiative
		var mod = 0
		if _turn_manager and _turn_manager.has_method("get_initiative_modifier_for_unit"):
			mod = _turn_manager.get_initiative_modifier_for_unit(unit)
		var total_initiative = base_init + mod

		tooltip_label.text = "%s\\nIniciativa: %d" % [unit.unit_data.unit_name, total_initiative]
	else:
		# Fallback pro případ nevalidních dat
		portrait.texture = null
		tooltip_label.text = "Neznámá jednotka"

	tooltip.hide()

func set_active(is_active: bool):
	"""Vizuálně zvýrazní ikonu, pokud je jednotka na tahu."""
	if is_active:
		modulate = Color.YELLOW
	else:
		modulate = Color.WHITE

func _on_mouse_entered():
	tooltip.show()

func _on_mouse_exited():
	tooltip.hide()
