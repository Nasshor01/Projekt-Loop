# Soubor: scenes/CharSelect/CharacterSelectScreen.gd
extends Control

@export_group("Data postav")
@export var paladin_class: ClassData
@export var paladin_subclass: SubclassData
@export var trapper_class: ClassData
@export var trapper_subclass: SubclassData

@onready var title_label: Label = $CenterContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var continue_button: Button = $CenterContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var back_button: Button = $CenterContainer/MarginContainer/VBoxContainer/BackButton
@onready var paladin_panel: PanelContainer = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/PaladinPanel
@onready var trapper_panel: PanelContainer = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/TrapperPanel
@onready var paladin_name: Label = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/PaladinPanel/VBoxContainer/NameLabel
@onready var trapper_name: Label = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/TrapperPanel/VBoxContainer/NameLabel
@onready var paladin_level: Label = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/PaladinPanel/VBoxContainer/LevelLabel
@onready var trapper_level: Label = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/TrapperPanel/VBoxContainer/LevelLabel
@onready var trapper_portrait: TextureRect = $CenterContainer/MarginContainer/VBoxContainer/CharactersContainer/TrapperPanel/VBoxContainer/Portrait

const LOCKED_MODULATE := Color(0.42, 0.42, 0.48, 1.0)

var _selected_class: ClassData = null
var _selected_subclass: SubclassData = null
var _coop_client_ready: bool = false


func _ready() -> void:
	if title_label:
		title_label.text = tr("ui.char_select.title")
	continue_button.text = tr("ui.char_select.continue")
	back_button.text = tr("ui.common.back")

	if paladin_name and paladin_subclass:
		paladin_name.text = paladin_subclass.get_localized_name()
	if trapper_name and trapper_subclass:
		trapper_name.text = trapper_subclass.get_localized_name()
	if paladin_level and paladin_subclass:
		paladin_level.text = TranslationHelper.tr_format(
			"ui.char_select.level",
			{"value": SaveManager.meta_progress.get_hero_level(paladin_subclass.subclass_id)}
		)

	paladin_panel.gui_input.connect(_on_paladin_gui_input)
	trapper_panel.gui_input.connect(_on_trapper_gui_input)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)
	if SaveManager:
		SaveManager.meta_progress_changed.connect(_refresh_lock_states)

	_refresh_lock_states()
	_select_character(paladin_class, paladin_subclass)

	if _is_coop():
		if MultiplayerManager.is_server():
			continue_button.disabled = true
			if title_label:
				title_label.text = tr("ui.char_select.title") + " — " + tr("ui.char_select.waiting_partner")
		else:
			if title_label:
				title_label.text = tr("ui.char_select.title") + " — " + tr("ui.char_select.choose_and_continue")


func _is_trapper_unlocked() -> bool:
	if not trapper_subclass:
		return false
	if not SaveManager or not SaveManager.meta_progress:
		return false
	return SaveManager.meta_progress.is_hero_unlocked(trapper_subclass.subclass_id)


func _refresh_lock_states() -> void:
	var unlocked := _is_trapper_unlocked()
	trapper_panel.modulate = Color.WHITE if unlocked else LOCKED_MODULATE
	if trapper_portrait:
		trapper_portrait.modulate = Color.WHITE if unlocked else LOCKED_MODULATE
	if trapper_level and trapper_subclass:
		if unlocked:
			trapper_level.text = TranslationHelper.tr_format(
				"ui.char_select.level",
				{"value": SaveManager.meta_progress.get_hero_level(trapper_subclass.subclass_id)}
			)
		else:
			trapper_level.text = VillageBonuses.get_trapper_lock_hint()
	if not unlocked and _selected_subclass == trapper_subclass:
		_select_character(paladin_class, paladin_subclass)
	else:
		_update_selection_visuals()


func _is_coop() -> bool:
	return has_node("/root/GameManager") and GameManager.is_coop_run and has_node("/root/MultiplayerManager") and MultiplayerManager.has_active_connection()


func _on_back_pressed() -> void:
	if _is_coop():
		MultiplayerManager.close_connection()
	GameManager.go_to_main_menu()


func _on_paladin_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_character(paladin_class, paladin_subclass)


func _on_trapper_gui_input(event: InputEvent) -> void:
	if not _is_trapper_unlocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_character(trapper_class, trapper_subclass)


func _select_character(p_class: ClassData, p_subclass: SubclassData) -> void:
	if p_subclass == trapper_subclass and not _is_trapper_unlocked():
		return
	_selected_class = p_class
	_selected_subclass = p_subclass
	_update_selection_visuals()


func _update_selection_visuals() -> void:
	var selected_sb := StyleBoxFlat.new()
	selected_sb.bg_color = Color(0.25, 0.35, 0.28, 0.95)
	selected_sb.set_border_width_all(3)
	selected_sb.border_color = Color(0.45, 0.85, 0.55)
	selected_sb.set_corner_radius_all(6)
	var idle_sb := StyleBoxFlat.new()
	idle_sb.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	idle_sb.set_border_width_all(1)
	idle_sb.border_color = Color(0.35, 0.35, 0.4)
	idle_sb.set_corner_radius_all(6)
	var locked_sb := StyleBoxFlat.new()
	locked_sb.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	locked_sb.set_border_width_all(1)
	locked_sb.border_color = Color(0.28, 0.28, 0.32)
	locked_sb.set_corner_radius_all(6)

	paladin_panel.add_theme_stylebox_override("panel", selected_sb if _selected_subclass == paladin_subclass else idle_sb)
	if _is_trapper_unlocked():
		trapper_panel.add_theme_stylebox_override("panel", selected_sb if _selected_subclass == trapper_subclass else idle_sb)
	else:
		trapper_panel.add_theme_stylebox_override("panel", locked_sb)


func _on_continue_pressed() -> void:
	if not _selected_class or not _selected_subclass:
		printerr("CHYBA: Není vybraná postava!")
		return
	if _selected_subclass == trapper_subclass and not _is_trapper_unlocked():
		_select_character(paladin_class, paladin_subclass)
		return

	if _is_coop():
		if MultiplayerManager.is_server():
			GameManager.go_to_run_prep_screen(_selected_class, _selected_subclass)
		else:
			var class_path = _selected_class.resource_path if _selected_class else ""
			var subclass_path = _selected_subclass.resource_path if _selected_subclass else ""
			rpc("_rpc_client_character_ready", class_path, subclass_path)
			GameManager.go_to_run_prep_screen(_selected_class, _selected_subclass)
	else:
		GameManager.go_to_run_prep_screen(_selected_class, _selected_subclass)


@rpc("any_peer")
func _rpc_client_character_ready(class_path: String = "", subclass_path: String = "") -> void:
	if MultiplayerManager.is_server() and is_node_ready():
		GameManager.coop_client_class_path = class_path
		GameManager.coop_client_subclass_path = subclass_path
		_coop_client_ready = true
		continue_button.disabled = false
		if title_label:
			title_label.text = tr("ui.char_select.title") + " — " + tr("ui.char_select.partner_ready")
