extends Control

@onready var feedback_text: TextEdit = %FeedbackText
@onready var submit_button: Button = %SubmitButton
@onready var cancel_button: Button = %CancelButton

func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	submit_button.pressed.connect(_on_submit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func open():
	show()
	feedback_text.grab_focus()

func _on_submit_pressed():
	var text = feedback_text.text.strip_edges()
	if text.is_empty():
		return
	DebugLogger.log_info("[PLAYER_FEEDBACK] " + text, "FEEDBACK")
	feedback_text.clear()
	hide()

func _on_cancel_pressed():
	feedback_text.clear()
	hide()
