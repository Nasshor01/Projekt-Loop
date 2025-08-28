# Soubor: scenes/rewards/RewardScene.gd (OPRAVENÁ VERZE)
extends PanelContainer

# --- Proměnné, které nastaví GameManager ---
var gold_reward: int = 0
var card_choices: Array = []
var artifact_rewards: Array = []

# --- Přednačtené scény ---
const CardUIScene = preload("res://scenes/ui/CardUI.tscn")
const ArtifactChoiceUIScene = preload("res://scenes/ui/ArtifactChoiceUI.tscn")

# --- Cesty k UI prvkům ---
@onready var title_label: Label = $VBoxContainer/CenterContainer/TitleLabel
@onready var gold_label: Label = $VBoxContainer/GoldRewardDisplay/GoldLabel
@onready var card_container: HBoxContainer = $VBoxContainer/CardContainer
@onready var artifact_container: HBoxContainer = $VBoxContainer/ArtifactContainer
@onready var skip_button: Button = $VBoxContainer/SkipButton

func _ready():
	# Jen inicializace, ŽÁDNÁ logika pro UI
	print("DEBUG: RewardScene._ready() volán")


func setup_ui():
	print("DEBUG: setup_ui() volán")
	print("DEBUG: gold_reward = ", gold_reward)
	print("DEBUG: card_choices.size() = ", card_choices.size())
	print("DEBUG: artifact_rewards.size() = ", artifact_rewards.size())
	
	# 1. Zlato
	PlayerData.add_gold(gold_reward)
	if gold_reward > 0:
		gold_label.text = "Získáno zlata: %d" % gold_reward
		gold_label.visible = true
	else:
		gold_label.visible = false
		
	# 2. Karty
	if not card_choices.is_empty():
		title_label.text = "Vyber si kartu"
		for card_data in card_choices:
			var card_ui = CardUIScene.instantiate()
			card_container.add_child(card_ui)
			card_ui.load_card(card_data)
			card_ui.gui_input.connect(_on_card_selected.bind(card_data))
	else:
		card_container.visible = false
		
	# 3. Artefakty
	if not artifact_rewards.is_empty():
		# Pokud nejsou karty, změníme nadpis
		if card_choices.is_empty():
			title_label.text = "Odměna!"
		
		# Vytvoříme UI pro artefakty
		for artifact_data in artifact_rewards:
			var artifact_ui = ArtifactChoiceUIScene.instantiate()
			artifact_container.add_child(artifact_ui)
			artifact_ui.display_artifact(artifact_data)
			artifact_ui.artifact_chosen.connect(_on_artifact_selected)
	else:
		artifact_container.visible = false
		
	# 4. Tlačítko "Přeskočit" / "Pokračovat"
	# TEPRVE NYNÍ nastavujeme tlačítko, když už máme správné hodnoty
	if card_choices.is_empty() and artifact_rewards.is_empty():
		skip_button.text = "Pokračovat"
		skip_button.pressed.connect(GameManager.reward_chosen)
	# Pokud jsou jen artefakty na výběr (např. po bossovi)
	elif card_choices.is_empty() and not artifact_rewards.is_empty():
		skip_button.visible = false # Po bossovi si musíš vybrat
	# Standardní situace s výběrem karty
	else:
		skip_button.text = "Přeskočit kartu"
		skip_button.pressed.connect(GameManager.reward_chosen)

func _on_card_selected(event: InputEvent, card_to_add: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		PlayerData.master_deck.append(card_to_add)
		
		# Deaktivujeme možnost vybrat další kartu
		for child in card_container.get_children():
			child.mouse_filter = MOUSE_FILTER_IGNORE
		
		card_container.visible = false
		skip_button.disabled = true
		
		# Pokud nejsou na výběr artefakty, rovnou končíme
		if artifact_container.get_child_count() == 0:
			GameManager.reward_chosen()
		# Pokud ano, změníme text tlačítka na "Pokračovat"
		else:
			skip_button.text = "Pokračovat"
			skip_button.disabled = false
			skip_button.pressed.connect(GameManager.reward_chosen)

func _on_artifact_selected(artifact_to_add: ArtifactsData):
	PlayerData.add_artifact(artifact_to_add)
	# Deaktivujeme všechny ostatní volby artefaktů, aby hráč mohl vybrat jen jeden
	for child in artifact_container.get_children():
		child.mouse_filter = MOUSE_FILTER_IGNORE
		if child.artifact_data != artifact_to_add:
			child.modulate = Color(0.5, 0.5, 0.5)
	skip_button.disabled = true
	# Po výběru artefaktu rovnou jdeme na mapu
	GameManager.reward_chosen()
