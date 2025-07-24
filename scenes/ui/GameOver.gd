# Soubor: scenes/ui/GameOver.gd
# POPIS: Skript pro obrazovku konce hry.
extends Control

@onready var restart_button: Button = $RestartButton

func _ready():
	# Propojíme signál tlačítka s funkcí pro restart.
	restart_button.pressed.connect(_on_restart_button_pressed)

func _on_restart_button_pressed():
	# Řekneme GameManageru, aby zahájil nový běh.
	# GameManager se postará o smazání této scény a načtení nové mapy.
	GameManager.start_new_run()
