extends CanvasLayer

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var content_label: RichTextLabel = $Panel/VBoxContainer/ScrollContainer/ContentVBox/RichTextLabel

func _ready():
	close_button.pressed.connect(GameManager.go_to_main_menu)
	
	# Nastavíme scroll container, aby se správně zobrazoval
	var scroll_container = $Panel/VBoxContainer/ScrollContainer
	if scroll_container:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	
	_update_ui_texts()

func _update_ui_texts():
	"""Aktualizuje UI texty pomocí překladů"""
	if title_label:
		title_label.text = tr("ui.how_to_play.title")
	if close_button:
		close_button.text = tr("ui.how_to_play.close")
	if content_label:
		content_label.text = _get_how_to_play_text()

func _get_how_to_play_text() -> String:
	"""Vrátí lokalizovaný text pro How to Play"""
	return tr("ui.how_to_play.content")

func show_guide():
	show()
	# Reset scroll pozice na začátek
	var scroll_container = $Panel/VBoxContainer/ScrollContainer
	if scroll_container:
		scroll_container.scroll_vertical = 0

func hide_guide():
	hide()
