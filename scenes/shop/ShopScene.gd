# Soubor: res://scenes/shop/ShopScene.gd
extends Node2D

const ShopItemUIScene = preload("res://scenes/shop/ShopItemUI.tscn")

const SHOP_CARD_POOL = preload("res://data/cards/shop_card_pool.tres")
const SHOP_ARTIFACT_POOL = preload("res://data/artifacts/basic_artifact_pool.tres")

var rare_card_chance: float = 0.3

@onready var title_label: Label = %TitleLabel
@onready var village_hint_label: Label = %VillageHintLabel
@onready var remove_card_button: Button = %RemoveCardButton
@onready var leave_button: Button = %LeaveButton
@onready var card_pile_viewer = %CardPileViewer
@onready var card_tooltip: CardTooltip = %CardTooltip
var card_slots: Array[LayoutSlot] = []
var artifact_slots: Array[LayoutSlot] = []

var items_on_sale: Dictionary = {}
var _current_tooltip_card_data: CardData = null

func _ready():
	_collect_layout_slots()
	leave_button.gui_input.connect(_on_leave_button_input)
	remove_card_button.pressed.connect(_on_remove_card_button_pressed)
	card_pile_viewer.visibility_changed.connect(_on_viewer_visibility_changed)
	if card_pile_viewer.has_signal("card_right_clicked"):
		card_pile_viewer.card_right_clicked.connect(_on_card_right_clicked)
	if has_node("/root/PlayerData") and not PlayerData.gold_changed.is_connected(_on_gold_changed):
		PlayerData.gold_changed.connect(_on_gold_changed)

	for slot in card_slots:
		if is_instance_valid(slot):
			slot.visible = false
	for slot in artifact_slots:
		if is_instance_valid(slot):
			slot.visible = false

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

func _collect_layout_slots() -> void:
	card_slots.clear()
	artifact_slots.clear()
	var root := get_node_or_null("CanvasLayer/Slots")
	if root == null:
		return
	var i := 0
	while true:
		var slot := root.get_node_or_null("CardSlot_%d" % i) as LayoutSlot
		if slot == null:
			break
		card_slots.append(slot)
		i += 1
	i = 0
	while true:
		var slot := root.get_node_or_null("ArtifactSlot_%d" % i) as LayoutSlot
		if slot == null:
			break
		artifact_slots.append(slot)
		i += 1

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
	_refresh_village_hint()

func _refresh_village_hint() -> void:
	if not is_instance_valid(village_hint_label):
		return
	var hint := ""
	if _all_shop_items().is_empty():
		hint = VillageBonuses.get_shop_empty_hint_text()
	elif VillageBonuses.is_shop_stock_below_max():
		hint = VillageBonuses.get_shop_village_hint_text()
	if hint.is_empty():
		village_hint_label.visible = false
		return
	village_hint_label.text = hint
	village_hint_label.visible = true

func _clear_shop_slots() -> void:
	for slot in card_slots:
		if is_instance_valid(slot):
			slot.clear_mounted()
			slot.visible = false
	for slot in artifact_slots:
		if is_instance_valid(slot):
			slot.clear_mounted()
			slot.visible = false

func _all_shop_items() -> Array:
	var items: Array = []
	for slot in card_slots:
		if not is_instance_valid(slot):
			continue
		var mounted := slot.get_mounted()
		if is_instance_valid(mounted):
			items.append(mounted)
	for slot in artifact_slots:
		if not is_instance_valid(slot):
			continue
		var mounted := slot.get_mounted()
		if is_instance_valid(mounted):
			items.append(mounted)
	return items

func _next_free_card_slot() -> LayoutSlot:
	for slot in card_slots:
		if is_instance_valid(slot) and slot.is_empty():
			return slot
	return null

func _next_free_artifact_slot() -> LayoutSlot:
	for slot in artifact_slots:
		if is_instance_valid(slot) and slot.is_empty():
			return slot
	return null

func _attach_shop_item(shop_item_ui: ShopItemUI, is_artifact: bool = false) -> void:
	var slot: LayoutSlot = _next_free_artifact_slot() if is_artifact else _next_free_card_slot()
	if slot == null:
		push_warning("ShopScene: no free layout slot for item")
		shop_item_ui.queue_free()
		return
	slot.visible = true
	slot.mount(shop_item_ui)
	shop_item_ui.item_purchased.connect(_on_item_purchased)
	shop_item_ui.card_right_clicked.connect(_on_card_right_clicked)
	shop_item_ui.card_hover_exited.connect(_on_card_hover_exited)

