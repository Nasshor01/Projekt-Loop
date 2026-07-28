# Soubor: res://scenes/events/EventScene.gd (KONZISTENTNÍ S OSTATNÍMI SCÉNAMI)
extends Node2D

const ChoiceButtonScene = preload("res://scenes/events/EventChoiceButton.tscn")
const CardPileViewerScene = preload("res://scenes/ui/CardPileViewer.tscn")

# Načteme si náš pool eventů stejně jako v ShopScene nebo RewardScene
const EVENT_POOL = preload("res://data/events/all_events_pool.tres")

@onready var event_panel: Panel = $UI/EventPanel
@onready var event_title: Label = $UI/EventPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var event_image: TextureRect = $UI/EventPanel/MarginContainer/VBoxContainer/EventImage
@onready var description_text: RichTextLabel = $UI/EventPanel/MarginContainer/VBoxContainer/DescriptionText
@onready var choices_container: VBoxContainer = $UI/EventPanel/MarginContainer/VBoxContainer/ChoicesContainer

@onready var result_panel: Panel = $UI/ResultPanel
@onready var result_text: RichTextLabel = $UI/ResultPanel/MarginContainer/VBoxContainer/ResultText
@onready var continue_button: Button = $UI/ResultPanel/MarginContainer/VBoxContainer/ContinueButton

@onready var card_removal_viewer: PanelContainer = $UI/CardPileViewer
@onready var card_tooltip: CardTooltip = $UI/CardTooltip

var _current_tooltip_card_data: CardData = null
var current_event: EventData
var event_resolved: bool = false
var choice_buttons: Array[Button] = []
var rng: RandomNumberGenerator

var pending_card_removal: bool = false
var pending_card_upgrade: bool = false
var cards_to_remove_count: int = 0
var _preview_upgraded_faces: bool = true
var _upgrade_preview_toggle: Button = null

var _is_coop: bool = false
var _is_host: bool = true

func _ready():
	DebugLogger.log_info("=== EVENT SCENE STARTED ===", "EVENT")
	
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	result_panel.visible = false
	event_panel.visible = true
	
	# Skryj card removal viewer na začátku
	if card_removal_viewer:
		card_removal_viewer.visible = false
	if card_removal_viewer.has_signal("card_right_clicked"):
		card_removal_viewer.card_right_clicked.connect(_on_card_right_clicked_tooltip)
	_ensure_upgrade_preview_toggle()
	
	continue_button.pressed.connect(_on_continue_pressed)
	
	_is_coop = has_node("/root/GameManager") and GameManager.is_coop_run
	_is_host = not _is_coop or (has_node("/root/MultiplayerManager") and MultiplayerManager.is_server())
	
	if _is_coop and not _is_host:
		# Klient: použij event path od hosta (pending data)
		var pending_path = GameManager._coop_pending_event_path
		if not pending_path.is_empty():
			var ev = load(pending_path) as EventData
			if is_instance_valid(ev):
				current_event = ev
				GameManager._coop_pending_event_path = ""
				display_event()
				return
		# Data ještě nepřišla – čekáme (poll)
		_wait_for_event_data()
		return
	
	# Host / solo: načti event normálně
	current_event = _get_random_event_for_floor(PlayerData.floors_cleared)
	
	if not current_event:
		DebugLogger.log_error("EventScene: Nepodařilo se načíst žádný event pro patro %d!" % PlayerData.floors_cleared, "EVENT")
		_show_error_message()
		return
	
	display_event()
	
	# Coop host: pošli event klientovi přes autoload
	if _is_coop and _is_host and is_instance_valid(current_event):
		MultiplayerManager.rpc("receive_go_to_event", current_event.resource_path)

func _wait_for_event_data():
	"""Klient: čeká na event data od hosta."""
	for i in range(50):
		await get_tree().create_timer(0.1).timeout
		var pending_path = GameManager._coop_pending_event_path
		if not pending_path.is_empty():
			var ev = load(pending_path) as EventData
			if is_instance_valid(ev):
				current_event = ev
				GameManager._coop_pending_event_path = ""
				display_event()
				return
	# Fallback: generuj lokálně
	current_event = _get_random_event_for_floor(PlayerData.floors_cleared)
	if current_event:
		display_event()
	else:
		_show_error_message()

