extends PanelContainer

const InitiativeIconScene = preload("res://scenes/ui/initiative_bar/InitiativeIcon.tscn")

@onready var hbox_container: HBoxContainer = $HBoxContainer

var _icon_nodes: Array[Node] = []
var _base_container_pos: Vector2
var _bar_tween: Tween

func _ready():
	_base_container_pos = hbox_container.position

func update_turn_order(units: Array[Unit]):
	# Vymazat staré ikony (a zrušit případný hover highlight)
	for icon in _icon_nodes:
		if is_instance_valid(icon) and icon.has_method("clear_hover"):
			icon.clear_hover()
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
	
	hbox_container.position = _base_container_pos


func set_active_unit(active_unit: Unit):
	for icon_node in _icon_nodes:
		if icon_node.unit == active_unit:
			icon_node.set_active(true)
		else:
			icon_node.set_active(false)

func refresh_initiatives():
	for icon_node in _icon_nodes:
		if icon_node.has_method("refresh_initiative"):
			icon_node.refresh_initiative()

func advance_to_active(active_unit: Unit):
	if _icon_nodes.is_empty():
		return
	var active_index = -1
	for i in range(_icon_nodes.size()):
		if _icon_nodes[i].unit == active_unit:
			active_index = i
			break
	if active_index <= 0:
		return
	
	var icon_width = _get_icon_width()
	var separation = hbox_container.get_theme_constant("separation")
	var offset = active_index * (icon_width + separation)
	
	if is_instance_valid(_bar_tween):
		_bar_tween.kill()
	
	_bar_tween = create_tween()
	_bar_tween.tween_property(hbox_container, "position:x", _base_container_pos.x - offset, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_bar_tween.finished.connect(func():
		_rotate_icons(active_index)
		hbox_container.position = _base_container_pos
	)

func _rotate_icons(steps: int):
	for _i in range(steps):
		var node = _icon_nodes.pop_front()
		_icon_nodes.append(node)
		hbox_container.move_child(node, hbox_container.get_child_count() - 1)

func _get_icon_width() -> float:
	if _icon_nodes.is_empty():
		return 48.0
	var first_icon = _icon_nodes[0]
	var width = first_icon.size.x
	if width <= 0 and first_icon is Control:
		width = max(width, first_icon.custom_minimum_size.x)
	return width if width > 0 else 48.0
