# Soubor: scenes/ui/MainMenu.gd (SPRÁVNÁ VERZE)
extends Control

@onready var new_game_button: Button = $VBoxContainer/new_game_button

func _ready():
	new_game_button.pressed.connect(_on_new_game_pressed)

func _on_new_game_pressed():
	# Řekneme GameManageru, aby přešel na obrazovku výběru postavy.
	# UŽ NEPOUŽÍVÁME change_scene_to_file!
	GameManager.go_to_character_screen()
