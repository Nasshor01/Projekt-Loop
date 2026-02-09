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
const HEAVY_STRIKE_CARD = preload("res://data/cards/everyone/heavy_strike.tres")

func _ready():
	heal_button.pressed.connect(_on_heal_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	_update_ui_texts()
	
	upgrade_preview.hide()
	_apply_tutorial_lock()

func _apply_tutorial_lock():
	if not has_node("/root/GameManager"):
		return
	if not GameManager.tutorial_active or GameManager.tutorial_step != GameManager.TUTORIAL_STEP_CAMP_UPGRADE:
		return
	heal_button.disabled = true
	leave_button.disabled = true
	title_label.text = tr("ui.tutorial.camp_upgrade_prompt")
	_highlight_upgrade_button(true)

func _update_ui_texts():
	var heal_amount = int(PlayerData.max_hp * 0.3)
	heal_button.text = TranslationHelper.tr_format("ui.rest.heal", {"value": heal_amount})
	upgrade_button.text = tr("ui.rest.upgrade")
	leave_button.text = tr("ui.rest.leave")
	title_label.text = tr("ui.rest.title")

func _on_heal_pressed():
	var heal_amount = int(PlayerData.max_hp * 0.3)
	PlayerData.heal(heal_amount)
	_on_leave_pressed()

func _on_upgrade_pressed():
	options_container.hide()
	title_label.text = tr("ui.rest.choose_card")
	
	var upgradeable_cards: Array[CardData] = []
	for card in PlayerData.master_deck:
		if not card.is_upgraded and is_instance_valid(card.upgraded_version):
			upgradeable_cards.append(card)
	
	if has_node("/root/GameManager") and GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_CAMP_UPGRADE:
		upgradeable_cards = []
		for card in PlayerData.master_deck:
			if card.resource_path == HEAVY_STRIKE_CARD.resource_path and not card.is_upgraded and is_instance_valid(card.upgraded_version):
				upgradeable_cards.append(card)
		_highlight_upgrade_button(false)

	card_pile_viewer.show_cards(upgradeable_cards, Vector2(0.7, 0.7))
	if not card_pile_viewer.is_connected("card_clicked_in_viewer", _on_card_selected_for_upgrade):
		card_pile_viewer.card_clicked_in_viewer.connect(_on_card_selected_for_upgrade)
	_connect_upgrade_card_signals()

func _connect_upgrade_card_signals():
	for card_ui in card_pile_viewer.grid_container.get_children():
		if card_ui is CardUI:
			if not card_ui.mouse_entered.is_connected(_on_card_hovered):
				card_ui.mouse_entered.connect(_on_card_hovered.bind(card_ui.card_data))
			if not card_ui.mouse_exited.is_connected(_on_card_exit_for_preview):
				card_ui.mouse_exited.connect(_on_card_exit_for_preview)
			if not card_ui.is_connected("card_clicked", _on_card_selected_for_upgrade):
				card_ui.card_clicked.connect(_on_card_selected_for_upgrade)
			if not card_ui.is_connected("card_right_clicked", _on_card_right_clicked):
				card_ui.card_right_clicked.connect(_on_card_right_clicked)

func _on_card_selected_for_upgrade(card_to_upgrade: CardData):
	var card_index = PlayerData.master_deck.find(card_to_upgrade)
	if card_index != -1:
		PlayerData.master_deck[card_index] = card_to_upgrade.upgraded_version
		print(TranslationHelper.tr_format("log.rest.card_upgraded", {"from": card_to_upgrade.get_localized_name(), "to": card_to_upgrade.upgraded_version.get_localized_name()}))
	
	_on_leave_pressed()

func _on_card_hovered(card_to_preview: CardData):
	var preview_container = upgrade_preview.get_node("CenterContainer/HBoxContainer")
	
	for child in preview_container.get_children():
		child.queue_free()
	
	if not is_instance_valid(card_to_preview.upgraded_version):
		return

	var original_card_ui = CardUIScene.instantiate()
	original_card_ui.card_data = card_to_preview
	original_card_ui.is_draggable = false
	original_card_ui.static_layout = true
	original_card_ui.custom_minimum_size = Vector2(140, 210)
	original_card_ui.pivot_offset = original_card_ui.custom_minimum_size * 0.5
	original_card_ui.set_target_scale(Vector2(0.7, 0.7))
	preview_container.add_child(original_card_ui)
	call_deferred("_sync_preview_card_layout", original_card_ui)

	var arrow_label = Label.new()
	arrow_label.text = "  ->  "
	arrow_label.add_theme_font_size_override("font_size", 40)
	arrow_label.set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER)
	preview_container.add_child(arrow_label)

	var upgraded_card_ui = CardUIScene.instantiate()
	upgraded_card_ui.card_data = card_to_preview.upgraded_version
	upgraded_card_ui.is_draggable = false
	upgraded_card_ui.static_layout = true
	upgraded_card_ui.custom_minimum_size = Vector2(140, 210)
	upgraded_card_ui.pivot_offset = upgraded_card_ui.custom_minimum_size * 0.5
	upgraded_card_ui.set_target_scale(Vector2(0.7, 0.7))
	preview_container.add_child(upgraded_card_ui)
	call_deferred("_sync_preview_card_layout", upgraded_card_ui)
	
	upgrade_preview.show()

func _on_card_exit_for_preview():
	upgrade_preview.hide()

func _on_card_right_clicked(_data: CardData):
	"""Right-click tooltip - RestScene has no CardTooltip; override in subclass or add node to show tooltip."""
	pass

func _sync_preview_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)
	card_ui.set_target_scale(card_ui.scale)
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_leave_pressed():
	if has_node("/root/GameManager") and GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_CAMP_UPGRADE:
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_MAP_FINAL
	GameManager.reward_chosen()

func _highlight_upgrade_button(enable: bool):
	if not is_instance_valid(upgrade_button):
		return
	if enable:
		var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		tween.tween_property(upgrade_button, "scale", Vector2(1.08, 1.08), 0.4)
		tween.tween_property(upgrade_button, "scale", Vector2(1.0, 1.0), 0.4)
		upgrade_button.set_meta("tutorial_pulse", tween)
	else:
		if upgrade_button.has_meta("tutorial_pulse"):
			var old_tween: Tween = upgrade_button.get_meta("tutorial_pulse")
			if is_instance_valid(old_tween):
				old_tween.kill()
			upgrade_button.remove_meta("tutorial_pulse")
		upgrade_button.scale = Vector2.ONE
