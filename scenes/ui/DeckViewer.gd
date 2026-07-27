extends PanelContainer

signal card_selected(card_data: CardData)
signal card_clicked_in_viewer(card_data)
signal card_right_clicked(card_data: CardData)
signal card_hovered(card_data: CardData)
signal card_unhovered()

@onready var grid_container: GridContainer = %GridContainer
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Label

var card_scene = preload("res://scenes/ui/CardUI.tscn")

## STS2-style smith: when true, faces show upgraded_version while clicks still use base card.
var _upgrade_preview_mode: bool = false
var _upgrade_show_as_upgraded: bool = true
var _upgrade_base_cards: Array[CardData] = []

func _ready():
	close_button.pressed.connect(hide)
	_update_ui_texts()
	z_index = 200
	hide()

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.deck_viewer.title_full")
	if close_button:
		close_button.text = tr("ui.common.close")

## Individual cards (upgrade pick, remove card, etc.) — full readable face.
func show_cards(cards: Array[CardData], _card_scale: Vector2 = Vector2.ZERO):
	_upgrade_preview_mode = false
	_upgrade_base_cards.clear()
	_clear_grid()
	grid_container.columns = 3
	for card_data in cards:
		if not is_instance_valid(card_data):
			continue
		_add_card_to_grid(card_data, CardUI.DisplayMode.DECK)
	self.show()
	_set_world_hud_dimmed(true)

## Rest-site smith / STS2: only upgradeable cards; optionally show upgraded faces.
func show_upgrade_selection(cards: Array[CardData], show_as_upgraded: bool = true) -> void:
	_upgrade_preview_mode = true
	_upgrade_show_as_upgraded = show_as_upgraded
	_upgrade_base_cards = cards.duplicate()
	_clear_grid()
	grid_container.columns = 3
	if title_label:
		title_label.text = tr("ui.rest.upgrade_preview_title") if show_as_upgraded else tr("ui.rest.choose_card")
	for base_card in cards:
		if not is_instance_valid(base_card) or not is_instance_valid(base_card.upgraded_version):
			continue
		var display_data: CardData = base_card.upgraded_version if show_as_upgraded else base_card
		_add_upgrade_card_to_grid(base_card, display_data, show_as_upgraded)
	show()
	_set_world_hud_dimmed(true)

func set_upgrade_preview_faces(show_as_upgraded: bool) -> void:
	"""Toggle STS2 mass-upgrade preview without closing the picker."""
	if not _upgrade_preview_mode:
		return
	show_upgrade_selection(_upgrade_base_cards, show_as_upgraded)

## Deck overview with counts — compact tiles stay legible.
func display_deck(deck: Array[CardData]):
	_upgrade_preview_mode = false
	_upgrade_base_cards.clear()
	_clear_grid()
	grid_container.columns = 4

	var card_counts = {}
	for card_data in deck:
		if not card_counts.has(card_data.card_name):
			card_counts[card_data.card_name] = {"data": card_data, "count": 0}
		card_counts[card_data.card_name]["count"] += 1

	for card_name in card_counts:
		var card_info = card_counts[card_name]
		var card_instance = _add_card_to_grid(card_info["data"], CardUI.DisplayMode.COMPACT)
		if card_instance:
			var count_label = Label.new()
			count_label.text = TranslationHelper.tr_format("ui.deck_viewer.count", {"value": card_info["count"]})
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_label.add_theme_font_size_override("font_size", 22)
			count_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4, 1))
			count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			count_label.add_theme_constant_override("outline_size", 4)
			count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			count_label.offset_left = -56
			count_label.offset_top = 4
			count_label.offset_right = -6
			count_label.offset_bottom = 28
			count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_instance.add_child(count_label)
			card_instance.gui_input.connect(_on_card_gui_input.bind(card_info["data"]))
	show()
	_set_world_hud_dimmed(true)

