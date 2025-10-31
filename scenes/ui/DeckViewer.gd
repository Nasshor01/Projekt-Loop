extends PanelContainer

@onready var grid_container: GridContainer = %GridContainer
@onready var close_button: Button = %CloseButton

var card_scene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	close_button.pressed.connect(hide)
	hide()

func display_deck(deck: Array[CardData]):
	# Vyčistíme staré karty
	for child in grid_container.get_children():
		child.queue_free()

	# Seskupíme karty podle jména a spočítáme jejich počet
	var card_counts = {}
	for card_data in deck:
		if not card_counts.has(card_data.card_name):
			card_counts[card_data.card_name] = {"data": card_data, "count": 0}
		card_counts[card_data.card_name]["count"] += 1

	# Vytvoříme a zobrazíme karty
	for card_name in card_counts:
		var card_info = card_counts[card_name]
		var card_instance = card_scene.instantiate()
		card_instance.load_card(card_info["data"])

		# Přidáme label s počtem karet
		var count_label = Label.new()
		count_label.text = "x%d" % card_info["count"]
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.set("theme_override_font_sizes/font_size", 24)
		count_label.set("theme_override_colors/font_color", Color.WHITE)
		card_instance.add_child(count_label)

		# Napojíme signál pro zobrazení detailu
		card_instance.gui_input.connect(_on_card_gui_input.bind(card_info["data"]))

		grid_container.add_child(card_instance)

	show()

func _on_card_gui_input(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("Detail karty: ", card_data.card_name)
		# Zde se v budoucnu může zobrazit detailní popup
