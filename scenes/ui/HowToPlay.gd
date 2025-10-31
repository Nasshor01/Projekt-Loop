extends CanvasLayer

func _ready():
	$Panel/VBoxContainer/CloseButton.pressed.connect(GameManager.go_to_main_menu)

func show_guide():
	show()

func hide_guide():
	hide()
