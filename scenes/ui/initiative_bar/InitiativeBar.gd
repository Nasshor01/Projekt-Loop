extends PanelContainer

## BG3-style bar: remaining turns this round | next-round preview (units can appear twice).

const InitiativeIconScene = preload("res://scenes/ui/initiative_bar/InitiativeIcon.tscn")

@onready var hbox_container: HBoxContainer = $HBoxContainer

var _icon_nodes: Array[Node] = []
var _separator: Control = null


func _ready() -> void:
	if hbox_container:
		hbox_container.alignment = BoxContainer.ALIGNMENT_CENTER


func refresh_from_turn_manager() -> void:
	"""Rebuild bar from TurnManager remaining + next-round preview."""
	if not has_node("/root/TurnManager"):
		printerr("InitiativeBar: TurnManager nenalezen!")
		return
	var tm: Node = get_node("/root/TurnManager")
	if not tm.has_method("get_initiative_bar_entries"):
		update_turn_order(tm.get_turn_order() if tm.has_method("get_turn_order") else [])
		return
	_rebuild_from_entries(tm.get_initiative_bar_entries(), tm)


func update_turn_order(_units: Array[Unit]) -> void:
	"""Legacy entry — prefer refresh_from_turn_manager()."""
	refresh_from_turn_manager()


func _rebuild_from_entries(entries: Array, turn_manager: Node) -> void:
	_clear_icons()

	var saw_preview := false
	var saw_current := false
	for entry_v in entries:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var is_preview: bool = bool(entry.get("is_preview", false))
		if is_preview and saw_current and not saw_preview:
			_add_round_separator()
			saw_preview = true
		if not is_preview:
			saw_current = true

		var unit: Unit = entry.get("unit") as Unit
		if not is_instance_valid(unit):
			continue
		var icon_instance = InitiativeIconScene.instantiate()
		hbox_container.add_child(icon_instance)
		icon_instance.setup(
			unit,
			turn_manager,
			is_preview,
			int(entry.get("initiative", 0)),
			int(entry.get("pending_mod", 0))
		)
		_icon_nodes.append(icon_instance)

	var active: Unit = turn_manager.get_current_unit() if turn_manager.has_method("get_current_unit") else null
	set_active_unit(active)


func _add_round_separator() -> void:
	var sep := PanelContainer.new()
	sep.custom_minimum_size = Vector2(10, 40)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.72, 0.35, 0.95)
	style.set_corner_radius_all(2)
	style.content_margin_left = 0
	style.content_margin_right = 0
	sep.add_theme_stylebox_override("panel", style)

	var tip := Label.new()
	tip.text = "›"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.1, 0.08, 0.04, 1))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.add_child(tip)

	hbox_container.add_child(sep)
	_separator = sep


func _clear_icons() -> void:
	for icon in _icon_nodes:
		if is_instance_valid(icon) and icon.has_method("clear_hover"):
			icon.clear_hover()
	_icon_nodes.clear()
	_separator = null
	for child in hbox_container.get_children():
		child.queue_free()


func set_active_unit(active_unit: Unit) -> void:
	"""Highlight only the current-round slot for the active unit (not preview copies)."""
	var marked := false
	for icon_node in _icon_nodes:
		if not is_instance_valid(icon_node):
			continue
		var is_preview: bool = bool(icon_node.get("is_preview")) if "is_preview" in icon_node else false
		var match_active: bool = (
			is_instance_valid(active_unit)
			and icon_node.unit == active_unit
			and not is_preview
			and not marked
		)
		if match_active:
			marked = true
		if icon_node.has_method("set_active"):
			icon_node.set_active(match_active)


func refresh_initiatives() -> void:
	"""Pending init changed — rebuild so next-round preview re-sorts."""
	refresh_from_turn_manager()


func advance_to_active(_active_unit: Unit) -> void:
	"""Deprecated rotate behavior — bar rebuilds from TurnManager instead."""
	refresh_from_turn_manager()