func _generate_shop_inventory():
	items_on_sale.clear()
	_clear_shop_slots()

	rare_card_chance = VillageBonuses.get_rare_card_chance()
	var card_offer_count := mini(VillageBonuses.get_shop_card_count(), card_slots.size())
	var cards_to_sell = SHOP_CARD_POOL.pick_weighted_cards(
		card_offer_count,
		rare_card_chance,
		PlayerData.selected_class,
		PlayerData.selected_subclass,
		PlayerData.unlocked_cards,
		VillageBonuses.get_epic_card_chance(),
		VillageBonuses.get_legendary_card_chance()
	)
	if cards_to_sell.is_empty():
		print(tr("log.shop.no_cards"))
		_refresh_village_hint()
		return

	var sale_card = cards_to_sell.pick_random()
	if is_instance_valid(sale_card):
		var sale_price = ShopPricing.card_sale_price(sale_card.rarity)
		if has_node("/root/ArtifactManager"):
			sale_price = ArtifactManager.modify_shop_price(sale_price, sale_card)
		items_on_sale[sale_card] = sale_price

	for card_data in cards_to_sell:
		if not is_instance_valid(card_data):
			continue
		var shop_item_ui = ShopItemUIScene.instantiate()
		var list_price = ShopPricing.card_list_price(card_data.rarity)
		if has_node("/root/ArtifactManager"):
			list_price = ArtifactManager.modify_shop_price(list_price, card_data)
		if items_on_sale.has(card_data):
			shop_item_ui.setup_item(card_data, items_on_sale[card_data], true, list_price)
		else:
			shop_item_ui.setup_item(card_data, list_price)
		_attach_shop_item(shop_item_ui)

	_offer_shop_artifacts()

	_refresh_all_affordability()
	_refresh_village_hint()


func _offer_shop_artifacts() -> void:
	var want := mini(VillageBonuses.get_shop_artifact_count(), artifact_slots.size())
	if want <= 0:
		return
	var available_artifacts = get_available_artifacts(SHOP_ARTIFACT_POOL.artifacts.duplicate())
	if available_artifacts.is_empty():
		return
	available_artifacts.shuffle()
	var offered := 0
	for artifact_to_sell in available_artifacts:
		if offered >= want:
			break
		if not is_instance_valid(artifact_to_sell):
			continue
		var shop_item_ui = ShopItemUIScene.instantiate()
		var stack_info = PlayerData.get_artifact_stack_info(artifact_to_sell.artifact_name)
		var art_price: int = ShopPricing.artifact_price(artifact_to_sell)
		if has_node("/root/ArtifactManager"):
			art_price = ArtifactManager.modify_shop_price(art_price, artifact_to_sell)
		shop_item_ui.setup_item(artifact_to_sell, art_price, false, 0, stack_info)
		_attach_shop_item(shop_item_ui, true)
		offered += 1

func _serialize_shop_inventory() -> Array:
	var result: Array = []
	for child in _all_shop_items():
		if not is_instance_valid(child) or not child.has_method("get_item_data"):
			continue
		var item = child.get_item_data()
		var shown_price: int = child.purchase_cost if child is ShopItemUI else 50
		if item is CardData:
			var is_sale = items_on_sale.has(item)
			var original = ShopPricing.CARD_BASE.get(item.rarity, 50)
			result.append({
				"type": "card",
				"path": item.resource_path,
				"price": shown_price,
				"is_sale": is_sale,
				"original_price": original
			})
		elif item is ArtifactsData:
			result.append({
				"type": "artifact",
				"path": item.resource_path,
				"price": shown_price
			})
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
			_attach_shop_item(shop_item_ui)

		elif item_type == "artifact":
			var artifact = load(path) as ArtifactsData
			if not is_instance_valid(artifact):
				continue
			var shop_item_ui = ShopItemUIScene.instantiate()
			var stack_info = PlayerData.get_artifact_stack_info(artifact.artifact_name)
			shop_item_ui.setup_item(artifact, price, false, 0, stack_info)
			_attach_shop_item(shop_item_ui, true)

	_refresh_all_affordability()
	_refresh_village_hint()

func _on_gold_changed(_new_amount: int = 0) -> void:
	_refresh_all_affordability()

func _refresh_all_affordability() -> void:
	for child in _all_shop_items():
		if child is ShopItemUI:
			child.refresh_affordability()

func _on_item_purchased(item_data: Resource, shop_item: ShopItemUI):
	if not (item_data is CardData or item_data is ArtifactsData):
		return
	# Always prefer the price shown on the shelf (includes Charm of Fortune, sales, free rolls).
	var cost: int = shop_item.purchase_cost if is_instance_valid(shop_item) else -1
	if cost < 0:
		if item_data is CardData:
			cost = items_on_sale[item_data] if items_on_sale.has(item_data) else ShopPricing.card_list_price(item_data.rarity)
		else:
			cost = ShopPricing.artifact_price(item_data as ArtifactsData)
		if has_node("/root/ArtifactManager"):
			cost = ArtifactManager.modify_shop_price(cost, item_data)

	if PlayerData.spend_gold(cost):
		var item_name = ""
		if item_data is CardData:
			item_name = item_data.card_name
			PlayerData.master_deck.append(PlayerData.duplicate_card_for_deck(item_data))
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
		if not is_instance_valid(artifact):
			continue
		if artifact is ArtifactsData and not artifact.in_live_pool:
			continue
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
	return ShopPricing.removal_cost(PlayerData.shop_card_removals_count)

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
	# Avoid stacking the hover tip with the detailed CardTooltip.
	if is_instance_valid(ArtifactHoverTooltip.instance):
		ArtifactHoverTooltip.instance.hide_tip()
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
