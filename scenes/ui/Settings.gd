extends CanvasLayer

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var language_label: Label = $Panel/VBoxContainer/LanguageSection/LanguageLabel
@onready var language_option: OptionButton = %LanguageOptionButton
@onready var reports_checkbox: CheckBox = %ReportsCheckBox
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var current_locale: String = "en"

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	language_option.item_selected.connect(_on_language_selected)
	reports_checkbox.toggled.connect(_on_reports_toggled)
	
	_setup_language_options()
	_load_current_language()
	_load_report_preference()
	_update_ui_texts()

func _setup_language_options():
	"""Nastaví možnosti jazyka v OptionButton"""
	language_option.clear()
	language_option.add_item(tr("ui.settings.lang.english"), 0)
	language_option.add_item(tr("ui.settings.lang.czech"), 1)
	language_option.set_item_metadata(0, "en")
	language_option.set_item_metadata(1, "cs")

func _load_current_language():
	"""Načte aktuální jazyk a nastaví OptionButton"""
	# Nejdřív zkusíme načíst z uložených preferencí
	var saved_locale = _load_language_preference()
	if saved_locale != "":
		TranslationServer.set_locale(saved_locale)
		current_locale = saved_locale
	else:
		current_locale = TranslationServer.get_locale()
	
	# Nastavíme OptionButton
	if current_locale.begins_with("cs"):
		language_option.selected = 1
	else:
		language_option.selected = 0

func _on_language_selected(index: int):
	"""Změna jazyka"""
	var locale = language_option.get_item_metadata(index)
	if locale != current_locale:
		TranslationServer.set_locale(locale)
		current_locale = locale
		# Uložíme preferenci jazyka
		_save_language_preference(locale)
		_update_ui_texts()
		# Aktualizujeme i MainMenu, pokud je viditelný
		_update_main_menu_if_visible()

func _save_language_preference(locale: String):
	"""Uloží preferenci jazyka do ConfigFile"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "language", locale)
	config.save("user://settings.cfg")

func _load_language_preference() -> String:
	"""Načte preferenci jazyka z ConfigFile"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		return config.get_value("settings", "language", "en")
	return "en"

func _update_ui_texts():
	"""Aktualizuje UI texty pomocí překladů"""
	if title_label:
		title_label.text = tr("ui.settings.title")
	if language_label:
		language_label.text = tr("ui.settings.language")
	if close_button:
		close_button.text = tr("ui.settings.close")
	if reports_checkbox:
		reports_checkbox.text = tr("ui.settings.reports_checkbox")
		reports_checkbox.tooltip_text = tr("ui.settings.reports_tooltip")

func _update_main_menu_if_visible():
	"""Aktualizuje MainMenu texty, pokud je viditelný"""
	# Najdeme MainMenu přes skupinu
	var main_menu_nodes = get_tree().get_nodes_in_group("main_menu")
	for main_menu in main_menu_nodes:
		if main_menu and main_menu.has_method("_update_ui_texts"):
			main_menu._update_ui_texts()
			break

func _on_close_pressed():
	hide()
	GameManager.go_to_main_menu()

func show_settings():
	show()
	_load_current_language()
	_load_report_preference()

func _on_reports_toggled(value: bool):
	if has_node("/root/DebugLogger"):
		DebugLogger.apply_report_consent(value)
	else:
		_save_report_preference(value)

func _load_report_preference():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	var value = true
	if err == OK and config.has_section_key("settings", "can_send_reports"):
		value = bool(config.get_value("settings", "can_send_reports", true))
	if reports_checkbox:
		reports_checkbox.button_pressed = value

func _save_report_preference(value: bool):
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "can_send_reports", value)
	config.save("user://settings.cfg")

func hide_settings():
	hide()
