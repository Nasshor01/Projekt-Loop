# Soubor: scenes/ui/MainMenu.gd (SPRÁVNÁ VERZE)
extends Control

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var exit_button: Button = $VBoxContainer/ExitButton 

func _ready():
	play_button.pressed.connect(GameManager.go_to_character_select)
	exit_button.pressed.connect(func(): get_tree().quit())

func _on_new_game_pressed():
	# Řekneme GameManageru, aby přešel na obrazovku výběru postavy.
	# UŽ NEPOUŽÍVÁME change_scene_to_file!
	GameManager.go_to_character_screen()
