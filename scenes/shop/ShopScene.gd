# Soubor: res://scenes/shop/ShopScene.gd
extends Node2D

const ShopItemUIScene = preload("res://scenes/shop/ShopItemUI.tscn")

const SHOP_CARD_POOL = preload("res://data/cards/shop_card_pool.tres")
const SHOP_ARTIFACT_POOL = preload("res://data/artifacts/basic_artifact_pool.tres")

const CARD_PRICES = {
	CardData.CardRarity.BASIC: 30,
	CardData.CardRarity.COMMON: 50,
	CardData.CardRarity.UNCOMMON: 50, ## deprecated → same as Common
	CardData.CardRarity.RARE: 120,
	CardData.CardRarity.EPIC: 200,
	CardData.CardRarity.LEGENDARY: 300,
}
const ARTIFACT_PRICE = 200
const CARD_REMOVAL_BASE_COST = 75
const CARD_REMOVAL_INCREMENT = 25
var rare_card_chance: float = 0.1

@onready var title_label: Label = %TitleLabel
@onready var cards_row: HBoxContainer = %CardsRow
@onready var relic_slot: HBoxContainer = %RelicSlot
@onready var remove_card_button: Button = %RemoveCardButton
@onready var leave_button: Button = %LeaveButton
@onready var card_pile_viewer = %CardPileViewer
@onready var card_tooltip: CardTooltip = %CardTooltip

var items_on_sale: Dictionary = {}
var _current_tooltip_card_data: CardData = null

func _ready():
	leave_button.gui_input.connect(_on_leave_button_input)
	remove_card_button.pressed.connect(_on_remove_card_button_pressed)
	card_pile_viewer.visibility_changed.connect(_on_viewer_visibility_changed)
	if card_pile_viewer.has_signal("card_right_clicked"):
		card_pile_viewer.card_right_clicked.connect(_on_card_right_clicked)
	if has_node("/root/PlayerData") and not PlayerData.gold_changed.is_connected(_on_gold_changed):
		PlayerData.gold_changed.connect(_on_gold_changed)

	_update_ui_texts()

	if _is_coop_run() and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server():
		var pending = GameManager._coop_pending_shop_items
		if not pending.is_empty():
			_generate_shop_from_host_data(pending)
			GameManager._coop_pending_shop_items = []
		else:
			_wait_for_shop_data()
	else:
		_generate_shop_inventory()
		if _is_coop_run() and has_node("/root/MultiplayerManager") and MultiplayerManager.is_server():
			var shop_data = _serialize_shop_inventory()
			MultiplayerManager.rpc("receive_go_to_shop", shop_data)

func _is_coop_run() -> bool:
	return has_node("/root/GameManager") and GameManager.is_coop_run

func _wait_for_shop_data():
	for i in range(50):
		await get_tree().create_timer(0.1).timeout
		var pending = GameManager._coop_pending_shop_items
		if not pending.is_empty():
			_generate_shop_from_host_data(pending)
			GameManager._coop_pending_shop_items = []
			return
	_generate_shop_inventory()

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.shop.title")
	if remove_card_button:
		remove_card_button.text = TranslationHelper.tr_format("ui.shop.remove_card", {"value": get_card_removal_cost()})
	if leave_button:
		leave_button.text = tr("ui.shop.leave")

func _clear_shop_slots() -> void:
	for child in cards_row.get_children():
		child.queue_free()
	for child in relic_slot.get_children():
		child.queue_free()

func _all_shop_items() -> Array:
	var items: Array = []
	items.append_array(cards_row.get_children())
	items.append_array(relic_slot.get_children())
	return items

func _attach_shop_item(shop_item_ui: ShopItemUI, parent: Control) -> void:
	parent.add_child(shop_item_ui)
	shop_item_ui.item_purchased.connect(_on_item_purchased)
	shop_item_ui.card_right_clicked.connect(_on_card_right_clicked)
	shop_item_ui.card_hover_exited.connect(_on_card_hover_exited)

