# Soubor: scenes/CharSelect/RunPrepScreen.gd (FINÁLNÍ VERZE)
extends Control

const PALADIN_PORTRAIT = preload("res://art/icons/paladin portrait.png")
const TRAPPER_PORTRAIT = preload("res://art/icons/trapper_portrait.png")

# Cesty k uzlům
@onready var portrait: TextureRect = $CenterContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/Portrait
@onready var level_label: Label = $CenterContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/LevelLabel
@onready var xp_bar: ProgressBar = $CenterContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/XPBar
@onready var xp_label: Label = $CenterContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/XPLabel
@onready var points_label: Label = $CenterContainer/MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/PointsLabel
@onready var start_button: Button = $CenterContainer/MarginContainer/VBoxContainer/VBoxContainer/StartButton
@onready var back_button: Button = $CenterContainer/MarginContainer/VBoxContainer/VBoxContainer/BackButton
@onready var title_label: Label = $CenterContainer/MarginContainer/VBoxContainer/VBoxContainer/TitleLabel
@onready var skill_tree = $CenterContainer/MarginContainer/VBoxContainer/HSplitContainer/RightPanel/SubViewportContainer/SubViewport/PassiveSkillTree

func _ready():
	start_button.pressed.connect(GameManager.start_new_run)
	back_button.pressed.connect(GameManager.go_to_character_select)
	SaveManager.meta_progress_changed.connect(update_display)
	
	PlayerData.initialize_player(GameManager.selected_class_data, GameManager.selected_subclass_data)
	_update_portrait()
	
	# Skill tree UI skryté — systém je vypnutý
	if is_instance_valid(skill_tree):
		var right_panel = skill_tree.get_parent()
		while right_panel and right_panel.name != "RightPanel" and right_panel.name != "HSplitContainer":
			right_panel = right_panel.get_parent()
		if right_panel and right_panel.name == "RightPanel":
			right_panel.visible = false
			var hsplit = right_panel.get_parent()
			if hsplit is HSplitContainer:
				hsplit.custom_minimum_size = Vector2(0, 0)
		elif skill_tree.get_parent():
			skill_tree.get_parent().visible = false
	
	if is_instance_valid(points_label):
		points_label.visible = false
	
	# Coop: Start smí zmáčknout jen host; klient čeká na přechod na mapu
	if GameManager.is_coop_run and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server():
		start_button.disabled = true
		start_button.text = "Čekám na hostitele…"
	
	_update_ui_texts()
	update_display()

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.run_prep.title")
	if start_button and not (GameManager.is_coop_run and has_node("/root/MultiplayerManager") and not MultiplayerManager.is_server()):
		start_button.text = tr("ui.run_prep.start")
	if back_button:
		back_button.text = tr("ui.common.back")

func _update_portrait() -> void:
	if not is_instance_valid(portrait):
		return
	var subclass = GameManager.selected_subclass_data
	if subclass and subclass.subclass_id == "trapper":
		portrait.texture = TRAPPER_PORTRAIT
	else:
		portrait.texture = PALADIN_PORTRAIT

func update_display():
	var meta = SaveManager.meta_progress
	var xp_needed = SaveManager.get_xp_for_next_level()
	
	level_label.text = TranslationHelper.tr_format("ui.run_prep.level", {"value": meta.player_level})
	if is_instance_valid(points_label):
		points_label.text = ""
	xp_label.text = TranslationHelper.tr_format("ui.run_prep.xp", {"current": meta.total_xp, "max": xp_needed})
	
	xp_bar.max_value = xp_needed
	xp_bar.value = meta.total_xp
