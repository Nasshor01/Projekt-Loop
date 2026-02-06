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
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip

# Tooltip management
var _current_tooltip_card_data: CardData = null

func _ready():
	# Jen inicializace, ŽÁDNÁ logika pro UI
	print("DEBUG: RewardScene._ready() volán")
	
	# Tooltip se nyní zobrazuje/schovává pomocí pravého kliknutí - žádné timery nejsou potřeba


func setup_ui():
	print("DEBUG: setup_ui() volán")
	print("DEBUG: gold_reward = ", gold_reward)
	print("DEBUG: card_choices.size() = ", card_choices.size())
	print("DEBUG: artifact_rewards.size() = ", artifact_rewards.size())
	
	# 1. Zlato
	PlayerData.add_gold(gold_reward)
	if gold_reward > 0:
		gold_label.text = TranslationHelper.tr_format("ui.reward.gold", {"value": gold_reward})
		gold_label.visible = true
	else:
		gold_label.visible = false
		
	# 2. Karty
	if not card_choices.is_empty():
		title_label.text = tr("ui.reward.choose_card")
		for card_data in card_choices:
			var card_ui = CardUIScene.instantiate()
			card_container.add_child(card_ui)
			card_ui.load_card(card_data)
			card_ui.gui_input.connect(_on_card_gui_input.bind(card_data))
	else:
		card_container.visible = false
		
	# 3. Artefakty
	if not artifact_rewards.is_empty():
		# Pokud nejsou karty, změníme nadpis
		if card_choices.is_empty():
			title_label.text = tr("ui.reward.title")
		
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
		skip_button.text = tr("ui.common.continue")
		skip_button.pressed.connect(GameManager.reward_chosen)
	# Pokud jsou jen artefakty na výběr (např. po bossovi)
	elif card_choices.is_empty() and not artifact_rewards.is_empty():
		skip_button.visible = false # Po bossovi si musíš vybrat
	# Standardní situace s výběrem karty
	else:
		skip_button.text = tr("ui.reward.skip_card")
		skip_button.pressed.connect(GameManager.reward_chosen)

func _on_card_gui_input(event: InputEvent, card_to_add: CardData):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			# Levý klik - výběr karty
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
				skip_button.text = tr("ui.common.continue")
				skip_button.disabled = false
				skip_button.pressed.connect(GameManager.reward_chosen)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			# Pravý klik - toggle tooltip
			_on_card_right_clicked(card_to_add)

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

func _on_card_right_clicked(card_data: CardData):
	"""Toggle tooltip při pravém kliknutí na kartu"""
	if not card_tooltip:
		return
	
	# Pokud je tooltip zobrazený pro tuto kartu, schováme ho
	if card_tooltip.visible and _current_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null
	else:
		# Jinak zobrazíme tooltip pro tuto kartu
		_current_tooltip_card_data = card_data
		_show_card_tooltip()

func _show_card_tooltip():
	"""Zobrazí tooltip pro aktuálně vybranou kartu"""
	if not _current_tooltip_card_data or not card_tooltip:
		return
	
	# V RewardScene je to PanelContainer, takže musíme použít global_position
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(350, 250)
	
	# Zobrazíme tooltip v pravém horním rohu (relativně k obrazovce) - offset 20px od okrajů
	var tooltip_pos = Vector2(
		screen_size.x - tooltip_size.x - 20,
		20
	)
	
	# Kontrola, aby tooltip nevyšel z obrazovky
	if tooltip_pos.x + tooltip_size.x > screen_size.x:
		tooltip_pos.x = screen_size.x - tooltip_size.x - 10
	if tooltip_pos.y + tooltip_size.y > screen_size.y:
		tooltip_pos.y = screen_size.y - tooltip_size.y - 10
	if tooltip_pos.x < 0:
		tooltip_pos.x = 10
	if tooltip_pos.y < 0:
		tooltip_pos.y = 10
	
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)
