# Soubor: scenes/ui/PlayerHandUI.gd
extends Control

signal hand_card_was_clicked(card_ui_instance: Control, card_data_resource: CardData)
signal card_right_clicked(card_data_resource: CardData)
signal card_draw_animation_finished() # Nový signál, který oznámí dokončení animace dobrání
signal hand_discard_animation_finished() # Nový signál pro dokončení odhození
signal hand_card_drag_started(card_ui_instance: Control, card_data_resource: CardData)
signal hand_card_drag_released(card_ui_instance: Control, card_data_resource: CardData)
signal hand_card_drag_cancelled(card_ui_instance: Control, card_data_resource: CardData)

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

@export_group("Vzhled vějíře")
@export var card_overlap_ratio: float = 0.45
@export var max_overlap_ratio: float = 0.75
@export var squish_threshold: int = 8
@export var hand_arc: float = 36.0

@export_group("Interakce")
@export var hover_y_offset: float = -8.0
@export var hover_scale: float = 1.12

@onready var _arrange_timer: Timer = $ArrangeTimer

var _hovered_card: Control = null
var _selected_card: Control = null
var _dragging_card: Control = null
var _hidden_cards: Array[Control] = []
var _suppress_hover_until_lmb_release: bool = false
var _suppress_click_until_lmb_release: bool = false
var _rmb_just_cancelled_drag: bool = false


func _ready():
	_arrange_timer.timeout.connect(_arrange_cards)
	child_order_changed.connect(_request_arrange)
	resized.connect(_request_arrange)

func _request_arrange():
	if is_inside_tree() and _arrange_timer.is_stopped():
		_arrange_timer.start()

# --- UPRAVENÁ FUNKCE PRO PŘIDÁNÍ KARET S ANIMACÍ (BEZ ASYNC) ---
func add_card_animated(card_data: CardData, from_pos: Vector2):
	var card_ui_instance = CardUIScene.instantiate()
	add_child(card_ui_instance)
	card_ui_instance.load_card(card_data)
	
	card_ui_instance.mouse_entered.connect(_on_card_mouse_entered.bind(card_ui_instance))
	card_ui_instance.mouse_exited.connect(_on_card_mouse_exited.bind(card_ui_instance))
	card_ui_instance.gui_input.connect(_on_card_gui_input.bind(card_ui_instance))
	if card_ui_instance is CardUI:
		card_ui_instance.apply_display_mode(CardUI.DisplayMode.FULL)
		card_ui_instance.is_draggable = true
		card_ui_instance.drag_started.connect(_on_card_drag_started)
		card_ui_instance.drag_released.connect(_on_card_drag_released)
	
	card_ui_instance.global_position = from_pos
	if card_ui_instance is CardUI:
		card_ui_instance.set_target_scale(Vector2.ZERO)
	card_ui_instance.scale = Vector2.ZERO
	card_ui_instance.rotation_degrees = randf_range(-15, 15)
	
	# Místo await použijeme Timer, který po dokončení animace vyšle signál
	var timer = get_tree().create_timer(0.01)
	# Použijeme .call_deferred, abychom zajistili, že se arrange zavolá až v dalším framu
	timer.timeout.connect(call_deferred.bind("_request_arrange"))
	
	var finish_timer = get_tree().create_timer(0.2) # Doba animace
	finish_timer.timeout.connect(func(): emit_signal("card_draw_animation_finished"))