func _get_random_event_for_floor(floor: int) -> EventData:
	"""Získá náhodný event z vlastního poolu pomocí EventManager logiky"""
	if not EVENT_POOL or not EVENT_POOL.events:
		printerr("EventScene: Event pool neexistuje nebo je prázdný!")
		return null
	
	# Použij EventManager pro filtrování
	var available_events = EventManager.filter_events_for_floor(EVENT_POOL.events, floor)
	
	if available_events.is_empty():
		printerr("EventScene: Pro patro %d nebyly nalezeny žádné dostupné eventy!" % floor)
		EventManager.debug_available_events(EVENT_POOL.events, floor)
		return null
	
	var chosen_event = available_events.pick_random()
	
	# Označ event jako použitý
	EventManager.mark_event_as_used(chosen_event)
	
	print(TranslationHelper.tr_format("log.event.selected", {"name": chosen_event.get_localized_name(), "floor": floor}))
	return chosen_event

func _show_error_message():
	"""Zobrazí chybovou zprávu místo fallback eventu"""
	event_title.text = tr("event.error.title")
	description_text.bbcode_enabled = true
	description_text.text = TranslationHelper.tr_format("event.error.description", {"floor": PlayerData.floors_cleared})
	
	event_image.visible = false
	
	# Vyčisti staré buttons
	for child in choices_container.get_children():
		child.queue_free()
	choice_buttons.clear()
	
	# Vytvoř jen button pro návrat
	var return_button = Button.new()
	return_button.text = tr("event.error.return_to_map")
	choices_container.add_child(return_button)
	return_button.pressed.connect(_on_error_continue_pressed)

func _on_error_continue_pressed():
	"""Návrat na mapu při chybě"""
	DebugLogger.log_info("Returning to map due to event loading error", "EVENT")
	GameManager.event_completed()

func display_event():
	if not current_event:
		return
		
	event_title.text = current_event.get_localized_name()
	
	description_text.bbcode_enabled = true
	description_text.text = current_event.get_localized_description()
	
	if current_event.artwork:
		event_image.texture = current_event.artwork
		event_image.visible = true
	else:
		event_image.visible = false
	
	# Vyčisti staré buttons
	for child in choices_container.get_children():
		child.queue_free()
	choice_buttons.clear()
	
	# Vytvoř nové
	for i in range(current_event.choices.size()):
		var choice = current_event.choices[i]
		var button_instance = ChoiceButtonScene.instantiate()
		choices_container.add_child(button_instance)
		choice_buttons.append(button_instance)
		
		# Nastav button s novým systémem
		button_instance.set_choice_data_new(choice)
		
		# Zkontroluj dostupnost
		button_instance.disabled = not choice.can_afford()
		
		# Connect signal
		button_instance.pressed.connect(_on_choice_made.bind(i))

func _on_choice_made(choice_index: int):
	if event_resolved or not current_event:
		return
	
	# Coop: jen host může vybrat (klient je read-only divák)
	if _is_coop and not _is_host:
		return
	
	event_resolved = true
	var choice: EventChoice = current_event.choices[choice_index]
	
	DebugLogger.log_info(TranslationHelper.tr_format("log.event.choice_selected", {"text": tr(choice.choice_text)}), "EVENT")
	
	# Deaktivuj všechny buttons
	for button in choice_buttons:
		button.disabled = true
	
	# Zpracuj volbu
	_process_choice_new(choice)
	
	# Coop: pošli výsledek klientovi
	if _is_coop and _is_host:
		rpc("_rpc_event_choice_made", choice_index)

@rpc("any_peer", "call_remote")
func _rpc_event_choice_made(choice_index: int):
	"""Klient: host vybral volbu – zpracuj ji lokálně."""
	if event_resolved or not current_event:
		return
	if choice_index < 0 or choice_index >= current_event.choices.size():
		return
	event_resolved = true
	var choice: EventChoice = current_event.choices[choice_index]
	for button in choice_buttons:
		button.disabled = true
	_process_choice_new(choice)

func _process_choice_new(choice: EventChoice):
	var results_log = []
	
	# 1. Aplikuj cenu
	if choice.cost:
		choice.cost.apply_cost()
		var cost_desc = choice.cost.get_cost_description()
		if cost_desc != "":
			results_log.append(tr("event.result.paid") + " " + cost_desc)
	
	# 2. Risk/Reward check
	var success = true
	if choice.success_chance < 1.0:
		var roll = rng.randf()
		success = roll <= choice.success_chance
		
		DebugLogger.log_info("Risk roll: %.2f vs %.2f (Success: %s)" % [
			roll, choice.success_chance, str(success)
		], "EVENT")
		
		if success:
			results_log.append("[color=green]" + tr("event.result.success") + "[/color]")
		else:
			results_log.append("[color=red]" + tr("event.result.failure") + "[/color]")
	
	# 3. Aplikuj výsledek
	if success:
		if choice.reward:
			choice.reward.apply_reward(results_log)
			# Zkontroluj pending akce
			if choice.reward.pending_card_removal:
				pending_card_removal = true
				cards_to_remove_count = 1
			if choice.reward.pending_card_upgrade:
				pending_card_upgrade = true
	else:
		if choice.failure_cost:
			choice.failure_cost.apply_cost()
			results_log.append(tr("event.result.additional_cost") + " " + choice.failure_cost.get_cost_description())
		if choice.failure_reward:
			choice.failure_reward.apply_reward(results_log)
	
	# 4. Zobraz výsledky
	show_result(results_log)

