# Soubor: scenes/ui/MainMenu.gd (SPRÁVNÁ VERZE)
extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var load_run_button: Button = %LoadRunButton
@onready var how_to_play_button: Button = $VBoxContainer/HowToPlayButton
@onready var exit_button: Button = $VBoxContainer/ExitButton 

func _ready():
	play_button.pressed.connect(GameManager.go_to_character_select)
	load_run_button.pressed.connect(GameManager.load_and_start_saved_run)
	how_to_play_button.pressed.connect(GameManager.go_to_how_to_play)
	exit_button.pressed.connect(func(): get_tree().quit())

	if SaveManager.has_saved_run():
		load_run_button.disabled = false
	else:
		load_run_button.disabled = true

func _on_new_game_pressed():
	# Tato funkce se již nepoužívá, ale pro jistotu ji zde nechávám zakomentovanou.
	# GameManager.go_to_character_screen()
	pass
