# Soubor: scenes/CharSelect/RunPrepScreen.gd (FINÁLNÍ VERZE)
extends Control

# Cesty k uzlům
@onready var level_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/LevelLabel
@onready var xp_bar: ProgressBar = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/XPBar
@onready var xp_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/XPLabel
@onready var points_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/LeftPanel/PointsLabel
@onready var start_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/StartButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/BackButton
@onready var skill_tree = $MarginContainer/VBoxContainer/HSplitContainer/RightPanel/SubViewportContainer/SubViewport/PassiveSkillTree

func _ready():
	start_button.pressed.connect(GameManager.start_new_run)
	back_button.pressed.connect(GameManager.go_to_character_select)
	
	SaveManager.meta_progress_changed.connect(update_display)
	update_display()
	
	# Starý kód, který se snažil strom generovat, je pryč.
	# Strom se teď postará sám o sebe díky signálu.

func update_display():
	var meta = SaveManager.meta_progress
	var xp_needed = SaveManager.get_xp_for_next_level()
	
	level_label.text = "Level: %d" % meta.player_level
	points_label.text = "Dovednostní body: %d" % meta.skill_points
	xp_label.text = "XP: %d / %d" % [meta.total_xp, xp_needed]
	
	xp_bar.max_value = xp_needed
	xp_bar.value = meta.total_xp
	
	# Po každé aktualizaci řekneme i stromu, ať se překreslí
	if is_instance_valid(skill_tree) and skill_tree.has_method("_refresh_tree"):
		skill_tree._refresh_tree()
