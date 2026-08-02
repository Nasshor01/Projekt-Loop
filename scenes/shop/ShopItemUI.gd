# Soubor: res://scenes/shop/ShopItemUI.gd
extends VBoxContainer
class_name ShopItemUI

signal item_purchased(item_data, shop_item_ui)
signal card_right_clicked(card_data: CardData)
signal card_hovered(card_data: CardData)
signal card_hover_exited(card_data: CardData)

@onready var item_content_container: Control = %ItemContent
@onready var price_label: Label = %PriceLabel
@onready var sale_label: Label = %SaleLabel

var item_data: Resource
var purchase_cost: int
var is_on_sale: bool = false
var original_price: int = 0
var artifact_stack_info: String = ""
var ui_nodes_ready: bool = false
var is_purchased: bool = false
var _can_afford: bool = true

const SHOP_CARD_MIN_SIZE = CardUI.DESIGN_SIZE
const HOVER_SCALE := 1.05

func _ready():
	ui_nodes_ready = true
	if is_instance_valid(sale_label):
		sale_label.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(item_data):
		_update_display()
	refresh_affordability()

func setup_item(p_item_data: Resource, p_cost: int, p_is_on_sale: bool = false, p_original_price: int = 0, p_artifact_stack_info: String = ""):
	self.item_data = p_item_data
	self.purchase_cost = p_cost
	self.is_on_sale = p_is_on_sale
	self.original_price = p_original_price
	self.artifact_stack_info = p_artifact_stack_info
	if ui_nodes_ready:
		_update_display()
		refresh_affordability()

func get_item_data() -> Resource:
	return item_data

func mark_purchased() -> void:
	is_purchased = true
	modulate = Color(0.45, 0.45, 0.45, 0.85)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(price_label):
		price_label.text = tr("ui.shop.purchased")
		price_label.modulate = Color(0.7, 0.7, 0.7, 1)
	if is_instance_valid(sale_label):
		sale_label.visible = false
	_set_content_interactive(false)

func refresh_affordability() -> void:
	if is_purchased or not ui_nodes_ready:
		return
	var gold := 0
	if has_node("/root/PlayerData"):
		gold = PlayerData.gold
	_can_afford = gold >= purchase_cost
	if _can_afford:
		modulate = Color.WHITE
		_set_content_interactive(true)
	else:
		modulate = Color(0.55, 0.55, 0.55, 0.9)
		_set_content_interactive(false)

func _set_content_interactive(enabled: bool) -> void:
	if not is_instance_valid(item_content_container):
		return
	for child in item_content_container.get_children():
		if child is Control:
			# Keep right-click tooltips on cards even when unaffordable
			if child is CardUI:
				child.mouse_filter = Control.MOUSE_FILTER_STOP
				if not enabled and not is_purchased:
					# Block left-buy via flag; CardUI still receives clicks — gated in _try_purchase
					pass
			else:
				child.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func _try_purchase() -> void:
	if is_purchased or not _can_afford:
		return
	emit_signal("item_purchased", item_data, self)

func _update_display():
	if not ui_nodes_ready:
		return
	if not is_instance_valid(item_data):
		return
	_display_item_content()
	_update_price_display()

func _display_item_content():
	if not is_instance_valid(item_content_container):
		return
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
			if not card_ui.card_clicked.is_connected(_on_card_clicked_buy):
				card_ui.card_clicked.connect(_on_card_clicked_buy)
			if not card_ui.card_right_clicked.is_connected(_on_card_right_clicked_from_ui):
				card_ui.card_right_clicked.connect(_on_card_right_clicked_from_ui)
			if not card_ui.mouse_entered.is_connected(_on_content_mouse_entered):
				card_ui.mouse_entered.connect(_on_content_mouse_entered.bind(card_ui))
			if not card_ui.mouse_exited.is_connected(_on_content_mouse_exited):
				card_ui.mouse_exited.connect(_on_content_mouse_exited.bind(card_ui))
		call_deferred("_center_card_in_slot", card_ui if card_ui is CardUI else null)

	elif item_data is ArtifactsData:
		var artifact_ui = preload("res://scenes/ui/ArtifactChoiceUI.tscn").instantiate()
		item_content_container.add_child(artifact_ui)
		artifact_ui.display_artifact(item_data)
		if artifact_stack_info and not artifact_stack_info.is_empty():
			artifact_ui.set_stack_info(artifact_stack_info)
		artifact_ui.scale = Vector2(0.85, 0.85)
		if not artifact_ui.artifact_chosen.is_connected(_on_artifact_clicked_buy):
			artifact_ui.artifact_chosen.connect(_on_artifact_clicked_buy)

func _on_card_clicked_buy(_data: CardData) -> void:
	_try_purchase()

func _on_artifact_clicked_buy(_data: ArtifactsData) -> void:
	_try_purchase()

func _on_card_right_clicked_from_ui(data: CardData):
	emit_signal("card_right_clicked", data)

func _on_content_mouse_entered(node: Control) -> void:
	if is_purchased or not is_instance_valid(node):
		return
	var base := Vector2.ONE
	if node is CardUI:
		base = (node as CardUI).original_scale if (node as CardUI).original_scale != Vector2.ZERO else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(node, "scale", base * HOVER_SCALE, 0.12)
	if item_data is CardData:
		emit_signal("card_hovered", item_data)

func _on_content_mouse_exited(node: Control) -> void:
	if not is_instance_valid(node):
		return
	var base := Vector2.ONE
	if node is CardUI:
		base = (node as CardUI).original_scale if (node as CardUI).original_scale != Vector2.ZERO else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(node, "scale", base, 0.12)
	if item_data is CardData:
		emit_signal("card_hover_exited", item_data)

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
	if not is_instance_valid(price_label):
		return
	price_label.visible = true
	if is_on_sale and original_price > 0:
		price_label.text = TranslationHelper.tr_format("ui.shop.sale_price", {"value": purchase_cost, "original": original_price})
		price_label.modulate = Color(0.45, 1.0, 0.45, 1)
		if is_instance_valid(sale_label):
			sale_label.text = tr("ui.shop.sale")
			sale_label.visible = true
	else:
		price_label.text = TranslationHelper.tr_format("ui.shop.price", {"value": purchase_cost})
		price_label.modulate = Color.WHITE
		if is_instance_valid(sale_label):
			sale_label.visible = false
