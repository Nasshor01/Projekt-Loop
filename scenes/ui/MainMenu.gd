# Soubor: scenes/ui/MainMenu.gd (SPRÁVNÁ VERZE)
extends Control

const HowToPlayScene = preload("res://scenes/ui/HowToPlay.tscn")

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var how_to_play_button: Button = $VBoxContainer/HowToPlayButton
@onready var exit_button: Button = $VBoxContainer/ExitButton 

func _ready():
	play_button.pressed.connect(GameManager.go_to_character_select)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	exit_button.pressed.connect(func(): get_tree().quit())

func _on_how_to_play_pressed():
	var how_to_play_instance = HowToPlayScene.instantiate()
	add_child(how_to_play_instance)

func _on_new_game_pressed():
	# Řekneme GameManageru, aby přešel na obrazovku výběru postavy.
	# UŽ NEPOUŽÍVÁME change_scene_to_file!
	GameManager.go_to_character_screen()
