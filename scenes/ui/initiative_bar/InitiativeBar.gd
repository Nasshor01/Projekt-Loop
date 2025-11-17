extends PanelContainer

const InitiativeIconScene = preload("res://scenes/ui/initiative_bar/InitiativeIcon.tscn")

@onready var hbox_container: HBoxContainer = $HBoxContainer

var _icon_nodes: Array[Node] = []

func update_turn_order(units: Array[Unit]):
	# Vymazat staré ikony
	for icon in _icon_nodes:
		icon.queue_free()
	_icon_nodes.clear()

	# Vytvořit nové ikony
	if has_node("/root/TurnManager"):
		var turn_manager = get_node("/root/TurnManager")
		for unit in units:
			var icon_instance = InitiativeIconScene.instantiate()
			icon_instance.setup(unit, turn_manager)
			hbox_container.add_child(icon_instance)
			_icon_nodes.append(icon_instance)
	else:
		printerr("InitiativeBar: TurnManager nenalezen!")


func set_active_unit(active_unit: Unit):
	for icon_node in _icon_nodes:
		if icon_node.unit == active_unit:
			icon_node.set_active(true)
		else:
			icon_node.set_active(false)
