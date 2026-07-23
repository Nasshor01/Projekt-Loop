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
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")
const HEAVY_STRIKE_CARD = preload("res://data/cards/everyone/heavy_strike.tres")

var _current_tooltip_card_data: CardData = null

func _ready():
	heal_button.pressed.connect(_on_heal_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	if card_pile_viewer.has_signal("card_right_clicked"):
		card_pile_viewer.card_right_clicked.connect(_on_card_right_clicked)
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

	card_pile_viewer.show_cards(upgradeable_cards)
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
	original_card_ui.apply_display_mode(CardUI.DisplayMode.REWARD)
	preview_container.add_child(original_card_ui)
	call_deferred("_sync_preview_card_layout", original_card_ui)

	var arrow_label = Label.new()
	arrow_label.text = "  ->  "
	arrow_label.add_theme_font_size_override("font_size", 40)
	arrow_label.set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER)
	preview_container.add_child(arrow_label)

	var upgraded_card_ui = CardUIScene.instantiate()
	upgraded_card_ui.card_data = card_to_preview.upgraded_version
	upgraded_card_ui.apply_display_mode(CardUI.DisplayMode.REWARD)
	preview_container.add_child(upgraded_card_ui)
	call_deferred("_sync_preview_card_layout", upgraded_card_ui)
	
	upgrade_preview.show()

func _on_card_exit_for_preview():
	upgrade_preview.hide()

func _on_card_right_clicked(card_data: CardData):
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

func _sync_preview_card_layout(card_ui: CardUI):
	if not is_instance_valid(card_ui):
		return
	card_ui.set_target_position(card_ui.position)
	card_ui.set_target_scale(card_ui.scale)
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

var _coop_my_ready: bool = false
var _coop_other_ready: bool = false

func _on_leave_pressed():
	if has_node("/root/GameManager") and GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_CAMP_UPGRADE:
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_MAP_FINAL
	
	# Coop: čekáme na oba hráče
	var is_coop = has_node("/root/GameManager") and GameManager.is_coop_run
	if is_coop and has_node("/root/MultiplayerManager"):
		_coop_my_ready = true
		leave_button.disabled = true
		leave_button.text = tr("ui.rest.waiting")
		rpc("_rpc_rest_peer_ready")
		_check_rest_both_ready()
		return
	
	GameManager.reward_chosen()

@rpc("any_peer", "call_remote")
func _rpc_rest_peer_ready():
	"""Druhý hráč je připraven odejít z rest scény."""
	_coop_other_ready = true
	_check_rest_both_ready()

func _check_rest_both_ready():
	if _coop_my_ready and _coop_other_ready:
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
