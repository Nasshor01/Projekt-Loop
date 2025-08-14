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

var current_event: EventData
var event_resolved: bool = false
var choice_buttons: Array[Button] = []
var rng: RandomNumberGenerator

var pending_card_removal: bool = false
var pending_card_upgrade: bool = false
var cards_to_remove_count: int = 0

func _ready():
	DebugLogger.log_info("=== EVENT SCENE STARTED ===", "EVENT")
	
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	result_panel.visible = false
	event_panel.visible = true
	
	# Skryj card removal viewer na začátku
	if card_removal_viewer:
		card_removal_viewer.visible = false
	
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Načti event pomocí vlastního poolu a EventManager logiky
	current_event = _get_random_event_for_floor(PlayerData.floors_cleared)
	
	if not current_event:
		DebugLogger.log_error("EventScene: Nepodařilo se načíst žádný event pro patro %d!" % PlayerData.floors_cleared, "EVENT")
		_show_error_message()
		return
	
	display_event()

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
	
	print("EventScene: Vybrán event: %s pro patro %d" % [chosen_event.event_name, floor])
	return chosen_event

func _show_error_message():
	"""Zobrazí chybovou zprávu místo fallback eventu"""
	event_title.text = "CHYBA: Žádné eventy"
	description_text.bbcode_enabled = true
	description_text.text = "[color=red]Nepodařilo se načíst žádný event![/color]\n\nMožné příčiny:\n• Event Pool soubor neexistuje nebo je prázdný\n• Žádné eventy nejsou vhodné pro patro %d\n• Eventy mají špatně nastavené min_floor/max_floor" % PlayerData.floors_cleared
	
	event_image.visible = false
	
	# Vyčisti staré buttons
	for child in choices_container.get_children():
		child.queue_free()
	choice_buttons.clear()
	
	# Vytvoř jen button pro návrat
	var return_button = Button.new()
	return_button.text = "Vrátit se na mapu"
	choices_container.add_child(return_button)
	return_button.pressed.connect(_on_error_continue_pressed)

func _on_error_continue_pressed():
	"""Návrat na mapu při chybě"""
	DebugLogger.log_info("Returning to map due to event loading error", "EVENT")
	GameManager.event_completed()

func display_event():
	if not current_event:
		return
		
	event_title.text = current_event.event_name
	
	description_text.bbcode_enabled = true
	description_text.text = current_event.description
	
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
	
	event_resolved = true
	var choice: EventChoice = current_event.choices[choice_index]
	
	DebugLogger.log_info("Event choice selected: %s" % choice.choice_text, "EVENT")
	
	# Deaktivuj všechny buttons
	for button in choice_buttons:
		button.disabled = true
	
	# Zpracuj volbu
	_process_choice_new(choice)

func _process_choice_new(choice: EventChoice):
	var results_log = []
	
	# 1. Aplikuj cenu
	if choice.cost:
		choice.cost.apply_cost()
		var cost_desc = choice.cost.get_cost_description()
		if cost_desc != "":
			results_log.append("Zaplatil jsi: " + cost_desc)
	
	# 2. Risk/Reward check
	var success = true
	if choice.success_chance < 1.0:
		var roll = rng.randf()
		success = roll <= choice.success_chance
		
		DebugLogger.log_info("Risk roll: %.2f vs %.2f (Success: %s)" % [
			roll, choice.success_chance, str(success)
		], "EVENT")
		
		if success:
			results_log.append("[color=green]✓ Úspěch![/color]")
		else:
			results_log.append("[color=red]✗ Selhání![/color]")
	
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
			results_log.append("Dodatečná cena: " + choice.failure_cost.get_cost_description())
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
		result_text.append_text("Pokračuješ v cestě.")
	else:
		for line in result_lines:
			result_text.append_text(line + "\n")

func _on_continue_pressed():
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
	
	# Skryj result panel
	result_panel.visible = false
	
	# Zobraz karty
	card_removal_viewer.visible = true
	card_removal_viewer.show_cards(PlayerData.master_deck)
	
	# Připoj signály pro kliknutí na karty
	for card_ui in card_removal_viewer.get_node("MarginContainer/VBoxContainer/ScrollContainer/GridContainer").get_children():
		if card_ui.has_signal("gui_input"):
			if not card_ui.is_connected("gui_input", _on_removal_card_clicked):
				card_ui.gui_input.connect(_on_removal_card_clicked.bind(card_ui.card_data))

func _on_removal_card_clicked(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Odstraň kartu
		PlayerData.master_deck.erase(card_data)
		print("Karta '%s' byla odstraněna z balíčku." % card_data.card_name)
		
		cards_to_remove_count -= 1
		
		# Pokud už není co odstranit, pokračuj
		if cards_to_remove_count <= 0:
			pending_card_removal = false
			card_removal_viewer.visible = false
			result_panel.visible = true
			
			# Aktualizuj result text
			result_text.append_text("\n[color=gray]Odstraněna karta: %s[/color]" % card_data.card_name)

func _open_card_upgrade_screen():
	"""Otevře obrazovku pro výběr karty k vylepšení"""
	if not card_removal_viewer:
		card_removal_viewer = CardPileViewerScene.instantiate()
		$UI.add_child(card_removal_viewer)
	
	# Filtruj jen upgradeable karty
	var upgradeable_cards = []
	for card in PlayerData.master_deck:
		if card and not card.is_upgraded and card.upgraded_version:
			upgradeable_cards.append(card)
	
	if upgradeable_cards.is_empty():
		pending_card_upgrade = false
		result_text.append_text("\n[color=gray]Žádné karty nelze vylepšit[/color]")
		return
	
	# Skryj result panel
	result_panel.visible = false
	
	# Zobraz upgradeable karty
	card_removal_viewer.visible = true
	card_removal_viewer.show_cards(upgradeable_cards)
	
	# Připoj signály
	for card_ui in card_removal_viewer.get_node("MarginContainer/VBoxContainer/ScrollContainer/GridContainer").get_children():
		if card_ui.has_signal("gui_input"):
			if not card_ui.is_connected("gui_input", _on_upgrade_card_clicked):
				card_ui.gui_input.connect(_on_upgrade_card_clicked.bind(card_ui.card_data))

func _on_upgrade_card_clicked(event: InputEvent, card_data: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# Vylepši kartu
		var index = PlayerData.master_deck.find(card_data)
		if index != -1 and card_data.upgraded_version:
			var upgraded = card_data.upgraded_version
			PlayerData.master_deck[index] = upgraded
			print("Karta vylepšena: %s → %s" % [card_data.card_name, upgraded.card_name])
			
			pending_card_upgrade = false
			card_removal_viewer.visible = false
			result_panel.visible = true
			
			# Aktualizuj result text
			result_text.append_text("\n[color=cyan]Vylepšena karta: %s → %s[/color]" % [
				card_data.card_name,
				upgraded.card_name
			])
