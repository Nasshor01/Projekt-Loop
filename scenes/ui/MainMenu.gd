# Soubor: scenes/ui/MainMenu.gd (SPRÁVNÁ VERZE)
extends Control

@onready var title_label: Label = $Label
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var load_run_button: Button = %LoadRunButton
@onready var how_to_play_button: Button = $VBoxContainer/HowToPlayButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton 

func _enter_tree():
	# Přidáme do skupiny pro snadné nalezení
	add_to_group("main_menu")

func _ready():
	play_button.pressed.connect(GameManager.go_to_character_select)
	load_run_button.pressed.connect(_on_load_run_button_pressed)
	how_to_play_button.pressed.connect(GameManager.go_to_how_to_play)
	settings_button.pressed.connect(GameManager.go_to_settings)
	exit_button.pressed.connect(func():
		if has_node("/root/DebugLogger"):
			DebugLogger.mark_quitting_legally()
		get_tree().quit()
	)
	
	_update_load_button_state()
	_update_ui_texts()

func _update_ui_texts():
	"""Aktualizuje UI texty pomocí překladů"""
	if title_label:
		title_label.text = tr("game.title")
	if play_button:
		play_button.text = tr("ui.main_menu.new_game")
	if how_to_play_button:
		how_to_play_button.text = tr("ui.main_menu.how_to_play")
	if settings_button:
		settings_button.text = tr("ui.main_menu.settings")
	if exit_button:
		exit_button.text = tr("ui.main_menu.exit")
	if load_run_button:
		load_run_button.text = tr("ui.main_menu.load_run")

func _on_load_run_button_pressed():
	if not SaveManager.has_saved_run():
		print(tr("ui.main_menu.no_saved_run"))
		return
	GameManager.load_and_start_saved_run()


func _update_load_button_state():
	"""Aktualizuje stav tlačítka 'Načíst run' podle existence uloženého runu"""
	if not is_instance_valid(load_run_button):
		return
	if SaveManager.has_saved_run():
		load_run_button.disabled = false
	else:
		load_run_button.disabled = true

func _on_new_game_pressed():
	# Tato funkce se již nepoužívá, ale pro jistotu ji zde nechávám zakomentovanou.
	# GameManager.go_to_character_screen()
	pass
