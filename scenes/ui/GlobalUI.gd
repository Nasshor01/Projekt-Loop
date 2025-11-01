extends CanvasLayer

@onready var hp_label = $MainPanel/MarginContainer/MainLayout/LeftSection/HPDisplay/HPLabel
@onready var gold_label = $MainPanel/MarginContainer/MainLayout/CenterSection/GoldDisplay/GoldLabel
@onready var floor_label = $MainPanel/MarginContainer/MainLayout/CenterSection/FloorDisplay/FloorLabel
@onready var ng_plus_label = $MainPanel/MarginContainer/MainLayout/CenterSection/NGPlusDisplay/NGPlusLabel
@onready var player_artifacts_ui = $MainPanel/MarginContainer/MainLayout/RightSection/PlayerArtifactsUI
@onready var deck_button = $MainPanel/MarginContainer/MainLayout/RightSection/DeckButton
@onready var menu_button = $MainPanel/MarginContainer/MainLayout/RightSection/MenuButton
@onready var deck_viewer = $DeckViewer
@onready var popup_menu = %PopupMenu

func _ready():
	# Připojení k signálům z PlayerData pro aktualizaci UI
	PlayerData.health_changed.connect(_on_player_health_changed)
	PlayerData.gold_changed.connect(_on_player_gold_changed)
	PlayerData.deck_changed.connect(_on_player_deck_changed)
	PlayerData.floor_changed.connect(_on_player_floor_changed)
	PlayerData.ng_plus_changed.connect(_on_player_ng_plus_changed)

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

	# Prvotní nastavení všech hodnot v UI
	_update_all_displays()

# --- Aktualizace UI ---

func _update_all_displays():
	_on_player_health_changed(PlayerData.current_hp, PlayerData.max_hp)
	_on_player_gold_changed(PlayerData.gold)
	_on_player_deck_changed()
	_on_player_floor_changed(PlayerData.floors_cleared)
	_on_player_ng_plus_changed(PlayerData.ng_plus_level)

func _on_player_health_changed(new_health, new_max_health):
	hp_label.text = "HP: %d/%d" % [new_health, new_max_health]

func _on_player_gold_changed(new_gold):
	gold_label.text = "Zlato: %d" % new_gold

func _on_player_deck_changed():
	deck_button.text = "Balíček (%d)" % PlayerData.master_deck.size()

func _on_player_floor_changed(new_floor):
	floor_label.text = "Patro: %d" % new_floor

func _on_player_ng_plus_changed(new_level):
	ng_plus_label.text = "NG+: %d" % new_level

# --- Obsluha tlačítek v hlavní liště ---

func _on_deck_button_pressed():
	# Pokud je otevřené menu, zavřeme ho
	if popup_menu.visible:
		_close_menu()
	deck_viewer.display_deck(PlayerData.master_deck)

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
	get_tree().call_group("GameManager", "_on_popup_restart_run")

func _on_popup_save_run_pressed():
	get_tree().call_group("GameManager", "_on_popup_save_run")
	# Po uložení jen zavřeme menu a pokračujeme ve hře
	_close_menu()

func _on_popup_back_to_char_select_pressed():
	get_tree().paused = false
	get_tree().call_group("GameManager", "_on_popup_back_to_char_select")

func _on_popup_save_and_quit_pressed():
	get_tree().paused = false
	get_tree().call_group("GameManager", "_on_popup_save_and_quit")

func _on_popup_back_to_menu_pressed():
	get_tree().paused = false
	get_tree().call_group("GameManager", "_on_popup_back_to_menu")
