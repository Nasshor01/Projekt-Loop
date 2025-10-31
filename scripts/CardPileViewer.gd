extends PanelContainer

@onready var grid_container = %GridContainer
@onready var close_button = %CloseButton

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	if not close_button.is_pressed.is_connected(hide):
		close_button.pressed.connect(hide)

func show_cards(cards: Array):
	# Clear previous cards
	for child in grid_container.get_children():
		child.queue_free()

	# Instance and add new cards
	for card_data in cards:
		var card_ui = CardUIScene.instantiate()
		grid_container.add_child(card_ui)
		card_ui.load_card(card_data)

	show()
