# Soubor: scenes/CharSelect/CharacterSelectScreen.gd (UPRAVENÁ VERZE)
extends Control

# Do těchto proměnných v Godot editoru přetáhneš soubory Tank.tres a Paladin.tres
@export_group("Data postavy")
@export var character_class: ClassData
@export var character_subclass: SubclassData

@onready var paladin_panel: PanelContainer = $VBoxContainer/CharactersContainer/PaladinPanel
@onready var level_label: Label = $VBoxContainer/CharactersContainer/PaladinPanel/VBoxContainer/LevelLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready():
	level_label.text = "Level: %d" % SaveManager.meta_progress.player_level
	
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(GameManager.go_to_main_menu)

func _on_continue_pressed():
	# Zkontrolujeme, jestli jsou data v editoru nastavená
	if not character_class or not character_subclass:
		printerr("CHYBA: V CharacterSelectScreen nejsou v inspektoru nastavená data postavy!")
		return
		
	# Řekneme GameManageru, jakou postavu jsme vybrali A ABY ROVNOU ZOBRAZIL PREP SCREEN
	GameManager.select_character_and_go_to_prep(character_class, character_subclass)