func _add_card_to_grid(card_data: CardData, mode: CardUI.DisplayMode) -> CardUI:
	var card_instance = card_scene.instantiate()
	card_instance.load_card(card_data)
	if not (card_instance is CardUI):
		return null
	var card_ui := card_instance as CardUI
	card_ui.apply_display_mode(mode)
	if not card_ui.is_connected("card_clicked", _on_card_clicked_in_viewer):
		card_ui.card_clicked.connect(_on_card_clicked_in_viewer)
	if not card_ui.card_right_clicked.is_connected(_on_card_right_clicked_in_viewer):
		card_ui.card_right_clicked.connect(_on_card_right_clicked_in_viewer)
	card_ui.gui_input.connect(_on_card_selected_input.bind(card_data))
	card_ui.mouse_entered.connect(_on_grid_card_hovered.bind(card_data))
	card_ui.mouse_exited.connect(_on_grid_card_unhovered)

	var scaled_size = card_ui.get_scaled_size()
	# Small padding between grid cells
	var cell = scaled_size + Vector2(12, 16)
	var wrapper = Control.new()
	wrapper.custom_minimum_size = cell
	wrapper.size = cell
	wrapper.clip_contents = false
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.add_child(card_ui)
	card_ui.position = Vector2(6, 8)
	grid_container.add_child(wrapper)
	call_deferred("_sync_deck_card_layout", card_ui)
	return card_ui

func _add_upgrade_card_to_grid(base_card: CardData, display_data: CardData, show_as_upgraded: bool) -> CardUI:
	var card_instance = card_scene.instantiate()
	card_instance.load_card(display_data)
	if not (card_instance is CardUI):
		return null
	var card_ui := card_instance as CardUI
	card_ui.apply_display_mode(CardUI.DisplayMode.DECK)
	card_ui.set_meta("upgrade_base_card", base_card)
	# Always emit the BASE card on click (even when face shows upgraded)
	card_ui.card_clicked.connect(func(_ignored: CardData): _on_card_clicked_in_viewer(base_card))
	card_ui.card_right_clicked.connect(func(_ignored: CardData): _on_card_right_clicked_in_viewer(base_card))
	card_ui.gui_input.connect(_on_card_selected_input.bind(base_card))
	card_ui.mouse_entered.connect(_on_grid_card_hovered.bind(base_card))
	card_ui.mouse_exited.connect(_on_grid_card_unhovered)
	if show_as_upgraded:
		_apply_upgrade_face_chrome(card_ui)

	var scaled_size = card_ui.get_scaled_size()
	var cell = scaled_size + Vector2(12, 16)
	var wrapper = Control.new()
	wrapper.custom_minimum_size = cell
	wrapper.size = cell
	wrapper.clip_contents = false
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.add_child(card_ui)
	card_ui.position = Vector2(6, 8)
	grid_container.add_child(wrapper)
	call_deferred("_sync_deck_card_layout", card_ui)
	return card_ui

func _apply_upgrade_face_chrome(card_ui: CardUI) -> void:
	"""Green upgrade tint + ↑ badge — STS2-style upgraded face."""
	card_ui.modulate = Color(0.88, 1.12, 0.95, 1.0)
	var badge := Label.new()
	badge.text = "↑"
	badge.add_theme_font_size_override("font_size", 28)
	badge.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	badge.add_theme_constant_override("outline_size", 6)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = 6
	badge.offset_top = 4
	badge.offset_right = 36
	badge.offset_bottom = 36
	card_ui.add_child(badge)

func _on_grid_card_hovered(card_data: CardData) -> void:
	card_hovered.emit(card_data)

func _on_grid_card_unhovered() -> void:
	card_unhovered.emit()

func _on_card_selected_input(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		card_selected.emit(card_data)
		if not _upgrade_preview_mode:
			hide_and_clear()

func _on_card_gui_input(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print(tr("ui.deck_viewer.detail_card") + " " + card_data.get_localized_name())

func hide_and_clear():
	_upgrade_preview_mode = false
	_upgrade_base_cards.clear()
	hide()
	_clear_grid()
	_set_world_hud_dimmed(false)

func _clear_grid():
	for child in grid_container.get_children():
		child.queue_free()

func _sync_deck_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)
	card_ui.set_target_scale(card_ui.scale)
	card_ui.size = card_ui.custom_minimum_size

func _on_card_clicked_in_viewer(card_data: CardData):
	card_clicked_in_viewer.emit(card_data)

func _on_card_right_clicked_in_viewer(card_data: CardData):
	card_right_clicked.emit(card_data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_set_world_hud_dimmed(false)

func _set_world_hud_dimmed(dimmed: bool) -> void:
	"""Hide battle HP bars while deck overlay is open (they draw on battle CanvasLayer)."""
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("unit_health_bars"):
		if is_instance_valid(n):
			n.visible = not dimmed
