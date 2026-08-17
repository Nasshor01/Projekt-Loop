# Soubor: scenes/CharSelect/CharacterSelectScreen.gd
extends Control

@export_group("Data postav")
@export var paladin_class: ClassData
@export var paladin_subclass: SubclassData
@export var trapper_class: ClassData
@export var trapper_subclass: SubclassData

@export_group("Select art")
## Full STS2 painting (~1920×1080, character on the right). Placeholder portraits work until then.
@export var paladin_select_art: Texture2D
@export var trapper_select_art: Texture2D

const BASE_HP := 50
const BASE_GOLD := 50

@onready var hero_art: TextureRect = %HeroArt
@onready var coop_status: Label = %CoopStatus
@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HpLabel
@onready var gold_label: Label = %GoldLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var xp_label: Label = %XPLabel
@onready var paladin_thumb: PanelContainer = %PaladinThumb
@onready var trapper_thumb: PanelContainer = %TrapperThumb
@onready var paladin_portrait: TextureRect = %PaladinPortrait
@onready var trapper_portrait: TextureRect = %TrapperPortrait
@onready var lock_overlay: ColorRect = %LockOverlay
@onready var continue_button: Button = %ContinueButton
@onready var back_button: Button = %BackButton

var _selected_class: ClassData = null
var _selected_subclass: SubclassData = null
var _coop_client_ready: bool = false


func _ready() -> void:
	continue_button.text = tr("ui.char_select.continue")
	back_button.text = tr("ui.common.back")

	paladin_thumb.gui_input.connect(_on_paladin_gui_input)
	trapper_thumb.gui_input.connect(_on_trapper_gui_input)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)
	if SaveManager:
		SaveManager.meta_progress_changed.connect(_refresh_lock_states)

	_refresh_lock_states()
	_select_character(paladin_class, paladin_subclass)
	_setup_coop_status()


func _setup_coop_status() -> void:
	if not _is_coop():
		coop_status.visible = false
		return
	coop_status.visible = true
	if MultiplayerManager.is_server():
		continue_button.disabled = true
		coop_status.text = tr("ui.char_select.waiting_partner")
	else:
		coop_status.text = tr("ui.char_select.choose_and_continue")


func _is_trapper_unlocked() -> bool:
	if not trapper_subclass:
		return false
	if not SaveManager or not SaveManager.meta_progress:
		return false
	return SaveManager.meta_progress.is_hero_unlocked(trapper_subclass.subclass_id)


func _refresh_lock_states() -> void:
	var unlocked := _is_trapper_unlocked()
	lock_overlay.visible = not unlocked
	trapper_portrait.modulate = Color.WHITE if unlocked else Color(0.28, 0.28, 0.32, 1.0)
	trapper_thumb.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_FORBIDDEN
	)
	trapper_thumb.tooltip_text = "" if unlocked else VillageBonuses.get_trapper_lock_hint()
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
	_fill_info_panel(p_subclass)
	_update_selection_visuals()


func _fill_info_panel(p_subclass: SubclassData) -> void:
	if not p_subclass:
		return
	name_label.text = p_subclass.get_localized_name()
	var hp := _starting_hp(p_subclass)
	hp_label.text = "%d/%d" % [hp, hp]
	gold_label.text = str(BASE_GOLD + VillageBonuses.get_starting_gold_bonus())
	var flavor_key := "class.%s.flavor" % p_subclass.subclass_id
	var flavor := tr(flavor_key)
	if flavor.is_empty() or flavor == flavor_key:
		flavor = p_subclass.get_localized_description()
	flavor_label.text = flavor
	_fill_hero_progress(p_subclass)

	var painting := paladin_select_art if p_subclass == paladin_subclass else trapper_select_art
	if painting:
		hero_art.texture = painting


func _fill_hero_progress(p_subclass: SubclassData) -> void:
	if not SaveManager or not SaveManager.meta_progress or not p_subclass:
		return
	var hero_id := p_subclass.subclass_id
	var level := SaveManager.meta_progress.get_hero_level(hero_id)
	var xp := SaveManager.meta_progress.get_hero_xp(hero_id)
	var xp_needed := SaveManager.get_xp_for_next_level(hero_id)
	level_label.text = TranslationHelper.tr_format("ui.run_prep.level", {"value": level})
	xp_label.text = TranslationHelper.tr_format("ui.run_prep.xp", {"current": xp, "max": xp_needed})
	xp_bar.max_value = maxi(xp_needed, 1)
	xp_bar.value = xp


func _starting_hp(p_subclass: SubclassData) -> int:
	var hp := BASE_HP
	if p_subclass and p_subclass.subclass_id == "paladin":
		hp += VillageBonuses.get_chapel_hp_bonus(VillageBonuses.get_level(VillageBonuses.CHAPEL))
	return hp


func _thumb_style(selected: bool, locked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sb.set_corner_radius_all(4)
	if locked:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.28, 0.28, 0.32, 1.0)
	elif selected:
		sb.set_border_width_all(3)
		sb.border_color = Color(0.95, 0.78, 0.28, 1.0)
	else:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.45, 0.46, 0.5, 0.9)
	return sb


func _update_selection_visuals() -> void:
	var paladin_selected := _selected_subclass == paladin_subclass
	var trapper_unlocked := _is_trapper_unlocked()
	var trapper_selected := trapper_unlocked and _selected_subclass == trapper_subclass
	paladin_thumb.add_theme_stylebox_override("panel", _thumb_style(paladin_selected, false))
	trapper_thumb.add_theme_stylebox_override("panel", _thumb_style(trapper_selected, not trapper_unlocked))
	paladin_portrait.modulate = Color.WHITE if paladin_selected else Color(0.72, 0.72, 0.76, 1.0)
	if trapper_unlocked:
		trapper_portrait.modulate = Color.WHITE if trapper_selected else Color(0.72, 0.72, 0.76, 1.0)


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
			continue_button.disabled = true
			coop_status.visible = true
			coop_status.text = tr("ui.char_select.waiting_partner")
	else:
		GameManager.go_to_run_prep_screen(_selected_class, _selected_subclass)


@rpc("any_peer")
func _rpc_client_character_ready(class_path: String = "", subclass_path: String = "") -> void:
	if MultiplayerManager.is_server() and is_node_ready():
		GameManager.coop_client_class_path = class_path
		GameManager.coop_client_subclass_path = subclass_path
		_coop_client_ready = true
		continue_button.disabled = false
		coop_status.visible = true
		coop_status.text = tr("ui.char_select.partner_ready")
