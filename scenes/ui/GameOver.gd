# Soubor: scenes/ui/GameOver.gd
# POPIS: Skript pro obrazovku konce hry.
extends Control

@onready var restart_button: Button = $RestartButton
@onready var title_label: Label = $Label

func _ready():
	# Propojíme signál tlačítka s funkcí pro restart.
	restart_button.pressed.connect(_on_restart_button_pressed)
	if title_label:
		title_label.text = tr("ui.game_over.title")
	if restart_button:
		restart_button.text = tr("ui.game_over.restart")

func _on_restart_button_pressed():
	# Řekneme GameManageru, aby zahájil nový běh.
	# GameManager se postará o smazání této scény a načtení nové mapy.
	GameManager.start_new_run()
