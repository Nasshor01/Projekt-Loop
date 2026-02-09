extends PanelContainer

signal card_clicked_in_viewer(card_data)

@onready var grid_container = %GridContainer
@onready var close_button = %CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Label

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	if not close_button.pressed.is_connected(hide):
		close_button.pressed.connect(hide)
	_update_ui_texts()

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.deck_viewer.title")
	if close_button:
		close_button.text = tr("ui.common.close")

func show_cards(cards: Array, card_scale: Vector2 = Vector2(0.7, 0.7)):
	# Clear previous cards
	for child in grid_container.get_children():
		child.queue_free()

	# Instance and add new cards
	var base_card_size = Vector2(200, 300)
	var min_card_size = base_card_size * card_scale
	for card_data in cards:
		var card_ui = CardUIScene.instantiate()
		grid_container.add_child(card_ui)
		card_ui.load_card(card_data)
		if card_ui is CardUI:
			card_ui.is_draggable = false
			card_ui.static_layout = true
			card_ui.custom_minimum_size = min_card_size
			card_ui.pivot_offset = card_ui.custom_minimum_size * 0.5
			card_ui.set_target_scale(card_scale)
			card_ui.scale = card_scale
			if not card_ui.is_connected("card_clicked", _on_card_clicked_in_viewer):
				card_ui.card_clicked.connect(_on_card_clicked_in_viewer)
			call_deferred("_sync_pile_card_layout", card_ui)

	show()

func _sync_pile_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)

func _on_card_clicked_in_viewer(card_data: CardData):
	card_clicked_in_viewer.emit(card_data)
