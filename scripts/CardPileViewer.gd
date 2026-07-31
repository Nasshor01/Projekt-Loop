extends PanelContainer

signal card_clicked_in_viewer(card_data)
signal card_right_clicked(card_data: CardData)

@onready var grid_container = %GridContainer
@onready var close_button = %CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Label

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	if not close_button.pressed.is_connected(hide):
		close_button.pressed.connect(hide)
	_update_ui_texts()
	z_index = 200

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.deck_viewer.title")
	if close_button:
		close_button.text = tr("ui.common.close")

func show_cards(cards: Array, _card_scale: Vector2 = Vector2.ZERO):
	for child in grid_container.get_children():
		child.queue_free()

	if grid_container is GridContainer:
		grid_container.columns = 3

	for card_data in cards:
		var card_ui = CardUIScene.instantiate()
		if card_ui is CardUI:
			var wrapper = Control.new()
			wrapper.clip_contents = false
			wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			# Enter tree before apply_display_mode so @onready + layout cache are valid.
			wrapper.add_child(card_ui)
			card_ui.position = Vector2(6, 8)
			grid_container.add_child(wrapper)

			card_ui.load_card(card_data)
			card_ui.apply_display_mode(CardUI.DisplayMode.DECK)
			if not card_ui.is_connected("card_clicked", _on_card_clicked_in_viewer):
				card_ui.card_clicked.connect(_on_card_clicked_in_viewer)
			if not card_ui.card_right_clicked.is_connected(_on_card_right_clicked_in_viewer):
				card_ui.card_right_clicked.connect(_on_card_right_clicked_in_viewer)
			var cell = card_ui.get_scaled_size() + Vector2(12, 16)
			wrapper.custom_minimum_size = cell
			wrapper.size = cell
			call_deferred("_sync_pile_card_layout", card_ui)
	show()

func _sync_pile_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)
	card_ui.size = card_ui.custom_minimum_size

func _on_card_clicked_in_viewer(card_data: CardData):
	card_clicked_in_viewer.emit(card_data)

func _on_card_right_clicked_in_viewer(card_data: CardData):
	card_right_clicked.emit(card_data)
