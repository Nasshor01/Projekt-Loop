# ===================================================================
# Soubor: res://scenes/ui/CardPileViewer.gd
# ===================================================================
extends PanelContainer

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var close_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/Control/CloseButton

func _ready():
	visible = false
	if is_instance_valid(close_button):
		close_button.pressed.connect(hide)
	else:
		printerr("CardPileViewer: Tlačítko 'CloseButton' nebylo nalezeno! Zkontroluj strukturu scény a cestu ve skriptu.")

func show_cards(cards: Array[CardData]):
	if not is_instance_valid(grid_container):
		printerr("CardPileViewer: 'GridContainer' nebyl nalezen!")
		return

	for child in grid_container.get_children():
		child.queue_free()

	if cards.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Balíček je prázdný."
		grid_container.add_child(empty_label)
	else:
		for card_data in cards:
			if not is_instance_valid(card_data): continue
			
			var card_ui_instance = CardUIScene.instantiate()
			card_ui_instance.card_data = card_data
			card_ui_instance.scale = Vector2(0.7, 0.7)
			grid_container.add_child(card_ui_instance)
	show()
