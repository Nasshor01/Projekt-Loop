class_name TutorialSpeech
extends Control

signal continue_pressed

const SCENE_PATH := "res://scenes/ui/TutorialSpeech.tscn"
const DUMMY_PORTRAIT := preload("res://art/sprites/units/statue_spirit.png")

@onready var _panel: PanelContainer = $Panel
@onready var _portrait: TextureRect = $Panel/Margin/HBox/Portrait
@onready var _name_label: Label = $Panel/Margin/HBox/VBox/NameLabel
@onready var _body_label: Label = $Panel/Margin/HBox/VBox/BodyLabel
@onready var _continue_button: Button = $Panel/Margin/HBox/VBox/Footer/ContinueButton
@onready var _action_hint: Label = $Panel/Margin/HBox/VBox/Footer/ActionHint

var _awaiting_continue := false
var _pending_speaker := ""
var _pending_body := ""
var _pending_action := ""
var _pending_continue := false
var _has_pending := false
var _bark_timer: Timer = null
var _pre_bark_body := ""
var _barking := false

static func mount_line(parent: Node, line_id: String, bottom: bool = true) -> TutorialSpeech:
	var speech := mount(parent)
	if not is_instance_valid(speech):
		return null
	if bottom:
		speech.use_bottom_anchor()
	speech.show_catalog_action(line_id)
	return speech

static func mount(parent: Node) -> TutorialSpeech:
	if not is_instance_valid(parent):
		return null
	var existing := parent.get_node_or_null("TutorialSpeech") as TutorialSpeech
	if is_instance_valid(existing):
		return existing
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("TutorialSpeech: missing scene at %s" % SCENE_PATH)
		return null
	var speech := packed.instantiate() as TutorialSpeech
	speech.name = "TutorialSpeech"
	parent.add_child(speech)
	return speech

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_panel):
		_panel.gui_input.connect(_on_panel_gui_input)
	if is_instance_valid(_continue_button):
		_continue_button.pressed.connect(_emit_continue)
		_continue_button.text = tr("ui.tutorial.continue")
	if is_instance_valid(_portrait) and _portrait.texture == null:
		_portrait.texture = DUMMY_PORTRAIT
	if _has_pending:
		_has_pending = false
		if _pending_continue:
			show_continue(_pending_speaker, _pending_body)
		else:
			show_action(_pending_speaker, _pending_body, _pending_action)
	elif not _awaiting_continue:
		visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_continue or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_emit_continue()
			get_viewport().set_input_as_handled()

func show_catalog_continue(line_id: String) -> void:
	var beat := _read_catalog(line_id)
	show_continue(String(beat.get("speaker", "")), String(beat.get("body", line_id)))

func show_catalog_action(line_id: String) -> void:
	var beat := _read_catalog(line_id)
	show_action(String(beat.get("speaker", "")), String(beat.get("body", line_id)), String(beat.get("action", "")))

func flash_bark(text: String, hold_seconds: float = 5.5) -> void:
	if text.is_empty() or not is_instance_valid(_body_label):
		return
	if not _barking:
		_pre_bark_body = _body_label.text
	_barking = true
	_body_label.text = text
	if _bark_timer == null:
		_bark_timer = Timer.new()
		_bark_timer.one_shot = true
		add_child(_bark_timer)
		_bark_timer.timeout.connect(_restore_after_bark)
	_bark_timer.start(hold_seconds)

func _restore_after_bark() -> void:
	if not _barking:
		return
	_barking = false
	if is_instance_valid(_body_label):
		_body_label.text = _pre_bark_body

func _clear_bark() -> void:
	_barking = false
	if is_instance_valid(_bark_timer):
		_bark_timer.stop()

func show_continue(speaker: String, body: String) -> void:
	if not is_instance_valid(_body_label):
		_pending_speaker = speaker
		_pending_body = body
		_pending_action = ""
		_pending_continue = true
		_has_pending = true
		_awaiting_continue = true
		visible = true
		return
	_apply_copy(speaker, body, true, "")
	_awaiting_continue = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_panel):
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func show_action(speaker: String, body: String, action_hint: String = "") -> void:
	if not is_instance_valid(_body_label):
		_pending_speaker = speaker
		_pending_body = body
		_pending_action = action_hint
		_pending_continue = false
		_has_pending = true
		_awaiting_continue = false
		visible = true
		return
	_apply_copy(speaker, body, false, action_hint)
	_awaiting_continue = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_panel):
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func use_bottom_anchor() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = -210.0
	offset_bottom = -16.0

func hide_speech() -> void:
	_clear_bark()
	_awaiting_continue = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func refresh_locale() -> void:
	if is_instance_valid(_continue_button):
		_continue_button.text = tr("ui.tutorial.continue")

func _apply_copy(speaker: String, body: String, show_continue: bool, action_hint: String) -> void:
	_clear_bark()
	visible = true
	if is_instance_valid(_name_label):
		_name_label.text = speaker
	if is_instance_valid(_body_label):
		_body_label.text = body
	if is_instance_valid(_continue_button):
		_continue_button.visible = show_continue
		_continue_button.disabled = not show_continue
		_continue_button.text = tr("ui.tutorial.continue")
	if is_instance_valid(_action_hint):
		_action_hint.visible = not show_continue and not action_hint.is_empty()
		_action_hint.text = action_hint

func _on_panel_gui_input(event: InputEvent) -> void:
	if not _awaiting_continue:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_emit_continue()
		accept_event()

func _read_catalog(line_id: String) -> Dictionary:
	var catalog := _dialogue_catalog()
	if catalog != null and catalog.has_method("line"):
		return catalog.line(line_id)
	return {"speaker": "", "body": line_id, "action": ""}

static func _dialogue_catalog() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("DialogueCatalog")

func _emit_continue() -> void:
	if not _awaiting_continue:
		return
	_awaiting_continue = false
	continue_pressed.emit()
