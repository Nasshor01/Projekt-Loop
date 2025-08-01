# Soubor: res://scenes/shop/ShopScene.gd (DEFINTIVNÍ A FINÁLNÍ OPRAVA)
extends Node2D

const ShopItemUIScene = preload("res://scenes/shop/ShopItemUI.tscn")

# --- BAZÉNY ZBOŽÍ PRO OBCHOD ---
# Můžeme je později načítat ze souboru, ale takto je to přehlednější
var shop_card_pool = [
	load("res://data/cards/paladin/smite.tres"),
	load("res://data/cards/paladin/holy_wave.tres"),
	load("res://data/cards/everyone/heavy_strike.tres"),
	# Přidej sem další karty, které se mohou objevit v obchodě
]
var shop_artifact_pool = [
	load("res://data/artifacts/basic/ManaKrystal.tres"),
	load("res://data/artifacts/basic/OstnatýNáhrdelník.tres"),
]
# -----------------------------

# --- DYNAMICKÉ CENY PODLE VZÁCNOSTI ---
const CARD_PRICES = {
	CardData.CardRarity.COMMON: 50,
	CardData.CardRarity.UNCOMMON: 75,
	CardData.CardRarity.RARE: 150,
	# Doplň další vzácnosti a jejich ceny
}
const ARTIFACT_PRICE = 200
const CARD_REMOVAL_COST = 75
# ------------------------------------
@onready var gold_label: Label = $CanvasLayer/MainContainer/VBoxContainer/Header/GoldDisplay/HBoxContainer/GoldLabel
@onready var items_grid: GridContainer = $CanvasLayer/MainContainer/VBoxContainer/ItemsPanel/ScrollContainer/ItemsGrid
@onready var remove_card_button: Button = $CanvasLayer/MainContainer/VBoxContainer/ServicesPanel/HBoxContainer/RemoveCardButton
@onready var leave_button: Button = $CanvasLayer/MainContainer/VBoxContainer/LeaveButton
@onready var card_pile_viewer = $CanvasLayer/MainContainer/CardPileViewer

func _ready():
	# Připojení signálů zůstává stejné
	leave_button.gui_input.connect(_on_leave_button_input)
	remove_card_button.pressed.connect(_on_remove_card_button_pressed)
	PlayerData.gold_changed.connect(_update_gold_label)
	card_pile_viewer.visibility_changed.connect(_on_viewer_visibility_changed)

	_update_gold_label(PlayerData.gold)
	_generate_shop_inventory()

# --- NOVÁ FUNKCE PRO TLAČÍTKO ODEJÍT ---
func _on_leave_button_input(event: InputEvent):
	# Obchod se zavře, jen pokud hráč tlačítko myši NAD TLAČÍTKEM UVOLNÍ.
	# Tím se ignoruje původní kliknutí, které scénu otevřelo.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		GameManager.leave_shop()

# Stará funkce pro odchod už není potřeba, můžeme ji nechat prázdnou nebo smazat
func _on_leave_button_pressed():
	pass
# -----------------------------------------

func _generate_shop_inventory():
	for child in items_grid.get_children():
		child.queue_free()

	# -- Generování karet s dynamickou cenou --
	var available_cards = shop_card_pool.duplicate()
	available_cards.shuffle()
	var cards_to_sell = available_cards.slice(0, 3) # Nabídneme 3 náhodné karty z poolu

	for card_data in cards_to_sell:
		if is_instance_valid(card_data):
			# Získáme cenu z našeho slovníku, defaultně 50, pokud by vzácnost nebyla nalezena
			var cost = CARD_PRICES.get(card_data.rarity, 50)
			
			var shop_item_ui = ShopItemUIScene.instantiate()
			items_grid.add_child(shop_item_ui)
			# Předáme do UI i cenu, kterou jsme vypočítali
			shop_item_ui.set_item(card_data, cost)
			shop_item_ui.item_purchased.connect(_on_item_purchased)

	# -- Generování artefaktu --
	var available_artifacts = shop_artifact_pool.duplicate()
	if not available_artifacts.is_empty():
		var artifact_to_sell = available_artifacts.pick_random()
		if is_instance_valid(artifact_to_sell):
			var shop_item_ui = ShopItemUIScene.instantiate()
			items_grid.add_child(shop_item_ui)
			shop_item_ui.set_item(artifact_to_sell, ARTIFACT_PRICE)
			shop_item_ui.item_purchased.connect(_on_item_purchased)




func _update_gold_label(new_amount: int):
	if is_instance_valid(gold_label):
		gold_label.text = "Zlato: %d" % new_amount


func _on_item_purchased(item_data: Resource, button_node: Button):
	var cost: int
	if item_data is CardData:
		# Znovu zjistíme cenu, abychom ji nemuseli předávat signálem
		cost = CARD_PRICES.get(item_data.rarity, 50)
	elif item_data is ArtifactsData:
		cost = ARTIFACT_PRICE
	else:
		return

	if PlayerData.spend_gold(cost):
		var item_name = item_data.get("card_name") or item_data.get("artifact_name")
		print("Koupeno: ", item_name)
		button_node.disabled = true
		button_node.text = "Koupeno"

		if item_data is CardData:
			PlayerData.master_deck.append(item_data)
		elif item_data is ArtifactsData:
			PlayerData.add_artifact(item_data)
	else:
		print("Nedostatek zlata!")


func _on_remove_card_button_pressed():
	if PlayerData.gold >= CARD_REMOVAL_COST:
		card_pile_viewer.show_cards(PlayerData.master_deck)
	else:
		print("Nemáš dostatek zlata na odstranění karty!")
		remove_card_button.self_modulate = Color.RED
		var tween = create_tween()
		tween.tween_interval(0.5)
		tween.tween_property(remove_card_button, "self_modulate", Color.WHITE, 0.3)


func _on_viewer_visibility_changed():
	if card_pile_viewer.visible:
		for card_ui in card_pile_viewer.grid_container.get_children():
			if card_ui is CardUI:
				if not card_ui.is_connected("gui_input", _on_card_in_viewer_clicked):
					card_ui.gui_input.connect(_on_card_in_viewer_clicked.bind(card_ui.card_data))


func _on_card_in_viewer_clicked(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if PlayerData.spend_gold(CARD_REMOVAL_COST):
			PlayerData.master_deck.erase(card_data)
			print("Karta '%s' byla odstraněna z balíčku." % card_data.card_name)
			card_pile_viewer.hide()
		else:
			print("Chyba: Nedostatek zlata při pokusu o odstranění.")
