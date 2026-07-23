# Soubor: res://scenes/shop/ShopItemUI.gd (Optimalizovaná verze)
extends PanelContainer
class_name ShopItemUI

signal item_purchased(item_data, button_node)
signal card_right_clicked(card_data: CardData)
signal card_hovered(card_data: CardData)
signal card_hover_exited()

@onready var item_content_container: Control = $MarginContainer/VBoxContainer/ItemContent
@onready var price_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/PriceLabel
@onready var sale_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/SaleLabel
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyButton

# Proměnné pro uložení dat
var item_data: Resource
var purchase_cost: int
var is_on_sale: bool = false
var original_price: int = 0
var artifact_stack_info: String = ""
var ui_nodes_ready: bool = false
const SHOP_CARD_SCALE = Vector2(1.0, 1.0)
const SHOP_CARD_MIN_SIZE = CardUI.DESIGN_SIZE

func _ready():
	ui_nodes_ready = true
	
	# Zkontrolujeme, jestli máme všechny potřebné uzly
	if not is_instance_valid(price_label):
		printerr("ShopItemUI: PriceLabel nebyl nalezen!")
	
	if is_instance_valid(sale_label):
		sale_label.visible = false
	else:
		printerr("ShopItemUI: SaleLabel nebyl nalezen!")
	
	if is_instance_valid(buy_button):
		buy_button.pressed.connect(_on_buy_button_pressed)
		buy_button.text = tr("ui.shop.buy")
	else:
		printerr("ShopItemUI: BuyButton nebyl nalezen!")
	
	# Pokud už máme data při inicializaci, zobrazíme je
	if is_instance_valid(item_data):
		_update_display()

func setup_item(p_item_data: Resource, p_cost: int, p_is_on_sale: bool = false, p_original_price: int = 0, p_artifact_stack_info: String = ""):
	"""Nastaví data pro shop item a aktualizuje display"""
	self.item_data = p_item_data
	self.purchase_cost = p_cost
	self.is_on_sale = p_is_on_sale
	self.original_price = p_original_price
	self.artifact_stack_info = p_artifact_stack_info
	
	# Pokud jsou UI uzly připravené, hned aktualizujeme display
	if ui_nodes_ready:
		_update_display()

func _connect_card_tooltip_signals_deferred():
	"""Připojí tooltip signály po vytvoření CardUI"""
	if item_data is CardData and item_content_container.get_child_count() > 0:
		var card_ui = item_content_container.get_child(0)
		if card_ui is CardUI and not card_ui.card_right_clicked.is_connected(_on_card_right_clicked_from_ui):
			card_ui.card_right_clicked.connect(_on_card_right_clicked_from_ui)

func _update_display():
	"""Aktualizuje celý vzhled shop itemu"""
	if not ui_nodes_ready:
		printerr("ShopItemUI: Pokus o update UI předtím, než jsou uzly připravené.")
		return
		
	if not is_instance_valid(item_data):
		printerr("ShopItemUI: Pokus o update UI bez validních item_data.")
		return
	
	# Zobrazíme obsah (kartu nebo artefakt) a nastavíme cenu
	_display_item_content()
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
		if card_ui.has_method("load_card"):
			card_ui.load_card(item_data)
		else:
			card_ui.card_data = item_data
		if card_ui is CardUI:
			card_ui.apply_display_mode(CardUI.DisplayMode.SHOP)
			card_ui.custom_minimum_size = SHOP_CARD_MIN_SIZE
			card_ui.pivot_offset = card_ui.custom_minimum_size * 0.5
			card_ui.position = Vector2.ZERO
		# Po vytvoření CardUI připojíme tooltip signály
		call_deferred("_connect_card_tooltip_signals_deferred")
		call_deferred("_center_card_in_slot", card_ui if card_ui is CardUI else null)
		
	elif item_data is ArtifactsData:
		var artifact_ui = preload("res://scenes/ui/ArtifactChoiceUI.tscn").instantiate()
		item_content_container.add_child(artifact_ui)
		artifact_ui.display_artifact(item_data)
		# Zobrazíme stack info jen pokud je neprázdné (např. Stack +1 (2/3) - ne pro nové artefakty)
		if artifact_stack_info and not artifact_stack_info.is_empty():
			artifact_ui.set_stack_info(artifact_stack_info)
		artifact_ui.scale = Vector2(0.8, 0.8)

func _on_card_right_clicked_from_ui(data: CardData):
	"""Forward CardUI card_right_clicked to ShopItemUI signal"""
	emit_signal("card_right_clicked", data)

func _on_card_mouse_entered():
	if item_data is CardData:
		emit_signal("card_hovered", item_data)

func _on_card_mouse_exited():
	emit_signal("card_hover_exited")

func _center_card_in_slot(card_ui: CardUI) -> void:
	if not is_instance_valid(card_ui) or not is_instance_valid(item_content_container):
		return
	var slot_size = item_content_container.size
	if slot_size.x < 1.0 or slot_size.y < 1.0:
		slot_size = item_content_container.custom_minimum_size
	var card_size = card_ui.get_scaled_size()
	card_ui.position = Vector2(
		maxf(0.0, (slot_size.x - card_size.x) * 0.5),
		maxf(0.0, (slot_size.y - card_size.y) * 0.5)
	)

func _update_price_display():
	"""Aktualizuje zobrazení ceny"""
	if not is_instance_valid(price_label):
		printerr("ShopItemUI: 'PriceLabel' nebyl nalezen!")
		return
	
	price_label.visible = true
	
	if is_on_sale and original_price > 0:
		# Sleva
		price_label.text = TranslationHelper.tr_format("ui.shop.sale_price", {"value": purchase_cost, "original": original_price})
		price_label.modulate = Color.GREEN
		
		if is_instance_valid(sale_label):
			sale_label.text = tr("ui.shop.sale")
			sale_label.visible = true
			sale_label.modulate = Color.RED
	else:
		# Normální cena
		price_label.text = TranslationHelper.tr_format("ui.shop.price", {"value": purchase_cost})
		price_label.modulate = Color.WHITE
		
		if is_instance_valid(sale_label):
			sale_label.visible = false

func _on_buy_button_pressed():
	"""Zpracuje stisknutí tlačítka koupit"""
	emit_signal("item_purchased", item_data, buy_button)

func get_item_data() -> Resource:
	return item_data
