extends CanvasLayer

func _ready():
	$Panel/CloseButton.pressed.connect(queue_free)

func show_guide():
	show()

func hide_guide():
	hide()