func discard_hand_animated(to_pos: Vector2):
	var cards = get_children().filter(func(c): return c is CardUI)
	if cards.is_empty():
		emit_signal("hand_discard_animation_finished")
		return

	var card_count = cards.size()

	# Projdeme všechny karty v ruce
	for i in range(card_count):
		var card = cards[i]
		if not is_instance_valid(card): continue
		if card is CardUI:
			card.set_target_position(to_pos)
			card.set_target_scale(Vector2.ZERO)
		
		# Vypneme možnost na kartu klikat
		card.set_mouse_filter(MOUSE_FILTER_IGNORE)
		
		# Vytvoříme si timer, který spustí animaci každé karty s malým zpožděním
		# První karta (i=0) se spustí hned, druhá za 0.1s, třetí za 0.2s atd.
		var delay_timer = get_tree().create_timer(i * 0.1)
		
		# Po uplynutí zpoždění se spustí tato anonymní funkce
		delay_timer.timeout.connect(func():
			# Vytvoříme animaci pro tuto jednu kartu
			var card_tween = create_tween()
			card_tween.set_parallel(true)
			card_tween.tween_property(card, "global_position", to_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			card_tween.tween_property(card, "scale", Vector2.ZERO, 0.25)
			
			# Důležitý krok: Pouze u POSLEDNÍ karty v ruce sledujeme, kdy její animace skončí.
			# Až když skončí poslední animace, vyčistíme ruku a dáme vědět BattleScene.
			if i == card_count - 1:
				card_tween.finished.connect(func():
					clear_hand()
					emit_signal("hand_discard_animation_finished")
				)
		)


func add_card_to_hand(card_data_resource: CardData):
	if not card_data_resource or not CardUIScene: return
	var card_ui_instance = CardUIScene.instantiate()
	add_child(card_ui_instance)
	
	if card_ui_instance.has_method("load_card"):
		card_ui_instance.load_card(card_data_resource)
	
	card_ui_instance.mouse_entered.connect(_on_card_mouse_entered.bind(card_ui_instance))
	card_ui_instance.mouse_exited.connect(_on_card_mouse_exited.bind(card_ui_instance))
	card_ui_instance.gui_input.connect(_on_card_gui_input.bind(card_ui_instance))
	if card_ui_instance is CardUI:
		card_ui_instance.apply_display_mode(CardUI.DisplayMode.FULL)
		card_ui_instance.is_draggable = true
		card_ui_instance.drag_started.connect(_on_card_drag_started)
		card_ui_instance.drag_released.connect(_on_card_drag_released)

func clear_hand():
	_hovered_card = null
	_selected_card = null
	for child in get_children():
		if child is CardUI:
			child.queue_free()

func set_selected_card(card_node: Control):
	_selected_card = card_node
	_request_arrange()

func _hide_other_cards(drag_card: Control):
	_hidden_cards.clear()
	for child in get_children():
		if child is CardUI and child != drag_card:
			child.visible = false
			child.mouse_filter = MOUSE_FILTER_IGNORE
			_hidden_cards.append(child)

func _restore_hidden_cards():
	for card in _hidden_cards:
		if is_instance_valid(card):
			card.visible = true
			card.mouse_filter = MOUSE_FILTER_STOP
	_hidden_cards.clear()

func cancel_drag_ui():
	if _dragging_card and _dragging_card is CardUI:
		_dragging_card.cancel_drag()
		emit_signal("hand_card_drag_cancelled", _dragging_card, _dragging_card.card_data)
	_dragging_card = null
	_selected_card = null
	_hovered_card = null
	_suppress_hover_until_lmb_release = true
	_suppress_click_until_lmb_release = true
	_restore_hidden_cards()
	_request_arrange()

func force_finish_drag():
	"""Obnoví skryté karty po úspěšném zahraní (klik na mřížku bez release na kartě)."""
	if _dragging_card and _dragging_card is CardUI:
		_dragging_card.cancel_drag()
	_dragging_card = null
	_restore_hidden_cards()
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
		var is_dragging = card is CardUI and card.is_dragging
		
		if (card == _selected_card or card == _hovered_card) and not is_dragging:
			target_pos.y = size.y - (card.custom_minimum_size.y * hover_scale) + hover_y_offset
			target_scale = card.original_scale * hover_scale
			target_z_index = num_cards + 1
		elif is_dragging:
			target_z_index = num_cards + 2
		
		card.z_index = target_z_index
		
		if card is CardUI:
			if not is_dragging:
				card.set_target_position(target_pos)
				card.set_target_scale(target_scale)
		else:
			card.position = target_pos
			card.scale = target_scale
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(card, "rotation_degrees", 0, 0.15)

func _on_card_mouse_entered(card: Control):
	"""Hover pro vizuální efekty - karta se zvedne"""
	if _suppress_hover_until_lmb_release:
		return
	_hovered_card = card
	_request_arrange()

func _on_card_mouse_exited(card: Control):
	"""Konec hoveru - karta se vrátí na normální pozici"""
	if _suppress_hover_until_lmb_release:
		return
	if _hovered_card == card:
		_hovered_card = null
		_request_arrange()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _dragging_card:
				_rmb_just_cancelled_drag = true
				cancel_drag_ui()
				call_deferred("_clear_rmb_cancel_flag")
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _dragging_card:
				var card = _dragging_card
				_dragging_card = null
				if card is CardUI:
					card.cancel_drag()
				_restore_hidden_cards()
				# Potlačíme click signál z _on_card_gui_input pro tento LMB release,
				# protože cancel_drag() nastavil mouse_filter zpět na STOP a GUI input
				# by mohl znovu emitovat hand_card_was_clicked pro stejný event.
				_suppress_click_until_lmb_release = true
				emit_signal("hand_card_drag_released", card, card.card_data)
			if _suppress_hover_until_lmb_release or _suppress_click_until_lmb_release:
				call_deferred("_clear_suppress_after_lmb_release")

func _on_card_gui_input(event: InputEvent, card_node: Control):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _suppress_click_until_lmb_release:
				accept_event()
				return
			if card_node is CardUI and (card_node.is_dragging or card_node.consume_drag_release()):
				return
			emit_signal("hand_card_was_clicked", card_node, card_node.card_data)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _rmb_just_cancelled_drag:
				accept_event()
				return
			if _dragging_card == card_node:
				cancel_drag_ui()
			elif _selected_card == card_node:
				_selected_card = null
				_hovered_card = null
				_suppress_click_until_lmb_release = true
				emit_signal("hand_card_drag_cancelled", card_node, card_node.card_data)
				_request_arrange()
			else:
				# Pravý klik - toggle tooltip
				emit_signal("card_right_clicked", card_node.card_data)
			accept_event()

func _clear_rmb_cancel_flag():
	_rmb_just_cancelled_drag = false

func _clear_suppress_after_lmb_release():
	if _suppress_hover_until_lmb_release:
		_suppress_hover_until_lmb_release = false
		_hovered_card = null
		_request_arrange()
	if _suppress_click_until_lmb_release:
		_suppress_click_until_lmb_release = false

func _on_card_drag_started(card_node: Control, _original_pos: Vector2 = Vector2.ZERO):
	_dragging_card = card_node
	_hide_other_cards(card_node)
	emit_signal("hand_card_drag_started", card_node, card_node.card_data)

func _on_card_drag_released(card_node: Control, _release_pos = null):
	# Emitovat jen když jsme první (karta dostala release dřív než _input).
	# Jinak _input už emitol hand_card_drag_released — zabráníme dvojímu odehrání karty.
	if _dragging_card == card_node:
		_dragging_card = null
		_restore_hidden_cards()
		emit_signal("hand_card_drag_released", card_node, card_node.card_data)
	else:
		_restore_hidden_cards()
