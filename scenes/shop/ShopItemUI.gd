# Soubor: res://scenes/shop/ShopItemUI.gd (OPRAVENÁ VERZE S FUNGUJÍCÍMI CENAMI)
extends PanelContainer
class_name ShopItemUI

signal item_purchased(item_data, button_node)

@onready var item_content_container: Control = $MarginContainer/VBoxContainer/ItemContent
@onready var price_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PriceLabel
@onready var sale_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/SaleLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton

# Proměnné pro uložení dat
var item_data: Resource
var purchase_cost: int
var is_on_sale: bool = false
var original_price: int = 0
var ui_nodes_ready: bool = false

func _ready():
	print("ShopItemUI: _ready() volán")
	ui_nodes_ready = true
	
	# Zkontrolujeme, jestli máme všechny potřebné uzly
	if not is_instance_valid(price_label):
		printerr("ShopItemUI: PriceLabel nebyl nalezen!")
	else:
		print("ShopItemUI: PriceLabel nalezen")
	
	if not is_instance_valid(sale_label):
		printerr("ShopItemUI: SaleLabel nebyl nalezen!")
	else:
		print("ShopItemUI: SaleLabel nalezen a skrývám ho")
		sale_label.visible = false
	
	if not is_instance_valid(buy_button):
		printerr("ShopItemUI: BuyButton nebyl nalezen!")
	else:
		print("ShopItemUI: BuyButton nalezen a připojujem signál")
		buy_button.pressed.connect(_on_buy_button_pressed)
	
	# Pokud už máme data, zobrazíme je
	if is_instance_valid(item_data):
		print("ShopItemUI: Mám data, volám _update_display()")
		_update_display()
	else:
		print("ShopItemUI: Ještě nemám data")

func setup_item(p_item_data: Resource, p_cost: int, p_is_on_sale: bool = false, p_original_price: int = 0):
	"""Nastaví data pro shop item a aktualizuje display"""
	print("ShopItemUI: setup_item() volán s cenou %d, sleva: %s" % [p_cost, p_is_on_sale])
	
	self.item_data = p_item_data
	self.purchase_cost = p_cost
	self.is_on_sale = p_is_on_sale
	self.original_price = p_original_price
	
	# Debug info o item_data
	if item_data:
		var item_name = "Unknown"
		if "card_name" in item_data:
			item_name = item_data.card_name
		elif "artifact_name" in item_data:
			item_name = item_data.artifact_name
		print("ShopItemUI: Nastavuji item: %s" % item_name)
	
	# Pokud jsou UI uzly připravené, hned aktualizujeme display
	if ui_nodes_ready:
		print("ShopItemUI: UI uzly připravené, volám _update_display()")
		_update_display()
	else:
		print("ShopItemUI: UI uzly ještě nejsou připravené")

func _update_display():
	"""Aktualizuje celý vzhled shop itemu"""
	print("ShopItemUI: _update_display() volán")
	
	if not ui_nodes_ready:
		print("ShopItemUI: UI uzly nejsou připravené!")
		return
		
	if not is_instance_valid(item_data):
		print("ShopItemUI: item_data není validní!")
		return
	
	print("ShopItemUI: Zobrazuji obsah a cenu")
	
	# Zobrazíme obsah (kartu nebo artefakt)
	_display_item_content()
	
	# Nastavíme cenu
	_update_price_display()

func _display_item_content():
	"""Zobrazí kartu nebo artefakt v kontejneru"""
	if not is_instance_valid(item_content_container):
		printerr("ShopItemUI: 'ItemContent' kontejner nebyl nalezen!")
		return
		
	# Vyčistíme starý obsah
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

func _update_price_display():
	"""Aktualizuje zobrazení ceny"""
	if not is_instance_valid(price_label):
		printerr("ShopItemUI: 'PriceLabel' nebyl nalezen!")
		return
	
	# DEBUGOVACÍ VÝPISY
	print("ShopItemUI: Nastavuji cenu %d, sleva: %s" % [purchase_cost, is_on_sale])
	
	# Zajistíme viditelnost
	price_label.visible = true
	price_label.modulate = Color.WHITE
	
	if is_on_sale and original_price > 0:
		# Sleva - zobrazíme jen novou cenu s "SLEVA!"
		price_label.text = "SLEVA: %d (původně %d)" % [purchase_cost, original_price]
		price_label.modulate = Color.GREEN
		
		if is_instance_valid(sale_label):
			sale_label.text = "SLEVA!"
			sale_label.visible = true
			sale_label.modulate = Color.RED
	else:
		# Normální cena - obyčejný text
		price_label.text = "Cena: %d" % purchase_cost
		price_label.modulate = Color.WHITE
		
		if is_instance_valid(sale_label):
			sale_label.visible = false
	
	print("ShopItemUI: Text nastavený na: '%s'" % price_label.text)

func _on_buy_button_pressed():
	"""Zpracuje stisknutí tlačítka koupit"""
	emit_signal("item_purchased", item_data, buy_button)