func _generate_shop_inventory():
	items_on_sale.clear()
	_clear_shop_slots()

	rare_card_chance = VillageBonuses.get_rare_card_chance()
	var cards_to_sell = SHOP_CARD_POOL.pick_weighted_cards(
		VillageBonuses.get_shop_card_count(),
		rare_card_chance,
		PlayerData.selected_class,
		PlayerData.selected_subclass,
		PlayerData.unlocked_cards,
		VillageBonuses.get_epic_card_chance(),
		VillageBonuses.get_legendary_card_chance()
	)
	if cards_to_sell.is_empty():
		print(tr("log.shop.no_cards"))
		return

	var sale_card = cards_to_sell.pick_random()
	if is_instance_valid(sale_card):
		var original_price = CARD_PRICES.get(sale_card.rarity, 50)
		items_on_sale[sale_card] = int(original_price * 0.5)

	for card_data in cards_to_sell:
		if not is_instance_valid(card_data):
			continue
		var shop_item_ui = ShopItemUIScene.instantiate()
		var original_price = CARD_PRICES.get(card_data.rarity, 50)
		if items_on_sale.has(card_data):
			shop_item_ui.setup_item(card_data, items_on_sale[card_data], true, original_price)
		else:
			shop_item_ui.setup_item(card_data, original_price)
		_attach_shop_item(shop_item_ui, cards_row)

	var available_artifacts = get_available_artifacts(SHOP_ARTIFACT_POOL.artifacts.duplicate())
	if not available_artifacts.is_empty():
		var artifact_to_sell = available_artifacts.pick_random()
		if is_instance_valid(artifact_to_sell):
			var shop_item_ui = ShopItemUIScene.instantiate()
			var stack_info = PlayerData.get_artifact_stack_info(artifact_to_sell.artifact_name)
			shop_item_ui.setup_item(artifact_to_sell, ARTIFACT_PRICE, false, 0, stack_info)
			_attach_shop_item(shop_item_ui, relic_slot)

	_refresh_all_affordability()

func _serialize_shop_inventory() -> Array:
	var result: Array = []
	for child in _all_shop_items():
		if not is_instance_valid(child) or not child.has_method("get_item_data"):
			continue
		var item = child.get_item_data()
		if item is CardData:
			var is_sale = items_on_sale.has(item)
			var price = items_on_sale[item] if is_sale else CARD_PRICES.get(item.rarity, 50)
			var original = CARD_PRICES.get(item.rarity, 50)
			result.append({"type": "card", "path": item.resource_path, "price": price, "is_sale": is_sale, "original_price": original})
		elif item is ArtifactsData:
			result.append({"type": "artifact", "path": item.resource_path, "price": ARTIFACT_PRICE})
	return result

func _generate_shop_from_host_data(data: Array):
	items_on_sale.clear()
	_clear_shop_slots()

	for entry in data:
		var item_type: String = entry.get("type", "")
		var path: String = entry.get("path", "")
		var price: int = int(entry.get("price", 50))

		if item_type == "card":
			var card = load(path) as CardData
			if not is_instance_valid(card):
				continue
			var is_sale: bool = entry.get("is_sale", false)
			var original_price: int = int(entry.get("original_price", price))
			if is_sale:
				items_on_sale[card] = price
			var shop_item_ui = ShopItemUIScene.instantiate()
			if is_sale:
				shop_item_ui.setup_item(card, price, true, original_price)
			else:
				shop_item_ui.setup_item(card, price)
			_attach_shop_item(shop_item_ui, cards_row)

		elif item_type == "artifact":
			var artifact = load(path) as ArtifactsData
			if not is_instance_valid(artifact):
				continue
			var shop_item_ui = ShopItemUIScene.instantiate()
			var stack_info = PlayerData.get_artifact_stack_info(artifact.artifact_name)
			shop_item_ui.setup_item(artifact, ARTIFACT_PRICE, false, 0, stack_info)
			_attach_shop_item(shop_item_ui, relic_slot)

	_refresh_all_affordability()

