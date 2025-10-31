extends PanelContainer

signal restart_run_pressed
signal save_run_pressed
signal back_to_char_select_pressed
signal save_and_quit_pressed
signal back_to_menu_pressed
signal close_pressed

@onready var restart_run_button = %RestartRunButton
@onready var save_run_button = %SaveRunButton
@onready var back_to_char_select_button = %BackToCharSelectButton
@onready var save_and_quit_button = %SaveAndQuitButton
@onready var back_to_menu_button = %BackToMenuButton
@onready var close_button = %CloseButton

func _ready():
	restart_run_button.pressed.connect(func(): emit_signal("restart_run_pressed"))
	save_run_button.pressed.connect(func(): emit_signal("save_run_pressed"))
	back_to_char_select_button.pressed.connect(func(): emit_signal("back_to_char_select_pressed"))
	save_and_quit_button.pressed.connect(func(): emit_signal("save_and_quit_pressed"))
	back_to_menu_button.pressed.connect(func(): emit_signal("back_to_menu_pressed"))
	close_button.pressed.connect(func(): emit_signal("close_pressed"))
	close_button.pressed.connect(hide)
