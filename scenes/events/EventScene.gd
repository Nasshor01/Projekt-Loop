# Soubor: res://scenes/events/EventScene.gd (Verze 2.0 FIXED)
extends Node2D

const ChoiceButtonScene = preload("res://scenes/events/EventChoiceButton.tscn")

# --- Nové @onready proměnné ---
@onready var event_panel: Panel = $UI/EventPanel
@onready var event_title: Label = $UI/EventPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var event_image: TextureRect = $UI/EventPanel/MarginContainer/VBoxContainer/EventImage
@onready var description_text: RichTextLabel = $UI/EventPanel/MarginContainer/VBoxContainer/DescriptionText
@onready var choices_container: VBoxContainer = $UI/EventPanel/MarginContainer/VBoxContainer/ChoicesContainer

# Pro nový panel s výsledky
@onready var result_panel: Panel = $UI/ResultPanel
@onready var result_text: RichTextLabel = $UI/ResultPanel/MarginContainer/VBoxContainer/ResultText
@onready var continue_button: Button = $UI/ResultPanel/MarginContainer/VBoxContainer/ContinueButton

# ------------------------------------
var current_event: EventData
var event_resolved: bool = false
var choice_buttons: Array[Button] = []
var rng: RandomNumberGenerator

func _ready():
	DebugLogger.log_info("=== EVENT SCENE STARTED ===", "EVENT")
	
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Na začátku je panel s výsledky skrytý
	result_panel.visible = false
	event_panel.visible = true
	
	# Propojíme tlačítko pro pokračování
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Načteme event
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
	
	# Vyčistíme staré buttons
	for child in choices_container.get_children():
		child.queue_free()
	choice_buttons.clear()
	
	# Vytvoříme nové
	for i in range(current_event.choices.size()):
		var choice = current_event.choices[i]
		var button_instance = ChoiceButtonScene.instantiate()
		choices_container.add_child(button_instance)
		choice_buttons.append(button_instance)
		
		# Nastavíme button
		button_instance.set_choice_data(choice)
		
		# Zkontrolujeme, jestli hráč může zaplatit cenu
		button_instance.disabled = not _can_afford_choice(choice)
		
		# Connect signal s bind indexu
		button_instance.pressed.connect(_on_choice_made.bind(i))

func _on_choice_made(choice_index: int):
	if event_resolved:
		return
	
	event_resolved = true
	var choice_data: EventChoice = current_event.choices[choice_index]
	
	DebugLogger.log_info("Event choice selected: %s" % choice_data.choice_text, "EVENT")
	
	# Deaktivujeme všechna tlačítka
	for button in choice_buttons:
		button.disabled = true
	
	# Zpracujeme volbu
	_process_choice(choice_data)

func _process_choice(choice_data: EventChoice):
	var results_log = [] # Array pro sbírání textů o výsledcích
	
	# 1. Zpracujeme cenu volby
	if choice_data.costs.has("gold") and choice_data.costs.gold > 0:
		PlayerData.spend_gold(choice_data.costs.gold)
		results_log.append("[color=yellow]Zaplatil jsi %d zlata[/color]" % choice_data.costs.gold)
	
	if choice_data.costs.has("hp") and choice_data.costs.hp > 0:
		PlayerData.take_damage(choice_data.costs.hp)
		results_log.append("[color=red]Ztratil jsi %d HP[/color]" % choice_data.costs.hp)
	
	if choice_data.costs.has("max_hp") and choice_data.costs.max_hp > 0:
		PlayerData.max_hp -= choice_data.costs.max_hp
		PlayerData.current_hp = min(PlayerData.current_hp, PlayerData.max_hp)
		results_log.append("[color=darkred]Ztratil jsi %d Max HP[/color]" % choice_data.costs.max_hp)
	
	if choice_data.costs.has("add_curse") and choice_data.costs.add_curse:
		# TODO: Přidat curse kartu do balíčku
		results_log.append("[color=purple]Získal jsi prokletí![/color]")
	
	# 2. Risk/Reward check
	var success = true
	if choice_data.success_chance < 1.0:
		var roll = rng.randf()
		success = roll <= choice_data.success_chance
		
		DebugLogger.log_info("Risk roll: %.2f vs %.2f (Success: %s)" % [
			roll, choice_data.success_chance, str(success)
		], "EVENT")
		
		if success:
			results_log.append("[color=green]✓ Úspěch![/color]")
		else:
			results_log.append("[color=red]✗ Selhání![/color]")
	
	# 3. Aplikuj odměny nebo penalty
	if success:
		_apply_rewards(choice_data.rewards, results_log)
	else:
		if choice_data.failure_penalty.size() > 0:
			_apply_rewards(choice_data.failure_penalty, results_log)
	
	# 4. Zobraz výsledky
	show_result(results_log)

