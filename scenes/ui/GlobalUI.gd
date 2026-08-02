extends CanvasLayer

@onready var hp_label = $MainPanel/MarginContainer/MainLayout/LeftSection/HPDisplay/HPLabel
@onready var gold_label = $MainPanel/MarginContainer/MainLayout/CenterSection/GoldDisplay/GoldLabel
@onready var floor_label = $MainPanel/MarginContainer/MainLayout/CenterSection/FloorDisplay/FloorLabel
@onready var ng_plus_label = $MainPanel/MarginContainer/MainLayout/CenterSection/NGPlusDisplay/NGPlusLabel
@onready var player_artifacts_ui = $MainPanel/MarginContainer/MainLayout/RightSection/PlayerArtifactsUI
@onready var deck_button = $MainPanel/MarginContainer/MainLayout/RightSection/DeckButton
@onready var menu_button = $MainPanel/MarginContainer/MainLayout/RightSection/MenuButton
@onready var deck_viewer = $DeckViewer
@onready var card_tooltip: CardTooltip = $TooltipLayer/CardTooltip
@onready var popup_menu = %PopupMenu
@onready var feedback_panel = %PlayerFeedback
@onready var settings_overlay = %SettingsOverlay
@onready var version_label = %VersionLabel

var _deck_tooltip_card_data: CardData = null

func _ready():
	# Připojení k signálům z PlayerData pro aktualizaci UI
	PlayerData.health_changed.connect(_on_player_health_changed)
	PlayerData.gold_changed.connect(_on_player_gold_changed)
	PlayerData.deck_changed.connect(_on_player_deck_changed)
	PlayerData.floor_changed.connect(_on_player_floor_changed)
	PlayerData.loop_level_changed.connect(_on_player_loop_level_changed)

	# Připojení tlačítek z hlavní lišty
	deck_button.pressed.connect(_on_deck_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

	# Připojení signálů z nového PopupMenu
	popup_menu.back_to_game_pressed.connect(_on_popup_back_to_game_pressed)
	popup_menu.restart_run_pressed.connect(_on_popup_restart_run_pressed)
	popup_menu.save_run_pressed.connect(_on_popup_save_run_pressed)
	popup_menu.back_to_char_select_pressed.connect(_on_popup_back_to_char_select_pressed)
	popup_menu.save_and_quit_pressed.connect(_on_popup_save_and_quit_pressed)
	popup_menu.back_to_menu_pressed.connect(_on_popup_back_to_menu_pressed)
	popup_menu.feedback_pressed.connect(_on_popup_feedback_pressed)
	popup_menu.settings_pressed.connect(_on_popup_settings_pressed)
	if settings_overlay != null:
		settings_overlay.overlay_closed.connect(_on_settings_overlay_closed)

	if deck_viewer.has_signal("card_right_clicked"):
		deck_viewer.card_right_clicked.connect(_on_deck_viewer_card_right_clicked)
	if deck_viewer.has_signal("card_unhovered"):
		deck_viewer.card_unhovered.connect(_on_deck_viewer_card_unhovered)

	# Prvotní nastavení všech hodnot v UI
	_update_ui_texts()
	_update_all_displays()
	_update_version_label()

func _update_version_label():
	if version_label:
		var version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
		version_label.text = "Pre-Alpha " + version

func _update_ui_texts():
	if menu_button:
		menu_button.text = tr("ui.global.menu")

# --- Aktualizace UI ---

func _update_all_displays():
	_on_player_health_changed(PlayerData.current_hp, PlayerData.max_hp)
	_on_player_gold_changed(PlayerData.gold)
	_on_player_deck_changed()
	_on_player_floor_changed(PlayerData.floors_cleared)
	_on_player_loop_level_changed(PlayerData.loop_level)

func _on_player_health_changed(new_health, new_max_health):
	hp_label.text = TranslationHelper.tr_format("ui.global.hp", {"current": new_health, "max": new_max_health})

func _on_player_gold_changed(new_gold):
	gold_label.text = TranslationHelper.tr_format("ui.global.gold", {"value": new_gold})

func _on_player_deck_changed():
	deck_button.text = TranslationHelper.tr_format("ui.global.deck", {"value": PlayerData.master_deck.size()})

func _on_player_floor_changed(new_floor):
	floor_label.text = TranslationHelper.tr_format("ui.global.floor", {"value": new_floor})

func _on_player_loop_level_changed(new_level):
	ng_plus_label.text = TranslationHelper.tr_format("ui.global.loop", {"value": new_level})

# --- Obsluha tlačítek v hlavní liště ---

func _on_deck_button_pressed():
	# Pokud je otevřené menu, zavřeme ho
	if popup_menu.visible:
		_close_menu()
	deck_viewer.display_deck(PlayerData.master_deck)

func _on_deck_viewer_card_right_clicked(card_data: CardData):
	if not card_tooltip:
		return
	if card_tooltip.visible and _deck_tooltip_card_data == card_data:
		card_tooltip.hide_tooltip()
		_deck_tooltip_card_data = null
	else:
		_deck_tooltip_card_data = card_data
		var screen_size = get_viewport().get_visible_rect().size
		var tooltip_size = Vector2(360, 420)
		var tooltip_pos = Vector2(screen_size.x - tooltip_size.x - 20, 90)
		tooltip_pos.x = clampf(tooltip_pos.x, 10, screen_size.x - tooltip_size.x - 10)
		tooltip_pos.y = clampf(tooltip_pos.y, 10, screen_size.y - tooltip_size.y - 10)
		card_tooltip.show_tooltip(card_data, tooltip_pos)

func _on_deck_viewer_card_unhovered() -> void:
	if card_tooltip and card_tooltip.visible:
		card_tooltip.hide_tooltip()
		_deck_tooltip_card_data = null

func _on_menu_button_pressed():
	# Pokud je otevřený prohlížeč balíčku, zavřeme ho
	deck_viewer.hide()
	# Zobrazíme menu a pozastavíme hru
	popup_menu.show()
	get_tree().paused = true

# --- Obsluha tlačítek z PopupMenu ---

func _close_menu():
	"""Skryje menu a zruší pozastavení hry."""
	popup_menu.hide()
	get_tree().paused = false

func _on_popup_back_to_game_pressed():
	_close_menu()

func _on_popup_restart_run_pressed():
	# Před přechodem na jinou scénu musíme hru "odpauzovat"
	get_tree().paused = false
	GameManager._on_popup_restart_run()

func _on_popup_save_run_pressed():
	GameManager._on_popup_save_run()
	# Po uložení jen zavřeme menu a pokračujeme ve hře
	_close_menu()

func _on_popup_back_to_char_select_pressed():
	get_tree().paused = false
	GameManager._on_popup_back_to_char_select()

func _on_popup_save_and_quit_pressed():
	get_tree().paused = false
	GameManager._on_popup_save_and_quit()

func _on_popup_back_to_menu_pressed():
	get_tree().paused = false
	GameManager._on_popup_back_to_menu()

func _on_popup_feedback_pressed():
	if feedback_panel:
		feedback_panel.open()

func _on_popup_settings_pressed():
	if settings_overlay != null:
		settings_overlay.show_as_overlay()

func _on_settings_overlay_closed():
	_close_menu()
