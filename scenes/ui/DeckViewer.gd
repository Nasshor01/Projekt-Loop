extends PanelContainer

signal card_selected(card_data: CardData)

@onready var grid_container: GridContainer = %GridContainer
@onready var close_button: Button = %CloseButton

var card_scene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	close_button.pressed.connect(hide)
	hide() # Začíná skrytý


## Zobrazí každou kartu individuálně.
func show_cards(cards: Array[CardData], card_scale: Vector2 = Vector2(1.0, 1.0)):
	# 1. Vyčisti všechny staré karty
	_clear_grid()

	# 2. Vytvoř a zobraz nové karty (každou zvlášť)
	for card_data in cards:
		if not is_instance_valid(card_data):
			continue
			
		var card_instance = card_scene.instantiate()
		
		# Použijeme metodu 'load_card' z tvého skriptu
		card_instance.load_card(card_data) 
		card_instance.scale = card_scale
		
		# 3. Připoj signál pro kliknutí k NOVÉMU handleru
		card_instance.gui_input.connect(_on_card_selected_input.bind(card_data))
		
		grid_container.add_child(card_instance)

	# 4. Zobraz celý panel
	self.show()


## Zavolá se, když se klikne na kartu zobrazenou přes 'show_cards'
func _on_card_selected_input(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Kliknuto! Vyšleme náš hlavní signál 'card_selected' ven.
		card_selected.emit(card_data)
		
		# Po výběru se viewer rovnou skryje a vyčistí
		hide_and_clear()

## Toto je funkce pro ZOBRAZENÍ DECKU (s počítáním)
func display_deck(deck: Array[CardData]):
	# Vyčistíme staré karty
	_clear_grid()

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
		card_instance.load_card(card_info["data"]) # Používáme 'load_card'

		# Přidáme label s počtem karet
		var count_label = Label.new()
		count_label.text = "x%d" % card_info["count"]
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.set("theme_override_font_sizes/font_size", 24)
		count_label.set("theme_override_colors/font_color", Color.WHITE)
		card_instance.add_child(count_label)

		# Napojíme signál pro zobrazení detailu na PŮVODNÍ handler
		card_instance.gui_input.connect(_on_card_gui_input.bind(card_info["data"]))

		grid_container.add_child(card_instance)

	show()


## Zavolá se, když se klikne na kartu zobrazenou přes 'display_deck'
func _on_card_gui_input(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		print("Detail karty: ", card_data.card_name)
		# Zde se v budoucnu může zobrazit detailní popup


## --- NOVÉ POMOCNÉ FUNKCE ---
func hide_and_clear():
	hide()
	_clear_grid()

func _clear_grid():
	for child in grid_container.get_children():
		child.queue_free()