func show_result(result_lines: Array):
	event_panel.visible = false
	result_panel.visible = true
	
	result_text.bbcode_enabled = true
	result_text.clear()
	
	if result_lines.is_empty():
		result_text.append_text(tr("event.result.continue"))
	else:
		for line in result_lines:
			result_text.append_text(line + "\n")

func _on_continue_pressed():
	# Coop: jen host může pokračovat
	if _is_coop and not _is_host:
		return
	
	# Zkontroluj pending akce
	if pending_card_removal:
		_open_card_removal_screen()
		return
	
	if pending_card_upgrade:
		_open_card_upgrade_screen()
		return
	
	DebugLogger.log_info("Leaving event scene", "EVENT")
	GameManager.event_completed()

func _open_card_removal_screen():
	"""Otevře obrazovku pro výběr karty k odstranění"""
	if not card_removal_viewer:
		# Vytvoř viewer pokud neexistuje
		card_removal_viewer = CardPileViewerScene.instantiate()
		$UI.add_child(card_removal_viewer)
		if card_removal_viewer.has_signal("card_right_clicked"):
			card_removal_viewer.card_right_clicked.connect(_on_card_right_clicked_tooltip)
	
	# Skryj result panel
	result_panel.visible = false
	if is_instance_valid(_upgrade_preview_toggle):
		_upgrade_preview_toggle.visible = false
	
	# Zobraz karty
	card_removal_viewer.visible = true
	var deck_cards: Array[CardData] = []
	for card in PlayerData.master_deck:
		if card:
			deck_cards.append(card)
	card_removal_viewer.show_cards(deck_cards)
	
	if not card_removal_viewer.card_clicked_in_viewer.is_connected(_on_removal_card_clicked):
		card_removal_viewer.card_clicked_in_viewer.connect(_on_removal_card_clicked)
	# Zavření vieweru (Zavřít / Escape) vrátí na result panel
	_connect_card_removal_viewer_close()

func _on_removal_card_clicked(card_data: CardData):
	# Odstraň kartu
	PlayerData.master_deck.erase(card_data)
	print(TranslationHelper.tr_format("event.card_removed", {"name": card_data.get_localized_name()}))
	
	cards_to_remove_count -= 1
	
	# Pokud už není co odstranit, pokračuj
	if cards_to_remove_count <= 0:
		pending_card_removal = false
		if card_removal_viewer.has_method("hide_and_clear"):
			card_removal_viewer.hide_and_clear()
		else:
			card_removal_viewer.visible = false
		result_panel.visible = true
		
		# Aktualizuj result text
		result_text.append_text("\n[color=gray]" + TranslationHelper.tr_format("event.result.removed_card", {"name": card_data.get_localized_name()}) + "[/color]")

func _ensure_upgrade_preview_toggle() -> void:
	if is_instance_valid(_upgrade_preview_toggle):
		return
	_upgrade_preview_toggle = Button.new()
	_upgrade_preview_toggle.name = "UpgradePreviewToggle"
	_upgrade_preview_toggle.visible = false
	_upgrade_preview_toggle.toggle_mode = true
	_upgrade_preview_toggle.button_pressed = true
	_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on")
	_upgrade_preview_toggle.pressed.connect(_on_upgrade_preview_toggle_pressed)
	$UI.add_child(_upgrade_preview_toggle)
	_upgrade_preview_toggle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_upgrade_preview_toggle.offset_left = 24
	_upgrade_preview_toggle.offset_top = 24
	_upgrade_preview_toggle.offset_right = 280
	_upgrade_preview_toggle.offset_bottom = 64
	_upgrade_preview_toggle.z_index = 250

func _on_upgrade_preview_toggle_pressed() -> void:
	_preview_upgraded_faces = _upgrade_preview_toggle.button_pressed
	_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on") if _preview_upgraded_faces else tr("ui.rest.preview_upgrades_off")
	if card_removal_viewer and card_removal_viewer.has_method("set_upgrade_preview_faces"):
		card_removal_viewer.set_upgrade_preview_faces(_preview_upgraded_faces)

