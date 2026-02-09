# Soubor: res://scenes/shop/ShopScene.gd (FINÁLNÍ VERZE S VYLEPŠENÍMI)
extends Node2D

const ShopItemUIScene = preload("res://scenes/shop/ShopItemUI.tscn")

# --- BAZÉNY ZBOŽÍ PRO OBCHOD ---
# Načítáme zdroje z tvých "pool" souborů"
const SHOP_CARD_POOL = preload("res://data/cards/shop_card_pool.tres")
const SHOP_ARTIFACT_POOL = preload("res://data/artifacts/basic_artifact_pool.tres")

# --- DYNAMICKÉ CENY PODLE VZÁCNOSTI ---
const CARD_PRICES = {
	CardData.CardRarity.COMMON: 50,
	CardData.CardRarity.UNCOMMON: 80,
	CardData.CardRarity.RARE: 160,
	# Můžeš doplnit další vzácnosti, např. EPIC, LEGENDARY
}
const ARTIFACT_PRICE = 200
const CARD_REMOVAL_COST = 75

@onready var gold_label: Label = $CanvasLayer/MainContainer/VBoxContainer/Header/GoldDisplay/HBoxContainer/GoldLabel
@onready var title_label: Label = $CanvasLayer/MainContainer/VBoxContainer/Header/TitleLabel
@onready var items_grid: GridContainer = $CanvasLayer/MainContainer/VBoxContainer/ItemsPanel/ScrollContainer/ItemsGrid
@onready var remove_card_button: Button = $CanvasLayer/MainContainer/VBoxContainer/ServicesPanel/HBoxContainer/RemoveCardButton
@onready var leave_button: Button = $CanvasLayer/MainContainer/VBoxContainer/LeaveButton
@onready var card_pile_viewer = $CanvasLayer/MainContainer/CardPileViewer
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip

# Slovník pro uložení zlevněných položek a jejich finálních cen
var items_on_sale: Dictionary = {}

# Tooltip management
var _current_tooltip_card_data: CardData = null

func _ready():
	leave_button.gui_input.connect(_on_leave_button_input)
	remove_card_button.pressed.connect(_on_remove_card_button_pressed)
	PlayerData.gold_changed.connect(_update_gold_label)
	card_pile_viewer.visibility_changed.connect(_on_viewer_visibility_changed)

	_update_ui_texts()
	_update_gold_label(PlayerData.gold)
	_generate_shop_inventory()
func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.shop.title")
	if remove_card_button:
		remove_card_button.text = TranslationHelper.tr_format("ui.shop.remove_card", {"value": CARD_REMOVAL_COST})
	if leave_button:
		leave_button.text = tr("ui.shop.leave")
	
	# Tooltip se nyní zobrazuje/schovává pomocí pravého kliknutí - žádné timery nejsou potřeba


func _generate_shop_inventory():
	items_on_sale.clear()
	for child in items_grid.get_children():
		child.queue_free()

	# KARTY - filtrujeme podle třídy a odemčených karet
	var available_cards = SHOP_CARD_POOL.get_available_cards(
		PlayerData.selected_class,
		PlayerData.selected_subclass,
		PlayerData.unlocked_cards
	)
	if available_cards.is_empty():
		print(tr("log.shop.no_cards"))
		return
	
	available_cards.shuffle()
	var cards_to_sell = available_cards.slice(0, 3)
	
	if not cards_to_sell.is_empty():
		var sale_card = cards_to_sell.pick_random()
		if is_instance_valid(sale_card):
			var original_price = CARD_PRICES.get(sale_card.rarity, 50)
			var sale_price = int(original_price * 0.5)
			items_on_sale[sale_card] = sale_price

		for card_data in cards_to_sell:
			if is_instance_valid(card_data):
				var shop_item_ui = ShopItemUIScene.instantiate()
				var original_price = CARD_PRICES.get(card_data.rarity, 50)
				
				if items_on_sale.has(card_data):
					shop_item_ui.setup_item(card_data, items_on_sale[card_data], true, original_price)
				else:
					shop_item_ui.setup_item(card_data, original_price)
				
				items_grid.add_child(shop_item_ui)
				shop_item_ui.item_purchased.connect(_on_item_purchased)
				shop_item_ui.card_right_clicked.connect(_on_card_right_clicked)

	# ARTEFAKTY - NOVÉ: Filtrujeme dostupné artefakty
	var all_artifacts = SHOP_ARTIFACT_POOL.artifacts.duplicate()
	var available_artifacts = get_available_artifacts(all_artifacts)
	
	if not available_artifacts.is_empty():
		var artifact_to_sell = available_artifacts.pick_random()
		if is_instance_valid(artifact_to_sell):
			var shop_item_ui = ShopItemUIScene.instantiate()
			
			# Zobrazíme stack info v názvu
			var stack_info = PlayerData.get_artifact_stack_info(artifact_to_sell.artifact_name)
			shop_item_ui.setup_item(artifact_to_sell, ARTIFACT_PRICE, false, 0, stack_info)
			items_grid.add_child(shop_item_ui)
			shop_item_ui.item_purchased.connect(_on_item_purchased)