func _on_gold_changed(_new_amount: int = 0) -> void:
	_refresh_all_affordability()

func _refresh_all_affordability() -> void:
	for child in _all_shop_items():
		if child is ShopItemUI:
			child.refresh_affordability()

func _on_item_purchased(item_data: Resource, shop_item: ShopItemUI):
	var cost: int
	if item_data is CardData:
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
			PlayerData.master_deck.append(item_data)
			shop_item.mark_purchased()
		elif item_data is ArtifactsData:
			item_name = item_data.artifact_name
			if PlayerData.add_artifact(item_data):
				shop_item.mark_purchased()
				print(tr("log.shop.artifact_purchased"))
			else:
				print(tr("log.shop.cannot_buy_artifact"))
				PlayerData.add_gold(cost)
				return
		print(TranslationHelper.tr_format("log.shop.purchased", {"name": tr(item_name)}))
		_refresh_all_affordability()
	else:
		print(tr("log.shop.not_enough_gold"))
		_refresh_all_affordability()

func get_available_artifacts(artifact_pool: Array) -> Array:
	var available = []
	for artifact in artifact_pool:
		if PlayerData.can_gain_artifact(artifact):
			available.append(artifact)
	return available

var _coop_my_ready: bool = false
var _coop_other_ready: bool = false

func _on_leave_button_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed():
		if _is_coop_run() and has_node("/root/MultiplayerManager"):
			_coop_my_ready = true
			leave_button.disabled = true
			leave_button.text = tr("ui.rest.waiting")
			rpc("_rpc_shop_peer_ready")
			_shop_check_both_ready()
		else:
			GameManager.leave_shop()

@rpc("any_peer", "call_remote")
func _rpc_shop_peer_ready():
	_coop_other_ready = true
	_shop_check_both_ready()

func _shop_check_both_ready():
	if _coop_my_ready and _coop_other_ready:
		GameManager.leave_shop()

func get_card_removal_cost() -> int:
	return CARD_REMOVAL_BASE_COST + PlayerData.shop_card_removals_count * CARD_REMOVAL_INCREMENT

func _on_remove_card_button_pressed():
	if PlayerData.gold >= get_card_removal_cost():
		card_pile_viewer.show_cards(PlayerData.master_deck)
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
		if card_ui is CardUI and not card_ui.is_connected("card_clicked", _on_card_selected_for_removal):
			card_ui.card_clicked.connect(_on_card_selected_for_removal)

func _on_card_right_clicked(card_data: CardData):
	if not card_tooltip:
		return
	if card_tooltip.visible and _current_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null
	else:
		_current_tooltip_card_data = card_data
		_show_card_tooltip()

func _on_card_hover_exited(card_data: CardData) -> void:
	if not card_tooltip or not card_tooltip.visible or _current_tooltip_card_data == null or card_data == null:
		return
	var same := card_data == _current_tooltip_card_data
	if not same and not card_data.resource_path.is_empty() and not _current_tooltip_card_data.resource_path.is_empty():
		same = card_data.resource_path == _current_tooltip_card_data.resource_path
	if same:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null

func _show_card_tooltip():
	if not _current_tooltip_card_data or not card_tooltip:
		return
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(360, 420)
	var tooltip_pos = Vector2(screen_size.x - tooltip_size.x - 20, 90)
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)

func _on_card_selected_for_removal(card_data: CardData):
	var cost = get_card_removal_cost()
	if PlayerData.spend_gold(cost):
		PlayerData.shop_card_removals_count += 1
		PlayerData.master_deck.erase(card_data)
		remove_card_button.text = TranslationHelper.tr_format("ui.shop.remove_card", {"value": get_card_removal_cost()})
		print(TranslationHelper.tr_format("log.shop.card_removed", {"name": card_data.card_name}))
		card_pile_viewer.hide()
		_refresh_all_affordability()
	else:
		print(tr("log.shop.removal_error"))
