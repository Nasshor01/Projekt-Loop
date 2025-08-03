# Soubor: scenes/ui/CharacterScreen.gd (NOVÝ SKRIPT)
extends Control

# Cesty k uzlům, ujisti se, že odpovídají tvé scéně
@onready var level_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/LevelLabel
@onready var xp_bar: ProgressBar = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/XPBar
@onready var xp_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/XPLabel
@onready var points_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/PointsLabel
@onready var start_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/StartButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/BackButton

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	update_display()

func update_display():
	# Načteme data ze SaveManageru
	var meta = SaveManager.meta_progress
	var xp_needed = SaveManager.get_xp_for_next_level()
	
	# Aktualizujeme UI
	level_label.text = "Level: %d" % meta.player_level
	points_label.text = "Dovednostní body: %d" % meta.skill_points
	xp_label.text = "XP: %d / %d" % [meta.total_xp, xp_needed]
	
	# Nastavíme ProgressBar
	xp_bar.max_value = xp_needed
	xp_bar.value = meta.total_xp

func _on_start_pressed():
	GameManager.start_new_run()

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
