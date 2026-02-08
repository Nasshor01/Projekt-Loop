extends Control

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var allow_button: Button = %AllowButton
@onready var deny_button: Button = %DenyButton

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	allow_button.pressed.connect(_on_allow_pressed)
	deny_button.pressed.connect(_on_deny_pressed)
	_update_ui_texts()

func _update_ui_texts():
	if title_label:
		title_label.text = tr("ui.consent.title")
	if message_label:
		message_label.text = tr("ui.consent.message")
	if deny_button:
		deny_button.text = tr("ui.consent.no")
	if allow_button:
		allow_button.text = tr("ui.consent.yes")

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
