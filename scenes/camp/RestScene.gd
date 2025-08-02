# Soubor: scenes/camp/RestScene.gd (VERZE PRO LAYOUT VEDLE SEBE)
extends PanelContainer

# Cesty k uzlům v nové struktuře
@onready var heal_button: Button = $HBoxContainer/LeftColumn/OptionsContainer/HealButton
@onready var upgrade_button: Button = $HBoxContainer/LeftColumn/OptionsContainer/UpgradeButton
@onready var leave_button: Button = $HBoxContainer/LeftColumn/LeaveButton
@onready var title_label: Label = $HBoxContainer/LeftColumn/TitleLabel
@onready var options_container: HBoxContainer = $HBoxContainer/LeftColumn/OptionsContainer
@onready var card_pile_viewer = $HBoxContainer/LeftColumn/CardPileViewer
@onready var upgrade_preview: PanelContainer = $HBoxContainer/RightColumn/UpgradePreview

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

func _ready():
	heal_button.pressed.connect(_on_heal_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	var heal_amount = int(PlayerData.max_hp * 0.3)
	heal_button.text = "Odpočinout si (+%d HP)" % heal_amount
	
	upgrade_preview.hide()

func _on_heal_pressed():
	var heal_amount = int(PlayerData.max_hp * 0.3)
	PlayerData.heal(heal_amount)
	_on_leave_pressed()

func _on_upgrade_pressed():
	options_container.hide()
	title_label.text = "Vyber kartu k vylepšení"
	
	var upgradeable_cards: Array[CardData] = []
	for card in PlayerData.master_deck:
		if not card.is_upgraded and is_instance_valid(card.upgraded_version):
			upgradeable_cards.append(card)

	card_pile_viewer.show_cards(upgradeable_cards, Vector2(0.6, 0.6)) # Mírně zvětšíme karty
	
	for card_ui in card_pile_viewer.grid_container.get_children():
		if card_ui is CardUI:
			card_ui.mouse_entered.connect(_on_card_hover_for_preview.bind(card_ui.card_data))
			card_ui.mouse_exited.connect(_on_card_exit_for_preview)
			card_ui.gui_input.connect(_on_card_selected_for_upgrade.bind(card_ui.card_data))

func _on_card_selected_for_upgrade(event: InputEvent, card_to_upgrade: CardData):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var card_index = PlayerData.master_deck.find(card_to_upgrade)
		if card_index != -1:
			PlayerData.master_deck[card_index] = card_to_upgrade.upgraded_version
			print("Karta '%s' vylepšena na '%s'" % [card_to_upgrade.card_name, card_to_upgrade.upgraded_version.card_name])
		
		_on_leave_pressed()

func _on_card_hover_for_preview(card_to_preview: CardData):
	var preview_container = upgrade_preview.get_node("CenterContainer/HBoxContainer")
	
	for child in preview_container.get_children():
		child.queue_free()
	
	if not is_instance_valid(card_to_preview.upgraded_version):
		return

	var original_card_ui = CardUIScene.instantiate()
	original_card_ui.card_data = card_to_preview
	preview_container.add_child(original_card_ui)

	var arrow_label = Label.new()
	arrow_label.text = "  ->  "
	arrow_label.add_theme_font_size_override("font_size", 40)
	arrow_label.set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER)
	preview_container.add_child(arrow_label)

	var upgraded_card_ui = CardUIScene.instantiate()
	upgraded_card_ui.card_data = card_to_preview.upgraded_version
	preview_container.add_child(upgraded_card_ui)
	
	upgrade_preview.show()

func _on_card_exit_for_preview():
	upgrade_preview.hide()

func _on_leave_pressed():
	GameManager.reward_chosen()
