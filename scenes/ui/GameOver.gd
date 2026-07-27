# Soubor: scenes/ui/GameOver.gd
# POPIS: Skript pro obrazovku konce hry.
extends Control

@onready var restart_button: Button = $RestartButton
@onready var village_button: Button = $VillageButton
@onready var title_label: Label = $Label

func _ready():
	restart_button.pressed.connect(_on_restart_button_pressed)
	if village_button:
		village_button.pressed.connect(GameManager.go_to_village)
		village_button.text = tr("ui.game_over.village")
	if title_label:
		title_label.text = tr("ui.game_over.title")
	if restart_button:
		restart_button.text = tr("ui.game_over.restart")

func _on_restart_button_pressed():
	GameManager.start_new_run()
