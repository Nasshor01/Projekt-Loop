# Soubor: res://scenes/shop/ShopItemUI.gd (DEFINTIVNÍ A POSLEDNÍ OPRAVA)
extends PanelContainer
class_name ShopItemUI

signal item_purchased(item_data, button_node)

@onready var item_content_container: Control = $MarginContainer/VBoxContainer/ItemContent
@onready var price_label: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/PriceLabel
@onready var sale_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/SaleLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton

# Proměnné pro uložení dat
var item_data: Resource
var purchase_cost: int
var is_on_sale: bool = false
var original_price: int = 0

func _ready():
	# Všechna logika pro nastavení UI je nyní bezpečně v _ready()
	
	# Nejdříve skryjeme label slevy
	sale_label.hide()

	# Zobrazíme správný item (kartu/artefakt)
	if is_instance_valid(item_data):
		_display_item_content()

	# Zobrazíme správnou cenu
	if is_on_sale:
		price_label.text = "[s]%d[/s] [color=green]%d[/color]" % [original_price, purchase_cost]
		price_label.set("rich_text", true)
		sale_label.show()
	else:
		price_label.text = "Cena: %d" % purchase_cost
		
	# Připojíme signál na tlačítko
	if is_instance_valid(buy_button):
		buy_button.pressed.connect(_on_buy_button_pressed)
	else:
		printerr("ShopItemUI: Tlačítko 'BuyButton' nebylo nalezeno!")

# Tato funkce nahrazuje staré set_item a set_on_sale
func setup_item(p_item_data: Resource, p_cost: int, p_is_on_sale: bool = false, p_original_price: int = 0):
	self.item_data = p_item_data
	self.purchase_cost = p_cost
	self.is_on_sale = p_is_on_sale
	self.original_price = p_original_price

func _display_item_content():
	if not is_instance_valid(item_content_container):
		printerr("ShopItemUI: 'ItemContent' kontejner nebyl nalezen!")
		return
		
	for child in item_content_container.get_children():
		child.queue_free()

	if item_data is CardData:
		var card_ui = preload("res://scenes/ui/CardUI.tscn").instantiate()
		item_content_container.add_child(card_ui)
		card_ui.card_data = item_data
		card_ui.scale = Vector2(0.6, 0.6) 
		card_ui.position = Vector2(40, 0)
	elif item_data is ArtifactsData:
		var artifact_ui = preload("res://scenes/ui/ArtifactChoiceUI.tscn").instantiate()
		item_content_container.add_child(artifact_ui)
		artifact_ui.display_artifact(item_data)
		artifact_ui.scale = Vector2(0.8, 0.8)

func _on_buy_button_pressed():
	emit_signal("item_purchased", item_data, buy_button)
