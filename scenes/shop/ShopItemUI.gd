# Soubor: res://scenes/shop/ShopItemUI.gd
extends PanelContainer
class_name ShopItemUI

signal item_purchased(item_data, button_node)

# --- FINÁLNÍ OPRAVA CEST PODLE TVOJÍ SCÉNY ---
# Cesty nyní začínají od přímých potomků PanelContaineru.
@onready var item_content_container: Control = $MarginContainer/VBoxContainer/ItemContent
@onready var price_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PriceLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton

var item_data: Resource
var purchase_cost: int

func _ready():
	if is_instance_valid(buy_button):
		buy_button.pressed.connect(_on_buy_button_pressed)
	else:
		printerr("ShopItemUI: Tlačítko 'BuyButton' nebylo nalezeno! Zkontroluj cestu ve skriptu: ", buy_button.get_path())


func set_item(p_item_data: Resource, p_cost: int):
	self.item_data = p_item_data
	self.purchase_cost = p_cost
	
	if is_instance_valid(price_label):
		price_label.text = "Cena: %d" % purchase_cost
	
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
