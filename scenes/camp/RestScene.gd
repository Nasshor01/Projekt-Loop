# Soubor: scenes/camp/RestScene.gd (VERZE PRO LAYOUT VEDLE SEBE)
extends PanelContainer

# Cesty k uzlům v nové struktuře
@onready var heal_button: Button = $HBoxContainer/LeftColumn/OptionsContainer/HealButton
@onready var upgrade_button: Button = $HBoxContainer/LeftColumn/OptionsContainer/UpgradeButton
@onready var leave_button: Button = $HBoxContainer/LeftColumn/LeaveButton
@onready var title_label: Label = $HBoxContainer/LeftColumn/TitleLabel
@onready var options_container: HBoxContainer = $HBoxContainer/LeftColumn/OptionsContainer
@onready var card_pile_viewer = $HBoxContainer/LeftColumn/CardPileViewer
@onready var card_tooltip: CardTooltip = $CanvasLayer/CardTooltip

const HEAVY_STRIKE_CARD = preload("res://data/cards/everyone/heavy_strike.tres")

var _current_tooltip_card_data: CardData = null
var _preview_upgraded_faces: bool = true
var _upgrade_preview_toggle: Button = null

func _ready():
	heal_button.pressed.connect(_on_heal_pressed)
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	if card_pile_viewer.has_signal("card_right_clicked"):
		card_pile_viewer.card_right_clicked.connect(_on_card_right_clicked)
	if card_pile_viewer.has_signal("card_unhovered"):
		card_pile_viewer.card_unhovered.connect(_on_card_unhovered_dismiss_tooltip)
	_update_ui_texts()
	_ensure_preview_toggle()
	_apply_tutorial_lock()

func _ensure_preview_toggle() -> void:
	if is_instance_valid(_upgrade_preview_toggle):
		return
	_upgrade_preview_toggle = Button.new()
	_upgrade_preview_toggle.name = "UpgradePreviewToggle"
	_upgrade_preview_toggle.visible = false
	_upgrade_preview_toggle.toggle_mode = true
	_upgrade_preview_toggle.button_pressed = true
	_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on")
	_upgrade_preview_toggle.pressed.connect(_on_preview_toggle_pressed)
	# Insert under title, above options
	var left_col: VBoxContainer = $HBoxContainer/LeftColumn
	left_col.add_child(_upgrade_preview_toggle)
	left_col.move_child(_upgrade_preview_toggle, options_container.get_index())

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
	if is_instance_valid(_upgrade_preview_toggle):
		_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on") if _preview_upgraded_faces else tr("ui.rest.preview_upgrades_off")

func _on_heal_pressed():
	var heal_amount = int(PlayerData.max_hp * 0.3)
	PlayerData.heal(heal_amount)
	_on_leave_pressed()

func _on_upgrade_pressed():
	options_container.hide()
	title_label.text = tr("ui.rest.choose_card")
	_preview_upgraded_faces = true
	if is_instance_valid(_upgrade_preview_toggle):
		_upgrade_preview_toggle.visible = true
		_upgrade_preview_toggle.button_pressed = true
		_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on")
	
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

	if card_pile_viewer.has_method("show_upgrade_selection"):
		card_pile_viewer.show_upgrade_selection(upgradeable_cards, _preview_upgraded_faces)
	else:
		card_pile_viewer.show_cards(upgradeable_cards)

	if not card_pile_viewer.is_connected("card_clicked_in_viewer", _on_card_selected_for_upgrade):
		card_pile_viewer.card_clicked_in_viewer.connect(_on_card_selected_for_upgrade)

func _on_preview_toggle_pressed() -> void:
	_preview_upgraded_faces = _upgrade_preview_toggle.button_pressed
	_upgrade_preview_toggle.text = tr("ui.rest.preview_upgrades_on") if _preview_upgraded_faces else tr("ui.rest.preview_upgrades_off")
	if card_pile_viewer.has_method("set_upgrade_preview_faces"):
		card_pile_viewer.set_upgrade_preview_faces(_preview_upgraded_faces)

func _on_card_selected_for_upgrade(card_to_upgrade: CardData):
	var card_index = PlayerData.master_deck.find(card_to_upgrade)
	if card_index != -1 and is_instance_valid(card_to_upgrade.upgraded_version):
		# Duplicate upgraded template so Seal/meta stays on this one deck slot only.
		var upgraded: CardData = PlayerData.duplicate_card_for_deck(card_to_upgrade.upgraded_version)
		PlayerData.transfer_seal_on_upgrade(card_to_upgrade, upgraded)
		PlayerData.master_deck[card_index] = upgraded
		print(TranslationHelper.tr_format("log.rest.card_upgraded", {"from": card_to_upgrade.get_localized_name(), "to": upgraded.get_localized_name()}))
	
	_on_leave_pressed()

func _on_card_right_clicked(card_data: CardData):
	if not card_tooltip:
		return
	if card_tooltip.visible and _current_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null
	else:
		_current_tooltip_card_data = card_data
		_show_card_tooltip()

func _on_card_unhovered_dismiss_tooltip() -> void:
	if card_tooltip and card_tooltip.visible:
		card_tooltip.hide_tooltip()
		_current_tooltip_card_data = null

func _show_card_tooltip():
	if not _current_tooltip_card_data or not card_tooltip:
		return
	var screen_size = get_viewport().get_visible_rect().size
	var tooltip_size = Vector2(360, 420)
	var tooltip_pos = Vector2(screen_size.x - tooltip_size.x - 20, 80)
	tooltip_pos.x = clampf(tooltip_pos.x, 10, screen_size.x - tooltip_size.x - 10)
	tooltip_pos.y = clampf(tooltip_pos.y, 10, screen_size.y - tooltip_size.y - 10)
	card_tooltip.show_tooltip(_current_tooltip_card_data, tooltip_pos)

var _coop_my_ready: bool = false
var _coop_other_ready: bool = false

func _on_leave_pressed():
	if has_node("/root/GameManager") and GameManager.tutorial_active and GameManager.tutorial_step == GameManager.TUTORIAL_STEP_CAMP_UPGRADE:
		GameManager.tutorial_step = GameManager.TUTORIAL_STEP_MAP_FINAL
	
	if is_instance_valid(_upgrade_preview_toggle):
		_upgrade_preview_toggle.visible = false
	
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
