# Soubor: res://scenes/events/EventScene.gd (UPRAVENÁ VERZE PRO NOVÉ RESOURCES)
extends Node2D

const ChoiceButtonScene = preload("res://scenes/events/EventChoiceButton.tscn")

@onready var event_panel: Panel = $UI/EventPanel
@onready var event_title: Label = $UI/EventPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var event_image: TextureRect = $UI/EventPanel/MarginContainer/VBoxContainer/EventImage
@onready var description_text: RichTextLabel = $UI/EventPanel/MarginContainer/VBoxContainer/DescriptionText
@onready var choices_container: VBoxContainer = $UI/EventPanel/MarginContainer/VBoxContainer/ChoicesContainer

@onready var result_panel: Panel = $UI/ResultPanel
@onready var result_text: RichTextLabel = $UI/ResultPanel/MarginContainer/VBoxContainer/ResultText
@onready var continue_button: Button = $UI/ResultPanel/MarginContainer/VBoxContainer/ContinueButton

var current_event: EventData
var event_resolved: bool = false
var choice_buttons: Array[Button] = []
var rng: RandomNumberGenerator

func _ready():
	DebugLogger.log_info("=== EVENT SCENE STARTED ===", "EVENT")
	
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	result_panel.visible = false
	event_panel.visible = true
	
	continue_button.pressed.connect(_on_continue_pressed)
	
	current_event = EventManager.get_random_event_for_floor(PlayerData.floors_cleared)
	
	if not current_event:
		DebugLogger.log_error("EventScene: Nepodařilo se načíst žádný event!", "EVENT")
		_load_fallback_event()
	
	display_event()

func display_event():
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
	if event_resolved:
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
	DebugLogger.log_info("Leaving event scene", "EVENT")
	GameManager.event_completed()

func _load_fallback_event():
	current_event = EventData.new()
	current_event.event_name = "Odpočinek"
	current_event.description = "Našel jsi klidné místo k odpočinku."
	current_event.event_type = EventData.EventType.BENEFIT
	
	var choice = EventChoice.new()
	choice.choice_text = "Odpočinout si"
	choice.reward = EventReward.new()
	choice.reward.heal = 10
	
	var choice2 = EventChoice.new()
	choice2.choice_text = "Pokračovat"
	
	current_event.choices = [choice, choice2]
