# Soubor: scenes/CharSelect/CharacterSelectScreen.gd (UPRAVENÁ VERZE)
extends Control

# Do těchto proměnných v Godot editoru přetáhneš soubory Tank.tres a Paladin.tres
@export_group("Data postavy")
@export var character_class: ClassData
@export var character_subclass: SubclassData

@onready var paladin_panel: PanelContainer = $VBoxContainer/CharactersContainer/PaladinPanel
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var name_label: Label = $VBoxContainer/CharactersContainer/PaladinPanel/VBoxContainer/NameLabel
@onready var level_label: Label = $VBoxContainer/CharactersContainer/PaladinPanel/VBoxContainer/LevelLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var back_button: Button = $VBoxContainer/BackButton

func _ready():
	if title_label:
		title_label.text = tr("ui.char_select.title")
	if name_label and character_class:
		name_label.text = character_class.get_localized_name()
	level_label.text = TranslationHelper.tr_format("ui.char_select.level", {"value": SaveManager.meta_progress.player_level})
	continue_button.text = tr("ui.char_select.continue")
	back_button.text = tr("ui.common.back")
	
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(GameManager.go_to_main_menu)

func _on_continue_pressed():
	if not character_class or not character_subclass:
		printerr("CHYBA: V CharacterSelectScreen nejsou v inspektoru nastavená data postavy!")
		return
		
	# Zavoláme upravenou funkci GameManageru a předáme jí data
	GameManager.go_to_run_prep_screen(character_class, character_subclass)
