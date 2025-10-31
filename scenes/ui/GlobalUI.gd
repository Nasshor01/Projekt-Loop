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
	PlayerData.health_changed.connect(_on_player_health_changed)
	PlayerData.gold_changed.connect(_on_player_gold_changed)
	PlayerData.deck_changed.connect(_on_player_deck_changed)
	PlayerData.floors_cleared_changed.connect(_on_player_floors_cleared_changed)
	PlayerData.ng_plus_level_changed.connect(_on_player_ng_plus_level_changed)

	deck_button.pressed.connect(_on_deck_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)

	# Connect signals from PopupMenu to GameManager
	popup_menu.restart_run_pressed.connect(func(): get_tree().call_group("GameManager", "_on_popup_restart_run"))
	popup_menu.save_run_pressed.connect(func(): get_tree().call_group("GameManager", "_on_popup_save_run"))
	popup_menu.back_to_char_select_pressed.connect(func(): get_tree().call_group("GameManager", "_on_popup_back_to_char_select"))
	popup_menu.save_and_quit_pressed.connect(func(): get_tree().call_group("GameManager", "_on_popup_save_and_quit"))
	popup_menu.back_to_menu_pressed.connect(func(): get_tree().call_group("GameManager", "_on_popup_back_to_menu"))

	_update_all_displays()

func _update_all_displays():
	_on_player_health_changed(PlayerData.health, PlayerData.max_health)
	_on_player_gold_changed(PlayerData.gold)
	_on_player_deck_changed()
	_on_player_floors_cleared_changed(PlayerData.floors_cleared)
	_on_player_ng_plus_level_changed(PlayerData.ng_plus_level)

func _on_player_health_changed(new_health, new_max_health):
	hp_label.text = "HP: %d/%d" % [new_health, new_max_health]

func _on_player_gold_changed(new_gold):
	gold_label.text = "Zlato: %d" % new_gold

func _on_player_deck_changed():
	deck_button.text = "Balíček (%d)" % PlayerData.master_deck.size()

func _on_player_floors_cleared_changed(new_floors):
	floor_label.text = "Patro: %d" % new_floors

func _on_player_ng_plus_level_changed(new_level):
	ng_plus_label.text = "NG+: %d" % new_level

func _on_deck_button_pressed():
	popup_menu.hide()
	deck_viewer.display_deck(PlayerData.master_deck)

func _on_menu_button_pressed():
	deck_viewer.hide()
	popup_menu.visible = not popup_menu.visible
