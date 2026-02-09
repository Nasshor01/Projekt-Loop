extends PanelContainer

signal card_selected(card_data: CardData)
signal card_clicked_in_viewer(card_data)

@onready var grid_container: GridContainer = %GridContainer
@onready var close_button: Button = %CloseButton
@onready var title_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/Label

var card_scene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	close_button.pressed.connect(hide)
	_update_ui_texts()
	hide() # Začíná skrytý

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.deck_viewer.title_full")
	if close_button:
		close_button.text = tr("ui.common.close")


## Zobrazí každou kartu individuálně.
func show_cards(cards: Array[CardData], card_scale: Vector2 = Vector2(0.7, 0.7)):
	# 1. Vyčisti všechny staré karty
	_clear_grid()

	# 2. Vytvoř a zobraz nové karty (každou zvlášť)
	for card_data in cards:
		if not is_instance_valid(card_data):
			continue
			
		var card_instance = card_scene.instantiate()
		
		# Použijeme metodu 'load_card' z tvého skriptu
		card_instance.load_card(card_data) 
		if card_instance is CardUI:
			card_instance.is_draggable = false
			card_instance.static_layout = true
			card_instance.custom_minimum_size = Vector2(200, 300)
			card_instance.pivot_offset = card_instance.custom_minimum_size * 0.5
			card_instance.set_target_scale(card_scale)
			card_instance.scale = card_scale
			if not card_instance.is_connected("card_clicked", _on_card_clicked_in_viewer):
				card_instance.card_clicked.connect(_on_card_clicked_in_viewer)
			call_deferred("_sync_deck_card_layout", card_instance)
		else:
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
		if card_instance is CardUI:
			card_instance.is_draggable = false
			card_instance.static_layout = true
			card_instance.custom_minimum_size = Vector2(200, 300)
			card_instance.pivot_offset = card_instance.custom_minimum_size * 0.5
			card_instance.set_target_scale(Vector2(0.7, 0.7))
			card_instance.scale = Vector2(0.7, 0.7)
			if not card_instance.is_connected("card_clicked", _on_card_clicked_in_viewer):
				card_instance.card_clicked.connect(_on_card_clicked_in_viewer)
			call_deferred("_sync_deck_card_layout", card_instance)

		# Přidáme label s počtem karet
		var count_label = Label.new()
		count_label.text = TranslationHelper.tr_format("ui.deck_viewer.count", {"value": card_info["count"]})
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
		print(tr("ui.deck_viewer.detail_card") + " " + card_data.get_localized_name())
		# Zde se v budoucnu může zobrazit detailní popup


## --- NOVÉ POMOCNÉ FUNKCE ---
func hide_and_clear():
	hide()
	_clear_grid()

func _clear_grid():
	for child in grid_container.get_children():
		child.queue_free()

func _sync_deck_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)
	card_ui.set_target_scale(card_ui.scale)

func _on_card_clicked_in_viewer(card_data: CardData):
	card_clicked_in_viewer.emit(card_data)