func _open_card_upgrade_screen():
	"""Otevře výběr karty k vylepšení — stejný UX jako Rest (náhled +/−)."""
	if not card_removal_viewer:
		card_removal_viewer = CardPileViewerScene.instantiate()
		$UI.add_child(card_removal_viewer)
		if card_removal_viewer.has_signal("card_right_clicked"):
			card_removal_viewer.card_right_clicked.connect(_on_card_right_clicked_tooltip)
	
	var upgradeable_cards: Array[CardData] = []
	for card in PlayerData.master_deck:
		if card and not card.is_upgraded and is_instance_valid(card.upgraded_version):
			upgradeable_cards.append(card)
	
	if upgradeable_cards.is_empty():
		pending_card_upgrade = false
		result_text.append_text("\n[color=gray]" + tr("event.reward.upgrade_none") + "[/color]")
		return
	
	result_panel.visible = false
	_preview_upgraded_faces = true
	_ensure_upgrade_preview_toggle()
	_upgrade_preview_toggle.visible = true
	_upgrade_preview_toggle.button_pressed = true
	_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on")
	
	card_removal_viewer.visible = true
	if card_removal_viewer.has_method("show_upgrade_selection"):
		card_removal_viewer.show_upgrade_selection(upgradeable_cards, _preview_upgraded_faces)
	else:
		card_removal_viewer.show_cards(upgradeable_cards)
	
	if not card_removal_viewer.card_clicked_in_viewer.is_connected(_on_upgrade_card_clicked):
		card_removal_viewer.card_clicked_in_viewer.connect(_on_upgrade_card_clicked)
	_connect_card_removal_viewer_close()

func _on_upgrade_card_clicked(card_data: CardData):
	# Vylepši kartu (card_data je vždy base, i když face ukazuje upgraded)
	var index = PlayerData.master_deck.find(card_data)
	if index != -1 and is_instance_valid(card_data.upgraded_version):
		var upgraded = card_data.upgraded_version
		PlayerData.master_deck[index] = upgraded
		print(TranslationHelper.tr_format("event.card_upgraded", {"from": card_data.get_localized_name(), "to": upgraded.get_localized_name()}))
		
		pending_card_upgrade = false
		if is_instance_valid(_upgrade_preview_toggle):
			_upgrade_preview_toggle.visible = false
		if card_removal_viewer.has_method("hide_and_clear"):
			card_removal_viewer.hide_and_clear()
		else:
			card_removal_viewer.visible = false
		result_panel.visible = true
		
		# Aktualizuj result text
		result_text.append_text("\n[color=cyan]" + TranslationHelper.tr_format("event.reward.upgraded_card", {"from": card_data.get_localized_name(), "to": upgraded.get_localized_name()}) + "[/color]")

func _connect_card_removal_viewer_close():
	"""Připoj tlačítko Zavřít a Escape – při šedé obrazovce (viewer bez výběru) lze vrátit na result."""
	if not is_instance_valid(card_removal_viewer):
		return
	var btn = card_removal_viewer.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/Control/CloseButton")
	if btn and not btn.pressed.is_connected(_on_card_removal_viewer_closed):
		btn.pressed.connect(_on_card_removal_viewer_closed)

func _on_card_removal_viewer_closed():
	"""Zavření vieweru bez výběru karty – vrátí na result panel, aby hráč neuvízl na šedé obrazovce."""
	if is_instance_valid(_upgrade_preview_toggle):
		_upgrade_preview_toggle.visible = false
	if card_removal_viewer.has_method("hide_and_clear"):
		card_removal_viewer.hide_and_clear()
	else:
		card_removal_viewer.visible = false
	result_panel.visible = true
	if pending_card_removal:
		pending_card_removal = false
		cards_to_remove_count = 0
		result_text.append_text("\n[color=gray]" + tr("event.result.no_card_removed") + "[/color]")
	if pending_card_upgrade:
		pending_card_upgrade = false
		result_text.append_text("\n[color=gray]" + tr("event.reward.upgrade_none") + "[/color]")

func _unhandled_input(event: InputEvent):
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_instance_valid(card_removal_viewer) and card_removal_viewer.visible:
		_on_card_removal_viewer_closed()

func _on_card_right_clicked_tooltip(card_data: CardData):
	if not card_tooltip:
		return
	if card_tooltip.visible and _current_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null
	else:
		_current_tooltip_card_data = card_data
		_show_card_tooltip()

func _show_card_tooltip():
	if not _current_tooltip_card_data or not card_tooltip:
		return
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(360, 420)
	var tooltip_pos = Vector2(screen_size.x - tooltip_size.x - 20, 80)
	tooltip_pos.x = clampf(tooltip_pos.x, 10, screen_size.x - tooltip_size.x - 10)
	tooltip_pos.y = clampf(tooltip_pos.y, 10, screen_size.y - tooltip_size.y - 10)
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)
