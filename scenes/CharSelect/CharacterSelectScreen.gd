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

var _coop_client_ready: bool = false

func _ready():
	if title_label:
		title_label.text = tr("ui.char_select.title")
	if name_label and character_class:
		name_label.text = character_class.get_localized_name()
	level_label.text = TranslationHelper.tr_format("ui.char_select.level", {"value": SaveManager.meta_progress.player_level})
	continue_button.text = tr("ui.char_select.continue")
	back_button.text = tr("ui.common.back")
	
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Coop: host nemůže pokračovat, dokud klient nevybere postavu
	if _is_coop():
		if MultiplayerManager.is_server():
			continue_button.disabled = true
			if title_label:
				title_label.text = tr("ui.char_select.title") + " — Čekám na výběr druhého hráče."
		else:
			if title_label:
				title_label.text = tr("ui.char_select.title") + " — Vyber postavu a pokračuj."

func _is_coop() -> bool:
	return has_node("/root/GameManager") and GameManager.is_coop_run and has_node("/root/MultiplayerManager") and MultiplayerManager.has_active_connection()

func _on_back_pressed():
	if _is_coop():
		MultiplayerManager.close_connection()
	GameManager.go_to_main_menu()

func _on_continue_pressed():
	if not character_class or not character_subclass:
		printerr("CHYBA: V CharacterSelectScreen nejsou v inspektoru nastavená data postavy!")
		return

	if _is_coop():
		if MultiplayerManager.is_server():
			# Host: pokračuje až když klient už vybral (tlačítko je odemčené)
			GameManager.go_to_run_prep_screen(character_class, character_subclass)
		else:
			# Klient: pošle hostovi výběr (cesty), pak přechod na run prep
			var class_path = character_class.resource_path if character_class else ""
			var subclass_path = character_subclass.resource_path if character_subclass else ""
			rpc("_rpc_client_character_ready", class_path, subclass_path)
			GameManager.go_to_run_prep_screen(character_class, character_subclass)
	else:
		GameManager.go_to_run_prep_screen(character_class, character_subclass)

@rpc("any_peer")
func _rpc_client_character_ready(class_path: String = "", subclass_path: String = ""):
	if MultiplayerManager.is_server() and is_node_ready():
		GameManager.coop_client_class_path = class_path
		GameManager.coop_client_subclass_path = subclass_path
		_coop_client_ready = true
		continue_button.disabled = false
		if title_label:
			title_label.text = tr("ui.char_select.title") + " — Druhý hráč vybral. Můžeš pokračovat."
