extends Control

@onready var allow_button: Button = %AllowButton
@onready var deny_button: Button = %DenyButton

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	allow_button.pressed.connect(_on_allow_pressed)
	deny_button.pressed.connect(_on_deny_pressed)

func open():
	show()

func _on_allow_pressed():
	if has_node("/root/DebugLogger"):
		DebugLogger.apply_report_consent(true)
	hide()

func _on_deny_pressed():
	if has_node("/root/DebugLogger"):
		DebugLogger.apply_report_consent(false)
	hide()
