extends CanvasLayer

signal play_again_pressed
signal main_menu_pressed

func _ready():
	$VBoxContainer/PlayAgainButton.pressed.connect(_on_play_again_pressed)
	$VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)

func _on_play_again_pressed():
	emit_signal("play_again_pressed")

func _on_main_menu_pressed():
	emit_signal("main_menu_pressed")
