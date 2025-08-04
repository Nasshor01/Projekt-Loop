# Soubor: scenes/CharSelect/CharacterSelectScreen.gd (NOVÝ SKRIPT)
extends Control

# Cesty k uzlům, uprav podle potřeby
@onready var paladin_panel: PanelContainer = $VBoxContainer/CharactersContainer/PaladinPanel
@onready var level_label: Label = $VBoxContainer/CharactersContainer/PaladinPanel/VBoxContainer/LevelLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var back_button: Button = $VBoxContainer/BackButton

# Zatím máme vybraného Paladina napevno
var selected_character = "Paladin"

func _ready():
	# Načteme level z uložených dat a zobrazíme ho
	level_label.text = "Level: %d" % SaveManager.meta_progress.player_level
	
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(GameManager.go_to_main_menu)
	
	# Zde by byla logika pro výběr (např. změna barvy panelu po kliknutí)

func _on_continue_pressed():
	# Řekneme GameManageru, aby přešel na přípravnou obrazovku
	GameManager.go_to_run_prep_screen()