func _apply_rewards(rewards: Dictionary, results_log: Array):
	if rewards.has("gold") and rewards.gold > 0:
		PlayerData.add_gold(rewards.gold)
		results_log.append("[color=yellow]Získal jsi %d zlata![/color]" % rewards.gold)
	
	if rewards.has("heal") and rewards.heal > 0:
		var actual_healed = min(rewards.heal, PlayerData.max_hp - PlayerData.current_hp)
		PlayerData.heal(rewards.heal)
		results_log.append("[color=green]Vyléčil jsi %d HP[/color]" % actual_healed)
	
	if rewards.has("max_hp"):
		if rewards.max_hp > 0:
			PlayerData.max_hp += rewards.max_hp
			PlayerData.current_hp += rewards.max_hp
			results_log.append("[color=green]Získal jsi +%d Max HP![/color]" % rewards.max_hp)
		else:
			PlayerData.max_hp += rewards.max_hp  # záporné
			PlayerData.current_hp = min(PlayerData.current_hp, PlayerData.max_hp)
			results_log.append("[color=red]Ztratil jsi %d Max HP[/color]" % abs(rewards.max_hp))
	
	if rewards.has("card") and rewards.card:
		# TODO: Přidat kartu do balíčku
		#PlayerData.master_deck.append(rewards.card)
		results_log.append("[color=cyan]Získal jsi novou kartu![/color]")
	
	if rewards.has("artifact") and rewards.artifact:
		# TODO: Přidat artefakt
		#PlayerData.add_artifact(rewards.artifact)
		results_log.append("[color=orange]Získal jsi nový artefakt![/color]")
	
	if rewards.has("buff_next_combat") and rewards.buff_next_combat != "":
		EventManager.add_combat_buff(rewards.buff_next_combat)
		results_log.append("[color=blue]Získal jsi bonus pro příští souboj![/color]")

func show_result(result_lines: Array):
	# Skryjeme původní panel s volbami
	event_panel.visible = false
	
	# Zobrazíme nový panel s výsledky
	result_panel.visible = true
	
	# Vyplníme text - OPRAVA PRO GODOT 4
	result_text.bbcode_enabled = true
	result_text.clear()
	
	if result_lines.is_empty():
		result_text.append_text("Pokračuješ v cestě.")
	else:
		# SPRÁVNÝ ZPŮSOB V GODOT 4:
		# Buď použijeme append_text pro každý řádek
		for line in result_lines:
			result_text.append_text(line + "\n")
		
		# NEBO můžeme použít tento způsob:
		# var joined_text = "\n".join(PackedStringArray(result_lines))
		# result_text.text = joined_text

func _on_continue_pressed():
	DebugLogger.log_info("Leaving event scene", "EVENT")
	GameManager.event_completed()

func _can_afford_choice(choice: EventChoice) -> bool:
	if choice.costs.has("gold") and choice.costs.gold > 0:
		if PlayerData.gold < choice.costs.gold:
			return false
	
	if choice.costs.has("hp") and choice.costs.hp > 0:
		if PlayerData.current_hp <= choice.costs.hp:
			return false  # Nemůžeš se zabít
	
	if choice.costs.has("max_hp") and choice.costs.max_hp > 0:
		if PlayerData.max_hp <= choice.costs.max_hp + 10:
			return false  # Minimum 10 HP
	
	# TODO: Další podmínky pro artefakty atd.
	
	return true

func _load_fallback_event():
	# Záložní event pokud se něco pokazí
	current_event = EventData.new()
	current_event.event_name = "Odpočinek"
	current_event.description = "Našel jsi klidné místo k odpočinku."
	current_event.event_type = EventData.EventType.BENEFIT
	
	var choice = EventChoice.new()
	choice.choice_text = "Odpočinout si"
	choice.costs = {}
	choice.rewards = {"heal": 10}
	
	var choice2 = EventChoice.new()
	choice2.choice_text = "Pokračovat"
	choice2.costs = {}
	choice2.rewards = {}
	
	current_event.choices = [choice, choice2]