func _on_item_purchased(item_data: Resource, button_node: Button):
	var cost: int
	if item_data is CardData:
		# Zkontrolujeme, jestli je item ve slevě, abychom odečetli správnou cenu
		if items_on_sale.has(item_data):
			cost = items_on_sale[item_data]
		else:
			cost = CARD_PRICES.get(item_data.rarity, 50)
	elif item_data is ArtifactsData:
		cost = ARTIFACT_PRICE
	else:
		return

	if PlayerData.spend_gold(cost):
		var item_name = ""
		if item_data is CardData:
			item_name = item_data.card_name
		elif item_data is ArtifactsData:
			item_name = item_data.artifact_name
		print(TranslationHelper.tr_format("log.shop.purchased", {"name": tr(item_name)}))

		if item_data is CardData:
			PlayerData.master_deck.append(item_data)
			button_node.disabled = true
			button_node.text = tr("ui.shop.purchased")
		elif item_data is ArtifactsData:
			# OPRAVENO: Používáme novou add_artifact funkci
			if PlayerData.add_artifact(item_data):
				button_node.disabled = true
				button_node.text = tr("ui.shop.purchased")
				print(tr("log.shop.artifact_purchased"))
			else:
				# Tohle by se nemělo stát díky filtrování, ale pro jistotu
				print(tr("log.shop.cannot_buy_artifact"))
				# Vrátíme zlato
				PlayerData.add_gold(cost)
	else:
		print(tr("log.shop.not_enough_gold"))

func get_available_artifacts(artifact_pool: Array) -> Array:
	"""Filtruje artefakty které hráč může získat"""
	var available = []
	
	for artifact in artifact_pool:
		if PlayerData.can_gain_artifact(artifact):
			available.append(artifact)
	
	return available

func _on_leave_button_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		GameManager.leave_shop()

func _on_leave_button_pressed():
	pass

func _update_gold_label(new_amount: int):
	if is_instance_valid(gold_label):
		gold_label.text = TranslationHelper.tr_format("ui.shop.gold", {"value": new_amount})

func _on_remove_card_button_pressed():
	if PlayerData.gold >= CARD_REMOVAL_COST:
		card_pile_viewer.show_cards(PlayerData.master_deck, Vector2(0.7, 0.7))
		if not card_pile_viewer.is_connected("card_clicked_in_viewer", _on_card_selected_for_removal):
			card_pile_viewer.card_clicked_in_viewer.connect(_on_card_selected_for_removal)
		_connect_pile_card_clicks()
	else:
		print(tr("ui.shop.not_enough_gold_remove"))
		remove_card_button.self_modulate = Color.RED
		var tween = create_tween()
		tween.tween_interval(0.5)
		tween.tween_property(remove_card_button, "self_modulate", Color.WHITE, 0.3)

func _on_viewer_visibility_changed():
	if card_pile_viewer.visible:
		_connect_pile_card_clicks()

func _connect_pile_card_clicks():
	for card_ui in card_pile_viewer.grid_container.get_children():
		if card_ui is CardUI:
			if not card_ui.is_connected("card_clicked", _on_card_selected_for_removal):
				card_ui.card_clicked.connect(_on_card_selected_for_removal)
			if not card_ui.is_connected("card_right_clicked", _on_card_right_clicked):
				card_ui.card_right_clicked.connect(_on_card_right_clicked)

func _on_card_right_clicked(card_data: CardData):
	"""Toggle tooltip při pravém kliknutí na kartu"""
	if not card_tooltip:
		return
	
	# Pokud je tooltip zobrazený pro tuto kartu, schováme ho
	if card_tooltip.visible and _current_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null
	else:
		# Jinak zobrazíme tooltip pro tuto kartu
		_current_tooltip_card_data = card_data
		_show_card_tooltip()

func _show_card_tooltip():
	"""Zobrazí tooltip pro aktuálně vybranou kartu"""
	if not _current_tooltip_card_data or not card_tooltip:
		return
	
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(350, 250)
	
	# Zobrazíme tooltip v pravém horním rohu (offset 20px od okrajů)
	var tooltip_pos = Vector2(
		screen_size.x - tooltip_size.x - 20,
		20
	)
	
	# Kontrola, aby tooltip nevyšel z obrazovky
	if tooltip_pos.x + tooltip_size.x > screen_size.x:
		tooltip_pos.x = screen_size.x - tooltip_size.x - 10
	if tooltip_pos.y + tooltip_size.y > screen_size.y:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 10
	if tooltip_pos.x < 0:
		tooltip_pos.x = 10
	if tooltip_pos.y < 0:
		tooltip_pos.y = 10
	
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)

func _on_card_hovered(card_data: CardData):
	if not card_tooltip:
		return
	_current_tooltip_card_data = card_data
	_show_card_tooltip()

func _on_card_hover_exited():
	if not card_tooltip:
		return
	card_tooltip.hide_tooltip()
	_current_tooltip_card_data = null

func _on_card_selected_for_removal(card_data: CardData):
	if PlayerData.spend_gold(CARD_REMOVAL_COST):
		PlayerData.master_deck.erase(card_data)
		print(TranslationHelper.tr_format("log.shop.card_removed", {"name": card_data.card_name}))
		card_pile_viewer.hide()
	else:
		print(tr("log.shop.removal_error"))
