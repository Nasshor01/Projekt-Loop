# ArtifactPromptUI — confirm / pick-card / pick-enemy prompts for artifact choices.
extends CanvasLayer

signal prompt_finished(result: Dictionary)

const CardUIScene = preload("res://scenes/ui/CardUI.tscn")

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var body_label: Label = $Panel/Margin/VBox/Body
@onready var card_row: HBoxContainer = $Panel/Margin/VBox/CardRow
@onready var button_row: HBoxContainer = $Panel/Margin/VBox/ButtonRow
@onready var yes_button: Button = $Panel/Margin/VBox/ButtonRow/YesButton
@onready var no_button: Button = $Panel/Margin/VBox/ButtonRow/NoButton

var _prompt: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	layer = 30
	hide()
	yes_button.pressed.connect(_on_yes)
	no_button.pressed.connect(_on_no)


func is_busy() -> bool:
	return _busy


func show_prompt(prompt: Dictionary) -> void:
	_prompt = prompt
	_busy = true
	_clear_cards()
	title_label.text = tr(String(prompt.get("title_key", "ui.artifact.prompt.title")))
	body_label.text = tr(String(prompt.get("body_key", "")))
	body_label.visible = not body_label.text.is_empty()
	var ptype: String = String(prompt.get("type", "confirm"))
	match ptype:
		"confirm":
			card_row.visible = false
			button_row.visible = true
			yes_button.text = tr(String(prompt.get("yes_key", "ui.common.confirm")))
			no_button.text = tr(String(prompt.get("no_key", "ui.common.skip")))
			no_button.visible = true
		"pick_card":
			card_row.visible = true
			button_row.visible = bool(prompt.get("allow_skip", true))
			yes_button.visible = false
			no_button.visible = bool(prompt.get("allow_skip", true))
			no_button.text = tr(String(prompt.get("no_key", "ui.common.skip")))
			_populate_cards(prompt.get("cards", []) as Array)
		"pick_enemy":
			card_row.visible = false
			button_row.visible = true
			yes_button.visible = false
			no_button.visible = true
			no_button.text = tr(String(prompt.get("no_key", "ui.common.skip")))
			body_label.text = tr(String(prompt.get("body_key", "ui.artifact.eye.deny_hint")))
		_:
			card_row.visible = false
			button_row.visible = true
	show()


func notify_enemy_picked(enemy: Node) -> void:
	if not _busy or String(_prompt.get("type", "")) != "pick_enemy":
		return
	_finish({"accepted": true, "enemy": enemy, "prompt_id": _prompt.get("id", "")})


func _populate_cards(cards: Array) -> void:
	for card_v in cards:
		var card: CardData = card_v as CardData
		if card == null:
			continue
		var card_ui: CardUI = CardUIScene.instantiate() as CardUI
		card_row.add_child(card_ui)
		card_ui.load_card(card)
		card_ui.apply_display_mode(CardUI.DisplayMode.DECK)
		card_ui.is_draggable = false
		if not card_ui.card_clicked.is_connected(_on_card_clicked):
			card_ui.card_clicked.connect(_on_card_clicked)


func _clear_cards() -> void:
	for child in card_row.get_children():
		child.queue_free()


func _on_card_clicked(card_data: CardData) -> void:
	_finish({"accepted": true, "card": card_data, "prompt_id": _prompt.get("id", "")})


func _on_yes() -> void:
	_finish({"accepted": true, "prompt_id": _prompt.get("id", "")})


func _on_no() -> void:
	_finish({"accepted": false, "prompt_id": _prompt.get("id", "")})


func _finish(result: Dictionary) -> void:
	_busy = false
	hide()
	_clear_cards()
	prompt_finished.emit(result)
