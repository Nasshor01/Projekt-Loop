# Soubor: scenes/ui/PlayerHandUI.gd
# POPIS: Kompletní finální verze, která řeší chybu časovače při mazání scény.
extends Control

signal hand_card_was_clicked(card_ui_instance: Control, card_data_resource: CardData)
signal card_hover_started(card_data_resource: CardData)
signal card_hover_ended()

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

@export_group("Vzhled vějíře")
@export var card_overlap_ratio: float = 0.55
@export var max_overlap_ratio: float = 0.85
@export var squish_threshold: int = 10
@export var hand_arc: float = 40.0

@export_group("Interakce")
@export var hover_y_offset: float = -60.0
@export var hover_scale: float = 1.0

@onready var _arrange_timer: Timer = $ArrangeTimer

var _hovered_card: Control = null
var _selected_card: Control = null


func _ready():
	_arrange_timer.timeout.connect(_arrange_cards)
	child_order_changed.connect(_request_arrange)
	resized.connect(_request_arrange)

func _request_arrange():
	# --- FINÁLNÍ OPRAVA ZDE ---
	# Spustíme časovač pouze pokud je tento uzel stále aktivní součástí scény
	# a pokud časovač zrovna neběží. Tím se vyhneme chybě při mazání.
	if is_inside_tree() and _arrange_timer.is_stopped():
		_arrange_timer.start()

func add_card_to_hand(card_data_resource: CardData):
	if not card_data_resource or not CardUIScene: return
	var card_ui_instance = CardUIScene.instantiate()
	add_child(card_ui_instance)
	
	if card_ui_instance.has_method("load_card"):
		card_ui_instance.load_card(card_data_resource)
	
	card_ui_instance.mouse_entered.connect(_on_card_mouse_entered.bind(card_ui_instance))
	card_ui_instance.mouse_exited.connect(_on_card_mouse_exited.bind(card_ui_instance))
	card_ui_instance.gui_input.connect(_on_card_gui_input.bind(card_ui_instance))

func clear_hand():
	_hovered_card = null
	_selected_card = null
	for child in get_children():
		if child is CardUI:
			child.queue_free()

func set_selected_card(card_node: Control):
	_selected_card = card_node
	_request_arrange()

func _arrange_cards():
	var cards = get_children().filter(func(c): return c is CardUI)
	var num_cards = cards.size()
	
	if num_cards == 0: return
	if not is_instance_valid(cards[0]): return

	var current_overlap = card_overlap_ratio
	if num_cards > squish_threshold:
		var excess_cards = float(num_cards - squish_threshold)
		current_overlap = lerp(card_overlap_ratio, max_overlap_ratio, min(1.0, excess_cards / 5.0))
	
	var card_size = cards[0].custom_minimum_size * cards[0].original_scale
	var effective_card_width = card_size.x * (1.0 - current_overlap)
	var total_width = (num_cards - 1) * effective_card_width + card_size.x
	var start_x = (size.x - total_width) / 2.0

	for i in range(num_cards):
		var card = cards[i]
		if not is_instance_valid(card): continue
		
		var normalized_pos = 0.5
		if num_cards > 1: normalized_pos = float(i) / (num_cards - 1)
		
		var base_x = start_x + i * effective_card_width
		var x_arc = (normalized_pos - 0.5) * 2.0
		var base_y = size.y - card_size.y + (x_arc * x_arc) * hand_arc
		
		var target_pos = Vector2(base_x, base_y)
		var target_scale = card.original_scale
		var target_z_index = i
		
		if card == _selected_card or card == _hovered_card:
			target_pos.y = size.y - (card.custom_minimum_size.y * hover_scale) + hover_y_offset
			target_scale = Vector2(hover_scale, hover_scale)
			target_z_index = num_cards + 1
		
		card.z_index = target_z_index
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.set_parallel(true)
		tween.tween_property(card, "position", target_pos, 0.15)
		tween.tween_property(card, "scale", target_scale, 0.15)
		tween.tween_property(card, "rotation_degrees", 0, 0.15)

func _on_card_mouse_entered(card: Control):
	_hovered_card = card
	emit_signal("card_hover_started", card.card_data)
	_request_arrange()

func _on_card_mouse_exited(card: Control):
	if _hovered_card == card:
		_hovered_card = null
		emit_signal("card_hover_ended")
		_request_arrange()

func _on_card_gui_input(event: InputEvent, card_node: Control):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("hand_card_was_clicked", card_node, card_node.card_data)
